#!/bin/bash

# Installs a tightly scoped sudoers rule so Raycast can toggle Low Power Mode
# without prompting for an administrator password every time.

set -euo pipefail

SUDOERS_FILE="/private/etc/sudoers.d/raycast-low-power-mode"
TEMP_FILE="$(mktemp /tmp/raycast-low-power-mode-sudoers.XXXXXX)"
APPLESCRIPT_FILE="$(mktemp /tmp/raycast-low-power-mode-install.XXXXXX.applescript)"

cleanup() {
    rm -f "$TEMP_FILE"
    rm -f "$APPLESCRIPT_FILE"
}
trap cleanup EXIT

cat > "$TEMP_FILE" <<'EOF'
# Allow admin users to toggle macOS Low Power Mode from Raycast without a password.
Cmnd_Alias RAYCAST_LOW_POWER_MODE = /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1
%admin ALL=(root) NOPASSWD: RAYCAST_LOW_POWER_MODE
EOF

echo "Validating sudoers rule..."
/usr/sbin/visudo -cf "$TEMP_FILE" >/dev/null

echo "Installing sudoers rule. macOS will ask for your admin password once..."
cat > "$APPLESCRIPT_FILE" <<'APPLESCRIPT'
on run argv
    set src to item 1 of argv
    set dst to item 2 of argv
    set cmd to "/bin/mkdir -p /private/etc/sudoers.d && /usr/bin/install -o root -g wheel -m 0440 " & quoted form of src & " " & quoted form of dst & " && /usr/sbin/visudo -cf /private/etc/sudoers"
    do shell script cmd with administrator privileges
end run
APPLESCRIPT
/usr/bin/osascript "$APPLESCRIPT_FILE" "$TEMP_FILE" "$SUDOERS_FILE"

echo "Testing passwordless Low Power Mode permission..."
if /usr/bin/sudo -n -l /usr/bin/pmset -a lowpowermode 1 >/dev/null 2>&1 \
    && /usr/bin/sudo -n -l /usr/bin/pmset -a lowpowermode 0 >/dev/null 2>&1; then
    echo "Low Power Mode can now be toggled without a password."
else
    echo "Installed, but sudo did not confirm the rule yet. Try opening a new terminal or restart Raycast."
fi
