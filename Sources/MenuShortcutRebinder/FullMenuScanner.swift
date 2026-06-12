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

/// Ergebnis eines Einzelmenü-Scans (mit Hinweis, falls die Sicherheitsgrenze griff).
struct MenuScanResult {
    let name: String
    let items: [BrowseItem]
    let truncated: Bool   // true = Menü war absurd gross, nur die ersten maxItemsPerMenu gelesen
}

/// Liest die KOMPLETTE Menüleiste einer App über die Accessibility-API.
/// (Ergänzt `MenuInspector`, der nur den Punkt unter dem Mauszeiger liest.)
///
/// Performance: Jeder AX-Aufruf ist ein Prozess-Roundtrip zur Ziel-App (~1-2 ms).
/// Darum werden alle benötigten Attribute eines Eintrags GEBÜNDELT in einem einzigen
/// Aufruf gelesen (`AXUIElementCopyMultipleAttributeValues`) statt mit 6 Einzelaufrufen,
/// und der Scan läuft menüweise (`topMenus` + `scanMenu`), damit der Aufrufer Ergebnisse
/// inkrementell anzeigen kann.
enum FullMenuScanner {

    /// Sicherheitsgrenze pro Top-Menü (dynamische Menüs können tausende Einträge haben).
    static let maxItemsPerMenu = 2000

    /// Die Top-Menüs der App (ohne Apple-Menü): Name + AXMenu-Element. Schnell (~10 Aufrufe).
    static func topMenus(pid: pid_t) -> [(name: String, menu: AXUIElement)] {
        let app = AXUIElementCreateApplication(pid)
        guard let barObj = rawAttr(app, "AXMenuBar") else { return [] }
        let bar = barObj as! AXUIElement
        var out: [(String, AXUIElement)] = []
        for (idx, item) in children(bar).enumerated() {
            if idx == 0 { continue }                       // Apple-Menü überspringen
            let menuName = title(item)
            guard !menuName.isEmpty, let menu = children(item).first else { continue }
            out.append((menuName, menu))
        }
        return out
    }

    /// Scannt EIN Top-Menü komplett (inkl. Untermenüs, gebündelte Attribut-Abfragen).
    static func scanMenu(_ menu: AXUIElement, named name: String, maxDepth: Int = 8) -> MenuScanResult {
        var items: [BrowseItem] = []
        walk(menu, path: [name], depth: 0, maxDepth: maxDepth, into: &items)
        return MenuScanResult(name: name, items: items, truncated: items.count >= maxItemsPerMenu)
    }

    /// Kompletter Scan in einem Rutsch (Mess-Modus und einfache Aufrufer).
    static func scan(pid: pid_t, maxDepth: Int = 8) -> [BrowseItem] {
        topMenus(pid: pid).flatMap { scanMenu($0.menu, named: $0.name, maxDepth: maxDepth).items }
    }

    private static func walk(_ menu: AXUIElement, path: [String],
                             depth: Int, maxDepth: Int, into out: inout [BrowseItem]) {
        if depth > maxDepth || out.count >= maxItemsPerMenu { return }
        for it in children(menu) {
            if out.count >= maxItemsPerMenu { return }
            // Alle Attribute des Eintrags in EINEM Roundtrip lesen.
            let v = itemAttributes(it)
            guard let t = v.title, !t.isEmpty else { continue }   // Trenner
            if let submenu = v.children.first {
                walk(submenu, path: path + [t], depth: depth + 1, maxDepth: maxDepth, into: &out)
            } else {
                let sc = shortcut(char: v.cmdChar, virtualKey: v.cmdVirtualKey, rawModifiers: v.cmdModifiers)
                out.append(BrowseItem(title: t, menuPath: path,
                                      pathDisplay: (path + [t]).joined(separator: " ▸ "),
                                      shortcut: sc.display, modifiers: sc.mods, baseKey: sc.base,
                                      enabled: v.enabled, element: it))
            }
        }
    }

    // MARK: - Gebündelte Attribut-Abfrage

    private struct ItemAttributes {
        var title: String?
        var children: [AXUIElement] = []
        var enabled = true
        var cmdChar: String?
        var cmdVirtualKey: Int?
        var cmdModifiers = 0
    }

    private static let batchAttrNames = ["AXTitle", "AXEnabled",
                                         "AXMenuItemCmdChar", "AXMenuItemCmdVirtualKey",
                                         "AXMenuItemCmdModifiers"]

