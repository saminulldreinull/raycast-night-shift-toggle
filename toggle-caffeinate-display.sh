#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Caffeinate Display
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon ☕
# @raycast.description Toggles caffeinate -d to keep the display awake.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/CaffeinateDisplayMenu.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/CaffeinateDisplayMenu"
PID_FILE="$HOME/.caffeinate-display-menu/pid"
STATE_FILE="$HOME/.caffeinate-display-menu/state"
SWIFT_SRC="$SCRIPT_DIR/caffeinate-display-menu.swift"
OLD_LABEL="com.raycast.caffeinate-display-menu"
OLD_SERVICE="gui/$(id -u)/$OLD_LABEL"
OLD_PID_FILE="$HOME/Library/Application Support/Raycast Scripts/caffeinate-display.pid"
OLDER_LABEL="com.raycast.caffeinate-display"
OLDER_SERVICE="gui/$(id -u)/$OLDER_LABEL"

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
    [[ "$args" == *"CaffeinateDisplayMenu"* ]]
}

running_pid() {
    local pid
    pid="$(read_pid)"
    if is_helper_pid "${pid:-}"; then
        printf '%s\n' "$pid"
    fi
}

is_running() {
    [[ -n "$(running_pid)" ]]
}

read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null
    else
        echo "off"
    fi
}

write_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s\n' "$1" > "$STATE_FILE"
}

cleanup_old_toggle() {
    if launchctl print "$OLD_SERVICE" >/dev/null 2>&1; then
        launchctl remove "$OLD_LABEL" >/dev/null 2>&1 || launchctl bootout "$OLD_SERVICE" >/dev/null 2>&1 || true
    fi
    if launchctl print "$OLDER_SERVICE" >/dev/null 2>&1; then
        launchctl remove "$OLDER_LABEL" >/dev/null 2>&1 || launchctl bootout "$OLDER_SERVICE" >/dev/null 2>&1 || true
    fi
    rm -f "$OLD_PID_FILE" 2>/dev/null || true
}

build_helper_app() {
    mkdir -p "$APP_BUNDLE/Contents/MacOS"

    if [[ ! -x "$APP_EXECUTABLE" || "$SWIFT_SRC" -nt "$APP_EXECUTABLE" ]]; then
        swiftc "$SWIFT_SRC" -o "$APP_EXECUTABLE" -O -framework Cocoa 2>/dev/null
        chmod +x "$APP_EXECUTABLE"
    fi
}

cleanup_old_toggle

build_helper_app

if [[ ! -x "$APP_EXECUTABLE" ]]; then
    echo "Error: Could not build menu bar helper"
    exit 1
fi

if is_running; then
    PID="$(running_pid)"
    CURRENT_STATE="$(read_state)"

    if [[ "$CURRENT_STATE" == "on" ]]; then
        write_state "off"
        kill -USR1 "$PID" 2>/dev/null || true
        echo "Caffeinate OFF 🫗"
        exit 0
    fi

    write_state "on"
    kill -USR1 "$PID" 2>/dev/null || true
    echo "Caffeinate ON ☕"
    exit 0
fi

write_state "on"

if open -g "$APP_BUNDLE" >/dev/null 2>&1; then
    for _ in {1..20}; do
        if is_running; then
            echo "Caffeinate ON ☕"
            exit 0
        fi
        sleep 0.1
    done
fi

echo "Error: Could not start Caffeinate menu bar helper"
exit 1
