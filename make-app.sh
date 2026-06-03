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

# Stabiles Zertifikat bevorzugen (hält die Bedienungshilfen-Freigabe über Rebuilds);
# sonst ad-hoc.
CERT_NAME="MenuShortcutRebinder Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -qF "$CERT_NAME"; then
    echo "→ Signiere mit '$CERT_NAME' …"
    codesign --force --sign "$CERT_NAME" --identifier com.realview.menushortcutrebinder "$APP"
else
    echo "→ Signiere ad-hoc (für dauerhafte Rechte einmal ./make-cert.sh ausführen) …"
    codesign --force --sign - --identifier com.realview.menushortcutrebinder "$APP"
fi

echo "✓ Fertig: $(pwd)/$APP"
echo "  Starten mit:  open \"$APP\""
