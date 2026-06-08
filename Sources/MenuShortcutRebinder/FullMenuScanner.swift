import AppKit
import ApplicationServices

/// Ein einzelner Menübefehl einer App – für die „Befehle durchsuchen"-Liste.
struct BrowseItem: Identifiable {
    let id = UUID()
    let title: String         // Leaf-Titel, z. B. „Suchen"
    let menuPath: [String]    // oberste Menüs zuerst, z. B. ["Bearbeiten"]
    let pathDisplay: String   // lesbarer Pfad, z. B. „Bearbeiten ▸ Suchen ▸ Im Web suchen"
    let shortcut: String      // aktuelles Kürzel, lesbar, z. B. „⌘F" (leer = keins)
    let modifiers: Set<Character>  // {⌃,⌥,⇧,⌘} des Kürzels – fürs Live-Highlight
    let baseKey: String            // Basistaste (leer = kein Kürzel)
    let enabled: Bool              // aktuell auswählbar? (sonst grau)
    let element: AXUIElement?      // Referenz auf den Menüpunkt – zum Ausführen (AXPress)

    /// Untermenü-Pfad ohne das oberste Menü, z. B. ["Automatisch ausfüllen"].
    var subPath: [String] { menuPath.count > 1 ? Array(menuPath.dropFirst()) : [] }
}

/// Liest die KOMPLETTE Menüleiste einer App über die Accessibility-API.
/// (Ergänzt `MenuInspector`, der nur den Punkt unter dem Mauszeiger liest.)
enum FullMenuScanner {

    static func scan(pid: pid_t, maxDepth: Int = 8) -> [BrowseItem] {
        let app = AXUIElementCreateApplication(pid)
        guard let barObj = rawAttr(app, "AXMenuBar") else { return [] }
        let bar = barObj as! AXUIElement
        var out: [BrowseItem] = []
        for (idx, item) in children(bar).enumerated() {
            if idx == 0 { continue }                       // Apple-Menü überspringen
            let menuName = title(item)
            guard !menuName.isEmpty, let menu = children(item).first else { continue }
            walk(menu, path: [menuName], depth: 0, maxDepth: maxDepth, into: &out)
        }
        return out
    }

    private static func walk(_ menu: AXUIElement, path: [String],
                             depth: Int, maxDepth: Int, into out: inout [BrowseItem]) {
        if depth > maxDepth { return }
        for it in children(menu) {
            let t = title(it)
            if t.isEmpty { continue }                      // Trenner
            if let submenu = children(it).first {
                walk(submenu, path: path + [t], depth: depth + 1, maxDepth: maxDepth, into: &out)
            } else {
                let sc = shortcut(of: it)
                let enabled = (rawAttr(it, "AXEnabled") as? Bool) ?? true
                out.append(BrowseItem(title: t, menuPath: path,
                                      pathDisplay: (path + [t]).joined(separator: " ▸ "),
                                      shortcut: sc.display, modifiers: sc.mods, baseKey: sc.base,
                                      enabled: enabled, element: it))
            }
        }
    }

    /// Liest das aktuell zugewiesene Tastenkürzel eines Menüpunkts.
    private static func shortcut(of item: AXUIElement) -> (display: String, mods: Set<Character>, base: String) {
        let raw = (rawAttr(item, "AXMenuItemCmdModifiers") as? Int) ?? 0
        var key = ""
        if let ch = rawAttr(item, "AXMenuItemCmdChar") as? String,
           !ch.trimmingCharacters(in: .whitespaces).isEmpty {
            key = symbolFor(ch)
        } else if let vk = rawAttr(item, "AXMenuItemCmdVirtualKey") as? Int, let sym = vkMap[vk] {
            key = sym
        }
        guard !key.isEmpty else { return ("", [], "") }
        var mods: Set<Character> = []
        var s = ""
        if raw & 0x04 != 0 { mods.insert("⌃"); s += "⌃" }   // Control
        if raw & 0x02 != 0 { mods.insert("⌥"); s += "⌥" }   // Option
        if raw & 0x01 != 0 { mods.insert("⇧"); s += "⇧" }   // Shift
        if raw & 0x08 == 0 { mods.insert("⌘"); s += "⌘" }   // Command (Eigenheit: 0x08 = KEIN ⌘)
        return (s + key, mods, key)
    }

    // MARK: - AX-Helfer

    private static func rawAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }
    private static func children(_ el: AXUIElement) -> [AXUIElement] {
        (rawAttr(el, "AXChildren") as? [AXUIElement]) ?? []
    }
    private static func title(_ el: AXUIElement) -> String {
        (rawAttr(el, "AXTitle") as? String) ?? ""
    }

    /// Wandelt ein AX-Kürzelzeichen in die lesbare Form. Pfeil-/Funktionstasten liefert macOS als
    /// Unicode-Funktionstasten (U+F700…), die sonst als „?" erscheinen würden.
    private static func symbolFor(_ ch: String) -> String {
        if let scalar = ch.unicodeScalars.first, let sym = fkMap[scalar.value] { return sym }
        return ch.uppercased()
    }

    private static let fkMap: [UInt32: String] = [
        0xF700: "↑", 0xF701: "↓", 0xF702: "←", 0xF703: "→",
        0xF728: "⌦", 0xF729: "↖", 0xF72B: "↘", 0xF72C: "⇞", 0xF72D: "⇟",
        0xF704: "F1", 0xF705: "F2", 0xF706: "F3", 0xF707: "F4", 0xF708: "F5",
        0xF709: "F6", 0xF70A: "F7", 0xF70B: "F8", 0xF70C: "F9", 0xF70D: "F10",
        0xF70E: "F11", 0xF70F: "F12", 0xF710: "F13", 0xF711: "F14", 0xF712: "F15",
    ]

    private static let vkMap: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Leertaste", 51: "⌫", 53: "⎋", 71: "⌧",
        76: "↩", 115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
    ]
}
