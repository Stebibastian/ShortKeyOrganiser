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
    /// Breiten-Anteil am Bildschirm (0.4-1.0) für das ShortKeyOrganiser-Fenster.
    static var browseScreenPercent: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseScreenPercentKey) as? Double ?? defaultBrowsePercent
            return min(1.0, max(0.4, v))
        }
        set { UserDefaults.standard.set(min(1.0, max(0.4, newValue)), forKey: browseScreenPercentKey) }
    }

    private static let browseHeightPercentKey = "browseHeightPercent"
    /// Höhen-Anteil am Bildschirm (0.4-1.0); nur relevant, wenn Breite/Höhe entkoppelt sind.
    static var browseHeightPercent: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseHeightPercentKey) as? Double ?? defaultBrowsePercent
            return min(1.0, max(0.4, v))
        }
        set { UserDefaults.standard.set(min(1.0, max(0.4, newValue)), forKey: browseHeightPercentKey) }
    }

    private static let browseSizeLinkedKey = "browseSizeLinked"
    /// true = ein Regler steuert Breite und Höhe gemeinsam; false = getrennt einstellbar.
    static var browseSizeLinked: Bool {
        get { UserDefaults.standard.object(forKey: browseSizeLinkedKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: browseSizeLinkedKey) }
    }

    private static let browseAnchorKey = "browseAnchor"
    /// Fenster-Anker: 0=Mitte, 1=oben, 2=unten, 3=links, 4=rechts, 5=oben-links, 6=oben-rechts, 7=unten-links, 8=unten-rechts.
    static var browseAnchor: Int {
        get { UserDefaults.standard.object(forKey: browseAnchorKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: browseAnchorKey) }
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

    private static let peekPressCountKey = "peekPressCount"
    /// Drücke für den Kurzblick (2-5; beim letzten wird gehalten).
    static var peekPressCount: Int {
        get {
            let v = UserDefaults.standard.object(forKey: peekPressCountKey) as? Int ?? 2
            return min(5, max(2, v))
        }
        set { UserDefaults.standard.set(min(5, max(2, newValue)), forKey: peekPressCountKey) }
    }

    private static let fixEnabledKey = "fixOpenEnabled"
    /// Geste „Fenster fix öffnen" aktiv?
    static var fixOpenEnabled: Bool {
        get { UserDefaults.standard.object(forKey: fixEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: fixEnabledKey) }
    }

    private static let fixPressCountKey = "fixPressCount"
    /// Drücke für „Fenster fix öffnen" (2-5).
    static var fixPressCount: Int {
        get {
            let v = UserDefaults.standard.object(forKey: fixPressCountKey) as? Int ?? 3
            return min(5, max(2, v))
        }
        set { UserDefaults.standard.set(min(5, max(2, newValue)), forKey: fixPressCountKey) }
    }

    private static let fixHoldKey = "fixHoldAtEnd"
    /// true = auch „fix öffnen" feuert erst beim Halten am Ende (statt sofort beim letzten Druck).
    static var fixHoldAtEnd: Bool {
        get { UserDefaults.standard.bool(forKey: fixHoldKey) }   // Standard: aus
        set { UserDefaults.standard.set(newValue, forKey: fixHoldKey) }
    }

    /// Symbol der gewählten Auslöser-Taste fürs Overlay/Onboarding (⌘/⌥/⌃).
    static var peekModifierSymbol: String {
        ["⌘", "⌥", "⌃"][min(2, max(0, peekModifierIndex))]
    }

    // MARK: Favoriten-Popup (eigener Auslöser, zeigt nur die Favoriten der aktiven App neben der Maus)
    private static let favEnabledKey = "favEnabled"
    static var favEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: favEnabledKey) }   // Standard: aus (opt-in)
        set { UserDefaults.standard.set(newValue, forKey: favEnabledKey) }
    }
    private static let favModifierKey = "favModifierIndex"
    /// 0=⌘, 1=⌥, 2=⌃. Standard ⌥, damit es sich vom Overlay-Auslöser (⌘) unterscheidet.
    static var favModifierIndex: Int {
        get { UserDefaults.standard.object(forKey: favModifierKey) as? Int ?? 1 }
        set { UserDefaults.standard.set(newValue, forKey: favModifierKey) }
    }
    private static let favPressCountKey = "favPressCount"
    static var favPressCount: Int {
        get { let v = UserDefaults.standard.object(forKey: favPressCountKey) as? Int ?? 2; return min(5, max(2, v)) }
        set { UserDefaults.standard.set(min(5, max(2, newValue)), forKey: favPressCountKey) }
    }
    private static let favHoldKey = "favHoldAtEnd"
    static var favHoldAtEnd: Bool {
        get { UserDefaults.standard.object(forKey: favHoldKey) as? Bool ?? true }   // Standard: halten (tap-tap-hold)
        set { UserDefaults.standard.set(newValue, forKey: favHoldKey) }
    }
    static var favModifierSymbol: String { ["⌘", "⌥", "⌃"][min(2, max(0, favModifierIndex))] }

    /// Setzt alle EINSTELLUNGEN auf die Werkseinstellung zurück. Nutzerdaten bleiben:
    /// Favoriten, Verlauf, ausgeblendete Befehle, Onboarding-Status und Sprache.
    static func resetAll() {
        let keys = [triggerKeyCodeKey, holdDurationKey,
                    peekModifierKey, peekHoldKey, peekEnabledKey, peekPressCountKey,
                    fixEnabledKey, fixPressCountKey, fixHoldKey,
                    favEnabledKey, favModifierKey, favPressCountKey, favHoldKey,
                    browseScreenPercentKey, browseHeightPercentKey, browseSizeLinkedKey,
                    browseAnchorKey, browseColumnWidthKey, browseZebraKey, browseHighlightKey,
                    browseFontSizeKey, browseTransparencyKey, browseBackgroundStyleKey,
                    browseCompactKey, browseKeyLeftKey, browseOpaqueRowsKey, browseShowRecentsKey,
                    autoUpdateKey]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
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

    private static let browseFontSizeKey = "browseFontSize"
    /// Schriftgrösse der Befehlszeilen (11-18 pt).
    static var browseFontSize: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseFontSizeKey) as? Double ?? 14
            return min(18, max(11, v))
        }
        set { UserDefaults.standard.set(min(18, max(11, newValue)), forKey: browseFontSizeKey) }
    }

    private static let autoUpdateKey = "autoUpdate"
    /// Neue Versionen automatisch im Hintergrund installieren (statt nur zu melden).
    static var autoUpdate: Bool {
        get { UserDefaults.standard.bool(forKey: autoUpdateKey) }   // Standard: aus
        set { UserDefaults.standard.set(newValue, forKey: autoUpdateKey) }
    }

    /// Unterstützte Oberflächensprachen.
    static let supportedLanguages = ["de", "en", "fr", "es", "it"]

    private static let appLanguageKey = "appLanguage"
    /// Sprache der Oberfläche: "system" (Standard) oder ein Code aus `supportedLanguages`.
    static var appLanguage: String {
        get { UserDefaults.standard.string(forKey: appLanguageKey) ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: appLanguageKey) }
    }

    /// Tatsächlich genutzte Sprache, aus Einstellung + System-Sprachreihenfolge abgeleitet.
    static var resolvedLanguage: String {
        if supportedLanguages.contains(appLanguage) { return appLanguage }
        for code in Locale.preferredLanguages {
            let base = String(code.prefix(2))
            if supportedLanguages.contains(base) { return base }
        }
        return "en"
    }

    private static let moveDeclinedKey = "moveDeclined"
    /// Hat der Nutzer das Verschieben nach /Applications einmal abgelehnt? Dann nicht erneut fragen.
    static var moveDeclined: Bool {
        get { UserDefaults.standard.bool(forKey: moveDeclinedKey) }
        set { UserDefaults.standard.set(newValue, forKey: moveDeclinedKey) }
    }

    private static let onboardingDoneKey = "onboardingDone"
    /// Wurde das Einführungs-Tutorial schon abgeschlossen/übersprungen?
    static var onboardingDone: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingDoneKey) }
    }

    private static let browseTransparencyKey = "browseTransparency"
    /// Transparenz des Durchsuchen-Fensters (0 = undurchsichtig, höher = mehr Blur/Durchblick).
    static var browseTransparency: Double {
        get {
            let v = UserDefaults.standard.object(forKey: browseTransparencyKey) as? Double ?? 0.15
            return min(0.30, max(0.0, v))
        }
        set { UserDefaults.standard.set(min(0.30, max(0.0, newValue)), forKey: browseTransparencyKey) }
    }

    private static let browseBackgroundStyleKey = "browseBackgroundStyle"
    /// 0 = undurchsichtig, 1 = transparent (mit browseTransparency), 2 = Milchglas (Blur). Standard: Milchglas.
    static var browseBackgroundStyle: Int {
        get { UserDefaults.standard.object(forKey: browseBackgroundStyleKey) as? Int ?? 2 }
        set { UserDefaults.standard.set(newValue, forKey: browseBackgroundStyleKey) }
    }

    private static let browseCompactKey = "browseCompactSections"
    /// Sektionen kompakt stapeln (mehrere je Spalte, KeyClu-Stil) statt jede Sektion in eine eigene Spalte.
    static var browseCompactSections: Bool {
        get { UserDefaults.standard.object(forKey: browseCompactKey) as? Bool ?? true }   // Standard: kompakt
        set { UserDefaults.standard.set(newValue, forKey: browseCompactKey) }
    }

    private static let browseKeyLeftKey = "browseKeyLeft"
    /// Tastenkürzel links (rechtsbündig) + Name rechts (linksbündig), statt Name links + Kürzel rechts.
    static var browseKeyLeft: Bool {
        get { UserDefaults.standard.bool(forKey: browseKeyLeftKey) }   // Standard: aus
        set { UserDefaults.standard.set(newValue, forKey: browseKeyLeftKey) }
    }

    private static let browseShowRecentsKey = "browseShowRecents"
    /// „Zuletzt benutzt"-Gruppe (die letzten ausgeführten Befehle je App) im Overlay anzeigen.
    static var browseShowRecents: Bool {
        get { UserDefaults.standard.object(forKey: browseShowRecentsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: browseShowRecentsKey) }
    }

    private static let browseOpaqueRowsKey = "browseOpaqueRows"
    /// Im Transparent-Modus: Befehlszeilen mit deckendem Hintergrund (bessere Lesbarkeit).
    static var browseOpaqueRows: Bool {
        get { UserDefaults.standard.object(forKey: browseOpaqueRowsKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: browseOpaqueRowsKey) }
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
