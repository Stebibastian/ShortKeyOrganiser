import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!
    private var triggerInfoItem: NSMenuItem!
    private let detector = LongPressDetector()
    private var trustTimer: Timer?
    private var didForceRelaunch = false
    private var trustedAtLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        detector.triggerKeyCode = Int64(Settings.triggerKeyCode)
        detector.holdDuration = Settings.holdDuration
        detector.onTrigger = { [weak self] in self?.handleTrigger() }

        promptAccessibility()   // System-Prompt + Eintrag in der Rechte-Liste anlegen
        trustedAtLaunch = AXIsProcessTrusted()
        detector.start()

        // Auf Änderungen der Bedienungshilfen-Freigabe lauschen und die App dann
        // automatisch neu starten. Ein frischer Prozess erhält den Tastatur-Tap
        // zuverlässig – im laufenden Prozess greift eine neue Freigabe oft nicht.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"), object: nil)

        if trustedAtLaunch && detector.isActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                HUD.show(Strings.launchedHint(TriggerKey.shortName(for: Settings.triggerKeyCode)))
            }
        } else {
            startTrustBackupPolling()
            showAccessibilityAlert()
        }
    }

    /// Wird vom System bei Änderungen der Bedienungshilfen-Einstellungen gepostet.
    @objc private func accessibilityChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.didForceRelaunch else { return }
            // Liefen wir ohne Rechte und es gab eine Änderung → sehr wahrscheinlich
            // wurden gerade wir freigegeben. Oder die Rechte wurden entzogen.
            if !self.trustedAtLaunch || !AXIsProcessTrusted() {
                self.didForceRelaunch = true
                self.relaunchSelf()
            }
        }
    }

    /// Backup, falls die System-Notification ausbleibt: pollt die Freigabe und
    /// startet bei Erteilung neu.
    private func startTrustBackupPolling() {
        trustTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.didForceRelaunch { timer.invalidate(); return }
            if !self.trustedAtLaunch && AXIsProcessTrusted() {
                self.didForceRelaunch = true
                timer.invalidate()
                self.trustTimer = nil
                self.relaunchSelf()
            }
        }
        RunLoop.main.add(timer, forMode: .common)   // feuert auch während modaler Dialoge
        trustTimer = timer
    }

    private func relaunchSelf() {
        let path = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; open \"\(path)\""]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: - Auslöser

    private func handleTrigger() {
        guard let target = MenuInspector.itemUnderCursor() else {
            HUD.show(Strings.noMenuItem)
            return
        }
        // Erst das offene Menü schließen, dann das Fenster zeigen – während ein Menü
        // im Tracking-Modus ist, kann kein eigenes Fenster den Fokus übernehmen.
        MenuInspector.dismissOpenMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            RecorderPanel.shared.present(target: target)
        }
    }

    // MARK: - Statusleiste

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square",
                                   accessibilityDescription: Strings.statusItemTooltip)
            button.toolTip = Strings.statusItemTooltip
        }

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: Strings.appTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        triggerInfoItem = NSMenuItem(title: triggerInfoText(), action: nil, keyEquivalent: "")
        triggerInfoItem.isEnabled = false
        menu.addItem(triggerInfoItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: Strings.menuChangeTrigger,
                                action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Strings.menuManage,
                                action: #selector(openManager), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Strings.menuSystemShortcuts,
                                action: #selector(openSystemShortcuts), keyEquivalent: ""))
        loginItem = NSMenuItem(title: Strings.menuLoginItem,
                               action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: Strings.menuDiagnose,
                                action: #selector(diagnose), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Strings.menuHelp,
                                action: #selector(showHelp), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: Strings.menuQuit,
                                action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    /// Vor dem Öffnen Login-Haken und Auslöser-Anzeige aktualisieren.
    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        triggerInfoItem.title = triggerInfoText()
    }

    private func triggerInfoText() -> String {
        Strings.triggerInfo(TriggerKey.name(for: Settings.triggerKeyCode))
    }

    // MARK: - Einstellungen

    @objc private func openSettings() {
        SettingsPanel.shared.present(currentKeyCode: Settings.triggerKeyCode,
                                     currentHold: Settings.holdDuration) { [weak self] keyCode, hold in
            self?.detector.triggerKeyCode = Int64(keyCode)
            self?.detector.holdDuration = hold
            self?.triggerInfoItem.title = self?.triggerInfoText() ?? ""
            HUD.show(Strings.triggerInfo(TriggerKey.name(for: keyCode)))
        }
    }

    @objc private func openManager() {
        ShortcutsWindow.shared.present(tab: 0)
    }

    @objc private func openSystemShortcuts() {
        ShortcutsWindow.shared.present(tab: 1)
    }

    // MARK: - Login-Eintrag

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            HUD.show(Strings.loginItemFailed(error.localizedDescription))
        }
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    // MARK: - Hilfe

    @objc private func showHelp() {
        let seconds = String(format: "%.1f", Settings.holdDuration)
            .replacingOccurrences(of: ".", with: ",")
        let alert = NSAlert()
        alert.messageText = Strings.helpTitle
        alert.informativeText = Strings.helpBody(
            trigger: TriggerKey.shortName(for: Settings.triggerKeyCode), seconds: seconds)
        alert.addButton(withTitle: Strings.ok)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Bedienungshilfen

    private func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @objc private func diagnose() {
        let alert = NSAlert()
        alert.messageText = Strings.diagnoseTitle
        alert.informativeText = Strings.diagnoseBody(
            accessibility: AXIsProcessTrusted(),
            tapActive: detector.isActive,
            trigger: TriggerKey.name(for: Settings.triggerKeyCode))
        alert.addButton(withTitle: Strings.openSettings)        // erster Button
        alert.addButton(withTitle: Strings.diagnoseReconnect)   // zweiter Button
        alert.addButton(withTitle: Strings.ok)                  // dritter Button
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openAccessibilitySettings()
        case .alertSecondButtonReturn:
            relaunchSelf()   // frischer Prozess erhält den Tap zuverlässig
        default:
            break
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = Strings.axAlertTitle
        alert.informativeText = Strings.axAlertBody
        alert.addButton(withTitle: Strings.openSettings)
        alert.addButton(withTitle: Strings.ok)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
