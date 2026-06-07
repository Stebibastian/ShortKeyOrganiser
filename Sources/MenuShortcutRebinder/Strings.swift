import Foundation

/// Zentrale Sammelstelle für alle benutzersichtbaren Texte - zweisprachig (Deutsch + Englisch).
///
/// `Strings.lang` wird beim Start gesetzt ("de"/"en", abgeleitet aus der Sprach-Einstellung
/// bzw. der System-Sprache). `s(de, en)` wählt die passende Fassung. Bewusst code-basiert
/// (kein `.strings`-Resource-Bundle), das ist im SwiftPM-Executable robuster und erlaubt
/// einen sofortigen Sprachwechsel ohne Bundle-Gefummel.
enum Strings {
    static var lang = "de"
    private static func s(_ de: String, _ en: String) -> String { lang == "en" ? en : de }

    // Statusleiste
    static let appTitle = "ShortKeyOrganiser"
    static var statusItemTooltip: String { s("Menü-Kurzbefehl anpassen", "Rebind a menu shortcut") }
    static func triggerInfo(_ t: String) -> String { s("Auslöser: \(t) lange halten", "Trigger: hold \(t)") }
    static var menuQuit: String { s("Beenden", "Quit") }
    static var menuDiagnose: String { s("Diagnose & Verbindung …", "Diagnostics & connection …") }

    // Diagnose
    static var diagnoseTitle: String { s("Diagnose", "Diagnostics") }
    static var diagnoseReconnect: String { s("Erneut verbinden", "Reconnect") }
    static var diagAccessibility: String { s("Bedienungshilfen", "Accessibility") }
    static var diagAxOk: String { s("erteilt", "granted") }
    static var diagAxBad: String { s("fehlt", "missing") }
    static var diagTap: String { s("Tasten-Erkennung", "Key detection") }
    static var diagTapOk: String { s("aktiv", "active") }
    static var diagTapBad: String { s("inaktiv", "inactive") }
    static var diagTrigger: String { s("Auslöser-Taste", "Trigger key") }
    static var diagFix: String {
        s("Behebung: Systemeinstellungen öffnen → Bedienungshilfen → ShortKeyOrganiser mit (−) entfernen und mit (+) neu hinzufügen, dann Erneut verbinden.",
          "Fix: open System Settings → Accessibility → remove ShortKeyOrganiser with (−) and add it again with (+), then Reconnect.")
    }

    // ⌘-Menü + Einstellungs-Aktionen
    static var menuShortcuts: String { s("Tastenkürzel verwalten …", "Manage shortcuts …") }
    static let menuBrowse = "ShortKeyOrganiser …"
    static var browseSettingsTip: String { s("Einstellungen", "Settings") }
    static var browseManageTip: String { s("Tastenkürzel verwalten", "Manage shortcuts") }
    static var menuSettings: String { s("Einstellungen …", "Settings …") }
    static var menuHelp: String { s("Kurzanleitung …", "Quick guide …") }
    static var menuCheckUpdate: String { s("Nach Updates suchen …", "Check for updates …") }

