#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Low Power Mode
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon 🔋
# @raycast.description Toggles macOS Low Power Mode and shows a menu bar icon while it is on.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/LowPowerModeMenu.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/LowPowerModeMenu"
PID_FILE="$HOME/.low-power-mode-menu/pid"
SWIFT_SRC="$SCRIPT_DIR/low-power-mode-menu.swift"

get_power_mode() {
    /usr/bin/pmset -g | awk '/^[[:space:]]*(powermode|lowpowermode)[[:space:]]/ {print $2; exit}'
}

read_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

is_helper_pid() {
    local pid="$1"
    local args

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1

    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    [[ "$args" == *"LowPowerModeMenu"* ]]
}

running_pid() {
    local pid
    pid="$(read_pid)"
    if is_helper_pid "${pid:-}"; then
        printf '%s\n' "$pid"
    fi
}

stop_helper() {
    local pid
    pid="$(running_pid)"
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
    fi
}

build_helper_app() {
    mkdir -p "$APP_BUNDLE/Contents/MacOS"

    if [[ ! -x "$APP_EXECUTABLE" || "$SWIFT_SRC" -nt "$APP_EXECUTABLE" ]]; then
        swiftc "$SWIFT_SRC" -o "$APP_EXECUTABLE" -O -framework Cocoa 2>/dev/null
        chmod +x "$APP_EXECUTABLE"
    fi
}

set_low_power_mode() {
    local value="$1"

    if sudo -n /usr/bin/pmset -a lowpowermode "$value"; then
        return $?
    fi

    echo "Run install-low-power-mode-passwordless.sh once"
    return 1
}

start_helper() {
    build_helper_app

    if [[ ! -x "$APP_EXECUTABLE" ]]; then
        echo "Error: Could not build Low Power menu bar helper"
        exit 1
    fi

    open -g "$APP_BUNDLE" >/dev/null 2>&1 || return 1
}

CURRENT_MODE="$(get_power_mode)"

if [[ "$CURRENT_MODE" == "1" ]]; then
    if set_low_power_mode 0 >/dev/null 2>&1; then
        stop_helper
        echo "Low Power Mode OFF ⚡"
        exit 0
    fi

    echo "Low Power Mode unchanged"
    exit 1
fi

if set_low_power_mode 1 >/dev/null 2>&1; then
    sleep 0.2

    if [[ "$(get_power_mode)" == "1" ]]; then
        start_helper >/dev/null 2>&1 || true
        echo "Low Power Mode ON 🔋"
        exit 0
    fi
fi

echo "Low Power Mode unchanged"
exit 1
