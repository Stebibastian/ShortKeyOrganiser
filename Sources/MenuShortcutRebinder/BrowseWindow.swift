import AppKit
import SwiftUI
import ApplicationServices

/// „Befehle durchsuchen" – Fenster mit KeyClu-artiger Übersicht (mehrspaltig, nach
/// Menü-Kategorien gruppiert, farbige Modifier). Trägt die SwiftUI-`BrowseView`,
/// folgt automatisch der vordersten App und verbindet Klick→Anpassen (RecorderPanel)
/// bzw. Lösch-Knopf→Zurücksetzen (Preferences).
final class BrowseWindow: NSObject, NSWindowDelegate {
    static let shared = BrowseWindow()

    private var window: NSWindow?
    private let model = BrowseModel()
    private var observer: Any?
    private var flagsMonitors: [Any] = []
    private var isPeek = false
    private var pinned = false

    func present(initialApp: NSRunningApplication?) {
        if window == nil { build() }
        // Toggle: ist das fixe Fenster bereits offen, schließt ⌘⌘⌘ es wieder.
        if window?.isVisible == true && !isPeek {
            closeBrowse()
            return
        }
        isPeek = false
        pinned = true   // normaler Modus: Fenster bleibt offen
        prepare(initialApp: initialApp)
        model.searchActive = true   // fix offen → sofort tippbereit
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Peek-Modus: erscheint, ohne die Ziel-App zu deaktivieren; schließt beim Loslassen
    /// des Auslösers, außer der Nutzer klickt hinein (dann „gepinnt").
    func presentPeek(initialApp: NSRunningApplication?) {
        if window == nil { build() }
        isPeek = true
        pinned = false
        prepare(initialApp: initialApp)
        model.heldMods = Self.mods(from: NSEvent.modifierFlags)   // schon gehaltene Modifier sofort highlighten
        window?.orderFrontRegardless()
    }

    /// Auslöser losgelassen: Peek-Ansicht schließen. Nur wenn der Nutzer schon
    /// hineingeklickt hat (`pinned`), bleibt sie offen.
    func peekReleased() {
        guard isPeek else { return }
        model.heldMods = []
        isPeek = false
        if pinned {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.orderOut(nil)
        }
    }

    /// Suche im Peek geöffnet → Fenster festpinnen, aktivieren und Tastatur-Fokus ermöglichen.
    private func pinForSearch() {
        pinned = true
        isPeek = false
        model.heldMods = []
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func prepare(initialApp: NSRunningApplication?) {
        model.onEdit = { [weak self] item, app in self?.edit(item, app) }
        model.onDelete = { [weak self] item, app in self?.delete(item, app) }
        model.onPerform = { [weak self] item, app in self?.perform(item, app) }
        model.onActivateSearch = { [weak self] in self?.pinForSearch() }
        model.onOpenSettings = { SettingsWindow.shared.present() }
        model.onManage = { ShortcutsWindow.shared.present() }
        model.query = ""
        model.searchActive = false
        model.selectedID = nil
        model.heldMods = []
        model.favorites = BrowsePrefs.favorites
        model.hidden = BrowsePrefs.hidden
        model.collapsed = BrowsePrefs.collapsed   // eingeklappte Kategorien bleiben über Öffnen hinweg erhalten
        model.showHidden = false
        model.showFavorites = true
        model.showRecents = Settings.browseShowRecents
        model.showDisabled = false
        model.kmMode = false   // beim Öffnen immer die normale Übersicht, nie Keyboard Maestro
        model.highlightEnabled = Settings.browseHighlight
        model.backgroundStyle = Settings.browseBackgroundStyle
        model.opaqueRows = Settings.browseOpaqueRows
        model.fontSize = Settings.browseFontSize
        model.keyLeft = Settings.browseKeyLeft
        model.compactSections = Settings.browseCompactSections
        applyBackground()
        model.refreshApps(preferredPid: initialApp?.processIdentifier)
        model.loadItems()
        applyWindowSize()
    }

    /// Setzt die Fenstergröße auf den eingestellten Bildschirm-Anteil und zentriert es.
    private func applyWindowSize() {
        guard let window, let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let wPct = CGFloat(Settings.browseScreenPercent)
        let hPct = CGFloat(Settings.browseSizeLinked ? Settings.browseScreenPercent
                                                      : Settings.browseHeightPercent)
        window.setContentSize(NSSize(width: (vf.width * wPct).rounded(),
                                     height: (vf.height * hPct).rounded()))
        // Anker-basiert positionieren – relativ zum aktuellen Bildschirm, funktioniert mit mehreren Monitoren.
        let w = window.frame.width, h = window.frame.height, m: CGFloat = 12
        let (col, rowTop) = Self.anchorColRow(Settings.browseAnchor)
        let x = col == 0 ? vf.minX + m : (col == 2 ? vf.maxX - w - m : vf.minX + (vf.width - w) / 2)
        let y = rowTop == 0 ? vf.maxY - h - m : (rowTop == 2 ? vf.minY + m : vf.minY + (vf.height - h) / 2)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Anker-Code → (Spalte 0=links/1=mitte/2=rechts, Zeile 0=oben/1=mitte/2=unten).
    static func anchorColRow(_ a: Int) -> (Int, Int) {
        switch a {
        case 1: return (1, 0); case 2: return (1, 2)      // oben / unten
        case 3: return (0, 1); case 4: return (2, 1)      // links / rechts
        case 5: return (0, 0); case 6: return (2, 0)      // oben-links / oben-rechts
        case 7: return (0, 2); case 8: return (2, 2)      // unten-links / unten-rechts
        default: return (1, 1)                            // Mitte
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) { offerSaveSize() }

    /// Fragt nach einem manuellen Resize, ob die neue Größe als Standard übernommen werden soll.
    private func offerSaveSize() {
        guard let window, let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let alert = NSAlert()
        alert.messageText = Strings.sizeSaveTitle
        alert.informativeText = Strings.sizeSaveBody
        alert.addButton(withTitle: Strings.sizeSaveDefault)
        alert.addButton(withTitle: Strings.sizeSaveTemp)
        if alert.runModal() == .alertFirstButtonReturn {
            Settings.browseScreenPercent = Double(window.frame.width / vf.width)
            Settings.browseHeightPercent = Double(window.frame.height / vf.height)
            Settings.browseSizeLinked = false
        }
    }

    private func build() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = Strings.browseTitle
        win.titleVisibility = .hidden                 // kein Titeltext, Inhalt reicht bis oben
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.titlebarAppearsTransparent = true
        win.contentMinSize = NSSize(width: 520, height: 300)   // verhindert ein zu flaches Fenster
        win.contentView = NSHostingView(rootView: BrowseView(model: model))
        win.delegate = self
        self.window = win
        applyBackground()

        // Auto-Follow: wechselt die vorderste App, folgt das offene Fenster automatisch
        // (die eigene App wird ignoriert, damit Klicks ins Fenster nichts umschalten).
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let win = self.window, win.isVisible else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self.model.query = ""          // App gewechselt → Suche zurücksetzen
            self.model.searchActive = false
            self.model.refreshApps(preferredPid: app.processIdentifier)
            self.model.loadItems()         // Items der neu aktivierten App laden (sonst bleibt die Liste alt)
        }

        // Live-Highlight: gehaltene Modifier beobachten, solange das Fenster offen ist.
        let update: (NSEvent) -> Void = { [weak self] event in
            guard let self, let win = self.window, win.isVisible else { return }
            self.model.heldMods = Self.mods(from: event.modifierFlags)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged,
                                                    handler: { event in update(event); return event }) {
            flagsMonitors.append(m)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: update) {
            flagsMonitors.append(m)
        }

        // Tastatur: Esc schließt; bei aktiver Suche ↑/↓ wählt, Enter führt aus.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }
            if event.keyCode == 53 { self.closeBrowse(); return nil }   // Esc
            if !self.model.query.isEmpty {
                switch event.keyCode {
                case 126: self.model.moveSelection(-1); return nil      // ↑
                case 125: self.model.moveSelection(1); return nil       // ↓
                case 36, 76: self.model.performSelected(); return nil   // Return/Enter
                default: break
                }
            }
            // ⌘-Kürzel direkt ausführen (außer Text-Bearbeitung im Suchfeld).
            if event.modifierFlags.contains(.command), let item = self.matchingItem(for: event) {
                self.model.perform(item)
                return nil
            }
            return event
        }) { flagsMonitors.append(m) }
    }

