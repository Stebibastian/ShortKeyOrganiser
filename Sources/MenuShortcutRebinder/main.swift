import AppKit

// Diagnose-Modus: `ShortKeyOrganiser --measure <App-Name>` misst den Menü-Scan
// (Dauer pro Menü + Kosten pro AX-Attribut) und beendet sich, ohne die UI zu starten.
if let i = CommandLine.arguments.firstIndex(of: "--measure"), i + 1 < CommandLine.arguments.count {
    FullMenuScanner.measure(appNamed: CommandLine.arguments[i + 1])
    exit(0)
}

// Menü-Kurzbefehl-Umbieger: lange die Auslöser-Taste (rechte ⌃) über einem
// Menüpunkt halten → Fenster „Tastenkürzel anpassen?" → für diese App oder global.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
