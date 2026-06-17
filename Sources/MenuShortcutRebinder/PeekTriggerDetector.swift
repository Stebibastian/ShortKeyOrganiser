import AppKit
import QuartzCore

/// Erkennt Mehrfachdruck-Gesten auf einer Modifier-Taste über einen globalen CGEventTap.
/// Zwei konfigurierbare Aktionen:
/// - Kurzblick (Peek): N-mal drücken und beim letzten Mal HALTEN → `onPeek`; Loslassen → `onRelease`.
///   (Halten gehört zum Wesen des Kurzblicks - er schliesst beim Loslassen.)
/// - Fix öffnen: M-mal drücken, wahlweise mit oder ohne Halten am Ende → `onFixOpen`.
///
/// Konfliktregeln: Gleiche Druckzahl ist erlaubt, solange sich die Aktionen im Halten
/// unterscheiden (kurzer Tap = Fix, Halten = Peek). Liegt die Fix-Druckzahl UNTER der
/// Peek-Druckzahl, feuert Fix erst nach Ablauf des Tap-Fensters (damit die längere
/// Geste noch möglich bleibt).
final class PeekTriggerDetector {
    var onPeek: (() -> Void)?
    var onRelease: (() -> Void)?
    var onFixOpen: (() -> Void)?

    var modifierIndex: Int = 0          // 0=⌘, 1=⌥, 2=⌃
    var holdDuration: TimeInterval = 0.15
    var tapWindow: TimeInterval = 0.4   // max. Abstand zwischen zwei Drücken

    var peekEnabled = true
    var peekCount = 2                   // Drücke für den Kurzblick (beim letzten halten)
    var fixEnabled = true
    var fixCount = 3                    // Drücke für „fix öffnen"
    var fixHold = false                 // true = auch Fix erst beim Halten am Ende

    private(set) var isActive = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private enum Phase { case idle, down, up, peeking }
    private var phase: Phase = .idle
    private var count = 0               // Drücke in der laufenden Geste
    private var pendingTapFix = false   // Fix (ohne Halten) bei gleicher Druckzahl wie Peek: feuert beim schnellen Loslassen
    private var triggerWasAlone = false
    private var lastReleaseTime: CFTimeInterval = 0
    private var holdToken = 0           // entwertet armierte Hold-/Verzögerungs-Timer
    private var suppressed = false      // nach Mausklick: Geste aus, bis der Auslöser ganz losgelassen wird

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
            | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
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
        suppressed = false
        reset()
    }

    func restart() { stop(); start() }

    private func reset() {
        phase = .idle; count = 0; pendingTapFix = false
        holdToken &+= 1
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            if phase == .peeking {
                // Im offenen Kurzblick schliesst jede Taste (z. B. ⌘Z) das Overlay, statt es
                // störend offen zu lassen – und unterdrückt es, bis der Auslöser losgelassen wird.
                reset()
                suppressed = true
                triggerWasAlone = false
                DispatchQueue.main.async { self.onRelease?() }
            } else {
                reset()   // normale Taste bricht eine laufende Geste ab
            }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            handleMouseDown()
        case .flagsChanged:
            handleFlags(active: event.flags.intersection(majorModifiers), now: CACurrentMediaTime())
        default:
            break
        }
    }

    /// Mausklick während des Auslöser-Haltens (vor dem Öffnen): Geste abbrechen und bis zum
    /// Loslassen des Auslösers unterdrücken – sonst poppt das Overlay auf, wenn man bei
    /// gehaltenem ⌘ klickt oder etwas markiert. Im bereits offenen Kurzblick bleibt der Klick
    /// unberührt (dort wählt er einen Befehl).
    private func handleMouseDown() {
        guard phase != .peeking else { return }
        if phase != .idle || triggerWasAlone {
            reset()
            suppressed = true
        }
    }

    private func handleFlags(active: CGEventFlags, now: CFTimeInterval) {
        let triggerDown = active.contains(mask)

        if suppressed {
            // Nach einem Mausklick unterdrückt, bis der Auslöser ganz losgelassen wird.
            if !triggerDown { suppressed = false }
            triggerWasAlone = (active == mask)
            return
        }

        if phase == .peeking {
            // Im Peek beendet nur das Loslassen des Auslösers (andere Modifier = Highlight, egal).
            if !triggerDown {
                reset()
                triggerWasAlone = false
                DispatchQueue.main.async { self.onRelease?() }
            }
            return
        }

        let aloneNow = (active == mask)
        defer { triggerWasAlone = aloneNow }

        if aloneNow && !triggerWasAlone {
            // Auslöser (alleine) gedrückt
            holdToken &+= 1   // verzögerten Fix-Schuss abbrechen - die Geste geht weiter
            let recent = (now - lastReleaseTime) <= tapWindow
            count = (phase == .up && recent) ? count + 1 : 1
            phase = .down
            pendingTapFix = false

            let peekHere = peekEnabled && count == peekCount
            let fixHere = fixEnabled && count == fixCount
            if peekHere { armHold(fix: false) }
            if fixHere && fixHold && !peekHere { armHold(fix: true) }
            if fixHere && !fixHold {
                if peekHere {
                    pendingTapFix = true                     // kurzer Tap = Fix, Halten = Peek
                } else if peekEnabled && peekCount > count {
                    // längere Peek-Geste noch möglich → erst beim Loslassen verzögert feuern
                } else {
                    fireFix()                                // eindeutig → sofort
                }
            }
        } else if !aloneNow && triggerWasAlone {
            if !triggerDown {
                // Auslöser losgelassen (bevor ein Halten gefeuert hat)
                lastReleaseTime = now
                let wasDown = (phase == .down)
                phase = .up
                holdToken &+= 1   // armierte Hold-Timer abbrechen (war nur ein kurzer Tap)
                if wasDown && pendingTapFix {
                    pendingTapFix = false
                    fireFix()
                } else if wasDown && fixEnabled && !fixHold && count == fixCount
                            && peekEnabled && peekCount > count {
                    armDelayedFix()   // feuert, wenn kein weiterer Druck mehr kommt
                }
            } else {
                reset()   // weiterer Modifier dazu → keine Auslöser-Geste
            }
        }
    }

    /// Plant das Halten-Feuern: Peek → `onPeek` (Phase peeking), Fix → `onFixOpen`.
    private func armHold(fix: Bool) {
        holdToken &+= 1
        let token = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self, self.holdToken == token, self.phase == .down else { return }
            if fix {
                self.reset()
                self.onFixOpen?()
            } else {
                self.phase = .peeking
                self.pendingTapFix = false
                self.onPeek?()
            }
        }
    }

    /// Fix mit WENIGER Drücken als der Kurzblick: erst feuern, wenn das Tap-Fenster
    /// ohne weiteren Druck verstrichen ist (sonst wäre die längere Geste unmöglich).
    private func armDelayedFix() {
        holdToken &+= 1
        let token = holdToken
        DispatchQueue.main.asyncAfter(deadline: .now() + tapWindow) { [weak self] in
            guard let self, self.holdToken == token, self.phase == .up else { return }
            self.fireFix()
        }
    }

    private func fireFix() {
        reset()
        DispatchQueue.main.async { self.onFixOpen?() }
    }
}
