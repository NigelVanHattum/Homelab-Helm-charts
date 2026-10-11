#!/usr/bin/env bash
# Self-check for check_helm_docs_render.sh. Fixtures live in a temp dir: committed ones would get their README rendered and pushed by the docs workflow.
# Needs helm-docs on PATH.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
check="$here/check_helm_docs_render.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# $1 = chart directory, stdin = the README.md.gotmpl body
make_chart() {
  mkdir -p "$1"
  cat > "$1/Chart.yaml" <<'YAML'
apiVersion: v2
name: fixture
description: Fixture chart for the helm-docs render check
type: application
version: 0.1.0
YAML
  cat > "$1/values.yaml" <<'YAML'
# -- Number of replicas
replicaCount: 1
YAML
  cat > "$1/README.md.gotmpl"
}

make_chart "$work/good/fixture" <<'GOTMPL'
{{ template "chart.header" . }}

{{ template "chart.description" . }}

{{ template "chart.valuesSection" . }}
GOTMPL

make_chart "$work/bad/fixture" <<'GOTMPL'
{{ template "chart.header" . }}

Name your resources after the release:

```yaml
metadata:
  name: "{{ .Release.Name }}-extra"
```

{{ template "chart.valuesSection" . }}
GOTMPL

fail=0

if out=$(bash "$check" "$work/good" 2>&1); then
  if ! grep -q 'with no warnings' <<<"$out"; then
    echo "$out"
    echo "::error::the guard passed the good fixture without reporting a clean render"
    fail=1
  fi
else
  echo "$out"
  echo "::error::the guard rejected the good fixture"
  fail=1
fi

out=$(bash "$check" "$work/bad" 2>&1) && status=0 || status=$?
# Require the render error itself: a script typo also exits 1.
if [ "$status" -ne 1 ] ||
  ! grep -q '^::error::' <<<"$out" ||
  ! grep -q 'Error generating documentation for chart' <<<"$out"; then
  echo "$out"
  echo "::error::the guard did not reject the chart with the broken template (exit $status)"
  fail=1
fi

[ "$fail" -eq 0 ] && echo "check_helm_docs_render.sh accepts the good fixture and rejects the broken one."
exit $fail
