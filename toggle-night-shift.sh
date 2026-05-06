#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Night Shift
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 🌙
# @raycast.description Toggles macOS Night Shift on or off

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/nightshift-toggle"
SWIFT_SRC="$SCRIPT_DIR/nightshift-toggle.swift"

# --- Primaer: Kompiliertes Swift-Binary verwenden ---
if [[ -x "$BINARY" ]]; then
    OUTPUT=$("$BINARY" 2>&1)
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "$OUTPUT"
        exit 0
    fi
fi

# --- Auto-Kompilierung falls Binary fehlt ---
if [[ ! -x "$BINARY" && -f "$SWIFT_SRC" ]]; then
    swiftc "$SWIFT_SRC" -o "$BINARY" -O 2>/dev/null
    if [[ -x "$BINARY" ]]; then
        OUTPUT=$("$BINARY" 2>&1)
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 0 ]]; then
            echo "$OUTPUT"
            exit 0
        fi
    fi
fi

# --- Fallback: AppleScript UI-Automation ---
APPLESCRIPT_FALLBACK="$SCRIPT_DIR/toggle-night-shift-fallback.applescript"
if [[ -f "$APPLESCRIPT_FALLBACK" ]]; then
    OUTPUT=$(osascript "$APPLESCRIPT_FALLBACK" 2>&1)
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "$OUTPUT"
        exit 0
    else
        echo "Error: Fallback AppleScript failed: $OUTPUT"
        exit 1
    fi
fi

echo "Error: No working Night Shift toggle method found. Run install-raycast-night-shift.sh first."
exit 1
