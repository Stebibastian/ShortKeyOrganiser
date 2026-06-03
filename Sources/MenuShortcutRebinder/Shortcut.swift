import AppKit

/// Repräsentiert ein Tastenkürzel und kodiert es in das Format, das macOS für
/// `NSUserKeyEquivalents` erwartet (z. B. `@$f` für ⌘⇧F).
///
/// Modifier-Glyphen im gespeicherten String:
///   `@` = Command, `~` = Option, `^` = Control, `$` = Shift
struct Shortcut {
    var command = false
    var option  = false
    var control = false
    var shift   = false
    /// Basistaste, bereits normalisiert: Kleinbuchstabe, Ziffer oder Spezial-Glyph.
    var baseKey: String

    /// Ein Menü-Kürzel braucht mindestens einen Modifier, sonst kollidiert es mit
    /// normaler Texteingabe und wird von macOS ignoriert.
    var isValid: Bool { !baseKey.isEmpty && (command || option || control || shift) }

    /// Kodierung für die Voreinstellung `NSUserKeyEquivalents`.
    var encoded: String {
        var s = ""
        if command { s += "@" }
        if option  { s += "~" }
        if control { s += "^" }
        if shift   { s += "$" }
        return s + baseKey
    }

    /// Menschlich lesbare Darstellung, z. B. „⌘⇧F".
    var display: String {
        var s = ""
        if control { s += "⌃" }
        if option  { s += "⌥" }
        if shift   { s += "⇧" }
        if command { s += "⌘" }
        return s + (Self.displayName[baseKey] ?? baseKey.uppercased())
    }

    // MARK: Aufnahme aus einem Tastendruck

    static func from(event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags
        var sc = Shortcut(baseKey: "")
        sc.command = flags.contains(.command)
        sc.option  = flags.contains(.option)
        sc.control = flags.contains(.control)
        sc.shift   = flags.contains(.shift)

        if let special = specialGlyph[event.keyCode] {
            sc.baseKey = special
        } else if let digit = digitForKeyCode[event.keyCode] {
            // Ziffern über den Tastencode auflösen, damit ⇧1 korrekt als „1" + Shift
            // landet und nicht als „!".
            sc.baseKey = digit
        } else if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            sc.baseKey = chars.lowercased()
        } else {
            return nil
        }
        return sc.isValid ? sc : nil
    }

    // MARK: Spezialtasten

    /// Tastencode → Unicode-Glyph, wie es `NSUserKeyEquivalents` für Sondertasten erwartet.
    private static let specialGlyph: [UInt16: String] = [
        36:  "\u{0D}",   // Return / ↩
        48:  "\u{09}",   // Tab / ⇥
        49:  " ",        // Leertaste
        51:  "\u{08}",   // Delete (Backspace) / ⌫
        53:  "\u{1B}",   // Escape / ⎋
        123: "\u{F702}", // ←
        124: "\u{F703}", // →
        125: "\u{F701}", // ↓
        126: "\u{F700}", // ↑
        // Funktionstasten F1–F12 (Glyphen 0xF704 … 0xF70F)
        122: "\u{F704}", 120: "\u{F705}", 99: "\u{F706}", 118: "\u{F707}",
        96:  "\u{F708}", 97:  "\u{F709}", 98: "\u{F70A}", 100: "\u{F70B}",
        101: "\u{F70C}", 109: "\u{F70D}", 103: "\u{F70E}", 111: "\u{F70F}",
    ]

    private static let digitForKeyCode: [UInt16: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
    ]

    /// Rückwärts-Zuordnung für die lesbare Anzeige der Sondertasten.
    private static let displayName: [String: String] = [
        "\u{0D}": "↩", "\u{09}": "⇥", " ": "Leertaste", "\u{08}": "⌫", "\u{1B}": "⎋",
        "\u{F702}": "←", "\u{F703}": "→", "\u{F701}": "↓", "\u{F700}": "↑",
        "\u{F704}": "F1", "\u{F705}": "F2", "\u{F706}": "F3", "\u{F707}": "F4",
        "\u{F708}": "F5", "\u{F709}": "F6", "\u{F70A}": "F7", "\u{F70B}": "F8",
        "\u{F70C}": "F9", "\u{F70D}": "F10", "\u{F70E}": "F11", "\u{F70F}": "F12",
    ]
}
