import AppKit

/// Eingabefeld, das den nächsten Tastendruck als Kürzel aufnimmt.
final class RecorderField: NSView {
    var onCapture: ((Shortcut) -> Void)?
    private(set) var current: Shortcut?
    private var focused = false
    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        focused = true; needsDisplay = true; installMonitor(); return true
    }
    override func resignFirstResponder() -> Bool {
        focused = false; needsDisplay = true; removeMonitor(); return true
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    deinit { removeMonitor() }

    // Lokaler Event-Monitor: fängt JEDEN Tastendruck ab, solange das Feld den Fokus
    // hat – auch ⌘-Kombinationen, die das Menü-/Key-Equivalent-System sonst abfängt,
    // bevor sie keyDown/performKeyEquivalent erreichen.
    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.window?.firstResponder === self else { return event }
            if let shortcut = Shortcut.from(event: event) {
                self.apply(shortcut)
                return nil   // verschluckt → löst nichts anderes aus
            }
            return event
        }
    }
    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }

    override func keyDown(with event: NSEvent) {
        if let shortcut = Shortcut.from(event: event) { apply(shortcut) }
        else { NSSound.beep() }
    }

    // ⌘-Kombinationen (z. B. ⌘⇧I) werden von AppKit als Key-Equivalent zugestellt,
    // NICHT über keyDown – hier abfangen, sonst lassen sie sich nicht aufnehmen.
    // Reine Tasten ohne Modifier (Return/Escape) liefern kein gültiges Shortcut →
    // wir geben sie frei, damit die Buttons weiter funktionieren.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self,
              let shortcut = Shortcut.from(event: event) else { return false }
        apply(shortcut)
        return true   // konsumiert → löst nicht versehentlich ein Menü/einen Button aus
    }

    private func apply(_ shortcut: Shortcut) {
        current = shortcut
        onCapture?(shortcut)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (focused ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = focused ? 2 : 1
        path.stroke()

        let hasValue = current != nil
        let text = current?.display ?? Strings.recorderPlaceholder
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: hasValue ? 22 : 13,
                                     weight: hasValue ? .semibold : .regular),
            .foregroundColor: hasValue ? NSColor.labelColor : NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let textRect = NSRect(x: 0, y: (bounds.height - size.height) / 2,
                              width: bounds.width, height: size.height)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}

/// Das „Tastenkürzel anpassen?"-Fenster.
final class RecorderPanel: NSObject, NSWindowDelegate {
    static let shared = RecorderPanel()

    private var window: NSWindow?
    private var field: RecorderField!
    private var appRadio: NSButton!
    private var globalRadio: NSButton!
    private var saveButton: NSButton!
    private var statusLabel: NSTextField!

    private var target: MenuTarget!
    private var captured: Shortcut?
    private var lockedScope: Scope?
    private var recordInRegistry = true
    private var onSaved: (() -> Void)?

