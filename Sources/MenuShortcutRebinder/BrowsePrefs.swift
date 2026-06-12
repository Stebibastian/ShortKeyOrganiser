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

    // MARK: Verlauf („Zuletzt benutzt")

    private static let recKey = "browseRecents"
    private static let recentsCap = 10

    /// Zuletzt ausgeführte Befehle einer App (Menüpfade, neuester zuerst).
    static func recents(for appKey: String) -> [String] {
        let dict = UserDefaults.standard.dictionary(forKey: recKey) as? [String: [String]] ?? [:]
        return dict[appKey] ?? []
    }

    /// Merkt einen ausgeführten Befehl (rückt an die Spitze, max. `recentsCap` je App).
    static func addRecent(_ path: String, for appKey: String) {
        guard !appKey.isEmpty else { return }
        var dict = UserDefaults.standard.dictionary(forKey: recKey) as? [String: [String]] ?? [:]
        var list = dict[appKey] ?? []
        list.removeAll { $0 == path }
        list.insert(path, at: 0)
        dict[appKey] = Array(list.prefix(recentsCap))
        UserDefaults.standard.set(dict, forKey: recKey)
    }
}
