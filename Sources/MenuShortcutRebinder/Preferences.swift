import Foundation

/// Geltungsbereich des Kürzels.
enum Scope: Equatable {
    case app      // nur die Ziel-App (Domain = Bundle-ID)
    case global   // alle Programme  (Domain = .GlobalPreferences)
}

/// Schreibt/liest die native macOS-Voreinstellung `NSUserKeyEquivalents` – also
/// genau den Mechanismus, den auch Systemeinstellungen → Tastatur → Kurzbefehle →
/// „App-Kurzbefehle" verwendet. Dadurch ist die Änderung dieselbe, die macOS selbst
/// anbietet (und z. B. mit CustomShortcuts kompatibel).
enum Preferences {
    private static let key = "NSUserKeyEquivalents" as CFString

    private static func appID(for scope: Scope, bundleID: String?) -> CFString {
        switch scope {
        case .global: return kCFPreferencesAnyApplication
        case .app:    return (bundleID ?? "") as CFString
        }
    }

    /// Aktuelle Zuordnung „Menütitel → Kürzel" für den gegebenen Bereich.
    static func current(scope: Scope, bundleID: String?) -> [String: String] {
        let id = appID(for: scope, bundleID: bundleID)
        let value = CFPreferencesCopyValue(key, id, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return (value as? [String: String]) ?? [:]
    }

    /// Setzt das Kürzel für einen Menüpunkt und schreibt es dauerhaft.
    @discardableResult
    static func set(menuTitle: String, encoded: String, scope: Scope, bundleID: String?) -> Bool {
        if scope == .app, (bundleID ?? "").isEmpty { return false }
        let id = appID(for: scope, bundleID: bundleID)
        var dict = current(scope: scope, bundleID: bundleID)
        dict[menuTitle] = encoded
        CFPreferencesSetValue(key, dict as CFDictionary, id,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesSynchronize(id, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    /// Entfernt das Kürzel für einen Menüpunkt wieder. Andere (z. B. vom Nutzer
    /// selbst angelegte) Einträge derselben Domain bleiben erhalten.
    @discardableResult
    static func remove(menuTitle: String, scope: Scope, bundleID: String?) -> Bool {
        let id = appID(for: scope, bundleID: bundleID)
        var dict = current(scope: scope, bundleID: bundleID)
        dict.removeValue(forKey: menuTitle)
        // Leeres Dictionary → Schlüssel ganz entfernen, sonst aktualisieren.
        let value: CFPropertyList? = dict.isEmpty ? nil : (dict as CFDictionary)
        CFPreferencesSetValue(key, value, id, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesSynchronize(id, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