    // Zentrale Einstellungen
    static var setWinTitle: String { s("Einstellungen", "Settings") }
    static var setRebindTrigger: String { s("Auslöser (über Menüpunkt halten)", "Trigger (hold over a menu item)") }
    static var setHold: String { s("Haltedauer", "Hold duration") }
    static var setPeekEnable: String { s("Per Mehrfachdruck öffnen", "Open by multi-press") }
    static var setPeekTrigger: String { s("Auslöser-Taste", "Trigger key") }
    static var setSecKeyboard: String { s("Tastenkürzel", "Shortcuts") }
    static var setFeatureOverlay: String { s("Befehls-Overlay (Hauptfunktion)", "Command overlay (main feature)") }
    static var setFeatureOverlayDesc: String {
        s("Auslöser-Taste zweimal drücken und beim zweiten Mal gedrückt halten → Overlay mit allen Kürzeln der aktiven App. Dreimal drücken → das Fenster bleibt offen und ist durchsuchbar.",
          "Press the trigger key twice and hold on the second press → an overlay with every shortcut of the front app. Press three times → the window stays open and searchable.")
    }
    static var setFeatureRebind: String { s("Menü-Kürzel umbelegen", "Rebind menu shortcuts") }
    static var setFeatureRebindDesc: String {
        s("Mit der Maus über einen Menüpunkt einer App fahren und die Auslöser-Taste gedrückt halten → Fenster zum Setzen eines eigenen Kürzels (pro App oder für alle Programme).",
          "Hover a menu item of an app and hold the trigger key → a window to set your own shortcut (per app or for all apps).")
    }
    static var setSecView: String { s("Anzeige", "Display") }
    static var setWindowSize: String { s("Fenstergröße", "Window size") }
    static var setColWidth: String { s("Spaltenbreite", "Column width") }
    static var setWidth: String { s("Breite", "Width") }
    static var setHeight: String { s("Höhe", "Height") }
    static var setSizeLinked: String { s("Breite und Höhe verknüpfen", "Link width and height") }
    static var setFontSize: String { s("Schriftgrösse", "Font size") }
    static var setZebra: String { s("Zebra-Streifen (abwechselnde Zeilenfarbe)", "Zebra stripes (alternating row colour)") }
    static var setTransparency: String { s("Transparenz", "Transparency") }
    static var setBackground: String { s("Hintergrund", "Background") }
    static var setBgOpaque: String { s("Undurchsichtig", "Opaque") }
    static var setBgTransparent: String { s("Transparent", "Transparent") }
    static var setBgBlur: String { s("Milchglas", "Frosted glass") }
    static var setOpaqueRows: String { s("Befehlszeilen deckend (besser lesbar)", "Opaque command rows (better readable)") }
    static var setSecAbout: String { s("Über", "About") }
    static var aboutTagline: String { s("Tastenkürzel-Overlay und Umbelegen für jede App.", "Shortcut overlay and rebinding for any app.") }
    static var aboutTools: String { s("Werkzeuge & Hilfe", "Tools & help") }
    static var aboutUpdates: String { s("Updates & Start", "Updates & launch") }
    static let aboutCopyright = "© 2026 Sebastian Kardos"
    static var setLogin: String { s("Beim Anmelden starten", "Launch at login") }
    static var setLanguage: String { s("Sprache", "Language") }
    static var setLangSystem: String { s("System", "System") }

    static var bsModCommand: String { s("Command ⌘", "Command ⌘") }
    static var bsModOption: String { s("Option ⌥", "Option ⌥") }
    static var bsModControl: String { s("Control ⌃", "Control ⌃") }

    static func setVersion(_ v: String) -> String { "ShortKeyOrganiser \(v)" }
    static var setAutoUpdate: String { s("Updates automatisch installieren", "Install updates automatically") }

    // Updates
    static var updateInstalling: String { s("Update wird installiert …", "Installing update …") }
    static func updateTitle(_ v: String) -> String { s("Version \(v) ist verfügbar", "Version \(v) is available") }
    static var updateBody: String { s("Eine neuere Version von ShortKeyOrganiser ist verfügbar. Jetzt laden und installieren?", "A newer version of ShortKeyOrganiser is available. Download and install now?") }
    static var updateInstall: String { s("Jetzt aktualisieren", "Update now") }
    static var updatePage: String { s("Release-Seite öffnen", "Open release page") }
    static var updateLater: String { s("Später", "Later") }
    static var updateNoneTitle: String { s("ShortKeyOrganiser ist aktuell", "ShortKeyOrganiser is up to date") }
    static func updateNoneBody(_ v: String) -> String { s("Du hast bereits die neueste Version (\(v)).", "You already have the latest version (\(v)).") }
    static var updateFailTitle: String { s("Update-Prüfung fehlgeschlagen", "Update check failed") }
    static var updateFailBody: String { s("Die neueste Version konnte nicht abgerufen werden. Bitte später erneut versuchen.", "Couldn't fetch the latest version. Please try again later.") }

    // Tastenkürzel-Fenster
    static var winTitle: String { s("Tastenkürzel", "Shortcuts") }
    static var tabTool: String { s("Vom Tool gesetzt", "Set by this tool") }
    static var tabSystem: String { s("Alle im System", "All in the system") }

