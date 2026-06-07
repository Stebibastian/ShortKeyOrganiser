import Foundation

/// Zentrale Sammelstelle für alle benutzersichtbaren Texte.
///
/// Dieses Tool hat (noch) keinen mehrsprachigen String-Katalog – es gibt genau
/// eine Zielsprache (Deutsch). Alle Texte stehen hier an einer Stelle und werden
/// nirgends inline hardcodiert, damit eine spätere Lokalisierung (z. B. `.xcstrings`
/// oder `NSLocalizedString`) ohne Suchen-und-Ersetzen möglich ist: Man ersetzt nur
/// die Rückgabewerte unten durch `String(localized:)`-Aufrufe.
enum Strings {
    // Statusleiste
    static let appTitle = "ShortKeyOrganiser"
    static let statusItemTooltip = "Menü-Kurzbefehl anpassen"
    static func triggerInfo(_ trigger: String) -> String { "Auslöser: \(trigger) lange halten" }
    static let menuQuit = "Beenden"
    static let menuDiagnose = "Diagnose & Verbindung …"

    // Diagnose
    static let diagnoseTitle = "Diagnose"
    static func diagnoseBody(accessibility: Bool, tapActive: Bool, trigger: String) -> String {
        let ax = accessibility ? "✓ erteilt" : "✗ fehlt"
        let tap = tapActive ? "✓ aktiv" : "✗ inaktiv"
        var text = "Bedienungshilfen: \(ax)\nTasten-Erkennung (Event-Tap): \(tap)\nAuslöser: \(trigger)"
        if !accessibility || !tapActive {
            text += "\n\nSo behebst du’s:\n"
                + "1. „Bedienungshilfen öffnen“ antippen.\n"
                + "2. MenuShortcutRebinder in der Liste entfernen (–) und mit (+) neu hinzufügen "
                + "– das ist zuverlässiger als nur den Haken umzulegen.\n"
                + "3. Hierher zurück, „Erneut verbinden“."
        }
        return text
    }
    static let diagnoseReconnect = "Erneut verbinden"
    static let menuLoginItem = "Beim Anmelden starten"
    static let menuChangeTrigger = "Auslöser-Taste ändern …"
    static let menuShortcuts = "Tastenkürzel verwalten …"
    static let menuBrowse = "ShortKeyOrganiser …"
    static let menuBrowseSettings = "Durchsuchen-Einstellungen …"
    static let browseSettingsTip = "Einstellungen"
    static let browseManageTip = "Tastenkürzel verwalten"
    static let menuSettings = "Einstellungen …"
    // Zentrale Einstellungen
    static let setWinTitle = "Einstellungen"
    static let setSecRebind = "Tastenkürzel umbelegen"
    static let setRebindTrigger = "Auslöser (über Menüpunkt halten)"
    static let setHold = "Haltedauer"
    static let setSecBrowse = "Befehle durchsuchen"
    static let setPeekEnable = "Per Mehrfachdruck öffnen"
    static let setPeekHint = "⌘⌘ halten = kurzer Blick · ⌘⌘⌘ = fix offen"
    static let setPeekTrigger = "Auslöser-Taste"
    static let setSecView = "Ansicht"
    static let setWindowSize = "Fenstergröße"
    static let setColWidth = "Spaltenbreite"
    static let setZebra = "Zebra-Streifen (abwechselnde Zeilenfarbe)"
    static let setSecTools = "Verwaltung & Hilfe"
    static let setSecGeneral = "Allgemein"
    static let setLogin = "Beim Anmelden starten"
    // Durchsuchen-Einstellungen (Peek + Fenstergröße)
    static let bsTitle = "Befehle durchsuchen - Einstellungen"
    static let bsModifierLabel = "Auslöser-Taste (zweimal drücken, beim zweiten Mal halten):"
    static let bsHoldLabel = "Haltedauer nach dem Doppeldruck"
    static let bsSizeLabel = "Fenstergröße (Anteil am Bildschirm)"
    static let bsModCommand = "Command ⌘"
    static let bsModOption = "Option ⌥"
    static let bsModControl = "Control ⌃"
    static let bsEnableLabel = "Per Doppeldruck öffnen"
    static let bsZebraLabel = "Zebra-Streifen (abwechselnde Zeilenfarbe)"
    static let bsPeekHint = "Zweimal drücken + halten = kurzer Blick (Loslassen schließt). Dreimal drücken = fix offen (bleibt offen). Im Blick die Lupe anklicken hält ebenfalls offen."
    static let bsClose = "Fertig"
    static let menuHelp = "Kurzanleitung …"

