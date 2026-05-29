import Cocoa

let caffeinatePath = "/usr/bin/caffeinate"
let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".caffeinate-display-menu")
let pidFile = appSupportDir.appendingPathComponent("pid")
let stateFile = appSupportDir.appendingPathComponent("state")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var stateItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
    private var caffeinateProcess: Process?
    private var sigtermSource: DispatchSourceSignal?
    private var sigintSource: DispatchSourceSignal?
    private var sigusr1Source: DispatchSourceSignal?
    private var isEnabled = false
    private var isShuttingDown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installSignalHandlers()
        createStatusItem()
        savePID()
        isEnabled = loadState()
        applyState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        isShuttingDown = true
        stopCaffeinate()
        removePID()
        statusItem = nil
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "CaffeinateDisplayMenuStatusItem"
        item.isVisible = true

        let menu = NSMenu()

        let stateItem = NSMenuItem(title: "Caffeinate Display OFF", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        self.stateItem = stateItem

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Turn On", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleItem = toggleItem

        item.menu = menu
        statusItem = item
    }

    private func loadState() -> Bool {
        guard let value = try? String(contentsOf: stateFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return value == "on"
    }

    private func saveState(_ enabled: Bool) {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? (enabled ? "on" : "off").write(to: stateFile, atomically: true, encoding: .utf8)
    }

    private func applyState() {
        if isEnabled {
            do {
                try startCaffeinate()
            } catch {
                fputs("ERROR: Could not start caffeinate -d: \(error)\n", stderr)
                isEnabled = false
                saveState(false)
            }
        } else {
            stopCaffeinate()
        }

        updateStatusItem()
    }

    private func updateStatusItem() {
        let symbolName = isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer"
        let description = isEnabled ? "Caffeinate Display ON" : "Caffeinate Display OFF"

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            image.isTemplate = true
            statusItem?.button?.image = image
            statusItem?.button?.imagePosition = .imageOnly
            statusItem?.button?.title = ""
            statusItem?.button?.alphaValue = isEnabled ? 1.0 : 0.45
        } else {
            statusItem?.button?.image = nil
            statusItem?.button?.title = isEnabled ? "☕" : "○"
            statusItem?.button?.alphaValue = isEnabled ? 1.0 : 0.55
        }

        statusItem?.button?.toolTip = description
        stateItem?.title = description
        toggleItem?.title = isEnabled ? "Turn Off" : "Turn On"
    }

    private func startCaffeinate() throws {
        if caffeinateProcess?.isRunning == true {
            return
        }

        isShuttingDown = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: caffeinatePath)
        process.arguments = ["-d"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.caffeinateProcess = nil
                guard self.isEnabled, !self.isShuttingDown else { return }
                self.isEnabled = false
                self.saveState(false)
                self.updateStatusItem()
            }
        }

        try process.run()
        caffeinateProcess = process
    }

    private func stopCaffeinate() {
        guard let process = caffeinateProcess else { return }
        if process.isRunning {
            process.terminate()
        }
        caffeinateProcess = nil
    }

    private func installSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler { [weak self] in
            self?.isShuttingDown = true
            self?.stopCaffeinate()
            NSApp.terminate(nil)
        }
        termSource.resume()
        sigtermSource = termSource

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler { [weak self] in
            self?.isShuttingDown = true
            self?.stopCaffeinate()
            NSApp.terminate(nil)
        }
        intSource.resume()
        sigintSource = intSource

        signal(SIGUSR1, SIG_IGN)
        let reloadSource = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        reloadSource.setEventHandler { [weak self] in
            guard let self else { return }
            self.isEnabled = self.loadState()
            self.applyState()
        }
        reloadSource.resume()
        sigusr1Source = reloadSource
    }

    @objc private func toggleFromMenu() {
        isEnabled.toggle()
        saveState(isEnabled)
        applyState()
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
