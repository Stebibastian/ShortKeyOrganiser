import AppKit
import Carbon.HIToolbox

/// Globale Tastenkürzel (echte Tastenkombinationen wie ⌘⇧T oder Hyperkey+8) über die
/// klassische Carbon-HotKey-API. Anders als die Modifier-Gesten (PeekTriggerDetector)
/// feuert das hier auf einen normalen Shortcut und „schluckt" ihn systemweit, sodass er
/// nicht zusätzlich in der Vordergrund-App landet.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private struct Entry {
        let ref: EventHotKeyRef
        let action: () -> Void
    }
    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    /// Registriert eine Kombination. `keyCode` < 0 = nichts registrieren.
    /// Liefert eine ID zum späteren Entfernen, oder nil bei Fehler/ungültiger Eingabe.
    @discardableResult
    func register(keyCode: Int, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) -> UInt32? {
        guard keyCode >= 0 else { return nil }
        installHandlerIfNeeded()
        let id = nextID; nextID += 1
        var ref: EventHotKeyRef?
        let hotID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), Self.carbonModifiers(modifiers),
                                         hotID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        entries[id] = Entry(ref: ref, action: action)
        return id
    }

    /// Entfernt alle registrierten Kürzel (vor jedem Neukonfigurieren aufrufen).
    func unregisterAll() {
        for (_, e) in entries { UnregisterEventHotKey(e.ref) }
        entries.removeAll()
    }

    // MARK: - intern

    private static let signature: OSType = {
        let c = Array("SKOr".utf8)
        return (OSType(c[0]) << 24) | (OSType(c[1]) << 16) | (OSType(c[2]) << 8) | OSType(c[3])
    }()

    private static func carbonModifiers(_ m: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if m.contains(.command) { c |= UInt32(cmdKey) }
        if m.contains(.option)  { c |= UInt32(optionKey) }
        if m.contains(.control) { c |= UInt32(controlKey) }
        if m.contains(.shift)   { c |= UInt32(shiftKey) }
        return c
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let this = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let entry = mgr.entries[hkID.id] {
                DispatchQueue.main.async { entry.action() }
            }
            return noErr
        }, 1, &spec, this, nil)
    }
}

/// Formatiert eine Tastenkombination zur Anzeige (z. B. „⌘⇧T", „⌃⌥⌘8").
enum HotKeyFormat {
    static func describe(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyName(keyCode)
    }

    /// Tastencode → lesbares Zeichen (US-Standardbelegung; reicht für die Anzeige).
    static func keyName(_ code: Int) -> String {
        if let n = names[code] { return n }
        return "#\(code)"
    }

    private static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        65: ".", 67: "*", 69: "+", 71: "⌧", 75: "/", 76: "↩", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "↖", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
