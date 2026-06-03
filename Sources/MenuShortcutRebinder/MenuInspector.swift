import AppKit
import ApplicationServices

/// Der Menüpunkt, über dem der Cursor beim Auslösen stand.
struct MenuTarget {
    let title: String        // Leaf-Titel, z. B. „Suchen"
    let menuPath: [String]   // Oberste Menüs zuerst, z. B. ["Bearbeiten"]
    let pid: pid_t
    let bundleID: String?
    let appName: String?
}

/// Liest per Accessibility-API den Menüpunkt unter dem Mauszeiger und schließt
/// offene Menüs wieder.
enum MenuInspector {

    /// Ermittelt den Menüpunkt unter der aktuellen Mausposition – oder `nil`,
    /// wenn dort kein Menüeintrag liegt.
    static func itemUnderCursor() -> MenuTarget? {
        // CGEvent.location liefert die Mausposition in globalen Display-Koordinaten
        // mit Ursprung oben-links – exakt das, was die AX-Trefferabfrage erwartet.
        guard let location = CGEvent(source: nil)?.location else { return nil }

        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(system,
                                                   Float(location.x),
                                                   Float(location.y),
                                                   &hit)
        guard err == .success, let element = hit else { return nil }
        guard axString(element, kAXRoleAttribute) == kAXMenuItemRole else { return nil }

        guard let title = axString(element, kAXTitleAttribute), !title.isEmpty else { return nil }

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)

        return MenuTarget(title: title,
                          menuPath: menuPath(of: element),
                          pid: pid,
                          bundleID: app?.bundleIdentifier,
                          appName: app?.localizedName)
    }

    /// Schließt ein offenes Menü, indem ⎋ (Escape) gepostet wird.
    static func dismissOpenMenu() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let escapeKey: CGKeyCode = 53
        CGEvent(keyboardEventSource: source, virtualKey: escapeKey, keyDown: true)?
            .post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: escapeKey, keyDown: false)?
            .post(tap: .cghidEventTap)
    }

    // MARK: - AX-Helfer

    private static func menuPath(of element: AXUIElement) -> [String] {
        var path: [String] = []
        var current: AXUIElement? = element
        var hops = 0
        while let node = current, hops < 25 {
            if axString(node, kAXRoleAttribute) == kAXMenuBarItemRole,
               let title = axString(node, kAXTitleAttribute) {
                path.insert(title, at: 0)
            }
            current = axElement(node, kAXParentAttribute)
            hops += 1
        }
        return path
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func axElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }
        return (raw as! AXUIElement)
    }
}