    private func closeBrowse() {
        window?.orderOut(nil)
        isPeek = false
        model.query = ""
        model.searchActive = false
        model.heldMods = []
    }

    private static func mods(from flags: NSEvent.ModifierFlags) -> Set<Character> {
        var s: Set<Character> = []
        if flags.contains(.control) { s.insert("⌃") }
        if flags.contains(.option) { s.insert("⌥") }
        if flags.contains(.shift) { s.insert("⇧") }
        if flags.contains(.command) { s.insert("⌘") }
        return s
    }

    /// Findet den Befehl, dessen Kürzel der gedrückten Kombination entspricht (Direkt-Ausführung).
    /// Standard-Textbearbeitung (⌘C/V/X/A/Z) bleibt dem Suchfeld vorbehalten.
    private func matchingItem(for event: NSEvent) -> BrowseItem? {
        let mods = Self.mods(from: event.modifierFlags)
        let base = (event.charactersIgnoringModifiers ?? "").uppercased()
        guard !base.isEmpty else { return nil }
        let textKeys: Set<String> = ["C", "V", "X", "A", "Z"]
        if (mods == ["⌘"] || mods == ["⌘", "⇧"]), textKeys.contains(base) { return nil }
        return model.items.first { $0.enabled && $0.modifiers == mods && $0.baseKey == base }
    }

