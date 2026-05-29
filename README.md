# macOS System Toggles – Raycast Script Commands

Raycast Script Commands für schnelle macOS-System-Toggles:

- Night Shift
- Caffeinate Display (`caffeinate -d`) mit Menüleistenstatus
- Low Power Mode mit Menüleistenstatus

## Architektur

```
Raycast → toggle-night-shift.sh → nightshift-toggle (Swift Binary)
                                 ↘ toggle-night-shift-fallback.applescript (Fallback)

Raycast → toggle-caffeinate-display.sh → CaffeinateDisplayMenu.app
                                      ↘ caffeinate -d

Raycast → toggle-low-power-mode.sh → pmset -a lowpowermode 0/1
                                  ↘ LowPowerModeMenu.app
```

**Primärer Ansatz:** Ein kompiliertes Swift-Binary nutzt die private `CoreBrightness`-Framework-API (`CBBlueLightClient`), um Night Shift direkt und sofort zu toggeln – ohne UI-Automation, ohne Drittanbieter-Tools.

**Fallback:** Falls das Binary nicht verfügbar ist, wird ein AppleScript genutzt, das die Systemeinstellungen per UI-Automation steuert.

### Warum dieser Ansatz?

| Ansatz | Zuverlässigkeit | Geschwindigkeit | Abhängigkeiten |
|---|---|---|---|
| **CoreBrightness API** ✅ | Sehr hoch | Sofort (~0.2s) | Keine |
| UI Scripting | Mittel | Langsam (~3s) | Accessibility-Berechtigung |
| Drittanbieter-CLI | Hoch | Schnell | Homebrew + Package |

Die CoreBrightness-API ist der beste Kompromiss aus Zuverlässigkeit und Wartbarkeit.

## Dateien

| Datei | Funktion |
|---|---|
| `toggle-night-shift.sh` | Raycast Script Command (Einstiegspunkt) |
| `nightshift-toggle.swift` | Swift-Quellcode für den Toggle |
| `nightshift-toggle` | Kompiliertes Binary (wird automatisch erzeugt) |
| `toggle-night-shift-fallback.applescript` | Fallback via UI-Automation |
| `install-raycast-night-shift.sh` | Installations- und Kompilierungsskript |
| `toggle-caffeinate-display.sh` | Raycast Script Command für `caffeinate -d` |
| `caffeinate-display-menu.swift` | Menüleisten-Helper für Caffeinate |
| `CaffeinateDisplayMenu.app/Contents/Info.plist` | App-Bundle-Metadaten für den Caffeinate-Helper |
| `toggle-low-power-mode.sh` | Raycast Script Command für Low Power Mode |
| `low-power-mode-menu.swift` | Menüleisten-Helper für Low Power Mode |
| `LowPowerModeMenu.app/Contents/Info.plist` | App-Bundle-Metadaten für den Low-Power-Helper |
| `install-low-power-mode-passwordless.sh` | Einmaliges Setup für passwortloses Low-Power-Toggling |

## Installation

### Schnell-Installation (ein Befehl)

```bash
chmod +x ~/raycast-scripts/install-raycast-night-shift.sh && ~/raycast-scripts/install-raycast-night-shift.sh
```

### Manuelle Installation

```bash
# 1. Ordner erstellen (falls nicht vorhanden)
mkdir -p ~/raycast-scripts

# 2. Swift-Binary kompilieren
cd ~/raycast-scripts
swiftc nightshift-toggle.swift -o nightshift-toggle -O

# 3. Skripte ausführbar machen
chmod +x toggle-night-shift.sh nightshift-toggle install-raycast-night-shift.sh
chmod +x toggle-caffeinate-display.sh toggle-low-power-mode.sh install-low-power-mode-passwordless.sh

# 4. Testen
./nightshift-toggle        # Direkt
./toggle-night-shift.sh    # Via Raycast-Wrapper
./toggle-caffeinate-display.sh
./toggle-low-power-mode.sh
```

### Low Power Mode ohne Passwortdialog

macOS erlaubt `pmset -a lowpowermode 0/1` nur als root. Damit der Raycast-Hotkey nicht jedes Mal nach dem Admin-Passwort fragt, installiere einmalig die eng begrenzte sudoers-Regel:

```bash
~/raycast-scripts/install-low-power-mode-passwordless.sh
```

Die Regel erlaubt nur diese zwei Befehle ohne Passwort:

```bash
/usr/bin/pmset -a lowpowermode 0
/usr/bin/pmset -a lowpowermode 1
```

## Raycast einrichten

### Script-Ordner hinzufügen

> [!IMPORTANT]
> **Voraussetzung:** Der Ordner `~/raycast-scripts` muss zuerst als Script Directory in Raycast hinterlegt sein. Falls du das noch nicht gemacht hast: in Raycast „Script Commands" suchen → „Add Script Directory" → `~/raycast-scripts` auswählen.

1. **Raycast öffnen** (Standard: `⌘ + Leertaste`)
2. **„Script Commands"** eingeben und öffnen
3. **„Add Script Directory"** auswählen
4. Ordner wählen: **`~/raycast-scripts`**
5. Bestätigen

### Command finden und testen

1. Raycast öffnen
2. Einen Command suchen:
   - **„Toggle Night Shift"**
   - **„Toggle Caffeinate Display"**
   - **„Toggle Low Power Mode"**
3. Enter drücken → der jeweilige Zustand wird getoggelt

### Hotkey zuweisen

