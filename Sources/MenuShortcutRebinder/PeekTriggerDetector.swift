import AppKit
import QuartzCore

/// Erkennt „Modifier zweimal kurz drücken und beim zweiten Mal halten" über einen
/// globalen CGEventTap - der Peek-Auslöser für die „Befehle durchsuchen"-Ansicht.
/// `onPeek` feuert, sobald der zweite Druck lange genug gehalten wurde; `onRelease`,
/// sobald der Auslöser danach wieder losgelassen wird.
final class PeekTriggerDetector {
    var onPeek: (() -> Void)?
    var onRelease: (() -> Void)?
    var onFixOpen: (() -> Void)?   // dreimal drücken → Fenster fix öffnen

    var modifierIndex: Int = 0          // 0=⌘, 1=⌥, 2=⌃
    var holdDuration: TimeInterval = 0.15
    var tapWindow: TimeInterval = 0.4   // max. Abstand zwischen den beiden Drücken

    private(set) var isActive = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private enum State { case idle, firstDown, waitSecond, secondDown, waitThird, peeking }
    private var state: State = .idle
    private var triggerWasAlone = false
    private var lastReleaseTime: CFTimeInterval = 0
    private var holdToken = 0

    private var mask: CGEventFlags {
        switch modifierIndex {
        case 1: return .maskAlternate
        case 2: return .maskControl
        default: return .maskCommand
        }
    }
    private let majorModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]

    func start() {
        let evMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<PeekTriggerDetector>.fromOpaque(refcon).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: evMask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            isActive = false
            NSLog("MenuShortcutRebinder: Peek-Event-Tap konnte nicht erstellt werden.")
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
    }

    func stop() {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil; runLoopSource = nil; isActive = false
        reset()
    }

    func restart() { stop(); start() }

    private func reset() { state = .idle; holdToken &+= 1 }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            if state != .peeking { reset() }   // normale Taste bricht die Geste ab
        case .flagsChanged:
            handleFlags(active: event.flags.intersection(majorModifiers), now: CACurrentMediaTime())
        default:
            break
        }
    }

    private func handleFlags(active: CGEventFlags, now: CFTimeInterval) {
        let triggerDown = active.contains(mask)

        if state == .peeking {
            // Im Peek beendet nur das Loslassen des Auslösers (andere Modifier = Highlight, egal).
            if !triggerDown {
                state = .idle
                triggerWasAlone = false
                DispatchQueue.main.async { self.onRelease?() }
            }
            return
        }

        let aloneNow = (active == mask)
        defer { triggerWasAlone = aloneNow }

        if aloneNow && !triggerWasAlone {
            // Auslöser (alleine) gedrückt
            let recent = (now - lastReleaseTime) <= tapWindow
            switch state {
            case .waitSecond where recent:
                state = .secondDown
                armHold()
            case .waitThird where recent:
                // dritter Druck → Fenster fix öffnen (bleibt offen)
                reset()
                DispatchQueue.main.async { self.onFixOpen?() }
            default:
                state = .firstDown
            }
        } else if !aloneNow && triggerWasAlone {
            // Auslöser-alleine endet: losgelassen oder mit weiterem Modifier kombiniert
            switch state {
            case .firstDown where !triggerDown:
                lastReleaseTime = now; state = .waitSecond
            case .secondDown where !triggerDown:
                lastReleaseTime = now; state = .waitThird
                holdToken &+= 1   // geplanten Peek-Hold abbrechen (war nur kurzer zweiter Tap)
            default:
                reset()
            }
        }
    }

    private func armHold() {
        holdToken &+= 1
        let token = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self, self.holdToken == token, self.state == .secondDown else { return }
            self.state = .peeking
            self.onPeek?()
        }
    }
}
