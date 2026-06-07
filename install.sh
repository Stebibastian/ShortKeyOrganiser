#!/bin/bash
# Ein Befehl: Signatur einrichten (lautlos) → bauen → nach /Applications → starten.
set -euo pipefail
cd "$(dirname "$0")"

./make-cert.sh || echo "  (certificate setup skipped - using existing or ad-hoc)"
./make-app.sh

DEST="/Applications/ShortKeyOrganiser.app"

# Laufende Instanz(en) beenden (alter + neuer Name), sonst kann 'open' mit Fehler -600 scheitern.
pkill -x ShortKeyOrganiser 2>/dev/null || true
pkill -x MenuShortcutRebinder 2>/dev/null || true
sleep 1

echo "→ Installing to $DEST …"
rm -rf "$DEST" "/Applications/MenuShortcutRebinder.app"   # alte Namens-Variante mit entfernen
cp -R "ShortKeyOrganiser.app" "$DEST"

# Launch Services neu registrieren, damit Finder/Programme sofort den neuen Namen zeigen.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true

echo "→ Launching …"
open "$DEST" 2>/dev/null || { sleep 2; open "$DEST"; }
echo "✓ Installed. The ⌘ icon appears in the menu bar."
echo "  First time: grant Accessibility - the app then relaunches itself."
