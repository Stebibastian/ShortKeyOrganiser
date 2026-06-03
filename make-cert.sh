#!/bin/bash
# Richtet lautloses Code-Signing ein: ein EIGENER Signier-Schlüsselbund mit festem
# Passwort, dem codesign dauerhaft vertraut (per set-key-partition-list).
# → Keine GUI-Nachfrage, kein Passwort-Tippen, stabile Signatur über Rebuilds.
# Der Schlüsselbund enthält nur ein selbstsigniertes Wegwerf-Zertifikat (signiert
# nichts Vertrauenswürdiges) – das feste Passwort ist daher unkritisch.
set -euo pipefail

NAME="MenuShortcutRebinder Local Signing"
SIGN_KC="$HOME/Library/Keychains/menushortcut-signing.keychain-db"
KC_PW="menushortcut-local"
OPENSSL="/usr/bin/openssl"

# Schlüsselbund anlegen (falls nötig) und immer entsperren – codesign braucht ihn offen.
if [ ! -f "$SIGN_KC" ]; then
    security create-keychain -p "$KC_PW" "$SIGN_KC"
fi
security set-keychain-settings "$SIGN_KC"          # kein Auto-Lock
security unlock-keychain -p "$KC_PW" "$SIGN_KC"

# In die Suchliste aufnehmen (vorhandene behalten), damit codesign das Zertifikat
# findet. WICHTIG: Pfade einzeln in ein Array lesen, NICHT per Wort-Splitting –
# sonst können Einträge verschmelzen und andere Schlüsselbünde (z. B. der von gh
# genutzte login.keychain) unbrauchbar werden.
current=()
while IFS= read -r line; do
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
    [ -n "$line" ] && current+=("$line")
done < <(security list-keychains -d user)
already=0
for k in "${current[@]}"; do [ "$k" = "$SIGN_KC" ] && already=1; done
if [ "$already" -eq 0 ]; then
    security list-keychains -d user -s "${current[@]}" "$SIGN_KC"
fi

if security find-identity -p codesigning "$SIGN_KC" 2>/dev/null | grep -qF "$NAME"; then
    echo "✓ Signatur bereit – Builds laufen lautlos."
    exit 0
fi

echo "→ Lege lokales Signatur-Zertifikat an (ohne Rückfragen) …"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
"$OPENSSL" req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/cert.cnf" >/dev/null 2>&1
"$OPENSSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:temp -name "$NAME" >/dev/null 2>&1

security import "$TMP/id.p12" -k "$SIGN_KC" -P temp -A -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PW" "$SIGN_KC" >/dev/null 2>&1

if security find-identity -p codesigning "$SIGN_KC" | grep -qF "$NAME"; then
    echo "✓ Eingerichtet – ab jetzt wird lautlos signiert."
else
    echo "⚠ Zertifikat-Setup fehlgeschlagen – Build nutzt ad-hoc (nach Updates ggf."
    echo "  Bedienungshilfen neu erteilen)."
fi
