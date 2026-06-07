#!/bin/bash
# Ein-Befehl-Installation der neuesten notarisierten ShortKeyOrganiser-Release.
# Aufruf (nur bei öffentlichem Repo):
#   curl -fsSL https://raw.githubusercontent.com/Stebibastian/ShortKeyOrganiser/main/web-install.sh | bash
set -euo pipefail

URL="https://github.com/Stebibastian/ShortKeyOrganiser/releases/latest/download/ShortKeyOrganiser.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Lade neueste Version …"
curl -fsSL "$URL" -o "$TMP/ShortKeyOrganiser.zip"

echo "→ Entpacke …"
ditto -x -k "$TMP/ShortKeyOrganiser.zip" "$TMP"

echo "→ Installiere nach /Applications …"
pkill -x ShortKeyOrganiser 2>/dev/null || true
sleep 1
rm -rf "/Applications/ShortKeyOrganiser.app"
mv "$TMP/ShortKeyOrganiser.app" "/Applications/ShortKeyOrganiser.app"

echo "→ Starte …"
open "/Applications/ShortKeyOrganiser.app"
echo "✓ Installiert. Beim ersten Mal Bedienungshilfen freigeben – die App startet sich dann selbst neu."
