#!/bin/bash
# install-raycast-night-shift.sh
# Installiert und kompiliert den Night Shift Raycast Script Command

set -e

SCRIPTS_DIR="$HOME/raycast-scripts"
SWIFT_SRC="$SCRIPTS_DIR/nightshift-toggle.swift"
BINARY="$SCRIPTS_DIR/nightshift-toggle"
SCRIPT_CMD="$SCRIPTS_DIR/toggle-night-shift.sh"

echo "=== Night Shift Raycast Script Command – Installation ==="
echo ""

# 1. Ordner pruefen
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "❌ Ordner $SCRIPTS_DIR nicht gefunden."
    echo "   Bitte zuerst die Dateien anlegen."
    exit 1
fi

# 2. Swift kompilieren
echo "▶ Kompiliere Swift-Helper..."
if [[ -f "$SWIFT_SRC" ]]; then
    if swiftc "$SWIFT_SRC" -o "$BINARY" -O 2>&1; then
        echo "  ✅ Binary erstellt: $BINARY"
    else
        echo "  ⚠️  Kompilierung fehlgeschlagen."
        echo "     Fallback auf AppleScript wird verwendet."
        echo "     Xcode Command Line Tools installieren: xcode-select --install"
    fi
else
    echo "  ⚠️  Swift-Quelldatei nicht gefunden: $SWIFT_SRC"
fi

# 3. Script Command ausfuehrbar machen
echo "▶ Setze Dateiberechtigungen..."
chmod +x "$SCRIPT_CMD"
echo "  ✅ $SCRIPT_CMD ist ausfuehrbar"

if [[ -x "$BINARY" ]]; then
    chmod +x "$BINARY"
    echo "  ✅ $BINARY ist ausfuehrbar"
fi

# 4. Schnelltest
echo ""
echo "▶ Teste Night Shift Toggle..."
if [[ -x "$BINARY" ]]; then
    OUTPUT=$("$BINARY" 2>&1) && echo "  ✅ Test erfolgreich: $OUTPUT" || echo "  ⚠️  Test-Ausgabe: $OUTPUT"
    # Sofort zurueck-toggeln
    sleep 0.5
    "$BINARY" >/dev/null 2>&1 || true
    echo "  ↩️  Zurueck-getoggelt (Originalzustand wiederhergestellt)"
else
    echo "  ⏭️  Kein Binary – AppleScript-Fallback wird beim ersten Aufruf getestet."
fi

echo ""
echo "=========================================="
echo "  ✅ Installation abgeschlossen!"
echo "=========================================="
echo ""
echo "NÄCHSTE SCHRITTE (manuell in Raycast):"
echo ""
echo "  1. Raycast öffnen (⌘ + Leertaste oder dein Raycast-Hotkey)"
echo "  2. 'Script Commands' eingeben und öffnen"
echo "  3. 'Add Script Directory' wählen"
echo "  4. Ordner auswählen: $SCRIPTS_DIR"
echo "  5. Danach: 'Toggle Night Shift' in Raycast suchen"
echo "  6. Optional: Hotkey zuweisen über das ⌘K-Menü"
echo ""
echo "BERECHTIGUNGEN (falls AppleScript-Fallback nötig):"
echo "  → Systemeinstellungen > Datenschutz & Sicherheit > Bedienungshilfen"
echo "  → Raycast muss dort aktiviert sein"
echo "  → Systemeinstellungen > Datenschutz & Sicherheit > Automation"
echo "  → Raycast muss 'System Events' steuern dürfen"
echo ""