    // Tastenkürzel-Fenster mit Tabs
    static let winTitle = "Tastenkürzel"
    static let tabTool = "Vom Tool gesetzt"
    static let tabSystem = "Alle im System"

    // Befehle durchsuchen (Suche im Stil der macOS-Hilfe-Suche)
    static let browseTitle = "ShortKeyOrganiser"
    static let browseSearchPlaceholder = "Befehl suchen … (Schlagwort eintippen)"
    static let browseAppLabel = "App:"
    static let browseLoading = "Befehle werden gelesen …"
    static let browseEmpty = "Keine Menübefehle gefunden. Ist die App offen und eine native Mac-App?"
    static let browseNoMatch = "Kein Treffer."
    static let browseNoAccess = "Bedienungshilfen-Recht fehlt - bitte im ⌘-Menü unter Diagnose & Verbindung prüfen."
    static let browseCustomTip = "Von Dir gesetzt"
    static let browseDeleteTip = "Eigenes Kürzel entfernen (Standard wiederherstellen)"
    static let browseEditTip = "Tastenkürzel anpassen"
    static let browsePerformTip = "Befehl ausführen"
    static let browseFavorites = "★ Favoriten"
    static let browseFavTip = "Als Favorit markieren"
    static let browseHideTip = "Befehl ausblenden"
    static let browseUnhideTip = "Wieder einblenden"
    static let browseShowHidden = "Ausgeblendete anzeigen"
    static let browseShowFavorites = "Favoriten-Gruppe anzeigen"
    static func browseCount(hits: Int, total: Int) -> String { "\(hits) von \(total) Befehlen" }
    static func browseCapped(_ cap: Int) -> String { " (erste \(cap) gezeigt)" }

    // System-Kurzbefehle (Anzeige)
    static let sysEmpty = "Keine eigenen App-Kurzbefehle gefunden."
    static let refresh = "Aktualisieren"
    static let sysEdit = "Ändern"
    static let sysDelete = "Löschen"
    static let sysReadOnly = "– nur lesbar"
    static let sysDeleteTitle = "Kürzel entfernen?"
    static func sysDeleteBody(shortcut: String, title: String, domain: String) -> String {
        "„\(shortcut)“ für „\(title)“ in \(domain) wirklich entfernen?\n\n"
        + "Das ändert einen echten macOS-App-Kurzbefehl. Die betroffene App muss danach "
        + "neu gestartet werden.\n\n"
        + "Hinweis: In den Systemeinstellungen wird die Änderung erst sichtbar, nachdem du "
        + "sie schließt und neu öffnest (deren Liste aktualisiert sich nicht von selbst)."
    }
    static let sysDeletedRestart = "Entfernt – betroffene App neu starten, damit es greift."

    // Verwaltung / Zurücksetzen
    static let managerEmpty = "Noch keine Kürzel über dieses Tool gesetzt."
    static let reset = "Zurücksetzen"
    static let resetAll = "Alle zurücksetzen"
    static let resetAllConfirm = "Wirklich alle hier gelisteten Kürzel zurücksetzen?"
    static let closeButton = "Schließen"
    static let resetDoneRestart = "Zurückgesetzt – betroffene App neu starten, damit es greift."

    // Einstellungsdialog
    static let settingsTitle = "Auslöser anpassen"
    static let settingsTriggerLabel = "Auslöser-Taste (gedrückt halten):"
    static let settingsTriggerHint =
        "Drück die gewünschte Modifier-Taste. Nur Modifier-Tasten – normale Tasten würden "
        + "in offenen Menüs Probleme machen. Am sichersten: ⌃ oder ⇧ (⌥ und teils ⌘ blenden "
        + "in Menüs alternative Einträge ein)."
    static let settingsDurationLabel = "Haltedauer:"

