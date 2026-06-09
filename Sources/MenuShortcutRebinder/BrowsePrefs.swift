import Foundation

/// Persistente Favoriten und dauerhaft ausgeblendete Befehle (in UserDefaults).
/// Schlüssel je Eintrag: „<bundleID>|<Menüpfad>" – also pro App eindeutig.
enum BrowsePrefs {
    private static let favKey = "browseFavorites"
    private static let hidKey = "browseHidden"
    private static let colKey = "browseCollapsed"

    static var favorites: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: favKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: favKey) }
    }
    static var hidden: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hidKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: hidKey) }
    }
    /// Eingeklappte Kategorien (Schlüssel „<bundleID>|<Kategorie>"), bleibt über Öffnen hinweg erhalten.
    static var collapsed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: colKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: colKey) }
    }
}