    /// Liest Titel, Aktiv-Status und Kürzel-Attribute eines Menüpunkts in einem einzigen
    /// AX-Roundtrip. Die Kinder (Untermenü-Erkennung) kommen separat per Einzelaufruf:
    /// `CopyMultipleAttributeValues` liefert für dynamische Untermenüs (z. B. FileMakers
    /// Layout-Liste) teils leere Platzhalter, der Einzelaufruf stösst die Befüllung an.
    private static func itemAttributes(_ el: AXUIElement) -> ItemAttributes {
        var arr: CFArray?
        let t0 = statsEnabled ? CFAbsoluteTimeGetCurrent() : 0
        let err = AXUIElementCopyMultipleAttributeValues(el, batchAttrNames as CFArray,
                                                         AXCopyMultipleAttributeOptions(), &arr)
        if statsEnabled { addStat("Batch(5 Attribute)", CFAbsoluteTimeGetCurrent() - t0) }
        var out = ItemAttributes()
        if err == .success, let values = arr as? [AnyObject], values.count == batchAttrNames.count {
            out.title = clean(values[0]) as? String
            out.enabled = (clean(values[1]) as? Bool) ?? true
            out.cmdChar = clean(values[2]) as? String
            out.cmdVirtualKey = clean(values[3]) as? Int
            out.cmdModifiers = (clean(values[4]) as? Int) ?? 0
        } else {
            // Fallback auf Einzelabfragen (sollte praktisch nie nötig sein).
            out.title = title(el)
            out.enabled = (rawAttr(el, "AXEnabled") as? Bool) ?? true
            out.cmdChar = rawAttr(el, "AXMenuItemCmdChar") as? String
            out.cmdVirtualKey = rawAttr(el, "AXMenuItemCmdVirtualKey") as? Int
            out.cmdModifiers = (rawAttr(el, "AXMenuItemCmdModifiers") as? Int) ?? 0
        }
        guard let t = out.title, !t.isEmpty else { return out }   // Trenner: Kinder-Abfrage sparen
        out.children = children(el)
        return out
    }

    /// Filtert die Platzhalter heraus, die `CopyMultipleAttributeValues` für fehlende
    /// Attribute liefert (kCFNull bzw. AXValue vom Typ .axError).
    private static func clean(_ v: AnyObject) -> AnyObject? {
        if v is NSNull { return nil }
        if CFGetTypeID(v) == AXValueGetTypeID(),
           AXValueGetType(v as! AXValue) == .axError { return nil }
        return v
    }

    /// Baut die lesbare Kürzel-Darstellung aus den (bereits gelesenen) Attributwerten.
    private static func shortcut(char: String?, virtualKey: Int?, rawModifiers raw: Int)
        -> (display: String, mods: Set<Character>, base: String) {
        var key = ""
        if let ch = char, !ch.trimmingCharacters(in: .whitespaces).isEmpty {
            key = symbolFor(ch)
        } else if let vk = virtualKey, let sym = vkMap[vk] {
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

    // MARK: - Diagnose (--measure)

    private static var statsEnabled = false
    private static var stats: [String: (count: Int, time: Double)] = [:]

    private static func addStat(_ name: String, _ dt: Double) {
        var s = stats[name] ?? (0, 0)
        s.count += 1; s.time += dt
        stats[name] = s
    }

    /// Misst den kompletten Scan einer laufenden App: Dauer + Eintragszahl pro Top-Menü
    /// sowie Anzahl/Gesamtdauer der AX-Aufrufe je Attribut. Ausgabe auf stdout.
    static func measure(appNamed name: String) {
        guard AXIsProcessTrusted() else {
            print("FEHLER: Prozess hat kein Bedienungshilfen-Recht."); return
        }
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.activationPolicy == .regular
                && (($0.localizedName ?? "").localizedCaseInsensitiveContains(name)
                    || ($0.bundleIdentifier ?? "").localizedCaseInsensitiveContains(name))
        }) else {
            print("FEHLER: App \"\(name)\" läuft nicht. Laufende Apps:")
            for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular {
                print("  - \(a.localizedName ?? "?") [\(a.bundleIdentifier ?? "-")]")
            }
            return
        }

        let pid = app.processIdentifier
        print("App: \(app.localizedName ?? "?") (pid \(pid))")
        statsEnabled = true
        stats = [:]
        let t0 = CFAbsoluteTimeGetCurrent()
        var firstMenuDone: Double?
        for (menuName, menu) in topMenus(pid: pid) {
            let t = CFAbsoluteTimeGetCurrent()
            let result = scanMenu(menu, named: menuName)
            let ms = (CFAbsoluteTimeGetCurrent() - t) * 1000
            if firstMenuDone == nil { firstMenuDone = (CFAbsoluteTimeGetCurrent() - t0) * 1000 }
            let cut = result.truncated ? "  [GEKAPPT]" : ""
            print("  \(menuName.padding(toLength: 28, withPad: " ", startingAt: 0)) \(String(format: "%5d", result.items.count)) Einträge  \(String(format: "%8.0f", ms)) ms\(cut)")
        }
        print(String(format: "TOTAL: %.0f ms  (erstes Menü nach %.0f ms)",
                     (CFAbsoluteTimeGetCurrent() - t0) * 1000, firstMenuDone ?? 0))
        print("\nAX-Aufrufe je Attribut:")
        for (attr, s) in stats.sorted(by: { $0.value.time > $1.value.time }) {
            print("  \(attr.padding(toLength: 28, withPad: " ", startingAt: 0)) \(String(format: "%6d", s.count))×  \(String(format: "%8.0f", s.time * 1000)) ms")
        }
        statsEnabled = false
    }

    // MARK: - AX-Helfer

    private static func rawAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var v: CFTypeRef?
        if statsEnabled {
            let t = CFAbsoluteTimeGetCurrent()
            let ok = AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success
            addStat(name, CFAbsoluteTimeGetCurrent() - t)
            return ok ? v : nil
        }
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