    // Start-Hinweis & Hilfe
    static func launchedHint(_ trigger: String) -> String {
        "Aktiv – \(trigger) über einem Menüpunkt halten"
    }
    static func loginItemFailed(_ reason: String) -> String { "Login-Eintrag fehlgeschlagen: \(reason)" }
    static let helpTitle = "So funktioniert’s"
    static func helpBody(trigger: String, seconds: String) -> String {
        "1. In einer beliebigen App ein Menü öffnen.\n"
        + "2. Mit der Maus über den gewünschten Eintrag fahren.\n"
        + "3. Die \(trigger)-Taste ~\(seconds) s halten.\n"
        + "4. Im Fenster das neue Kürzel drücken, Bereich wählen, „Anpassen“.\n\n"
        + "Bei „nur diese App“ die App danach neu starten, damit das Menü das "
        + "Kürzel zeigt."
    }

    // Fenster „Anpassen?"
    static let panelTitle = "Tastenkürzel anpassen?"
    static func panelTarget(item: String, app: String) -> String {
        "Menüpunkt „\(item)“ in \(app)"
    }
    static let panelTargetUnknownApp = "unbekannte App"
    static let recorderPlaceholder = "Neues Kürzel drücken …"
    static let recorderHint = "Halte die gewünschte Kombination (z. B. ⌘⇧F) gedrückt."
    static let scopeApp = "Nur in dieser App"
    static func scopeAppNamed(_ app: String) -> String { "Nur in \(app)" }
    static let scopeGlobal = "In allen Programmen"
    static let cancel = "Abbrechen"
    static let save = "Anpassen"

    // Hinweise / Fehler
    static let noMenuItem = "Kein Menüpunkt unter dem Mauszeiger."
    static let needShortcut = "Bitte zuerst ein Kürzel drücken."
    static let appScopeNeedsBundle = "Diese App liefert keine Programm-Kennung – nur „alle Programme“ möglich."
    static func conflictWarning(shortcut: String, other: String) -> String {
        "Achtung: \(shortcut) ist hier schon für „\(other)“ vergeben – wird ersetzt."
    }

    // Neustart-Nachfrage
    static let restartTitle = "Kürzel gespeichert"
    static func restartBodyApp(_ app: String) -> String {
        "Damit „\(app)“ das neue Kürzel zeigt, muss die App einmal neu gestartet werden. "
        + "In den Systemeinstellungen → Tastatur erscheint es erst nach Schliessen und Neuöffnen."
    }
    static let restartBodyGlobal =
        "Das Kürzel gilt für alle Programme. Bereits laufende Apps übernehmen es erst nach einem Neustart. "
        + "In den Systemeinstellungen → Tastatur erscheint es erst nach Schliessen und Neuöffnen."
    static let restartNow = "Jetzt neu starten"
    static let restartLater = "Später"
    static let ok = "OK"
    static let resetRestartTitle = "Kürzel entfernt"
    static func resetRestartBodyApp(_ app: String) -> String {
        "Damit „\(app)“ wieder sein Standard-Kürzel zeigt, muss die App einmal neu gestartet werden."
    }
    static let resetRestartBodyGlobal =
        "Das Kürzel wurde entfernt. Bereits laufende Programme zeigen den Standard erst nach einem Neustart."

    // Bedienungshilfen
    static let axAlertTitle = "Bedienungshilfen-Zugriff nötig"
    static let axAlertBody =
        "MenuShortcutRebinder braucht Zugriff auf „Bedienungshilfen“, um den Menüpunkt unter dem "
        + "Mauszeiger zu lesen und die Auslöser-Taste global zu erkennen.\n\n"
        + "Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → MenuShortcutRebinder "
        + "aktivieren. Falls schon ein Eintrag da ist, der nicht wirkt: mit (–) entfernen und mit (+) "
        + "neu hinzufügen. Danach im ⌘-Menü „Diagnose & Verbindung“ → „Erneut verbinden“."
    static let openSettings = "Systemeinstellungen öffnen"
}