    private func edit(_ item: BrowseItem, _ app: AppChoice) {
        pinned = true
        let target = MenuTarget(title: item.title, menuPath: item.menuPath,
                                pid: app.pid, bundleID: app.bundleID, appName: app.name)
        RecorderPanel.shared.present(target: target, lockScope: nil, recordInRegistry: true) { [weak self] in
            self?.model.loadItems()
        }
    }

    private func delete(_ item: BrowseItem, _ app: AppChoice) {
        pinned = true
        let inApp = model.customAppTitles.contains(item.title)
        let inGlobal = model.customGlobalTitles.contains(item.title)
        guard inApp || inGlobal else { return }

        let alert = NSAlert()
        alert.messageText = Strings.sysDeleteTitle
        alert.informativeText = Strings.sysDeleteBody(shortcut: item.shortcut, title: item.title,
                                                      domain: inApp ? app.name : Strings.scopeGlobal)
        alert.addButton(withTitle: Strings.sysDelete)
        alert.addButton(withTitle: Strings.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if inApp { Preferences.remove(menuTitle: item.title, scope: .app, bundleID: app.bundleID) }
        if inGlobal { Preferences.remove(menuTitle: item.title, scope: .global, bundleID: nil) }
        for record in Registry.all()
        where record.menuTitle == item.title && (record.bundleID == app.bundleID || record.scope == .global) {
            Registry.remove(record)
        }
        model.loadItems()
        offerRestartAfterDelete(app: app, appScope: inApp)
    }

    /// Nach dem Entfernen: Neustart der Ziel-App anbieten, damit der Standard zurückkommt.
    private func offerRestartAfterDelete(app: AppChoice, appScope: Bool) {
        let alert = NSAlert()
        alert.messageText = Strings.resetRestartTitle
        alert.informativeText = appScope ? Strings.resetRestartBodyApp(app.name)
                                         : Strings.resetRestartBodyGlobal
        if appScope {
            alert.addButton(withTitle: Strings.restartNow)
            alert.addButton(withTitle: Strings.restartLater)
        } else {
            alert.addButton(withTitle: Strings.ok)
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if appScope, response == .alertFirstButtonReturn {
            AppInfo.relaunch(pid: app.pid)
        }
    }

    // Klick ins Fenster (Suche/Eintrag) macht es key → im Peek-Modus „anpinnen".
    func windowDidBecomeKey(_ notification: Notification) {
        if isPeek { pinned = true }
    }

    func windowDidResignKey(_ notification: Notification) {
        model.query = ""           // beim Verlassen des Fensters die aktive Suche zurücksetzen
        model.searchActive = false
    }

    /// Führt den Menüpunkt in der Ziel-App aus (schließt die Ansicht vorher).
    private func perform(_ item: BrowseItem, _ app: AppChoice) {
        isPeek = false
        window?.orderOut(nil)
        model.heldMods = []
        guard item.enabled, let el = item.element else { return }
        NSRunningApplication(processIdentifier: app.pid)?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AXUIElementPerformAction(el, kAXPressAction as CFString)
        }
    }

    /// Übernimmt geänderte Einstellungen (Zebra, Spaltenbreite, Fenstergröße).
    func applySettings() {
        model.zebra = Settings.browseZebra
        model.showRecents = Settings.browseShowRecents
        model.columnWidth = Settings.browseColumnWidth
        model.backgroundStyle = Settings.browseBackgroundStyle
        model.opaqueRows = Settings.browseOpaqueRows
        model.fontSize = Settings.browseFontSize
        model.keyLeft = Settings.browseKeyLeft
        model.compactSections = Settings.browseCompactSections
        applyBackground()
        if window?.isVisible == true { applyWindowSize() }
    }

    /// Fenster-Hintergrund je nach Modus.
    /// 0 = undurchsichtig, 1 = echte Transparenz (Fensterfarbe mit Alpha, inkl. Titelleiste),
    /// 2 = Milchglas (Blur kommt aus der BrowseView, Fenster selbst klar).
    private func applyBackground() {
        guard let window else { return }
        switch Settings.browseBackgroundStyle {
        case 1:
            window.isOpaque = false
            window.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(max(0.15, 1.0 - Settings.browseTransparency))
        case 2:
            window.isOpaque = false
            window.backgroundColor = .clear
        default:
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
}
