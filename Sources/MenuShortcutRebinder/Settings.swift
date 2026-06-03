import AppKit

/// Dauerhaft gespeicherte Einstellungen (UserDefaults).
enum Settings {
    private static let triggerKeyCodeKey = "triggerKeyCode"
    private static let holdDurationKey = "holdDuration"

    static let defaultTriggerKeyCode = 62   // rechte ⌃ (Control)
    static let defaultHoldDuration = 0.6

    static var triggerKeyCode: Int {
        get { UserDefaults.standard.object(forKey: triggerKeyCodeKey) as? Int ?? defaultTriggerKeyCode }
        set { UserDefaults.standard.set(newValue, forKey: triggerKeyCodeKey) }
    }

    static var holdDuration: Double {
        get { UserDefaults.standard.object(forKey: holdDurationKey) as? Double ?? defaultHoldDuration }
        set { UserDefaults.standard.set(newValue, forKey: holdDurationKey) }
    }
}

/// Bekannte Modifier-Tasten, die als Auslöser taugen.
///
/// Bewusst nur Modifier (kein normaler Buchstabe): Eine normale Taste würde in
/// offenen Menüs die Tipp-Auswahl auslösen und beim Halten Zeichen einfügen.
enum TriggerKey {
    /// Tastencode → Anzeigename.
    static let names: [Int: String] = [
        59: "Linke ⌃ (Control)",  62: "Rechte ⌃ (Control)",
        58: "Linke ⌥ (Option)",   61: "Rechte ⌥ (Option)",
        55: "Linke ⌘ (Command)",  54: "Rechte ⌘ (Command)",
        56: "Linke ⇧ (Shift)",    60: "Rechte ⇧ (Shift)",
    ]

    static func name(for keyCode: Int) -> String {
        names[keyCode] ?? "Taste \(keyCode)"
    }

    /// Kompakter Name für knappe Anzeigen (HUD/Hilfe), z. B. „rechte ⌘".
    static let shortNames: [Int: String] = [
        59: "linke ⌃",  62: "rechte ⌃",
        58: "linke ⌥",  61: "rechte ⌥",
        55: "linke ⌘",  54: "rechte ⌘",
        56: "linke ⇧",  60: "rechte ⇧",
    ]

    static func shortName(for keyCode: Int) -> String {
        shortNames[keyCode] ?? "Taste \(keyCode)"
    }

    static func isValid(_ keyCode: Int) -> Bool {
        names[keyCode] != nil
    }

    /// Zugehörige Modifier-Maske (zum Erkennen von „gedrückt").
    static func flag(for keyCode: Int) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 59, 62: return .control
        case 58, 61: return .option
        case 55, 54: return .command
        case 56, 60: return .shift
        default:     return nil
        }
    }

    static func isPressed(_ keyCode: Int, in flags: NSEvent.ModifierFlags) -> Bool {
        guard let flag = flag(for: keyCode) else { return false }
        return flags.contains(flag)
    }
}
