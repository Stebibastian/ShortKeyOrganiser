#!/bin/bash
# Rendert das App-Icon und baut daraus AppSupport/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")"

ICONSET="AppSupport/AppIcon.iconset"
echo "→ Rendere Icon-Größen …"
rm -rf "$ICONSET"
swift tools/make-icon.swift "$ICONSET"

echo "→ Baue AppIcon.icns …"
iconutil -c icns -o "AppSupport/AppIcon.icns" "$ICONSET"
rm -rf "$ICONSET"
echo "✓ AppSupport/AppIcon.icns"
