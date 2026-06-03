#!/bin/bash
# Ein-Zeilen-Installer von GitHub:
#   curl -fsSL https://raw.githubusercontent.com/Stebibastian/MenuShortcutRebinder/main/bootstrap.sh | bash
# Holt den Quellcode und baut + installiert lokal (lautlos signiert, keine Prompts).
set -euo pipefail

REPO="https://github.com/Stebibastian/MenuShortcutRebinder.git"
DEST="$HOME/.menushortcutrebinder/src"

if ! command -v swift >/dev/null 2>&1; then
    echo "⚠ Xcode Command Line Tools (Swift) fehlen."
    echo "  Bitte einmal ausführen:   xcode-select --install"
    echo "  …und diesen Installer danach erneut starten."
    exit 1
fi

echo "→ Hole Quellcode nach $DEST …"
if [ -d "$DEST/.git" ]; then
    git -C "$DEST" pull --ff-only
else
    mkdir -p "$(dirname "$DEST")"
    git clone "$REPO" "$DEST"
fi

cd "$DEST"
chmod +x ./*.sh 2>/dev/null || true
./install.sh

echo
echo "✓ MenuShortcutRebinder installiert – ⌘-Symbol erscheint in der Menüleiste."
echo "  Einmal Bedienungshilfen freigeben → die App startet sich selbst neu. Fertig."
