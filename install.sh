#!/bin/bash
# Baut die App und installiert sie nach /Applications, dann Start.
set -euo pipefail
cd "$(dirname "$0")"

./make-app.sh

DEST="/Applications/MenuShortcutRebinder.app"
echo "→ Installiere nach $DEST …"
rm -rf "$DEST"
cp -R "MenuShortcutRebinder.app" "$DEST"

echo "→ Starte …"
open "$DEST"
echo "✓ Installiert. Das ⌘-Symbol erscheint in der Menüleiste."
echo "  Beim ersten Mal: Bedienungshilfen freigeben und über das Menü „Beenden“ → erneut starten."
