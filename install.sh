#!/bin/bash
# Ein Befehl: Signatur einrichten (lautlos) → bauen → nach /Applications → starten.
set -euo pipefail
cd "$(dirname "$0")"

./make-cert.sh      # richtet lautloses Signieren ein (einmalig) + entsperrt den Schlüsselbund
./make-app.sh

DEST="/Applications/MenuShortcutRebinder.app"
echo "→ Installiere nach $DEST …"
rm -rf "$DEST"
cp -R "MenuShortcutRebinder.app" "$DEST"

echo "→ Starte …"
open "$DEST"
echo "✓ Installiert. Das ⌘-Symbol erscheint in der Menüleiste."
echo "  Beim ersten Mal: Bedienungshilfen freigeben – die App startet sich danach von selbst neu."