1. In Raycast nach **„Toggle Night Shift"** suchen
2. **`⌘ + K`** drücken (Action-Menü)
3. **„Assign Hotkey"** wählen
4. Gewünschte Tastenkombination drücken (z.B. `⌃⌥N`)
5. Fertig – der Hotkey funktioniert jetzt systemweit

## Caffeinate Display

`toggle-caffeinate-display.sh` startet und stoppt `caffeinate -d`, damit das Display wach bleibt.

- ON: volle Tasse in der Menüleiste, `caffeinate -d` läuft
- OFF: leere/abgeschwächte Tasse bleibt in der Menüleiste, `caffeinate -d` ist gestoppt
- Klick auf das Menüleisten-Icon zeigt **Turn On** oder **Turn Off**

Der Helper wird bei Bedarf automatisch aus `caffeinate-display-menu.swift` kompiliert.

## Low Power Mode

`toggle-low-power-mode.sh` toggelt macOS Low Power Mode über `pmset`.

- ON: Low Power Mode aktiv, Batterie-Icon in der Menüleiste
- OFF: Low Power Mode aus, Menüleisten-Helper beendet
- Der Menüleisten-Helper beendet sich automatisch, wenn Low Power Mode extern ausgeschaltet wird

Voraussetzung für Hotkey-Nutzung ohne Passwortdialog ist das einmalige Setup mit `install-low-power-mode-passwordless.sh`.

## Berechtigungen

### Für den primären Ansatz (CoreBrightness)

**Keine besonderen Berechtigungen nötig.** Das Binary nutzt die CoreBrightness-API direkt.

### Für den Fallback (AppleScript UI-Automation)

Falls der Fallback benötigt wird, müssen folgende Berechtigungen erteilt werden:

1. **Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen**
   - Raycast muss hier aktiviert sein
2. **Systemeinstellungen → Datenschutz & Sicherheit → Automation**
   - Raycast muss „System Events" steuern dürfen

Beim ersten Ausführen erscheint normalerweise ein Dialog zur Berechtigung.

## Troubleshooting

### „Command not found" in Raycast

- Prüfe, ob der Script-Ordner in Raycast hinterlegt ist
- Prüfe, ob `toggle-night-shift.sh` ausführbar ist: `chmod +x ~/raycast-scripts/toggle-night-shift.sh`
- Raycast neu starten

### „CoreBrightness framework not found"

- Tritt auf, wenn die private API in einer zukünftigen macOS-Version entfernt wird
- Der AppleScript-Fallback greift automatisch

### Binary lässt sich nicht kompilieren

```bash
# Xcode Command Line Tools installieren
xcode-select --install

# Danach neu kompilieren
cd ~/raycast-scripts && swiftc nightshift-toggle.swift -o nightshift-toggle -O
```

### Night Shift reagiert nicht

- Prüfe, ob Night Shift auf dem Gerät unterstützt wird (ältere Macs ggf. nicht)
- Prüfe in Systemeinstellungen → Displays → Night Shift, ob die Funktion vorhanden ist
- Teste direkt im Terminal: `~/raycast-scripts/nightshift-toggle`

### AppleScript-Fallback schlägt fehl

- Berechtigungen prüfen (siehe oben)
- macOS-Sprache: Der Fallback unterstützt Deutsch und Englisch
- System Settings muss sich öffnen lassen

### Nach macOS-Update funktioniert es nicht mehr

```bash
# Binary neu kompilieren
cd ~/raycast-scripts && swiftc nightshift-toggle.swift -o nightshift-toggle -O
```

Die CoreBrightness-API ist seit macOS Sierra stabil. Falls Apple die Struct-Layout ändert, muss ggf. der `enabled`-Offset im Swift-Code angepasst werden (aktuell: Byte 1).

## Bekannte Einschränkungen

- **Private API:** `CoreBrightness` ist ein privates Framework. Apple könnte es in Zukunft ändern. In der Praxis ist es seit 2016 stabil.
- **Struct-Layout:** Der Offset des `enabled`-Feldes (Byte 1) wurde auf macOS 26 Tahoe verifiziert. Auf älteren Versionen könnte der Offset bei Byte 0 liegen.
- **Kein App-Store:** Lösungen mit privaten APIs sind nicht App-Store-kompatibel (für lokale Skripte irrelevant).
- **Fallback-Sprachen:** Der UI-Automation-Fallback unterstützt aktuell Deutsch und Englisch.

## Deinstallation

```bash
rm -rf ~/raycast-scripts/nightshift-toggle*
rm -f ~/raycast-scripts/toggle-night-shift.sh
rm -f ~/raycast-scripts/toggle-night-shift-fallback.applescript
rm -f ~/raycast-scripts/install-raycast-night-shift.sh
rm -f ~/raycast-scripts/README-Night-Shift-Raycast.md
rm -f ~/raycast-scripts/toggle-caffeinate-display.sh
rm -f ~/raycast-scripts/caffeinate-display-menu.swift
rm -rf ~/raycast-scripts/CaffeinateDisplayMenu.app
rm -f ~/raycast-scripts/toggle-low-power-mode.sh
rm -f ~/raycast-scripts/low-power-mode-menu.swift
rm -rf ~/raycast-scripts/LowPowerModeMenu.app
rm -f ~/raycast-scripts/install-low-power-mode-passwordless.sh
```

Danach in Raycast den Script-Ordner entfernen (falls gewünscht).

Die Low-Power-sudoers-Regel kann so entfernt werden:

```bash
sudo rm -f /private/etc/sudoers.d/raycast-low-power-mode
sudo visudo -cf /private/etc/sudoers
```
