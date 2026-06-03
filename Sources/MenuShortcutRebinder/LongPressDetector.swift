import AppKit

/// Erkennt das lange Halten einer einzelnen Modifier-Taste (Standard: rechte ⌃)
/// über einen globalen `CGEventTap`.
///
/// Warum ein Modifier und ausgerechnet **Control**?
///  • Modifier lösen kein „Type-Select" in offenen Menüs aus (eine normale Buchstaben-
///    taste würde im Menü zur Tipp-Auswahl springen).
///  • Anders als ⌥ (Option) oder ⌘ blendet ⌃ in Menüs **keine alternativen Einträge**
///    ein – der Punkt unter dem Cursor bleibt also derselbe, den wir gleich auslesen.
///
/// Anpassbar über `triggerKeyCode` und `holdDuration`.
final class LongPressDetector {

    /// Wird auf dem Main-Thread aufgerufen, wenn der Auslöser lange genug gehalten wurde.
    var onTrigger: (() -> Void)?

    /// Tastencode der Auslöser-Taste. 62 = rechte Control-Taste.
    var triggerKeyCode: Int64 = 62
    /// Haltedauer, ab der ausgelöst wird.
    var holdDuration: TimeInterval = 0.6

    /// Ob der Event-Tap erfolgreich erstellt und aktiv ist (sonst fehlt meist die
    /// Bedienungshilfen-Freigabe).
    private(set) var isActive = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Monoton steigendes Token, um eine geplante Auslösung zu entwerten,
    /// sobald die Taste losgelassen oder eine andere Taste gedrückt wird.
    private var armToken = 0
    private var triggerIsDown = false

    /// Modifier-Maske, die zum `triggerKeyCode` gehört (für die „nur diese Taste"-Prüfung).
    private var triggerMask: CGEventFlags {
        switch triggerKeyCode {
        case 59, 62: return .maskControl
        case 58, 61: return .maskAlternate
        case 54, 55: return .maskCommand
        case 56, 60: return .maskShift
        default:     return .maskControl
        }
    }

    private let majorModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let detector = Unmanaged<LongPressDetector>.fromOpaque(refcon).takeUnretainedValue()
            detector.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isActive = false
            NSLog("MenuShortcutRebinder: Event-Tap konnte nicht erstellt werden (Bedienungshilfen?).")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
    }

    /// Tap verwerfen und neu aufbauen – z. B. nachdem die Bedienungshilfen-Freigabe
    /// erteilt wurde, ohne die App neu zu starten.
    func restart() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
        start()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .keyDown:
            // Jede normale Taste während des Wartens bricht ab → ⌃C usw. bleiben normal.
            cancelPending()

        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let active = event.flags.intersection(majorModifiers)
            if keyCode == triggerKeyCode {
                if active == triggerMask {
                    // Auslöser-Taste alleine gedrückt → Countdown starten.
                    triggerIsDown = true
                    armPending()
                } else {
                    // Losgelassen oder mit weiteren Modifiern kombiniert.
                    triggerIsDown = false
                    cancelPending()
                }
            } else {
                // Eine andere Modifier-Taste kam hinzu → abbrechen.
                cancelPending()
            }

        default:
            break
        }
    }

    private func armPending() {
        armToken &+= 1
        let token = armToken
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self, self.armToken == token, self.triggerIsDown else { return }
            self.triggerIsDown = false
            self.onTrigger?()
        }
    }

    private func cancelPending() {
        armToken &+= 1
    }
}
