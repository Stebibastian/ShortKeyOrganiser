import AppKit

private final class SysFlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Schreibgeschütztes Fenster, das alle vorhandenen macOS-App-Kurzbefehle zeigt
/// (global + pro App), gruppiert und entschlüsselt.
final class SystemShortcutsPanel: NSObject {
    static let shared = SystemShortcutsPanel()

    private var window: NSWindow?
    private var stack: NSStackView!
    private var statusLabel: NSTextField!

    func present() {
        let content = NSRect(x: 0, y: 0, width: 520, height: 460)
        let window = NSWindow(contentRect: content,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = Strings.sysTitle
        window.level = .floating
        window.isReleasedWhenClosed = false
        let root = window.contentView!

        let title = label(Strings.sysTitle, NSRect(x: 24, y: 424, width: 472, height: 24))
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        root.addSubview(title)

        let subtitle = label(Strings.sysSubtitle, NSRect(x: 24, y: 400, width: 472, height: 18))
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        root.addSubview(subtitle)

        let scroll = NSScrollView(frame: NSRect(x: 24, y: 64, width: 472, height: 326))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = false
        let doc = SysFlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        root.addSubview(scroll)
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -10),
        ])

        statusLabel = label("", NSRect(x: 24, y: 22, width: 280, height: 18))
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        root.addSubview(statusLabel)

        let refresh = NSButton(title: Strings.refresh, target: self, action: #selector(reloadClicked))
        refresh.bezelStyle = .rounded
        refresh.frame = NSRect(x: 300, y: 16, width: 100, height: 32)
        root.addSubview(refresh)

        let close = NSButton(title: Strings.closeButton, target: self, action: #selector(closeClicked))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        close.frame = NSRect(x: 404, y: 16, width: 92, height: 32)
        root.addSubview(close)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        reload()
    }

    @objc private func reloadClicked() { reload() }
    @objc private func closeClicked() { window?.orderOut(nil); window = nil }

    private func reload() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let groups = SystemShortcuts.scan()
        if groups.isEmpty {
            let empty = label(Strings.sysEmpty, .zero)
            empty.textColor = .secondaryLabelColor
            stack.addArrangedSubview(empty)
            pinWidth(empty)
            statusLabel.stringValue = Strings.sysCount(0)
            return
        }
        for group in groups {
            let header = label("\(group.domain)  (\(group.entries.count))", .zero)
            header.font = .systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabelColor
            stack.addArrangedSubview(header)
            pinWidth(header)
            for entry in group.entries {
                let row = rowView(shortcut: entry.display, title: entry.menuTitle)
                stack.addArrangedSubview(row)
                pinWidth(row)
            }
        }
        statusLabel.stringValue = Strings.sysCount(SystemShortcuts.totalCount(groups))
    }

    // Breite immer NACH dem Einhängen verankern (sonst Constraint-Ausnahme).
    private func pinWidth(_ view: NSView) {
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func rowView(shortcut: String, title: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 1, left: 10, bottom: 1, right: 8)

        let kbd = label(shortcut, .zero)
        kbd.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        kbd.setContentHuggingPriority(.required, for: .horizontal)
        kbd.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let name = label(title, .zero)
        name.lineBreakMode = .byTruncatingTail
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(kbd)
        row.addArrangedSubview(name)
        return row
    }

    private func label(_ string: String, _ frame: NSRect) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.frame = frame
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
