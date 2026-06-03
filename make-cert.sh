#!/bin/bash
# Erzeugt einmalig ein selbstsigniertes Code-Signing-Zertifikat im Login-Schlüsselbund.
# Damit bleibt die Signatur über Rebuilds STABIL → die Bedienungshilfen-Freigabe
# (TCC) bleibt erhalten und muss nicht nach jedem Build neu erteilt werden.
set -euo pipefail

CERT_NAME="MenuShortcutRebinder Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
# System-OpenSSL (LibreSSL) erzeugt für Apples `security` kompatibles PKCS12;
# Homebrew-OpenSSL 3 nicht (MAC-Verifikation schlägt fehl).
OPENSSL="/usr/bin/openssl"

if security find-identity -p codesigning 2>/dev/null | grep -qF "$CERT_NAME"; then
    echo "✓ Zertifikat existiert bereits: $CERT_NAME"
else
    echo "→ Erzeuge selbstsigniertes Zertifikat: $CERT_NAME"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    cat > "$TMP/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $CERT_NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

    "$OPENSSL" req -x509 -newkey rsa:2048 -nodes \
        -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
        -days 3650 -config "$TMP/cert.cnf" >/dev/null 2>&1

    "$OPENSSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
        -out "$TMP/id.p12" -passout pass:temp -name "$CERT_NAME" >/dev/null 2>&1

    # -A: alle Programme dürfen den Schlüssel nutzen; -T codesign: explizit erlauben
    security import "$TMP/id.p12" -k "$KEYCHAIN" -P temp -A -T /usr/bin/codesign >/dev/null
    echo "✓ Importiert."
    security find-identity -p codesigning | grep -qF "$CERT_NAME" || {
        echo "⚠ Zertifikat nicht in der Codesigning-Liste – Build fällt auf ad-hoc zurück."
        exit 1
    }
fi

# Ohne dies fragt der Schlüsselbund bei JEDEM Signieren nach dem Passwort.
# set-key-partition-list erlaubt Apple-Tools (codesign) den Zugriff dauerhaft.
echo
echo "→ Erlaube 'codesign' den Schlüsselzugriff ohne ständige Nachfrage …"
if [ -e /dev/tty ]; then
    ok=0
    # Direkt vom Terminal lesen (/dev/tty) + mehrere Versuche, damit ein
    # versehentlich leeres Passwort (z. B. aus einem eingefügten Befehlsblock)
    # nicht gleich abbricht.
    for _ in 1 2 3; do
        printf "  macOS-Anmeldepasswort (Eingabe unsichtbar): " > /dev/tty
        KCPW=""
        IFS= read -r -s KCPW < /dev/tty || true
        printf "\n" > /dev/tty
        if [ -n "$KCPW" ] && security set-key-partition-list \
                -S apple-tool:,apple: -s -k "$KCPW" "$KEYCHAIN" >/dev/null 2>&1; then
            echo "✓ Erledigt – codesign signiert ab jetzt ohne Nachfrage."
            ok=1
            break
        fi
        echo "  ✗ leer oder falsch – nochmal …"
    done
    unset KCPW
    if [ "$ok" -ne 1 ]; then
        echo "⚠ Nicht gesetzt. Einfachste Alternative: beim nächsten ./install.sh im"
        echo "  Schlüsselbund-Dialog 'Immer erlauben' wählen (statt 'Erlauben')."
    fi
else
    echo "ℹ Kein Terminal – beim ersten Signieren im Dialog 'Immer erlauben' wählen."
fi