    // Befehle durchsuchen (Overlay)
    static let browseTitle = "ShortKeyOrganiser"
    static var browseSearchPlaceholder: String { s("Befehl suchen … (Schlagwort eintippen)", "Search commands … (type a keyword)") }
    static var browseLoading: String { s("Befehle werden gelesen …", "Reading commands …") }
    static var browseEmpty: String { s("Keine Menübefehle gefunden. Ist die App offen und eine native Mac-App?", "No menu commands found. Is the app open and a native Mac app?") }
    static var browseNoMatch: String { s("Kein Treffer.", "No match.") }
    static var browseNoAccess: String { s("Bedienungshilfen-Recht fehlt - bitte unter Diagnose & Verbindung prüfen.", "Accessibility permission missing - check Diagnostics & connection.") }
    static var browseEditTip: String { s("Tastenkürzel anpassen", "Change shortcut") }
    static var browsePerformTip: String { s("Befehl ausführen", "Run command") }
    static var browseFavorites: String { s("★ Favoriten", "★ Favourites") }
    static var browseFavTip: String { s("Als Favorit markieren", "Mark as favourite") }
    static var browseHideTip: String { s("Befehl ausblenden", "Hide command") }
    static var browseUnhideTip: String { s("Wieder einblenden", "Show again") }
    static var browseShowHidden: String { s("Ausgeblendete Befehle ein-/ausblenden", "Show/hide hidden commands") }
    static var browseShowFavorites: String { s("Favoriten-Gruppe anzeigen", "Show favourites group") }
    static var browseHighlightTip: String { s("Tasten-Highlight beim Halten von Modifiern", "Key highlight when holding modifiers") }
    static var browseShowDisabledTip: String { s("Inaktive Befehle ein-/ausblenden", "Show/hide inactive commands") }
    static var browseDeleteTip: String { s("Eigenes Kürzel entfernen (Standard wiederherstellen)", "Remove your shortcut (restore default)") }

    // System-Kürzel löschen
    static var sysDeleteTitle: String { s("Kürzel entfernen?", "Remove shortcut?") }
    static func sysDeleteBody(shortcut: String, title: String, domain: String) -> String {
        s("\(shortcut) für „\(title)“ in \(domain) wirklich entfernen?\n\nDas ändert einen echten macOS-App-Kurzbefehl. Die betroffene App muss danach neu gestartet werden.\n\nHinweis: In den Systemeinstellungen wird die Änderung erst sichtbar, nachdem du sie schließt und neu öffnest.",
          "Really remove \(shortcut) for \(title) in \(domain)?\n\nThis changes a real macOS app shortcut. The affected app must be restarted afterwards.\n\nNote: in System Settings the change only shows after you close and reopen it.")
    }
    static var sysDelete: String { s("Löschen", "Delete") }

    // Login / Hinweise
    static func launchedHint(_ t: String) -> String { s("Aktiv – \(t) über einem Menüpunkt halten", "Active - hold \(t) over a menu item") }
    static func loginItemFailed(_ r: String) -> String { s("Login-Eintrag fehlgeschlagen: \(r)", "Login item failed: \(r)") }
    static var helpTitle: String { s("So funktioniert’s", "How it works") }
    static func helpBody(trigger: String, seconds: String) -> String {
        s("1. In einer beliebigen App ein Menü öffnen.\n2. Mit der Maus über den gewünschten Eintrag fahren.\n3. Die \(trigger)-Taste ~\(seconds) s halten.\n4. Im Fenster das neue Kürzel drücken, Bereich wählen, Anpassen.\n\nBei „nur diese App“ die App danach neu starten, damit das Menü das Kürzel zeigt.",
          "1. Open a menu in any app.\n2. Hover the item you want.\n3. Hold the \(trigger) key for ~\(seconds) s.\n4. In the window press the new shortcut, pick the scope, Apply.\n\nFor \"this app only\" restart the app afterwards so its menu shows the shortcut.")
    }

    // Umbelegen-Fenster
    static var panelTitle: String { s("Tastenkürzel anpassen?", "Rebind shortcut?") }
    static func panelTarget(item: String, app: String) -> String { s("Menüpunkt „\(item)“ in \(app)", "Menu item \(item) in \(app)") }
    static var panelTargetUnknownApp: String { s("unbekannte App", "unknown app") }
    static var recorderPlaceholder: String { s("Neues Kürzel drücken …", "Press the new shortcut …") }
    static var recorderHint: String { s("Halte die gewünschte Kombination (z. B. ⌘⇧F) gedrückt.", "Hold the combination you want (e.g. ⌘⇧F).") }
    static var scopeApp: String { s("Nur in dieser App", "This app only") }
    static func scopeAppNamed(_ app: String) -> String { s("Nur in \(app)", "\(app) only") }
    static var scopeGlobal: String { s("In allen Programmen", "All apps") }
    static var cancel: String { s("Abbrechen", "Cancel") }
    static var save: String { s("Anpassen", "Apply") }

