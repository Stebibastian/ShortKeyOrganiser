import Foundation

/// Ein von diesem Tool gesetztes Kürzel (zum Auflisten & Zurücksetzen).
struct ShortcutRecord: Equatable {
    var scope: Scope
    var bundleID: String?
    var appName: String?
    var menuTitle: String
    var display: String   // lesbar, z. B. „⌘⇧F"
    var encoded: String   // gespeicherte Kodierung, z. B. „@$f"

    /// Identität eines Eintrags (Bereich + App + Menütitel).
    func matches(_ other: ShortcutRecord) -> Bool {
        scope == other.scope && bundleID == other.bundleID && menuTitle == other.menuTitle
    }

    var asDict: [String: String] {
        [
            "scope": scope == .global ? "global" : "app",
            "bundleID": bundleID ?? "",
            "appName": appName ?? "",
            "menuTitle": menuTitle,
            "display": display,
            "encoded": encoded,
        ]
    }

    init(scope: Scope, bundleID: String?, appName: String?,
         menuTitle: String, display: String, encoded: String) {
        self.scope = scope
        self.bundleID = bundleID
        self.appName = appName
        self.menuTitle = menuTitle
        self.display = display
        self.encoded = encoded
    }

    init?(dict: [String: String]) {
        guard let menuTitle = dict["menuTitle"], let encoded = dict["encoded"] else { return nil }
        self.scope = (dict["scope"] == "global") ? .global : .app
        let bundle = dict["bundleID"] ?? ""
        self.bundleID = bundle.isEmpty ? nil : bundle
        let name = dict["appName"] ?? ""
        self.appName = name.isEmpty ? nil : name
        self.menuTitle = menuTitle
        self.display = dict["display"] ?? encoded
        self.encoded = encoded
    }
}

/// Merkt sich – in den eigenen UserDefaults – welche Kürzel dieses Tool gesetzt hat,
/// damit man sie später gezielt zurücksetzen kann (ohne fremde Einträge zu berühren).
enum Registry {
    private static let key = "shortcutRecords"

    static func all() -> [ShortcutRecord] {
        let raw = UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
        return raw.compactMap(ShortcutRecord.init(dict:))
    }

    private static func save(_ records: [ShortcutRecord]) {
        UserDefaults.standard.set(records.map(\.asDict), forKey: key)
    }

    static func add(_ record: ShortcutRecord) {
        var records = all().filter { !$0.matches(record) }
        records.append(record)
        save(records)
    }

    static func remove(_ record: ShortcutRecord) {
        save(all().filter { !$0.matches(record) })
    }

    static func clear() {
        save([])
    }
}
