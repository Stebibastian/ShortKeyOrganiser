#!/bin/bash
# Deinstalliert MenuShortcutRebinder vollständig:
#   • App aus /Applications + laufende Instanz
#   • eigene Einstellungen (Auslöser, Haltedauer, Kürfel-Registry)
#   • Rechte (Bedienungshilfen/TCC)
#   • lokaler Signier-Schlüsselbund
#   • Build-Artefakte im Projektordner
# Lässt UNANGETASTET: in anderen Apps gesetzte Menü-Kürzel (z. B. eigene
# FileMaker-Kürzel) und den Quellcode/Repo.
set -o pipefail

BUNDLE="com.realview.menushortcutrebinder"
APP_INSTALLED="/Applications/MenuShortcutRebinder.app"
SIGN_KC="$HOME/Library/Keychains/menushortcut-signing.keychain-db"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "→ App beenden …"
pkill -x MenuShortcutRebinder 2>/dev/null && sleep 1 || true

# Vom Tool gesetzte Kürzel anzeigen (werden NICHT automatisch entfernt), bevor die
# Einstellungen gelöscht werden.
echo
echo "ℹ Von diesem Tool gesetzte Menü-Kürzel (bleiben bestehen):"
if defaults read "$BUNDLE" shortcutRecords >/dev/null 2>&1; then
    defaults read "$BUNDLE" shortcutRecords 2>/dev/null \
        | grep -E "appName|menuTitle|display|scope" | sed 's/^/   /'
    echo "   → Wolltest du die zurücksetzen, vor dem Deinstallieren im App-Menü"
    echo "     'Gesetzte Kürzel verwalten → Alle zurücksetzen' nutzen."
else
    echo "   (keine)"
fi

echo
echo "→ Rechte (Bedienungshilfen/TCC) zurücksetzen …"
if tccutil reset All "$BUNDLE" 2>/dev/null; then echo "   ✓"; else echo "   (kein Eintrag mehr)"; fi

echo "→ App aus /Applications entfernen …"
rm -rf "$APP_INSTALLED"

echo "→ Eigene Einstellungen entfernen …"
defaults delete "$BUNDLE" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$BUNDLE.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE.savedState"

echo "→ Build-Artefakte im Projekt entfernen …"
rm -rf "$SCRIPT_DIR/.build" "$SCRIPT_DIR/MenuShortcutRebinder.app"

# Signier-Schlüsselbund entfernen. WICHTIG: Suchliste sicher per Array filtern
# (nie per Wort-Splitting – das würde andere Schlüsselbünde zerschießen).
if [ -f "$SIGN_KC" ]; then
    echo "→ Lokalen Signier-Schlüsselbund entfernen …"
    keep=()
    while IFS= read -r line; do
        line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
        if [ -n "$line" ] && [ "$line" != "$SIGN_KC" ]; then keep+=("$line"); fi
    done < <(security list-keychains -d user)
    if [ "${#keep[@]}" -gt 0 ]; then
        security list-keychains -d user -s "${keep[@]}"
    fi
    security delete-keychain "$SIGN_KC" 2>/dev/null || true
    echo "   ✓"
fi

echo
echo "✓ MenuShortcutRebinder ist deinstalliert."
echo "  Unangetastet geblieben: in anderen Apps gesetzte Menü-Kürzel + der Quellcode."
echo "  Optional: das Alt-Zertifikat 'MenuShortcutRebinder Self-Signed' im Login-"
echo "  Schlüsselbund kannst du bei Bedarf in 'Schlüsselbundverwaltung' löschen."
