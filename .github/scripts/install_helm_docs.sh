#!/usr/bin/env bash
# Install helm-docs from its GitHub release, checked against a sha256 pinned here: release assets are mutable (HOMAAA-225).
set -euo pipefail

version=1.14.2
asset="helm-docs_${version}_Linux_x86_64.tar.gz"
# Matches the release's checksums.txt and a local hash of the asset; bump both lines together.
sha256=a8cf72ada34fad93285ba2a452b38bdc5bd52cc9a571236244ec31022928d6cc

dir="${RUNNER_TEMP:-$(mktemp -d)}/helm-docs"
mkdir -p "$dir"
curl -fsSL --retry 3 -o "$dir/$asset" "https://github.com/norwoodj/helm-docs/releases/download/v${version}/${asset}"
(cd "$dir" && echo "$sha256  $asset" | sha256sum -c -)
tar -xzf "$dir/$asset" -C "$dir" helm-docs
rm "$dir/$asset"
"$dir/helm-docs" --version

echo "$dir" >>"${GITHUB_PATH:-/dev/stdout}"
