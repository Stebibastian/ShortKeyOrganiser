import Foundation

/// Liest die Hotkey-Makros aus Keyboard Maestro und stellt sie als `BrowseItem` dar,
/// damit sie im Overlay neben den Menübefehlen auftauchen. Ausführen läuft über die
/// Keyboard-Maestro-Engine (AppleScript) - das verlangt einmalig das Automation-Recht.
enum KeyboardMaestro {
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/Keyboard Maestro.app")
    }

    private static var macrosPlist: String {
        NSHomeDirectory() + "/Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist"
    }

    /// Alle Makros mit Hotkey-Trigger als BrowseItems (menuPath = KM-Gruppe, shortcut = Hotkey).
    static func scan() -> [BrowseItem] {
        guard let data = FileManager.default.contents(atPath: macrosPlist),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let groups = dict["MacroGroups"] as? [[String: Any]] else { return [] }

        var items: [BrowseItem] = []
        for group in groups {
            let gname = (group["Name"] as? String) ?? "Keyboard Maestro"
            guard let macros = group["Macros"] as? [[String: Any]] else { continue }
            for macro in macros {
                guard let name = macro["Name"] as? String, !name.isEmpty,
                      let triggers = macro["Triggers"] as? [[String: Any]] else { continue }
                for t in triggers where (t["MacroTriggerType"] as? String) == "HotKey" {
                    guard let keyCode = t["KeyCode"] as? Int, keyCode >= 0 else { continue }
                    let mods = (t["Modifiers"] as? Int) ?? 0
                    let (shortcut, modSet, baseKey) = format(keyCode: keyCode, modifiers: mods)
                    items.append(BrowseItem(
                        title: name, menuPath: [gname], pathDisplay: gname + " ▸ " + name,
                        shortcut: shortcut, modifiers: modSet, baseKey: baseKey,
                        enabled: true, element: nil))
                    break   // ein Hotkey pro Makro genügt
                }
            }
        }
        return items
    }

    /// Führt ein Makro über die Keyboard-Maestro-Engine aus (per Name).
    static func run(_ name: String) {
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Keyboard Maestro Engine\" to do script \"\(escaped)\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    /// Carbon-Modifier-Maske → ⌃⌥⇧⌘ und virtueller KeyCode → Basistaste.
    private static func format(keyCode: Int, modifiers: Int) -> (String, Set<Character>, String) {
        var glyphs = ""
        var set: Set<Character> = []
        if modifiers & 0x1000 != 0 { glyphs += "⌃"; set.insert("⌃") }   // control
        if modifiers & 0x0800 != 0 { glyphs += "⌥"; set.insert("⌥") }   // option
        if modifiers & 0x0200 != 0 { glyphs += "⇧"; set.insert("⇧") }   // shift
        if modifiers & 0x0100 != 0 { glyphs += "⌘"; set.insert("⌘") }   // command
        let base = keyNames[keyCode] ?? "key\(keyCode)"
        return (glyphs + base, set, base)
    }

    /// Gängige virtuelle Tastencodes → Anzeigezeichen.
    private static let keyNames: [Int: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B",
        12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P",
        37:"L", 38:"J", 40:"K", 45:"N", 46:"M",
        18:"1", 19:"2", 20:"3", 21:"4", 23:"5", 22:"6", 26:"7", 28:"8", 25:"9", 29:"0",
        24:"=", 27:"-", 30:"]", 33:"[", 39:"'", 41:";", 42:"\\", 43:",", 44:"/", 47:".", 50:"`",
        36:"↩", 48:"⇥", 49:"Space", 51:"⌫", 53:"⎋", 117:"⌦",
        123:"←", 124:"→", 125:"↓", 126:"↑",
        122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6", 98:"F7",
        100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12",
    ]
}
