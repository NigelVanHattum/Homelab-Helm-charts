#!/usr/bin/env bash
# Fail when helm-docs could not render a chart: it logs every per-chart failure as a warning and exits 0 (HOMAAA-221).
# Usage: check_helm_docs_render.sh [chart-search-root]
set -euo pipefail

root="${1:-.}"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Keep options equal to the helm-docs-pr.yaml push step, or the two render different things.
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
