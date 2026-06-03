import AppKit

// Menü-Kurzbefehl-Umbieger: lange die Auslöser-Taste (rechte ⌃) über einem
// Menüpunkt halten → Fenster „Tastenkürzel anpassen?" → für diese App oder global.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
