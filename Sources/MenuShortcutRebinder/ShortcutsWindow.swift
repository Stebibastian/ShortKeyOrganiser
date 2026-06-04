import AppKit

private final class TabFlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// NSButton, der einen Closure auslöst (für Icon-Aktionen pro Zeile).
private final class ClosureButton: NSButton {
    var onClick: (() -> Void)?
    @objc func fire() { onClick?() }
}

/// Ein Fenster mit zwei Tabs:
///   • „Vom Tool gesetzt"  – die von diesem Tool angelegten Kürzel
///   • „Alle im System"    – alle macOS-App-Kurzbefehle (global + pro App)
/// Beide Tabs: Kürzel groß lesbar, links 🗑️ Löschen (rot) + ✏️ Ändern.
final class ShortcutsWindow: NSObject, NSTabViewDelegate {
    static let shared = ShortcutsWindow()

    private var window: NSWindow?
    private var tabView: NSTabView!
    private var toolStack: NSStackView!
    private var sysStack: NSStackView!
    private var resetAllButton: NSButton!

    func present(tab: Int = 0) {
        if window == nil { build() }
        reloadTool()
        reloadSystem()
        tabView.selectTabViewItem(at: max(0, min(tab, 1)))
        updateBottomBar()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Aufbau

    private func build() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = Strings.winTitle
        window.level = .floating
        window.isReleasedWhenClosed = false
        let root = window.contentView!

        tabView = NSTabView(frame: NSRect(x: 16, y: 56, width: 548, height: 452))
        tabView.autoresizingMask = [.width, .height]

        // „Vom Tool gesetzt" zuerst (Standard-Tab), dann „Alle im System".
        let (toolView, ts) = makeList()
        toolStack = ts
        let toolItem = NSTabViewItem(identifier: "tool")
        toolItem.label = Strings.tabTool
        toolItem.view = toolView
        tabView.addTabViewItem(toolItem)

        let (sysView, ss) = makeList()
        sysStack = ss
        let sysItem = NSTabViewItem(identifier: "system")
        sysItem.label = Strings.tabSystem
        sysItem.view = sysView
        tabView.addTabViewItem(sysItem)

        root.addSubview(tabView)

        resetAllButton = NSButton(title: Strings.resetAll, target: self, action: #selector(resetAllClicked))
        resetAllButton.bezelStyle = .rounded
        resetAllButton.frame = NSRect(x: 18, y: 14, width: 160, height: 32)
        root.addSubview(resetAllButton)

        let refresh = NSButton(title: Strings.refresh, target: self, action: #selector(refreshClicked))
        refresh.bezelStyle = .rounded
        refresh.frame = NSRect(x: 372, y: 14, width: 110, height: 32)
        root.addSubview(refresh)

        let close = NSButton(title: Strings.closeButton, target: self, action: #selector(closeClicked))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        close.frame = NSRect(x: 486, y: 14, width: 78, height: 32)
        root.addSubview(close)

        // Delegate erst JETZT setzen – sonst feuert didSelect bereits beim Hinzufügen
        // der Tabs, bevor resetAllButton existiert (→ nil-Crash).
        tabView.delegate = self

        self.window = window
    }

    /// Container mit ScrollView + vertikalem Stack; gibt beides zurück.
    private func makeList() -> (NSView, NSStackView) {
        let container = NSView()
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let doc = TabFlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -10),
        ])
        return (container, stack)
    }

    // MARK: - Befüllen

    private func reloadTool() {
        clear(toolStack)
        let records = Registry.all()
        if records.isEmpty {
            addEmpty(toolStack, Strings.managerEmpty)
            return
        }
        for record in records {
            let domain = record.scope == .global
                ? Strings.scopeGlobal
                : (record.appName ?? record.bundleID ?? Strings.panelTargetUnknownApp)
            let row = rowView(display: record.display, title: record.menuTitle, editable: true,
                onEdit: { [weak self] in
                    self?.edit(title: record.menuTitle, scope: record.scope,
                               bundleID: record.bundleID, appName: record.appName, recordInRegistry: true)
                },
                onDelete: { [weak self] in
                    self?.confirmDelete(title: record.menuTitle, display: record.display,
                                        domain: domain, scope: record.scope, bundleID: record.bundleID)
                })
            toolStack.addArrangedSubview(row)
            pinWidth(row, toolStack)
        }
    }

