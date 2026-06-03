import AppKit

/// Hilfsview mit Ursprung oben-links (für die Dokumentenfläche im ScrollView).
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Fenster, das alle von diesem Tool gesetzten Kürzel listet und einzeln/alle
/// zurücksetzt. Fremde Einträge (z. B. eigene FileMaker-Kürzel) werden nicht gezeigt
/// und nicht angefasst.
final class ManagerPanel: NSObject {
    static let shared = ManagerPanel()

    private var window: NSWindow?
    private var stack: NSStackView!
    private var records: [ShortcutRecord] = []

    func present() {
        let content = NSRect(x: 0, y: 0, width: 560, height: 420)
        let window = NSWindow(contentRect: content,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = Strings.managerTitle
        window.level = .floating
        window.isReleasedWhenClosed = false
        let root = window.contentView!

        let title = label(Strings.managerTitle, frame: NSRect(x: 24, y: 384, width: 512, height: 24))
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        root.addSubview(title)

        let subtitle = label(Strings.managerSubtitle, frame: NSRect(x: 24, y: 362, width: 512, height: 18))
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        root.addSubview(subtitle)

        let scroll = NSScrollView(frame: NSRect(x: 24, y: 64, width: 512, height: 286))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        root.addSubview(scroll)

        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -10),
        ])

        let resetAll = NSButton(title: Strings.resetAll, target: self, action: #selector(resetAllClicked))
        resetAll.bezelStyle = .rounded
        resetAll.frame = NSRect(x: 24, y: 18, width: 160, height: 32)
        root.addSubview(resetAll)

        let closeButton = NSButton(title: Strings.closeButton, target: self, action: #selector(closeClicked))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.frame = NSRect(x: 436, y: 18, width: 100, height: 32)
        root.addSubview(closeButton)

        self.window = window
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func reload() {
        records = Registry.all()
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard !records.isEmpty else {
            let empty = label(Strings.managerEmpty, frame: .zero)
            empty.textColor = .secondaryLabelColor
            stack.addArrangedSubview(empty)
            return
        }
        for (index, record) in records.enumerated() {
            stack.addArrangedSubview(rowView(index: index, record: record))
        }
    }

    private func rowView(index: Int, record: ShortcutRecord) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        row.layer?.cornerRadius = 6

        let scopeText = record.scope == .global
            ? Strings.scopeGlobal
            : (record.appName ?? record.bundleID ?? Strings.panelTargetUnknownApp)
        let description = NSTextField(labelWithString:
            "\(record.display)     „\(record.menuTitle)“     ·     \(scopeText)")
        description.lineBreakMode = .byTruncatingTail
        description.setContentHuggingPriority(.defaultLow, for: .horizontal)
        description.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let button = NSButton(title: Strings.reset, target: self, action: #selector(resetClicked(_:)))
        button.bezelStyle = .rounded
        button.tag = index
        button.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(description)
        row.addArrangedSubview(button)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return row
    }

    // MARK: - Aktionen

    @objc private func resetClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < records.count else { return }
        let record = records[sender.tag]
        Preferences.remove(menuTitle: record.menuTitle, scope: record.scope, bundleID: record.bundleID)
        Registry.remove(record)
        reload()
        HUD.show(Strings.resetDoneRestart)
    }

    @objc private func resetAllClicked() {
        guard !records.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = Strings.resetAll
        alert.informativeText = Strings.resetAllConfirm
        alert.addButton(withTitle: Strings.resetAll)
        alert.addButton(withTitle: Strings.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for record in records {
            Preferences.remove(menuTitle: record.menuTitle, scope: record.scope, bundleID: record.bundleID)
        }
        Registry.clear()
        reload()
        HUD.show(Strings.resetDoneRestart)
    }

    @objc private func closeClicked() {
        window?.orderOut(nil)
        window = nil
    }

    private func label(_ text: String, frame: NSRect) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
