#!/usr/bin/env bash
#
# Fail when helm-docs could not render a chart.
#
# helm-docs reports every per-chart failure - a template error, an unreadable
# Chart.yaml, a missing dependency, a bad sort order - through log.Warnf and
# still exits 0, so a job that only checks its exit status is green on a chart
# whose README it truncated. Worse, the truncated render is deterministic: it is
# byte-identical on every later run, so the diff check that follows reports the
# README as up to date and the broken docs stay published. That is how
# charts/influxdb3-core shipped a cut-off README for four months (HOMAAA-221).
#
# Every warning and error helm-docs 1.14.2 logs means something was skipped,
# defaulted or failed; none of them is informational. So any of them fails this
# check, which also covers the failure modes nobody has hit yet.
#
# Usage: check_helm_docs_render.sh [chart-search-root]
set -euo pipefail

root="${1:-.}"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# --dry-run renders to stdout, so this pass cannot touch the README.md files the
# push step writes. Every other option stays at its default because the push
# step passes none either - a flag added to the action has to be added here too
# or the two stop rendering the same thing.
status=0
helm-docs --dry-run --chart-search-root "$root" >/dev/null 2>"$log" || status=$?

cat "$log" >&2

if [ "$status" -ne 0 ]; then
  echo "::error::helm-docs exited $status for chart-search-root $root"
  exit 1
fi

# logrus text format on a non-TTY: `time="..." level=warning msg="..."`.
if failures=$(grep -E '^(time="[^"]*" )?level=(warning|error|fatal|panic)' "$log"); then
  while IFS= read -r line; do
    echo "::error::$line"
  done <<<"$failures"
  echo "::error::helm-docs could not render every chart under $root; the README it wrote is incomplete"
  exit 1
fi

echo "helm-docs rendered every chart under $root with no warnings."