    func present(target: MenuTarget,
                 lockScope: Scope? = nil,
                 recordInRegistry: Bool = true,
                 onSaved: (() -> Void)? = nil) {
        close()   // ein evtl. schon offenes Anpassen-Fenster zuerst schließen → nie mehrere gleichzeitig
        self.target = target
        self.captured = nil
        self.lockedScope = lockScope
        self.recordInRegistry = recordInRegistry
        self.onSaved = onSaved

        let content = NSRect(x: 0, y: 0, width: 440, height: 300)
        let window = NSWindow(contentRect: content,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = Strings.panelTitle
        window.level = .floating
        window.delegate = self
        window.isReleasedWhenClosed = false
        let root = window.contentView!

        // Titel
        let title = label(Strings.panelTitle, frame: NSRect(x: 20, y: 258, width: 400, height: 26))
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        root.addSubview(title)

        // Zielbeschreibung
        let appName = target.appName ?? Strings.panelTargetUnknownApp
        let subtitle = label(Strings.panelTarget(item: target.title, app: appName),
                             frame: NSRect(x: 20, y: 232, width: 400, height: 20))
        subtitle.textColor = .secondaryLabelColor
        root.addSubview(subtitle)

        // Aufnahmefeld
        field = RecorderField(frame: NSRect(x: 20, y: 176, width: 400, height: 48))
        field.onCapture = { [weak self] _ in
            self?.updateSaveEnabled()
            self?.checkConflict()
        }
        root.addSubview(field)

        let hint = label(Strings.recorderHint, frame: NSRect(x: 20, y: 152, width: 400, height: 18))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        root.addSubview(hint)

        // Bereichswahl (Radio-Gruppe)
        appRadio = NSButton(radioButtonWithTitle: Strings.scopeAppNamed(appName),
                            target: self, action: #selector(scopeChanged))
        appRadio.frame = NSRect(x: 20, y: 118, width: 400, height: 20)
        globalRadio = NSButton(radioButtonWithTitle: Strings.scopeGlobal,
                               target: self, action: #selector(scopeChanged))
        globalRadio.frame = NSRect(x: 20, y: 94, width: 400, height: 20)
        root.addSubview(appRadio)
        root.addSubview(globalRadio)

        // Bereich festlegen (beim Bearbeiten gesperrt) bzw. wählbar.
        if let locked = lockScope {
            appRadio.state = (locked == .app) ? .on : .off
            globalRadio.state = (locked == .global) ? .on : .off
            appRadio.isEnabled = false
            globalRadio.isEnabled = false
        } else if (target.bundleID ?? "").isEmpty {
            appRadio.isEnabled = false
            globalRadio.state = .on
        } else {
            appRadio.state = .on
        }

        // Statuszeile
        statusLabel = label("", frame: NSRect(x: 20, y: 58, width: 400, height: 32))
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .systemRed
        statusLabel.maximumNumberOfLines = 2
        root.addSubview(statusLabel)

        // Buttons
        let cancel = NSButton(title: Strings.cancel, target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 220, y: 16, width: 100, height: 32)
        root.addSubview(cancel)

        saveButton = NSButton(title: Strings.save, target: self, action: #selector(saveClicked))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 324, y: 16, width: 100, height: 32)
        saveButton.keyEquivalent = "\r"
        root.addSubview(saveButton)
        updateSaveEnabled()

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }

    // MARK: - Aktionen

    @objc private func scopeChanged() {
        checkConflict()
    }

    /// Warnt, wenn das gewählte Kürzel im Zielbereich schon für einen ANDEREN
    /// Menüpunkt vergeben ist – macOS würde es sonst lautlos überschreiben.
    private func checkConflict() {
        statusLabel.stringValue = ""
        guard let shortcut = field.current else { return }
        let scope: Scope = lockedScope ?? ((globalRadio.state == .on) ? .global : .app)
        if scope == .app, (target.bundleID ?? "").isEmpty { return }
        let existing = Preferences.current(scope: scope, bundleID: target.bundleID)
        if let other = existing.first(where: { $0.value == shortcut.encoded && $0.key != target.title })?.key {
            statusLabel.textColor = .systemOrange
            statusLabel.stringValue = Strings.conflictWarning(shortcut: shortcut.display, other: other)
        }
    }

    @objc private func cancelClicked() { close() }

    @objc private func saveClicked() {
        statusLabel.textColor = .systemRed
        guard let shortcut = field.current, shortcut.isValid else {
            statusLabel.stringValue = Strings.needShortcut
            return
        }
        let scope: Scope = lockedScope ?? ((globalRadio.state == .on) ? .global : .app)
        if scope == .app, (target.bundleID ?? "").isEmpty {
            statusLabel.stringValue = Strings.appScopeNeedsBundle
            return
        }

        let ok = Preferences.set(menuTitle: target.title,
                                 encoded: shortcut.encoded,
                                 scope: scope,
                                 bundleID: target.bundleID)
        let appName = target.appName ?? Strings.panelTargetUnknownApp
        if ok && recordInRegistry {
            Registry.add(ShortcutRecord(scope: scope,
                                        bundleID: target.bundleID,
                                        appName: target.appName,
                                        menuTitle: target.title,
                                        display: shortcut.display,
                                        encoded: shortcut.encoded))
        }
        close()
        if ok { offerRestart(scope: scope, appName: appName) }
        if ok { onSaved?() }
    }

    private func updateSaveEnabled() {
        saveButton?.isEnabled = (field?.current?.isValid == true)
    }

    private func close() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Neustart-Nachfrage

    private func offerRestart(scope: Scope, appName: String) {
        let alert = NSAlert()
        alert.messageText = Strings.restartTitle
        alert.informativeText = (scope == .app)
            ? Strings.restartBodyApp(appName)
            : Strings.restartBodyGlobal
        if scope == .app {
            alert.addButton(withTitle: Strings.restartNow)
            alert.addButton(withTitle: Strings.restartLater)
        } else {
            alert.addButton(withTitle: Strings.ok)
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if scope == .app, response == .alertFirstButtonReturn {
            AppInfo.relaunch(pid: target.pid)
        }
    }

    // MARK: - Helfer

    private func label(_ text: String, frame: NSRect) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
