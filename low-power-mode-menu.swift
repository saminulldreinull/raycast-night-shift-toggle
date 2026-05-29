import Cocoa

let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".low-power-mode-menu")
let pidFile = appSupportDir.appendingPathComponent("pid")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pollTimer: Timer?
    private var sigtermSource: DispatchSourceSignal?
    private var sigintSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installSignalHandlers()

        guard isLowPowerModeOn() else {
            NSApp.terminate(nil)
            return
        }

        createStatusItem()
        savePID()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard self?.isLowPowerModeOn() == true else {
                NSApp.terminate(nil)
                return
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
        removePID()
        statusItem = nil
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let image = NSImage(systemSymbolName: "battery.25", accessibilityDescription: "Low Power Mode ON") {
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        } else {
            item.button?.title = "🔋"
        }

        item.button?.toolTip = "Low Power Mode ON"
        item.autosaveName = "LowPowerModeMenuStatusItem"
        item.isVisible = true

        let menu = NSMenu()

        let stateItem = NSMenuItem(title: "Low Power Mode ON", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let offItem = NSMenuItem(title: "Turn Off", action: #selector(turnOff), keyEquivalent: "")
        offItem.target = self
        menu.addItem(offItem)

        item.menu = menu
        statusItem = item
    }

    private func isLowPowerModeOn() -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return false }

        for line in output.split(separator: "\n") {
            let parts = line.split { $0 == " " || $0 == "\t" }
            guard parts.count >= 2 else { continue }
            if parts[0] == "powermode" || parts[0] == "lowpowermode" {
                return parts[1] == "1"
            }
        }

        return false
    }

    @objc private func turnOff() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a", "lowpowermode", "0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSSound.beep()
            return
        }

        if process.terminationStatus == 0 {
            NSApp.terminate(nil)
        } else {
            NSSound.beep()
        }
    }

    private func installSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler {
            NSApp.terminate(nil)
        }
        termSource.resume()
        sigtermSource = termSource

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler {
            NSApp.terminate(nil)
        }
        intSource.resume()
        sigintSource = intSource
    }

    private func savePID() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? String(ProcessInfo.processInfo.processIdentifier).write(to: pidFile, atomically: true, encoding: .utf8)
    }

    private func removePID() {
        try? FileManager.default.removeItem(at: pidFile)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
