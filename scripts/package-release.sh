#!/usr/bin/env bash
set -euo pipefail

package="${1:-gitci-screens-local}"
binary_path="${2:-.build/release/gitci-screens}"

if [[ ! -x "$binary_path" ]]; then
  echo "Missing executable binary at $binary_path" >&2
  exit 1
fi

rm -rf "dist/$package"
mkdir -p "dist/$package/bin"
mkdir -p "dist/$package/share/gitci-screens"

cp "$binary_path" "dist/$package/bin/gitci-screens"
rsync -a js/ "dist/$package/share/gitci-screens/js/" --exclude ".vite"
rsync -a templates/ "dist/$package/share/gitci-screens/templates/"
rsync -a schemas/ "dist/$package/share/gitci-screens/schemas/"

tar -czf "dist/$package.tar.gz" -C dist "$package"
echo "dist/$package.tar.gz"