    private func reloadSystem() {
        clear(sysStack)
        let groups = SystemShortcuts.scan()
        if groups.isEmpty {
            addEmpty(sysStack, Strings.sysEmpty)
            return
        }
        for group in groups {
            let suffix = group.editable ? "" : "  \(Strings.sysReadOnly)"
            let header = makeLabel("\(group.domain)  (\(group.entries.count))\(suffix)")
            header.font = .systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabelColor
            sysStack.addArrangedSubview(header)
            pinWidth(header, sysStack)
            for entry in group.entries {
                let row = rowView(display: entry.display, title: entry.menuTitle, editable: group.editable,
                    onEdit: { [weak self] in
                        self?.edit(title: entry.menuTitle, scope: group.scope,
                                   bundleID: group.bundleID, appName: group.domain, recordInRegistry: false)
                    },
                    onDelete: { [weak self] in
                        self?.confirmDelete(title: entry.menuTitle, display: entry.display,
                                            domain: group.domain, scope: group.scope, bundleID: group.bundleID)
                    })
                sysStack.addArrangedSubview(row)
                pinWidth(row, sysStack)
            }
        }
    }

    // MARK: - Zeile

    private func rowView(display: String, title: String, editable: Bool,
                         onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

        if editable {
            let del = iconButton("trash", .systemRed, Strings.sysDelete, onDelete)
            let edit = iconButton("pencil", .controlAccentColor, Strings.sysEdit, onEdit)
            row.addArrangedSubview(del)
            row.addArrangedSubview(edit)
            row.setCustomSpacing(18, after: edit)
        } else {
            let spacer = NSView()
            spacer.widthAnchor.constraint(equalToConstant: 52).isActive = true
            row.addArrangedSubview(spacer)
            row.setCustomSpacing(18, after: spacer)
        }

        let kbd = makeLabel(display)
        kbd.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        kbd.textColor = .labelColor
        kbd.setContentHuggingPriority(.required, for: .horizontal)
        kbd.widthAnchor.constraint(equalToConstant: 124).isActive = true

        let name = makeLabel(title)
        name.font = .systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingTail
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(kbd)
        row.addArrangedSubview(name)
        return row
    }

    private func iconButton(_ symbol: String, _ tint: NSColor, _ tip: String,
                            _ onClick: @escaping () -> Void) -> NSButton {
        let button = ClosureButton()
        button.onClick = onClick
        button.target = button
        button.action = #selector(ClosureButton.fire)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(config)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = tint
        button.toolTip = tip
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    // MARK: - Aktionen

    private func edit(title: String, scope: Scope, bundleID: String?, appName: String?, recordInRegistry: Bool) {
        let target = MenuTarget(title: title, menuPath: [], pid: runningPid(bundleID),
                                bundleID: bundleID, appName: appName)
        RecorderPanel.shared.present(target: target, lockScope: scope,
                                     recordInRegistry: recordInRegistry) { [weak self] in
            self?.reloadTool()
            self?.reloadSystem()
        }
    }

    private func confirmDelete(title: String, display: String, domain: String,
                               scope: Scope, bundleID: String?) {
        let alert = NSAlert()
        alert.messageText = Strings.sysDeleteTitle
        alert.informativeText = Strings.sysDeleteBody(shortcut: display, title: title, domain: domain)
        alert.addButton(withTitle: Strings.sysDelete)
        alert.addButton(withTitle: Strings.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Preferences.remove(menuTitle: title, scope: scope, bundleID: bundleID)
        for record in Registry.all()
        where record.scope == scope && record.bundleID == bundleID && record.menuTitle == title {
            Registry.remove(record)
        }
        reloadTool()
        reloadSystem()
    }

    @objc private func resetAllClicked() {
        let records = Registry.all()
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
        reloadTool()
        reloadSystem()
    }

    @objc private func refreshClicked() {
        reloadTool()
        reloadSystem()
    }

    @objc private func closeClicked() {
        window?.orderOut(nil)
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        updateBottomBar()
    }

    private func updateBottomBar() {
        // „Alle zurücksetzen" nur im Tool-Tab anzeigen. Defensiv gegen frühe/leere Aufrufe.
        guard let resetAllButton = resetAllButton,
              let selected = tabView?.selectedTabViewItem else { return }
        resetAllButton.isHidden = (selected.identifier as? String) != "tool"
    }

    // MARK: - Helfer

    private func runningPid(_ bundleID: String?) -> pid_t {
        guard let bundleID else { return 0 }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first?.processIdentifier ?? 0
    }

    private func clear(_ stack: NSStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func pinWidth(_ view: NSView, _ stack: NSStackView) {
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addEmpty(_ stack: NSStackView, _ text: String) {
        let label = makeLabel(text)
        label.textColor = .secondaryLabelColor
        stack.addArrangedSubview(label)
        pinWidth(label, stack)
    }

    private func makeLabel(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
