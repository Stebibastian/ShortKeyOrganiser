import AppKit

/// Dauerhaft gespeicherte Einstellungen (UserDefaults).
enum Settings {
    private static let triggerKeyCodeKey = "triggerKeyCode"
    private static let holdDurationKey = "holdDuration"

    static let defaultTriggerKeyCode = 54   // rechte ⌘ (Command)
    static let defaultHoldDuration = 0.6

    static var triggerKeyCode: Int {
        get { UserDefaults.standard.object(forKey: triggerKeyCodeKey) as? Int ?? defaultTriggerKeyCode }
        set { UserDefaults.standard.set(newValue, forKey: triggerKeyCodeKey) }
    }

    static var holdDuration: Double {
        get { UserDefaults.standard.object(forKey: holdDurationKey) as? Double ?? defaultHoldDuration }
        set { UserDefaults.standard.set(newValue, forKey: holdDurationKey) }
    }

    private static let browseScreenPercentKey = "browseScreenPercent"
    static let defaultBrowsePercent = 0.8
    /// Anteil des Bildschirms (0.5-1.0), den das „Befehle durchsuchen"-Fenster einnimmt.
    static var browseScreenPercent: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseScreenPercentKey) as? Double ?? defaultBrowsePercent
            return min(1.0, max(0.5, v))
        }
        set { UserDefaults.standard.set(min(1.0, max(0.5, newValue)), forKey: browseScreenPercentKey) }
    }

    private static let browseColumnWidthKey = "browseColumnWidth"
    static let defaultBrowseColumnWidth = 250.0
    /// Gewünschte Spaltenbreite (160-520 pt) der „Befehle durchsuchen"-Ansicht; bestimmt die Spaltenzahl.
    static var browseColumnWidth: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseColumnWidthKey) as? Double ?? defaultBrowseColumnWidth
            return min(520, max(160, v))
        }
        set { UserDefaults.standard.set(min(520, max(160, newValue)), forKey: browseColumnWidthKey) }
    }

    // Peek-Auslöser für „Befehle durchsuchen": Modifier zweimal drücken + halten.
    private static let peekModifierKey = "peekModifierIndex"
    static let defaultPeekModifier = 0   // 0=⌘, 1=⌥, 2=⌃
    static var peekModifierIndex: Int {
        get { UserDefaults.standard.object(forKey: peekModifierKey) as? Int ?? defaultPeekModifier }
        set { UserDefaults.standard.set(newValue, forKey: peekModifierKey) }
    }

    private static let peekHoldKey = "peekHoldDuration"
    static let defaultPeekHold = 0.15
    /// Sekunden, die der zweite Druck gehalten werden muss (0.05-1.0).
    static var peekHoldDuration: Double {
        get {
            let v = UserDefaults.standard.object(forKey: peekHoldKey) as? Double ?? defaultPeekHold
            return min(1.0, max(0.05, v))
        }
        set { UserDefaults.standard.set(min(1.0, max(0.05, newValue)), forKey: peekHoldKey) }
    }

    private static let peekEnabledKey = "peekEnabled"
    static var peekEnabled: Bool {
        get { UserDefaults.standard.object(forKey: peekEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: peekEnabledKey) }
    }

    private static let browseZebraKey = "browseZebra"
    static var browseZebra: Bool {
        get { UserDefaults.standard.object(forKey: browseZebraKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: browseZebraKey) }
    }

    private static let browseHighlightKey = "browseHighlight"
    static var browseHighlight: Bool {
        get { UserDefaults.standard.object(forKey: browseHighlightKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: browseHighlightKey) }
    }

    private static let browseTransparencyKey = "browseTransparency"
    /// Transparenz des Durchsuchen-Fensters (0 = undurchsichtig, höher = mehr Blur/Durchblick).
    static var browseTransparency: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseTransparencyKey) as? Double ?? 0.15
            return min(0.6, max(0.0, v))
        }
        set { UserDefaults.standard.set(min(0.6, max(0.0, newValue)), forKey: browseTransparencyKey) }
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
