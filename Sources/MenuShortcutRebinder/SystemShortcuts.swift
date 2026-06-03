import AppKit

struct SystemShortcutEntry {
    let menuTitle: String
    let display: String   // lesbar, z. B. „⌃⌥⌘Q"
}

struct SystemShortcutGroup {
    let domain: String    // „Alle Programme" oder App-Name
    let entries: [SystemShortcutEntry]
}

/// Liest alle vom Nutzer angelegten macOS-App-Kurzbefehle (`NSUserKeyEquivalents`)
/// – global und pro App – zur reinen Anzeige.
enum SystemShortcuts {
    static func scan() -> [SystemShortcutGroup] {
        var groups: [SystemShortcutGroup] = []

        // Global („Alle Programme")
        if let global = read(appID: kCFPreferencesAnyApplication), !global.isEmpty {
            groups.append(SystemShortcutGroup(domain: Strings.scopeGlobal, entries: entries(global)))
        }

        // Pro App in ~/Library/Preferences
        let prefs = NSHomeDirectory() + "/Library/Preferences"
        for file in (try? FileManager.default.contentsOfDirectory(atPath: prefs))?.sorted() ?? []
        where file.hasSuffix(".plist") {
            let bundleID = String(file.dropLast(6))
            if bundleID == ".GlobalPreferences" { continue }
            guard let dict = read(appID: bundleID as CFString), !dict.isEmpty else { continue }
            groups.append(SystemShortcutGroup(domain: appName(bundleID), entries: entries(dict)))
        }

        // Pro App in Sandbox-Containern (direkt aus der Datei)
        let containers = NSHomeDirectory() + "/Library/Containers"
        for c in (try? FileManager.default.contentsOfDirectory(atPath: containers))?.sorted() ?? [] {
            let plist = "\(containers)/\(c)/Data/Library/Preferences/\(c).plist"
            guard let dict = NSDictionary(contentsOfFile: plist) as? [String: Any],
                  let ke = dict["NSUserKeyEquivalents"] as? [String: String], !ke.isEmpty else { continue }
            if groups.contains(where: { $0.domain == appName(c) }) { continue }
            groups.append(SystemShortcutGroup(domain: appName(c), entries: entries(ke)))
        }

        return groups
    }

    static func totalCount(_ groups: [SystemShortcutGroup]) -> Int {
        groups.reduce(0) { $0 + $1.entries.count }
    }

    private static func read(appID: CFString) -> [String: String]? {
        CFPreferencesCopyValue("NSUserKeyEquivalents" as CFString, appID,
                               kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: String]
    }

    private static func entries(_ dict: [String: String]) -> [SystemShortcutEntry] {
        dict.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { SystemShortcutEntry(menuTitle: $0.key,
                                       display: Shortcut(encoded: $0.value)?.display ?? $0.value) }
    }

    private static func appName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }
}
