import AppKit
import AudioToolbox
import Carbon
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusLabel = NSTextField(labelWithString: "Pomodoro: Idle")
    private let hotKeyLabel = NSTextField(labelWithString: "Hotkeys: registering...")
    private var session: PomodoroSession = .idle
    private var tickTimer: Timer?
    private var hotKeyManager: HotKeyManager?
    private var window: NSWindow?
    private var hotKeySummary = "Hotkeys: registering..."
    private var endSound: NSSound?
    private var notificationAuthorizationRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        ProcessInfo.processInfo.disableAutomaticTermination("Pomodoro menu bar timer is active")

        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()

        configureWindow()
        configureMenu()
        updateStatusItem()
        updateWindowStatus()

        hotKeyManager = HotKeyManager { [weak self] action in
            DispatchQueue.main.async {
                switch action {
                case .startFocus:
                    self?.startSession(.focus)
                case .startRest:
                    self?.startSession(.rest)
                case .stop:
                    self?.stopSession()
                }
            }
        }
        let registeredHotKeys = hotKeyManager?.register() ?? []
        hotKeySummary = registeredHotKeys.isEmpty
            ? "Hotkeys: unavailable; use the buttons or menu"
            : "Hotkeys: \(registeredHotKeys.joined(separator: ", "))"
        configureMenu()
        updateWindowStatus()
        showWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
        tickTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func startSession(_ kind: PomodoroSession.Kind) {
        let duration: TimeInterval
        switch kind {
        case .focus:
            duration = 25 * 60
        case .rest:
            duration = 5 * 60
        }

        session = .running(kind: kind, endDate: Date().addingTimeInterval(duration))
        startTicking()
        configureMenu()
        updateStatusItem()
        updateWindowStatus()
    }

    private func stopSession() {
        session = .idle
        tickTimer?.invalidate()
        tickTimer = nil
        configureMenu()
        updateStatusItem()
        updateWindowStatus()
    }

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    private func tick() {
        guard case let .running(kind, endDate) = session else {
            tickTimer?.invalidate()
            tickTimer = nil
            return
        }

        if Date() >= endDate {
            session = .idle
            tickTimer?.invalidate()
            tickTimer = nil
            notifySessionEnded(kind)
        }

        configureMenu()
        updateStatusItem()
        updateWindowStatus()
    }

    private func configureMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: detailTitle, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: hotKeySummary, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "Show Pomodoro", action: #selector(showWindowFromMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let focusItem = NSMenuItem(title: "Start Focus Session", action: #selector(startFocusFromMenu), keyEquivalent: "")
        focusItem.target = self
        menu.addItem(focusItem)

        let restItem = NSMenuItem(title: "Start Rest Session", action: #selector(startRestFromMenu), keyEquivalent: "")
        restItem.target = self
        menu.addItem(restItem)

        let stopItem = NSMenuItem(title: "Stop Session", action: #selector(stopSessionFromMenu), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = session.isRunning
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Pomodoro", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func configureWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 190),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomodoro"
        window.center()
        window.isReleasedWhenClosed = false

        statusLabel.alignment = .center
        statusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)

        hotKeyLabel.alignment = .center
        hotKeyLabel.font = NSFont.systemFont(ofSize: 12)
        hotKeyLabel.textColor = .secondaryLabelColor
        hotKeyLabel.lineBreakMode = .byWordWrapping
        hotKeyLabel.maximumNumberOfLines = 2

        let focusButton = NSButton(title: "Start Focus", target: self, action: #selector(startFocusFromMenu))
        let restButton = NSButton(title: "Start Rest", target: self, action: #selector(startRestFromMenu))
        let stopButton = NSButton(title: "Stop", target: self, action: #selector(stopSessionFromMenu))

        let buttonStack = NSStackView(views: [focusButton, restButton, stopButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10

        let stack = NSStackView(views: [statusLabel, hotKeyLabel, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .gravityAreas
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        window.contentView = stack
        self.window = window
    }

    private func updateWindowStatus() {
        statusLabel.stringValue = detailTitle
        hotKeyLabel.stringValue = hotKeySummary
    }

    private func showWindow() {
        if window == nil {
            configureWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let title: String
        let iconColor: NSColor
        let textColor: NSColor

        switch session {
        case .idle:
            title = ""
            iconColor = .secondaryLabelColor
            textColor = .secondaryLabelColor
        case .running(.focus, _):
            title = ""
            iconColor = .systemRed
            textColor = .systemRed
        case let .running(.rest, endDate):
            title = Self.formatRemaining(until: endDate)
            iconColor = .systemGreen
            textColor = .systemGreen
        }

        let image = Self.makeStatusImage(title: title, iconColor: iconColor, textColor: textColor)
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        statusItem.length = image.size.width + 10
    }

    private var detailTitle: String {
        switch session {
        case .idle:
            return "Pomodoro: Idle"
        case let .running(.focus, endDate):
            return "Focus: \(Self.formatRemaining(until: endDate)) remaining"
        case let .running(.rest, endDate):
            return "Rest: \(Self.formatRemaining(until: endDate)) remaining"
        }
    }

    private func notifySessionEnded(_ kind: PomodoroSession.Kind) {
        playSessionEndedSound()
        NSApp.requestUserAttention(.criticalRequest)

        let content = UNMutableNotificationContent()
        content.title = kind == .focus ? "Focus session complete" : "Rest session complete"
        content.body = kind == .focus ? "Time for a 5-minute rest." : "Ready for another focus session."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        guard !notificationAuthorizationRequested else {
            return
        }

        notificationAuthorizationRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func playSessionEndedSound() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_UserPreferredAlert))

        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.volume = 1
            sound.currentTime = 0
            sound.play()
            endSound = sound
        } else {
            NSSound.beep()
        }
    }

    private static func formatRemaining(until endDate: Date) -> String {
        let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func makeStatusImage(title: String, iconColor: NSColor, textColor: NSColor) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let textSize = title.size(withAttributes: attributes)
        let hasTitle = !title.isEmpty
        let iconSize: CGFloat = 17
        let gap: CGFloat = hasTitle ? 5 : 0
        let width = ceil(iconSize + gap + textSize.width)
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()

        let iconRect = NSRect(x: 0, y: 0.5, width: iconSize, height: iconSize)
        if let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) {
            symbol.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
            iconColor.setFill()
            iconRect.fill(using: .sourceIn)
        }

        if hasTitle {
            let textOrigin = NSPoint(x: iconSize + gap, y: (height - textSize.height) / 2)
            title.draw(at: textOrigin, withAttributes: attributes)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func startFocusFromMenu() {
        startSession(.focus)
    }

    @objc private func startRestFromMenu() {
        startSession(.rest)
    }

    @objc private func stopSessionFromMenu() {
        stopSession()
    }

    @objc private func showWindowFromMenu() {
        showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
