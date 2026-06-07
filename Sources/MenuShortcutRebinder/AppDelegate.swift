import AppKit
import SwiftUI
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let detector = LongPressDetector()
    private let peekDetector = PeekTriggerDetector()
    private var trustTimer: Timer?
    private var didForceRelaunch = false
    private var trustedAtLaunch = false
    private var lastFrontApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Strings.lang = Settings.resolvedLanguage   // Sprache VOR dem ersten Text-Zugriff setzen
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        // Zuletzt aktive Fremd-App merken – das ist die App, deren Befehle „Befehle
        // durchsuchen" beim Öffnen anzeigt (die eigene App wird ignoriert).
        lastFrontApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self.lastFrontApp = app
            }
        }

        detector.triggerKeyCode = Int64(Settings.triggerKeyCode)
        detector.holdDuration = Settings.holdDuration
        detector.onTrigger = { [weak self] in self?.handleTrigger() }

        configurePeek()
        peekDetector.onPeek = { [weak self] in
            BrowseWindow.shared.presentPeek(initialApp: self?.lastFrontApp)
        }
        peekDetector.onRelease = { BrowseWindow.shared.peekReleased() }
        peekDetector.onFixOpen = { [weak self] in
            BrowseWindow.shared.present(initialApp: self?.lastFrontApp)
        }
        configureSettingsWindow()
        autoCheckForUpdates()

        promptAccessibility()   // System-Prompt + Eintrag in der Rechte-Liste anlegen
        trustedAtLaunch = AXIsProcessTrusted()
        detector.start()
        if Settings.peekEnabled { peekDetector.start() }

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
            // Der System-Dialog (aus promptAccessibility) genügt – kein zweites App-Fenster.
            startTrustBackupPolling()
        }
    }

    /// Wird vom System bei Änderungen der Bedienungshilfen-Einstellungen gepostet.
    @objc private func accessibilityChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.didForceRelaunch else { return }
            // NUR neu starten, wenn sich der Vertrauensstatus seit dem Start tatsächlich
            // GEÄNDERT hat (Rechte gerade erteilt ODER entzogen). Sonst entsteht eine
            // Endlos-Neustart-Schleife, solange die App nicht freigegeben ist.
            if AXIsProcessTrusted() != self.trustedAtLaunch {
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
        let pid = ProcessInfo.processInfo.processIdentifier
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Erst warten, bis DIESER Prozess wirklich beendet ist, dann neu öffnen –
        // sonst zeigt macOS „Programm ist nicht mehr geöffnet".
        process.arguments = ["-c",
            "while /bin/kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(path)\""]
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
            let iconConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            button.image = NSImage(systemSymbolName: "command.square",
                                   accessibilityDescription: Strings.statusItemTooltip)?
                .withSymbolConfiguration(iconConfig)
            button.image?.isTemplate = true
            button.toolTip = Strings.statusItemTooltip
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(NSMenuItem(title: Strings.menuBrowse,
                                action: #selector(openBrowse), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Strings.menuSettings,
                                action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: Strings.menuQuit,
                                action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    /// Vor dem Öffnen Login-Haken und Auslöser-Anzeige aktualisieren.
    func menuWillOpen(_ menu: NSMenu) { }

    // MARK: - Einstellungen

    private func configureSettingsWindow() {
        SettingsWindow.shared.onChange = { [weak self] in
            guard let self else { return }
            self.detector.triggerKeyCode = Int64(Settings.triggerKeyCode)
            self.detector.holdDuration = Settings.holdDuration
            self.configurePeek()
            self.peekDetector.stop()
            if Settings.peekEnabled { self.peekDetector.start() }
            BrowseWindow.shared.applySettings()
        }
        SettingsWindow.shared.onToggleLogin = { [weak self] on in self?.setLogin(on) }
        SettingsWindow.shared.onManage = { ShortcutsWindow.shared.present() }
        SettingsWindow.shared.onDiagnose = { [weak self] in self?.diagnose() }
        SettingsWindow.shared.onHelp = { [weak self] in self?.showHelp() }
        SettingsWindow.shared.onCheckUpdate = { [weak self] in self?.checkForUpdates() }
        SettingsWindow.shared.onLanguageChange = { [weak self] lang in
            Settings.appLanguage = lang
            self?.relaunchSelf()   // Neustart, damit alle Texte/Menüs in der neuen Sprache neu aufgebaut werden
        }
        SettingsWindow.shared.onLiveView = { BrowseWindow.shared.applySettings() }
        SettingsWindow.shared.loginEnabled = { SMAppService.mainApp.status == .enabled }
    }

    @objc private func openSettings() { SettingsWindow.shared.present() }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { HUD.show(Strings.loginItemFailed(error.localizedDescription)) }
    }

    @objc private func openShortcuts() {
        ShortcutsWindow.shared.present()
    }

    @objc private func openBrowse() {
        BrowseWindow.shared.present(initialApp: lastFrontApp)
    }

    private func configurePeek() {
        peekDetector.modifierIndex = Settings.peekModifierIndex
        peekDetector.holdDuration = Settings.peekHoldDuration
    }

    // MARK: - Updates

    /// Beim Start max. 1×/Tag still prüfen; nur bei verfügbarem Update melden.
    private func autoCheckForUpdates() {
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        let now = Date().timeIntervalSince1970
        guard now - last > 86_400 else { return }
        UserDefaults.standard.set(now, forKey: "lastUpdateCheck")
        UpdateChecker.check { [weak self] result in
            guard case .success(let info?) = result else { return }
            if Settings.autoUpdate {
                HUD.show(Strings.updateInstalling)
                self?.runUpdate()                 // im Hintergrund laden + installieren + neu starten
            } else {
                self?.showUpdateAlert(info)
            }
        }
    }

    /// Manuelle Prüfung (aus den Einstellungen): meldet auch „bereits aktuell" bzw. Fehler.
    @objc private func checkForUpdates() {
        UpdateChecker.check { [weak self] result in
            switch result {
            case .success(let info?):
                self?.showUpdateAlert(info)
            case .success(nil):
                self?.infoAlert(Strings.updateNoneTitle,
                                Strings.updateNoneBody(UpdateChecker.currentVersion))
            case .failure:
                self?.infoAlert(Strings.updateFailTitle, Strings.updateFailBody)
            }
        }
    }

    private func showUpdateAlert(_ info: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = Strings.updateTitle(info.version)
        let host = NSHostingView(rootView: UpdateView(notes: info.notes))
        host.frame.size = host.fittingSize
        alert.accessoryView = host
        alert.addButton(withTitle: Strings.updateInstall)
        alert.addButton(withTitle: Strings.updatePage)
        alert.addButton(withTitle: Strings.updateLater)
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: runUpdate()
        case .alertSecondButtonReturn:
            if let url = URL(string: info.pageURL) { NSWorkspace.shared.open(url) }
        default: break
        }
    }

    /// Lädt + installiert die neueste notarisierte Version (web-install.sh) und startet neu.
    /// Das Skript wird LOSGELÖST gestartet (nohup + &, eigene Session), damit es den
    /// Selbst-Neustart (pkill) der App überlebt; Ausgabe nach /tmp/sko-update.log.
    private func runUpdate() {
        HUD.show(Strings.updateInstalling)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c",
            "nohup /bin/bash -c '\(UpdateChecker.installCommand)' >/tmp/sko-update.log 2>&1 &"]
        do {
            try task.run()
        } catch {
            HUD.show(Strings.updateFailBody)
        }
    }

    private func infoAlert(_ title: String, _ body: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = body
        a.addButton(withTitle: Strings.ok)
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    // MARK: - Hilfe

    @objc private func showHelp() {
        let seconds = String(format: "%.1f", Settings.holdDuration)
            .replacingOccurrences(of: ".", with: ",")
        let alert = NSAlert()
        alert.messageText = Strings.helpTitle
        let host = NSHostingView(rootView: HelpView(
            trigger: TriggerKey.shortName(for: Settings.triggerKeyCode), seconds: seconds))
        host.frame.size = host.fittingSize
        alert.accessoryView = host
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
        let host = NSHostingView(rootView: DiagnoseView(
            accessibility: AXIsProcessTrusted(),
            tapActive: detector.isActive,
            trigger: TriggerKey.name(for: Settings.triggerKeyCode)))
        host.frame.size = host.fittingSize
        alert.accessoryView = host
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

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
