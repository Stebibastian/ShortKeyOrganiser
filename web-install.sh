#!/bin/bash
# One-line install of the latest notarized ShortKeyOrganiser release.
# Usage (public repo only):
#   curl -fsSL https://raw.githubusercontent.com/Stebibastian/ShortKeyOrganiser/main/web-install.sh | bash
set -euo pipefail

URL="https://github.com/Stebibastian/ShortKeyOrganiser/releases/latest/download/ShortKeyOrganiser.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading latest version …"
curl -fsSL "$URL" -o "$TMP/ShortKeyOrganiser.zip"

echo "→ Unpacking …"
ditto -x -k "$TMP/ShortKeyOrganiser.zip" "$TMP"

echo "→ Installing to /Applications …"
pkill -x ShortKeyOrganiser 2>/dev/null || true
sleep 1
rm -rf "/Applications/ShortKeyOrganiser.app"
mv "$TMP/ShortKeyOrganiser.app" "/Applications/ShortKeyOrganiser.app"

echo "→ Launching …"
sleep 0.5
# retry: right after a kill+replace, Launch Services can briefly miss the app
open "/Applications/ShortKeyOrganiser.app" 2>/dev/null \
  || { sleep 2; open "/Applications/ShortKeyOrganiser.app" 2>/dev/null; } \
  || { sleep 3; open "/Applications/ShortKeyOrganiser.app"; }
echo "✓ Installed. On first launch, grant Accessibility - the app then relaunches itself."
