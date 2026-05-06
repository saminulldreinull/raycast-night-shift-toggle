-- toggle-night-shift-fallback.applescript
-- Fallback: Night Shift via System Settings UI-Automation toggeln
-- Unterstuetzt Englisch und Deutsch

on run
    set nightShiftLabels to {"Night Shift", "Night Shift…", "Night Shift..."}
    set scheduleOffLabels to {"Off", "Aus"}
    set scheduleOnLabels to {"Sunset to Sunrise", "Sonnenuntergang bis Sonnenaufgang", "Custom Schedule", "Eigener Zeitplan"}
    set turnOnLabels to {"Turn On Until Tomorrow", "Bis morgen aktivieren", "Turn On Until Sunrise", "Bis Sonnenaufgang aktivieren"}
    set closeLabels to {"Done", "Fertig", "OK"}

    -- System Settings oeffnen (Displays)
    tell application "System Settings"
        activate
        delay 0.3
    end tell

    try
        do shell script "open 'x-apple.systempreferences:com.apple.Displays-Settings.extension'"
    on error
        tell application "System Settings"
            activate
        end tell
    end try

    delay 1.0

    tell application "System Events"
        tell process "System Settings"
            set frontmost to true
            delay 0.5

            -- Night Shift Button suchen und klicken
            set foundNS to false
            repeat with lbl in nightShiftLabels
                try
                    -- Suche in der gesamten UI-Hierarchie
                    set nsButtons to every button of group 1 of scroll area 1 of group 1 of group 1 of splitter group 1 of group 1 of window 1 whose title contains (lbl as text)
                    if (count of nsButtons) > 0 then
                        click item 1 of nsButtons
                        set foundNS to true
                        exit repeat
                    end if
                end try
            end repeat

            -- Alternatives Suchen falls erster Versuch fehlschlaegt
            if not foundNS then
                repeat with lbl in nightShiftLabels
                    try
                        click button (lbl as text) of group 1 of scroll area 1 of group 1 of group 1 of splitter group 1 of group 1 of window 1
                        set foundNS to true
                        exit repeat
                    end try
                end repeat
            end if

            if not foundNS then
                tell application "System Settings" to quit
                error "Night Shift button not found. Check macOS version and language."
            end if

            delay 0.8

            -- Im Night Shift Sheet: Checkbox oder Toggle suchen
            set toggled to false

            -- Methode 1: "Turn On Until Tomorrow" Checkbox suchen
            repeat with lbl in turnOnLabels
                try
                    set theCheckbox to checkbox (lbl as text) of sheet 1 of window 1
                    click theCheckbox
                    set toggled to true
                    exit repeat
                end try
                try
                    set theCheckbox to checkbox (lbl as text) of group 1 of sheet 1 of window 1
                    click theCheckbox
                    set toggled to true
                    exit repeat
                end try
            end repeat

            -- Methode 2: Generisch erste Checkbox im Sheet
            if not toggled then
                try
                    set allCheckboxes to every checkbox of sheet 1 of window 1
                    if (count of allCheckboxes) > 0 then
                        click item 1 of allCheckboxes
                        set toggled to true
                    end if
                end try
            end if

            if not toggled then
                -- Sheet schliessen
                repeat with lbl in closeLabels
                    try
                        click button (lbl as text) of sheet 1 of window 1
                        exit repeat
                    end try
                end repeat
                tell application "System Settings" to quit
                error "Could not find Night Shift toggle in System Settings."
            end if

            delay 0.3

            -- Sheet schliessen
            repeat with lbl in closeLabels
                try
                    click button (lbl as text) of sheet 1 of window 1
                    exit repeat
                end try
            end repeat
        end tell
    end tell

    delay 0.3
    tell application "System Settings" to quit

    return "Night Shift toggled (via UI)"
end run
