import AppKit

/// Feld, das eine gedrückte Modifier-Taste als Auslöser aufnimmt.
final class TriggerRecorderField: NSView {
    var onCapture: ((Int) -> Void)?
    var currentKeyCode: Int = Settings.defaultTriggerKeyCode
    private var focused = false

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { focused = true; needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { focused = false; needsDisplay = true; return true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

    override func flagsChanged(with event: NSEvent) {
        let code = Int(event.keyCode)
        guard TriggerKey.isValid(code) else { return }
        // Nur beim Drücken (Maske vorhanden) übernehmen, nicht beim Loslassen.
        if TriggerKey.isPressed(code, in: event.modifierFlags) {
            currentKeyCode = code
            onCapture?(code)
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        NSSound.beep()   // normale Tasten sind als Auslöser nicht zulässig
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (focused ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = focused ? 2 : 1
        path.stroke()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
        let text = TriggerKey.name(for: currentKeyCode) as NSString
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2,
                          width: bounds.width, height: size.height)
        text.draw(in: rect, withAttributes: attributes)
    }
}

/// Dialog zum Anpassen der „magischen Taste" und der Haltedauer.
final class SettingsPanel: NSObject {
    static let shared = SettingsPanel()

    private var window: NSWindow?
    private var field: TriggerRecorderField!
    private var slider: NSSlider!
    private var durationLabel: NSTextField!
    private var onSave: ((Int, Double) -> Void)?

    func present(currentKeyCode: Int, currentHold: Double, onSave: @escaping (Int, Double) -> Void) {
        self.onSave = onSave

        let content = NSRect(x: 0, y: 0, width: 460, height: 272)
        let window = NSWindow(contentRect: content,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = Strings.settingsTitle
        window.level = .floating
        window.isReleasedWhenClosed = false
        let root = window.contentView!

        let title = label(Strings.settingsTitle, frame: NSRect(x: 24, y: 232, width: 412, height: 26))
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        root.addSubview(title)

        let triggerLabel = label(Strings.settingsTriggerLabel,
                                 frame: NSRect(x: 24, y: 206, width: 412, height: 18))
        triggerLabel.textColor = .secondaryLabelColor
        root.addSubview(triggerLabel)

        field = TriggerRecorderField(frame: NSRect(x: 24, y: 158, width: 412, height: 44))
        field.currentKeyCode = currentKeyCode
        root.addSubview(field)

        let hint = label(Strings.settingsTriggerHint, frame: NSRect(x: 24, y: 120, width: 412, height: 34))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 2
        root.addSubview(hint)

        durationLabel = label("", frame: NSRect(x: 24, y: 92, width: 412, height: 18))
        root.addSubview(durationLabel)

        slider = NSSlider(value: currentHold, minValue: 0.3, maxValue: 1.5,
                          target: self, action: #selector(durationChanged))
        slider.isContinuous = true
        slider.frame = NSRect(x: 24, y: 66, width: 412, height: 22)
        root.addSubview(slider)
        updateDurationLabel()

        let cancel = NSButton(title: Strings.cancel, target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 236, y: 18, width: 100, height: 32)
        root.addSubview(cancel)

        let save = NSButton(title: Strings.save, target: self, action: #selector(saveClicked))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 340, y: 18, width: 100, height: 32)
        root.addSubview(save)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }

    @objc private func durationChanged() { updateDurationLabel() }

    @objc private func cancelClicked() { close() }

    @objc private func saveClicked() {
        let keyCode = field.currentKeyCode
        let hold = slider.doubleValue
        Settings.triggerKeyCode = keyCode
        Settings.holdDuration = hold
        onSave?(keyCode, hold)
        close()
    }

    private func updateDurationLabel() {
        let seconds = String(format: "%.2f", slider.doubleValue)
            .replacingOccurrences(of: ".", with: ",")
        durationLabel.stringValue = "\(Strings.settingsDurationLabel) \(seconds) s"
    }

    private func close() {
        window?.orderOut(nil)
        window = nil
    }

    private func label(_ text: String, frame: NSRect) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        field.lineBreakMode = .byWordWrapping
        return field
    }
}
