import Foundation

/// Persistente Favoriten und dauerhaft ausgeblendete Befehle (in UserDefaults).
/// Schlüssel je Eintrag: „<bundleID>|<Menüpfad>" – also pro App eindeutig.
enum BrowsePrefs {
    private static let favKey = "browseFavorites"
    private static let hidKey = "browseHidden"

    static var favorites: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: favKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: favKey) }
    }
    static var hidden: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: hidKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: hidKey) }
    }
}