    static var noMenuItem: String { s("Kein Menüpunkt unter dem Mauszeiger.", "No menu item under the cursor.") }
    static var needShortcut: String { s("Bitte zuerst ein Kürzel drücken.", "Press a shortcut first.") }
    static var appScopeNeedsBundle: String { s("Diese App liefert keine Programm-Kennung – nur „alle Programme“ möglich.", "This app provides no bundle id - only \"all apps\" is possible.") }
    static func conflictWarning(shortcut: String, other: String) -> String { s("Achtung: \(shortcut) ist hier schon für „\(other)“ vergeben – wird ersetzt.", "Note: \(shortcut) is already assigned to \(other) here - it will be replaced.") }

    // Neustart-Nachfrage (nach Umbelegen)
    static var restartTitle: String { s("Kürzel gespeichert", "Shortcut saved") }
    static func restartBodyApp(_ app: String) -> String { s("Damit „\(app)“ das neue Kürzel zeigt, muss die App einmal neu gestartet werden. In den Systemeinstellungen → Tastatur erscheint es erst nach Schliessen und Neuöffnen.", "For \(app) to show the new shortcut, the app has to be restarted once. In System Settings → Keyboard it only appears after closing and reopening.") }
    static var restartBodyGlobal: String { s("Das Kürzel gilt für alle Programme. Bereits laufende Apps übernehmen es erst nach einem Neustart.", "The shortcut applies to all apps. Apps already running pick it up only after a restart.") }
    static var restartNow: String { s("Jetzt neu starten", "Restart now") }
    static var restartLater: String { s("Später", "Later") }
    static var ok: String { s("OK", "OK") }
    static var resetRestartTitle: String { s("Kürzel entfernt", "Shortcut removed") }
    static func resetRestartBodyApp(_ app: String) -> String { s("Damit „\(app)“ wieder sein Standard-Kürzel zeigt, muss die App einmal neu gestartet werden.", "For \(app) to show its default shortcut again, the app has to be restarted once.") }
    static var resetRestartBodyGlobal: String { s("Das Kürzel wurde entfernt. Bereits laufende Programme zeigen den Standard erst nach einem Neustart.", "The shortcut was removed. Apps already running show the default only after a restart.") }

    static var openSettings: String { s("Systemeinstellungen öffnen", "Open System Settings") }

    // Tastenkürzel-Verwaltung (ShortcutsWindow) + weitere Browse-Texte
    static var refresh: String { s("Aktualisieren", "Refresh") }
    static var sysEdit: String { s("Ändern", "Change") }
    static var sysReadOnly: String { s("– nur lesbar", "– read-only") }
    static var sysEmpty: String { s("Keine eigenen App-Kurzbefehle gefunden.", "No custom app shortcuts found.") }
    static var managerEmpty: String { s("Noch keine Kürzel über dieses Tool gesetzt.", "No shortcuts set via this tool yet.") }
    static var reset: String { s("Zurücksetzen", "Reset") }
    static var resetAll: String { s("Alle zurücksetzen", "Reset all") }
    static var resetAllConfirm: String { s("Wirklich alle hier gelisteten Kürzel zurücksetzen?", "Really reset all shortcuts listed here?") }
    static var closeButton: String { s("Schließen", "Close") }
    static var resetDoneRestart: String { s("Zurückgesetzt – betroffene App neu starten, damit es greift.", "Reset - restart the affected app for it to take effect.") }
    static var sysDeletedRestart: String { s("Entfernt – betroffene App neu starten, damit es greift.", "Removed - restart the affected app for it to take effect.") }
    static let browseAppLabel = "App:"
    static var browseCustomTip: String { s("Von Dir gesetzt", "Set by you") }
    static func browseCount(hits: Int, total: Int) -> String { s("\(hits) von \(total) Befehlen", "\(hits) of \(total) commands") }
    static func browseCapped(_ cap: Int) -> String { s(" (erste \(cap) gezeigt)", " (first \(cap) shown)") }
}
