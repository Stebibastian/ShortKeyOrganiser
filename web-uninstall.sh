#!/bin/bash
# Ein-Zeilen-Deinstaller:
#   curl -fsSL https://raw.githubusercontent.com/Stebibastian/MenuShortcutRebinder/main/web-uninstall.sh | bash
# Entfernt App, eigene Einstellungen, Rechte, Signier-Schlüsselbund und den
# Online-Installer-Quellcode. Lässt in anderen Apps gesetzte Menü-Kürzel bestehen
# (die funktionieren als normale macOS-App-Kurzbefehle eigenständig weiter).
set -o pipefail

BUNDLE="com.realview.menushortcutrebinder"
SIGN_KC="$HOME/Library/Keychains/menushortcut-signing.keychain-db"

echo "→ App beenden …"
pkill -x MenuShortcutRebinder 2>/dev/null && sleep 1 || true

echo "→ Rechte (Bedienungshilfen/TCC) zurücksetzen …"
tccutil reset All "$BUNDLE" 2>/dev/null || true

echo "→ App aus /Applications entfernen …"
rm -rf "/Applications/MenuShortcutRebinder.app"

echo "→ Eigene Einstellungen entfernen …"
defaults delete "$BUNDLE" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$BUNDLE.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE.savedState"

echo "→ Quellcode des Online-Installers entfernen …"
rm -rf "$HOME/.menushortcutrebinder"

echo "→ Lokalen Signier-Schlüsselbund entfernen (sichere Array-Filterung) …"
if [ -f "$SIGN_KC" ]; then
    keep=()
    while IFS= read -r line; do
        line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
        if [ -n "$line" ] && [ "$line" != "$SIGN_KC" ]; then keep+=("$line"); fi
    done < <(security list-keychains -d user)
    if [ "${#keep[@]}" -gt 0 ]; then
        security list-keychains -d user -s "${keep[@]}"
    fi
    security delete-keychain "$SIGN_KC" 2>/dev/null || true
fi

echo
echo "✓ MenuShortcutRebinder ist deinstalliert."
echo "  Bestehen bleiben: in anderen Apps gesetzte Menü-Kürzel (laufen als normale"
echo "  macOS-App-Kurzbefehle weiter; verwalten unter Systemeinstellungen → Tastatur →"
echo "  Tastaturkurzbefehle → App-Kurzbefehle)."
echo "  Bedienungshilfen-Eintrag bei Bedarf in Systemeinstellungen → Datenschutz &"
echo "  Sicherheit → Bedienungshilfen mit '–' entfernen."
