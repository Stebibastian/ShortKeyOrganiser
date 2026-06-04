#!/bin/bash
# Baut das Release-Binary und verpackt es in ein signiertes .app-Bundle,
# damit die Bedienungshilfen-Freigabe dauerhaft erhalten bleibt.
set -euo pipefail
cd "$(dirname "$0")"

APP="MenuShortcutRebinder.app"

echo "→ Kompiliere (release) …"
swift build -c release

echo "→ Baue $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/MenuShortcutRebinder" "$APP/Contents/MacOS/MenuShortcutRebinder"
cp "AppSupport/Info.plist" "$APP/Contents/Info.plist"

# Icon bei Bedarf erzeugen und einbetten
if [ ! -f "AppSupport/AppIcon.icns" ]; then
    ./make-icon.sh
fi
cp "AppSupport/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Erweiterte Attribute entfernen (iCloud/Finder hängt sie an → codesign lehnt sonst
# mit „resource fork … not allowed" ab).
xattr -cr "$APP"

# Lautloses Signieren über den lokalen Signier-Schlüsselbund (siehe make-cert.sh);
# hält die Bedienungshilfen-Freigabe über Rebuilds stabil. Sonst ad-hoc.
CERT_NAME="MenuShortcutRebinder Local Signing"
SIGN_KC="$HOME/Library/Keychains/menushortcut-signing.keychain-db"
[ -f "$SIGN_KC" ] && security unlock-keychain -p "menushortcut-local" "$SIGN_KC" 2>/dev/null || true
if security find-identity -p codesigning 2>/dev/null | grep -qF "$CERT_NAME"; then
    echo "→ Signiere lautlos mit lokalem Zertifikat …"
    codesign --force --sign "$CERT_NAME" --identifier com.realview.menushortcutrebinder "$APP"
else
    echo "→ Signiere ad-hoc (für stabile Rechte einmal ./make-cert.sh ausführen) …"
    codesign --force --sign - --identifier com.realview.menushortcutrebinder "$APP"
fi

echo "✓ Fertig: $(pwd)/$APP"
echo "  Starten mit:  open \"$APP\""
