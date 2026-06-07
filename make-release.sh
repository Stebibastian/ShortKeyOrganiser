#!/bin/bash
# Baut ShortKeyOrganiser, signiert mit Developer ID (Hardened Runtime),
# notarisiert bei Apple und staplet das Ticket -> warnungsfrei auf jedem Mac.
# Bundle wird in einem Temp-Ordner AUSSERHALB iCloud gebaut/signiert
# (iCloud hängt sonst com.apple.FinderInfo an, an dem codesign scheitert).
# Ergebnis: ShortKeyOrganiser.zip im Projektordner (für GitHub-Release).
set -euo pipefail
cd "$(dirname "$0")"
PROJ="$(pwd)"

SIGN_ID="Developer ID Application: Sebastian Kardos (GW847K38C6)"
NOTARY_PROFILE="ShortKeyOrganiser-Notary"
ZIP="ShortKeyOrganiser.zip"

echo "→ Build (release) …"
swift build -c release

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/ShortKeyOrganiser.app"

echo "→ Bundle in Temp-Ordner …"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/MenuShortcutRebinder" "$APP/Contents/MacOS/ShortKeyOrganiser"
cp "AppSupport/Info.plist" "$APP/Contents/Info.plist"
[ -f "AppSupport/AppIcon.icns" ] || ./make-icon.sh
cp "AppSupport/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP" 2>/dev/null || true

echo "→ Signiere mit Developer ID + Hardened Runtime …"
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "→ ZIP für die Notarisierung …"
ditto -c -k --keepParent "$APP" "$WORK/$ZIP"

echo "→ Notarisiere bei Apple (kann ein paar Minuten dauern) …"
xcrun notarytool submit "$WORK/$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "→ Ticket an die App heften …"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "→ Finales ZIP (mit Ticket) in den Projektordner …"
rm -f "$PROJ/$ZIP"
ditto -c -k --keepParent "$APP" "$PROJ/$ZIP"

echo ""
echo "✓ Fertig: $PROJ/$ZIP"
echo "  Gatekeeper-Prüfung:"
spctl -a -vvv "$APP" 2>&1 | head -4
