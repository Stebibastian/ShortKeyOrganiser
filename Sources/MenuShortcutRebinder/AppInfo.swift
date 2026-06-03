import AppKit

enum AppInfo {
    /// Beendet die Ziel-App und startet sie nach kurzer Verzögerung neu, damit sie
    /// die geänderte `NSUserKeyEquivalents`-Voreinstellung neu einliest.
    static func relaunch(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let url = app.bundleURL else { return }
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }
}

/// Kurze, selbstschließende Hinweisblase (z. B. „kein Menüpunkt unter dem Cursor").
enum HUD {
    private static var window: NSWindow?

    static func show(_ message: String) {
        window?.orderOut(nil)

        let textField = NSTextField(labelWithString: message)
        textField.font = .systemFont(ofSize: 13, weight: .medium)
        textField.textColor = .white
        textField.sizeToFit()

        let padding: CGFloat = 16
        let size = NSSize(width: textField.frame.width + padding * 2,
                          height: textField.frame.height + padding)
        let panel = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: .borderless, backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.ignoresMouseEvents = true

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        textField.frame.origin = NSPoint(x: padding, y: padding / 2)
        background.addSubview(textField)
        panel.contentView = background

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                         y: visible.minY + 120))
        }
        panel.orderFrontRegardless()
        window = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if panel == window {
                panel.orderOut(nil)
                window = nil
            }
        }
    }
}
