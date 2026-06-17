import Foundation

/// Zentrale Sammelstelle für alle benutzersichtbaren Texte - zweisprachig (Deutsch + Englisch).
///
/// `Strings.lang` wird beim Start gesetzt ("de"/"en", abgeleitet aus der Sprach-Einstellung
/// bzw. der System-Sprache). `s(de, en)` wählt die passende Fassung. Bewusst code-basiert
/// (kein `.strings`-Resource-Bundle), das ist im SwiftPM-Executable robuster und erlaubt
/// einen sofortigen Sprachwechsel ohne Bundle-Gefummel.
enum Strings {
    static var lang = "de"
    /// Wählt die Fassung je Sprache; fr/es/it fallen auf Englisch zurück, wenn nicht angegeben.
    private static func s(_ de: String, _ en: String,
                          fr: String? = nil, es: String? = nil, it: String? = nil) -> String {
        switch lang {
        case "fr": return fr ?? en
        case "es": return es ?? en
        case "it": return it ?? en
        case "en": return en
        default:   return de
        }
    }

    // Statusleiste
    static let appTitle = "ShortKeyOrganiser"
    static var statusItemTooltip: String { s("Menü-Kurzbefehl anpassen", "Rebind a menu shortcut") }
    static func triggerInfo(_ t: String) -> String { s("Auslöser: \(t) lange halten", "Trigger: hold \(t)") }
    static var menuQuit: String { s("Beenden", "Quit", fr: "Quitter", es: "Salir", it: "Esci") }
    static var menuDiagnose: String { s("Diagnose & Verbindung …", "Diagnostics & connection …", fr: "Diagnostic et connexion …", es: "Diagnóstico y conexión …", it: "Diagnostica e connessione …") }

    // Diagnose
    static var diagnoseTitle: String { s("Diagnose", "Diagnostics", fr: "Diagnostic", es: "Diagnóstico", it: "Diagnostica") }
    static var diagnoseReconnect: String { s("Erneut verbinden", "Reconnect", fr: "Reconnecter", es: "Reconectar", it: "Riconnetti") }
    static var diagAccessibility: String { s("Bedienungshilfen", "Accessibility", fr: "Accessibilité", es: "Accesibilidad", it: "Accessibilità") }
    static var diagAxOk: String { s("erteilt", "granted", fr: "accordé", es: "concedido", it: "concesso") }
    static var diagAxBad: String { s("fehlt", "missing", fr: "manquant", es: "falta", it: "mancante") }
    static var diagTap: String { s("Tasten-Erkennung", "Key detection", fr: "Détection des touches", es: "Detección de teclas", it: "Rilevamento tasti") }
    static var diagTapOk: String { s("aktiv", "active", fr: "actif", es: "activo", it: "attivo") }
    static var diagTapBad: String { s("inaktiv", "inactive", fr: "inactif", es: "inactivo", it: "inattivo") }
    static var diagTrigger: String { s("Auslöser-Taste", "Trigger key", fr: "Touche de déclenchement", es: "Tecla disparador", it: "Tasto attivatore") }
    static var diagFix: String {
        s("Behebung: Systemeinstellungen öffnen → Bedienungshilfen → ShortKeyOrganiser mit (−) entfernen und mit (+) neu hinzufügen, dann Erneut verbinden.",
          "Fix: open System Settings → Accessibility → remove ShortKeyOrganiser with (−) and add it again with (+), then Reconnect.")
    }

    // ⌘-Menü + Einstellungs-Aktionen
    static var menuShortcuts: String { s("Tastenkürzel verwalten …", "Manage shortcuts …", fr: "Gérer les raccourcis …", es: "Gestionar atajos …", it: "Gestisci scorciatoie …") }
    static let menuBrowse = "ShortKeyOrganiser …"
    static var browseSettingsTip: String { s("Einstellungen", "Settings") }
    static var browseManageTip: String { s("Tastenkürzel verwalten", "Manage shortcuts") }
    static var menuSettings: String { s("Einstellungen …", "Settings …", fr: "Réglages …", es: "Ajustes …", it: "Impostazioni …") }
    static var menuHelp: String { s("Kurzanleitung …", "Quick guide …", fr: "Guide rapide …", es: "Guía rápida …", it: "Guida rapida …") }
    static var menuCheckUpdate: String { s("Nach Updates suchen …", "Check for updates …", fr: "Rechercher des mises à jour …", es: "Buscar actualizaciones …", it: "Cerca aggiornamenti …") }

    // Zentrale Einstellungen
    static var setWinTitle: String { s("Einstellungen", "Settings") }
    static var setRebindTrigger: String { s("Auslöser (über Menüpunkt halten)", "Trigger (hold over a menu item)", fr: "Déclencheur (maintenir sur un élément de menu)", es: "Disparador (mantener sobre un elemento de menú)", it: "Attivatore (tieni premuto su una voce di menu)") }
    static var setHold: String { s("Haltedauer", "Hold duration", fr: "Durée de maintien", es: "Duración de pulsación", it: "Durata pressione") }
    static var setPeekEnable: String { s("Kurzblick (Overlay, solange Du hältst)", "Quick peek (overlay while you hold)", fr: "Aperçu rapide (visible tant que tu maintiens)", es: "Vistazo rápido (visible mientras mantienes)", it: "Sguardo rapido (visibile finché tieni premuto)") }
    static var setFixEnable: String { s("Fix öffnen (Fenster bleibt offen)", "Pinned open (window stays open)", fr: "Ouverture fixe (la fenêtre reste ouverte)", es: "Apertura fija (la ventana queda abierta)", it: "Apertura fissa (la finestra resta aperta)") }
    static var setPressCount: String { s("Anzahl Drücke", "Number of presses", fr: "Nombre d'appuis", es: "Número de pulsaciones", it: "Numero di pressioni") }
    static var setTriggerMode: String { s("Modus", "Mode", fr: "Mode", es: "Modo", it: "Modalità") }
    static var setModeOff: String { s("Aus", "Off", fr: "Désactivé", es: "Desactivado", it: "Disattivato") }
    static var setModeHold: String { s("Nur Halten", "Hold only", fr: "Maintien seul", es: "Solo mantener", it: "Solo tenere premuto") }
    static var setModeTap: String { s("Tippen", "Tap", fr: "Appui", es: "Pulsar", it: "Tocco") }
    static var setModeTapHold: String { s("Tippen + Halten", "Tap + hold", fr: "Appui + maintien", es: "Pulsar + mantener", it: "Tocco + tenere premuto") }
    static var setGesturePeek: String { s("Kurzblick (Loslassen schließt)", "Quick peek (release closes)", fr: "Aperçu rapide (relâcher ferme)", es: "Vistazo rápido (soltar cierra)", it: "Sguardo rapido (rilasciando si chiude)") }
    static var setGestureFix: String { s("Fix öffnen (bleibt offen)", "Pinned open (stays open)", fr: "Ouverture fixe (reste ouvert)", es: "Apertura fija (queda abierto)", it: "Apertura fissa (resta aperto)") }
    static var setModeHotkey: String { s("Tastenkürzel", "Keyboard shortcut", fr: "Raccourci clavier", es: "Atajo de teclado", it: "Scorciatoia da tastiera") }
    static var setShortcut: String { s("Kürzel", "Shortcut", fr: "Raccourci", es: "Atajo", it: "Scorciatoia") }
    static var setRecordPrompt: String { s("Klicken, dann Kombi drücken", "Click, then press combo", fr: "Cliquer, puis presser la combinaison", es: "Haz clic y pulsa la combinación", it: "Clicca, poi premi la combinazione") }
    static var setRecording: String { s("Jetzt drücken … (⎋ bricht ab)", "Press now … (⎋ to cancel)", fr: "Presse maintenant … (⎋ pour annuler)", es: "Pulsa ahora … (⎋ para cancelar)", it: "Premi ora … (⎋ per annullare)") }
    static var setHotkeyHint: String { s("Funktioniert systemweit - z. B. ⌘⇧T oder ein Hyperkey wie ⌃⌥⇧⌘8.", "Works system-wide - e.g. ⌘⇧T or a hyper key like ⌃⌥⇧⌘8.", fr: "Fonctionne sur tout le système - p. ex. ⌘⇧T ou une hyper-touche comme ⌃⌥⇧⌘8.", es: "Funciona en todo el sistema: p. ej. ⌘⇧T o una hyper key como ⌃⌥⇧⌘8.", it: "Funziona a livello di sistema - es. ⌘⇧T o un hyper key come ⌃⌥⇧⌘8.") }
    static var setTestHotkey: String { s("Tastenkürzel erkannt ✓", "Keyboard shortcut detected ✓", fr: "Raccourci clavier détecté ✓", es: "Atajo de teclado detectado ✓", it: "Scorciatoia da tastiera rilevata ✓") }
    static var setPlusHold: String { s("+ halten", "+ hold", fr: "+ maintenir", es: "+ mantener", it: "+ tenere") }
    static var setFixHold: String { s("Beim letzten Druck halten", "Hold on the last press", fr: "Maintenir au dernier appui", es: "Mantener en la última pulsación", it: "Tenere premuto all'ultima pressione") }
    static var setFeatureFavorites: String { s("Favoriten-Popup", "Favourites popup", fr: "Popup des favoris", es: "Ventana de favoritos", it: "Popup preferiti") }
    static var setFeatureFavoritesDesc: String { s("Ein eigener Auslöser zeigt nur die Favoriten der aktiven App in einem kleinen Popup direkt neben der Maus.", "A separate trigger shows only the active app's favourites in a small popup right next to the mouse.", fr: "Un déclencheur dédié affiche uniquement les favoris de l'app active dans un petit popup près de la souris.", es: "Un disparador propio muestra solo los favoritos de la app activa en una pequeña ventana junto al ratón.", it: "Un attivatore dedicato mostra solo i preferiti dell'app attiva in un piccolo popup vicino al mouse.") }
    static var setFavTrigger: String { s("Auslöser-Taste", "Trigger key", fr: "Touche de déclenchement", es: "Tecla disparador", it: "Tasto attivatore") }
    static var setFavEnable: String { s("Favoriten-Popup aktivieren", "Enable favourites popup", fr: "Activer le popup des favoris", es: "Activar ventana de favoritos", it: "Attiva popup preferiti") }
    static var setFavHold: String { s("Beim letzten Druck halten", "Hold on the last press", fr: "Maintenir au dernier appui", es: "Mantener en la última pulsación", it: "Tenere premuto all'ultima pressione") }
    static var favPopupEmpty: String { s("Noch keine Favoriten in dieser App – im Overlay mit ★ markieren.", "No favourites in this app yet – mark some with ★ in the overlay.", fr: "Aucun favori dans cette app – marque-les avec ★ dans l'aperçu.", es: "Aún no hay favoritos en esta app – márcalos con ★ en la vista.", it: "Ancora nessun preferito in questa app – segnali con ★ nell'overlay.") }
    static var setTriggerConflict: String { s("Gleiche Geste wie der Kurzblick - bitte Anzahl Drücke oder Halten anpassen.", "Same gesture as the quick peek - please change the press count or the hold option.", fr: "Même geste que l'aperçu rapide - change le nombre d'appuis ou l'option maintenir.", es: "Es el mismo gesto que el vistazo rápido: cambia el número de pulsaciones o la opción de mantener.", it: "Stesso gesto dello sguardo rapido: cambia il numero di pressioni o l'opzione di tenuta.") }
    static var setTestTitle: String { s("Auslöser testen", "Test the trigger", fr: "Tester le déclencheur", es: "Probar el disparador", it: "Prova l'attivatore") }
    static var setTestHint: String { s("Führ die Geste jetzt aus, solange dieses Fenster vorne ist - hier leuchtet auf, was erkannt wurde.", "Perform the gesture now while this window is in front - whatever gets detected lights up here.", fr: "Fais le geste maintenant, tant que cette fenêtre est devant - ce qui est détecté s'allume ici.", es: "Haz el gesto ahora, mientras esta ventana esté delante: aquí se ilumina lo que se detecte.", it: "Esegui il gesto adesso, finché questa finestra è in primo piano: qui si illumina ciò che viene rilevato.") }
    static var setTestPeek: String { s("Kurzblick erkannt ✓", "Quick peek detected ✓", fr: "Aperçu rapide détecté ✓", es: "Vistazo rápido detectado ✓", it: "Sguardo rapido rilevato ✓") }
    static var setTestFix: String { s("Fix öffnen erkannt ✓", "Pinned open detected ✓", fr: "Ouverture fixe détectée ✓", es: "Apertura fija detectada ✓", it: "Apertura fissa rilevata ✓") }
    static var setReset: String { s("Auf Standard zurücksetzen …", "Reset to defaults …", fr: "Réinitialiser aux valeurs par défaut …", es: "Restablecer valores predeterminados …", it: "Ripristina i valori predefiniti …") }
    static var setResetNote: String { s("Favoriten, Verlauf und ausgeblendete Befehle bleiben erhalten.", "Favourites, history and hidden commands are kept.", fr: "Les favoris, l'historique et les commandes masquées sont conservés.", es: "Los favoritos, el historial y los comandos ocultos se conservan.", it: "Preferiti, cronologia e comandi nascosti vengono mantenuti.") }
    static var setResetTitle: String { s("Einstellungen zurücksetzen?", "Reset settings?", fr: "Réinitialiser les réglages ?", es: "¿Restablecer los ajustes?", it: "Ripristinare le impostazioni?") }
    static var setResetBody: String { s("Alle Einstellungen werden auf die Werkseinstellung zurückgesetzt. Favoriten, Verlauf und ausgeblendete Befehle bleiben erhalten.", "All settings will be reset to their defaults. Favourites, history and hidden commands are kept.", fr: "Tous les réglages seront réinitialisés. Les favoris, l'historique et les commandes masquées sont conservés.", es: "Todos los ajustes se restablecerán a sus valores predeterminados. Los favoritos, el historial y los comandos ocultos se conservan.", it: "Tutte le impostazioni torneranno ai valori predefiniti. Preferiti, cronologia e comandi nascosti vengono mantenuti.") }
    static var setResetDone: String { s("Einstellungen zurückgesetzt.", "Settings reset.", fr: "Réglages réinitialisés.", es: "Ajustes restablecidos.", it: "Impostazioni ripristinate.") }
    static var setPeekTrigger: String { s("Auslöser-Taste", "Trigger key", fr: "Touche de déclenchement", es: "Tecla disparador", it: "Tasto attivatore") }
    static var setSecKeyboard: String { s("Tastenkürzel", "Shortcuts", fr: "Raccourcis", es: "Atajos", it: "Scorciatoie") }
    static var setFeatureOverlay: String { s("Befehls-Overlay (Hauptfunktion)", "Command overlay (main feature)") }
    static var setFeatureOverlayDesc: String {
        s("Die Auslöser-Taste mehrmals kurz drücken: Der Kurzblick zeigt das Overlay, solange Du am Ende hältst; Fix öffnen lässt es offen und durchsuchbar. Anzahl Drücke und Halten stellst Du hier ein.",
          "Press the trigger key several times in a row: the quick peek shows the overlay while you hold at the end; pinned open keeps it open and searchable. Configure press count and hold here.",
          fr: "Appuie plusieurs fois de suite sur la touche : l'aperçu rapide montre l'overlay tant que tu maintiens à la fin ; l'ouverture fixe le garde ouvert et consultable. Configure ici le nombre d'appuis et le maintien.",
          es: "Pulsa la tecla varias veces seguidas: el vistazo rápido muestra el overlay mientras mantienes al final; la apertura fija lo deja abierto y permite buscar. Configura aquí las pulsaciones y el mantener.",
          it: "Premi il tasto più volte di seguito: lo sguardo rapido mostra l'overlay finché tieni premuto alla fine; l'apertura fissa lo lascia aperto e consultabile. Configura qui pressioni e tenuta.")
    }
    static var setFeatureRebind: String { s("Menü-Kürzel umbelegen", "Rebind menu shortcuts") }
    static var setFeatureRebindDesc: String {
        s("Mit der Maus über einen Menüpunkt einer App fahren und die Auslöser-Taste gedrückt halten → Fenster zum Setzen eines eigenen Kürzels (pro App oder für alle Programme).",
          "Hover a menu item of an app and hold the trigger key → a window to set your own shortcut (per app or for all apps).")
    }
    static var setSecView: String { s("Anzeige", "Display", fr: "Affichage", es: "Pantalla", it: "Visualizzazione") }
    static var setWindowSize: String { s("Fenstergröße", "Window size", fr: "Taille de la fenêtre", es: "Tamaño de ventana", it: "Dimensione finestra") }
    static var setColWidth: String { s("Spaltenbreite", "Column width", fr: "Largeur des colonnes", es: "Ancho de columna", it: "Larghezza colonna") }
    static var setWidth: String { s("Breite", "Width", fr: "Largeur", es: "Ancho", it: "Larghezza") }
    static var setHeight: String { s("Höhe", "Height", fr: "Hauteur", es: "Alto", it: "Altezza") }
    static var setSizeLinked: String { s("Breite und Höhe verknüpfen", "Link width and height", fr: "Lier largeur et hauteur", es: "Vincular ancho y alto", it: "Collega larghezza e altezza") }
    static var setFontSize: String { s("Schriftgrösse", "Font size", fr: "Taille du texte", es: "Tamaño de fuente", it: "Dimensione testo") }
    static var setZebra: String { s("Zebra-Streifen (abwechselnde Zeilenfarbe)", "Zebra stripes (alternating row colour)", fr: "Rayures zébrées (couleurs alternées)", es: "Rayas cebra (colores alternos)", it: "Strisce zebrate (colori alternati)") }
    static var setKeyLeft: String { s("Tastenkürzel links, Name rechts", "Shortcut on the left, name on the right", fr: "Raccourci à gauche, nom à droite", es: "Atajo a la izquierda, nombre a la derecha", it: "Scorciatoia a sinistra, nome a destra") }
    static var setCompactSections: String { s("Sektionen kompakt gruppieren (mehrere je Spalte)", "Group sections compactly (several per column)", fr: "Grouper les sections de façon compacte (plusieurs par colonne)", es: "Agrupar secciones de forma compacta (varias por columna)", it: "Raggruppa le sezioni in modo compatto (più per colonna)") }
    static var setPosition: String { s("Fensterposition", "Window position", fr: "Position de la fenêtre", es: "Posición de la ventana", it: "Posizione della finestra") }
    static var sizeSaveTitle: String { s("Fenstergröße geändert", "Window size changed", fr: "Taille de fenêtre modifiée", es: "Tamaño de ventana cambiado", it: "Dimensione finestra modificata") }
    static var sizeSaveBody: String { s("Möchtest du die neue Größe als Standard übernehmen oder nur dieses Mal verwenden?", "Use the new size as the default, or just this time?", fr: "Utiliser la nouvelle taille par défaut ou seulement cette fois ?", es: "¿Usar el nuevo tamaño como predeterminado o solo esta vez?", it: "Usare la nuova dimensione come predefinita o solo questa volta?") }
    static var sizeSaveDefault: String { s("Als Standard", "Set as default", fr: "Par défaut", es: "Predeterminado", it: "Come predefinita") }
    static var sizeSaveTemp: String { s("Nur temporär", "Just this time", fr: "Temporairement", es: "Solo esta vez", it: "Solo per ora") }
    static var setTransparency: String { s("Transparenz", "Transparency", fr: "Transparence", es: "Transparencia", it: "Trasparenza") }
    static var setBackground: String { s("Hintergrund", "Background", fr: "Arrière-plan", es: "Fondo", it: "Sfondo") }
    static var setBgOpaque: String { s("Undurchsichtig", "Opaque", fr: "Opaque", es: "Opaco", it: "Opaco") }
    static var setBgTransparent: String { s("Transparent", "Transparent", fr: "Transparent", es: "Transparente", it: "Trasparente") }
    static var setBgBlur: String { s("Milchglas", "Frosted glass", fr: "Verre dépoli", es: "Vidrio esmerilado", it: "Vetro smerigliato") }
    static var setOpaqueRows: String { s("Befehlszeilen deckend (besser lesbar)", "Opaque command rows (better readable)", fr: "Lignes de commande opaques (plus lisibles)", es: "Filas de comandos opacas (más legibles)", it: "Righe comando opache (più leggibili)") }
    static var setSecAbout: String { s("Über", "About", fr: "À propos", es: "Acerca de", it: "Informazioni") }
    static var aboutTagline: String { s("Tastenkürzel-Overlay und Umbelegen für jede App.", "Shortcut overlay and rebinding for any app.") }
    static var aboutTools: String { s("Werkzeuge & Hilfe", "Tools & help") }
    static var aboutUpdates: String { s("Updates & Start", "Updates & launch") }
    static let aboutCopyright = "© 2026 Sebastian Kardos"
    static var setLogin: String { s("Beim Anmelden starten", "Launch at login", fr: "Lancer à la connexion", es: "Abrir al iniciar sesión", it: "Avvia all’accesso") }
    static var setLanguage: String { s("Sprache", "Language", fr: "Langue", es: "Idioma", it: "Lingua") }
    static var setLangSystem: String { s("System", "System", fr: "Système", es: "Sistema", it: "Sistema") }

    static var bsModCommand: String { s("Command ⌘", "Command ⌘") }
    static var bsModOption: String { s("Option ⌥", "Option ⌥") }
    static var bsModControl: String { s("Control ⌃", "Control ⌃") }

    static func setVersion(_ v: String) -> String { "ShortKeyOrganiser \(v)" }
    static var setAutoUpdate: String { s("Updates automatisch installieren", "Install updates automatically", fr: "Installer les mises à jour automatiquement", es: "Instalar actualizaciones automáticamente", it: "Installa aggiornamenti automaticamente") }

    // Updates
    static var updateInstalling: String { s("Update wird installiert …", "Installing update …") }
    static var updateRelaunchHint: String { s("ShortKeyOrganiser wird heruntergeladen und startet sich neu.", "ShortKeyOrganiser is downloading and will relaunch.", fr: "ShortKeyOrganiser se télécharge et redémarre.", es: "ShortKeyOrganiser se está descargando y se reiniciará.", it: "ShortKeyOrganiser si sta scaricando e si riavvierà.") }
    static func updateTitle(_ v: String) -> String { s("Version \(v) ist verfügbar", "Version \(v) is available") }
    static var updateBody: String { s("Eine neuere Version von ShortKeyOrganiser ist verfügbar. Jetzt laden und installieren?", "A newer version of ShortKeyOrganiser is available. Download and install now?") }
    static var updateInstall: String { s("Jetzt aktualisieren", "Update now", fr: "Mettre à jour", es: "Actualizar ahora", it: "Aggiorna ora") }
    static var updatePage: String { s("Release-Seite öffnen", "Open release page", fr: "Ouvrir la page de version", es: "Abrir página de la versión", it: "Apri pagina della versione") }
    static var updateLater: String { s("Später", "Later", fr: "Plus tard", es: "Más tarde", it: "Più tardi") }
    static var updateNoneTitle: String { s("ShortKeyOrganiser ist aktuell", "ShortKeyOrganiser is up to date", fr: "ShortKeyOrganiser est à jour", es: "ShortKeyOrganiser está actualizado", it: "ShortKeyOrganiser è aggiornato") }
    static func updateNoneBody(_ v: String) -> String { s("Du hast bereits die neueste Version (\(v)).", "You already have the latest version (\(v)).") }
    static var updateFailTitle: String { s("Update-Prüfung fehlgeschlagen", "Update check failed") }
    static var updateFailBody: String { s("Die neueste Version konnte nicht abgerufen werden. Bitte später erneut versuchen.", "Couldn't fetch the latest version. Please try again later.") }

    // Tastenkürzel-Fenster
    static var winTitle: String { s("Tastenkürzel", "Shortcuts") }
    static var tabTool: String { s("Vom Tool gesetzt", "Set by this tool") }
    static var tabSystem: String { s("Alle im System", "All in the system") }

    // Befehle durchsuchen (Overlay)
    static let browseTitle = "ShortKeyOrganiser"
    static var browseSearchPlaceholder: String { s("Befehl suchen … (Schlagwort eintippen)", "Search commands … (type a keyword)", fr: "Rechercher une commande … (tape un mot-clé)", es: "Buscar comando … (escribe una palabra)", it: "Cerca comando … (digita una parola)") }
    static var browseLoading: String { s("Befehle werden gelesen …", "Reading commands …") }
    static var browseEmpty: String { s("Keine Menübefehle gefunden", "No menu commands found", fr: "Aucune commande de menu trouvée", es: "No se encontraron comandos de menú", it: "Nessun comando di menu trovato") }
    static var browseEmptyHint: String { s("Ist die App geöffnet und eine native Mac-App? Web- und Electron-Apps liefern oft keine Menüeinträge über die Bedienungshilfen.", "Is the app open and a native Mac app? Web and Electron apps often don't expose menu items via accessibility.", fr: "L'app est-elle ouverte et une app Mac native ? Les apps web et Electron n'exposent souvent pas leurs menus via l'accessibilité.", es: "¿Está la app abierta y es una app nativa de Mac? Las apps web y Electron a menudo no exponen sus menús por accesibilidad.", it: "L'app è aperta ed è un'app Mac nativa? Le app web ed Electron spesso non espongono i menu tramite accessibilità.") }
    static var browseRetry: String { s("Erneut einlesen", "Scan again", fr: "Relire", es: "Volver a leer", it: "Rileggi") }
    static var browseNoMatch: String { s("Kein Treffer", "No match", fr: "Aucun résultat", es: "Sin resultados", it: "Nessun risultato") }
    static var browseNoMatchHint: String { s("Anderen Suchbegriff probieren - gesucht wird in Name, Menüpfad und Kürzel.", "Try a different keyword - the search covers name, menu path and shortcut.", fr: "Essaie un autre mot-clé - la recherche couvre le nom, le chemin de menu et le raccourci.", es: "Prueba otra palabra clave: la búsqueda cubre nombre, ruta de menú y atajo.", it: "Prova un'altra parola chiave: la ricerca copre nome, percorso del menu e scorciatoia.") }
    static var browseNoAccess: String { s("Bedienungshilfen-Recht fehlt", "Accessibility permission missing", fr: "Autorisation d'accessibilité manquante", es: "Falta el permiso de accesibilidad", it: "Manca il permesso di accessibilità") }
    static var browseNoAccessHint: String { s("ShortKeyOrganiser liest die Menüs über die Bedienungshilfen. Bitte in den Systemeinstellungen unter Datenschutz & Sicherheit → Bedienungshilfen freigeben.", "ShortKeyOrganiser reads menus via accessibility. Please allow it in System Settings under Privacy & Security → Accessibility.", fr: "ShortKeyOrganiser lit les menus via l'accessibilité. Autorise-le dans Réglages Système sous Confidentialité et sécurité → Accessibilité.", es: "ShortKeyOrganiser lee los menús mediante accesibilidad. Permítelo en Ajustes del Sistema en Privacidad y seguridad → Accesibilidad.", it: "ShortKeyOrganiser legge i menu tramite accessibilità. Consentilo in Impostazioni di Sistema sotto Privacy e sicurezza → Accessibilità.") }
    static var browseUpdating: String { s("Liste wird aktualisiert …", "Updating list …", fr: "Mise à jour de la liste …", es: "Actualizando la lista …", it: "Aggiornamento dell'elenco …") }
    static var browseRefreshTip: String { s("Befehle neu einlesen", "Rescan commands", fr: "Relire les commandes", es: "Volver a leer los comandos", it: "Rileggi i comandi") }
    static var browseEditTip: String { s("Tastenkürzel anpassen", "Change shortcut") }
    static var browsePerformTip: String { s("Befehl ausführen", "Run command") }
    static var browseFavorites: String { s("★ Favoriten", "★ Favourites") }
    static var browseRecents: String { s("⏱ Zuletzt benutzt", "⏱ Recently used", fr: "⏱ Récemment utilisés", es: "⏱ Usados recientemente", it: "⏱ Usati di recente") }
    static var setShowRecents: String { s("Zuletzt benutzte als Gruppe anzeigen", "Show recently used as a group", fr: "Afficher les commandes récentes en groupe", es: "Mostrar los usados recientemente como grupo", it: "Mostra gli usati di recente come gruppo") }
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
    static var helpTitle: String { s("So funktioniert’s", "How it works", fr: "Comment ça marche", es: "Cómo funciona", it: "Come funziona") }
    static var help1: String { s("In einer beliebigen App ein Menü öffnen.", "Open a menu in any app.") }
    static var help2: String { s("Mit der Maus über den gewünschten Eintrag fahren.", "Hover the item you want.") }
    static func help3(trigger: String, seconds: String) -> String { s("Die \(trigger)-Taste ~\(seconds) s halten.", "Hold the \(trigger) key for ~\(seconds) s.") }
    static var help4: String { s("Im Fenster das neue Kürzel drücken, Bereich wählen, Anpassen.", "Press the new shortcut, pick the scope, Apply.") }
    static var helpNote: String { s("Bei „nur diese App“ die betroffene App danach neu starten, damit das Menü das Kürzel zeigt.", "For this-app-only, restart that app afterwards so its menu shows the shortcut.") }
    static var updateAvailableLabel: String { s("Was ist neu:", "What’s new:") }

    // Umbelegen-Fenster
    static var panelTitle: String { s("Tastenkürzel anpassen?", "Rebind shortcut?", fr: "Réattribuer le raccourci ?", es: "¿Reasignar atajo?", it: "Riassegnare la scorciatoia?") }
    static func panelTarget(item: String, app: String) -> String { s("Menüpunkt „\(item)“ in \(app)", "Menu item \(item) in \(app)") }
    static var panelTargetUnknownApp: String { s("unbekannte App", "unknown app") }
    static var recorderPlaceholder: String { s("Neues Kürzel drücken …", "Press the new shortcut …", fr: "Appuie sur le nouveau raccourci …", es: "Pulsa el nuevo atajo …", it: "Premi la nuova scorciatoia …") }
    static var recorderHint: String { s("Halte die gewünschte Kombination (z. B. ⌘⇧F) gedrückt.", "Hold the combination you want (e.g. ⌘⇧F).") }
    static var scopeApp: String { s("Nur in dieser App", "This app only", fr: "Cette app uniquement", es: "Solo esta app", it: "Solo questa app") }
    static func scopeAppNamed(_ app: String) -> String { s("Nur in \(app)", "\(app) only", fr: "\(app) uniquement", es: "Solo \(app)", it: "Solo \(app)") }
    static var scopeGlobal: String { s("In allen Programmen", "All apps", fr: "Toutes les apps", es: "Todas las apps", it: "Tutte le app") }
    static var cancel: String { s("Abbrechen", "Cancel", fr: "Annuler", es: "Cancelar", it: "Annulla") }
    static var save: String { s("Anpassen", "Apply", fr: "Appliquer", es: "Aplicar", it: "Applica") }

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

    // Nach /Applications verschieben
    static var moveTitle: String { s("In den Programme-Ordner verschieben?", "Move to Applications?", fr: "Déplacer vers Applications ?", es: "¿Mover a Aplicaciones?", it: "Spostare in Applicazioni?") }
    static func moveBody(_ folder: String) -> String { s("ShortKeyOrganiser läuft gerade aus dem Ordner \(folder). Für automatische Updates und einen festen Platz verschiebst du es am besten in den Programme-Ordner.", "ShortKeyOrganiser is running from the \(folder) folder. For automatic updates and a stable location, it is best to move it to the Applications folder.", fr: "ShortKeyOrganiser fonctionne depuis le dossier \(folder). Pour les mises à jour automatiques et un emplacement stable, mieux vaut le déplacer dans le dossier Applications.", es: "ShortKeyOrganiser se está ejecutando desde la carpeta \(folder). Para actualizaciones automáticas y una ubicación estable, conviene moverlo a la carpeta Aplicaciones.", it: "ShortKeyOrganiser è in esecuzione dalla cartella \(folder). Per gli aggiornamenti automatici e una posizione stabile, è meglio spostarlo nella cartella Applicazioni.") }
    static var moveNow: String { s("Verschieben", "Move", fr: "Déplacer", es: "Mover", it: "Sposta") }
    static var moveLater: String { s("Nicht jetzt", "Not now", fr: "Pas maintenant", es: "Ahora no", it: "Non ora") }
    static var moveFailed: String { s("Verschieben fehlgeschlagen.", "Move failed.", fr: "Échec du déplacement.", es: "Error al mover.", it: "Spostamento non riuscito.") }

    // Tastenkürzel-Verwaltung (ShortcutsWindow) + weitere Browse-Texte
    static var refresh: String { s("Aktualisieren", "Refresh", fr: "Actualiser", es: "Actualizar", it: "Aggiorna") }
    static var sysEdit: String { s("Ändern", "Change", fr: "Modifier", es: "Cambiar", it: "Modifica") }
    static var sysReadOnly: String { s("– nur lesbar", "– read-only") }
    static var sysEmpty: String { s("Keine eigenen App-Kurzbefehle gefunden.", "No custom app shortcuts found.") }
    static var managerEmpty: String { s("Noch keine Kürzel über dieses Tool gesetzt.", "No shortcuts set via this tool yet.") }
    static var reset: String { s("Zurücksetzen", "Reset", fr: "Réinitialiser", es: "Restablecer", it: "Reimposta") }
    static var resetAll: String { s("Alle zurücksetzen", "Reset all", fr: "Tout réinitialiser", es: "Restablecer todo", it: "Reimposta tutto") }
    static var resetAllConfirm: String { s("Wirklich alle hier gelisteten Kürzel zurücksetzen?", "Really reset all shortcuts listed here?") }
    static var closeButton: String { s("Schließen", "Close", fr: "Fermer", es: "Cerrar", it: "Chiudi") }
    static var resetDoneRestart: String { s("Zurückgesetzt – betroffene App neu starten, damit es greift.", "Reset - restart the affected app for it to take effect.") }
    static var sysDeletedRestart: String { s("Entfernt – betroffene App neu starten, damit es greift.", "Removed - restart the affected app for it to take effect.") }
    static let browseAppLabel = "App:"
    static var browseCustomTip: String { s("Von Dir gesetzt", "Set by you") }
    static func browseCount(hits: Int, total: Int) -> String { s("\(hits) von \(total) Befehlen", "\(hits) of \(total) commands") }
    static func browseCapped(_ cap: Int) -> String { s(" (erste \(cap) gezeigt)", " (first \(cap) shown)") }

    // Onboarding / Tutorial
    static var menuTutorial: String { s("Einführung …", "Tutorial …", fr: "Tutoriel …", es: "Tutorial …", it: "Tutorial …") }
    static var obIntroTitle: String { s("Willkommen bei ShortKeyOrganiser", "Welcome to ShortKeyOrganiser", fr: "Bienvenue dans ShortKeyOrganiser", es: "Bienvenido a ShortKeyOrganiser", it: "Benvenuto in ShortKeyOrganiser") }
    static var obIntroDesc: String { s("Drei kurze Gesten – probier sie gleich selbst aus. Überspringen geht jederzeit.", "Three quick gestures – try them yourself right now. You can skip anytime.", fr: "Trois gestes rapides – essaie-les tout de suite. Tu peux passer à tout moment.", es: "Tres gestos rápidos: pruébalos ahora mismo. Puedes omitir cuando quieras.", it: "Tre gesti rapidi – provali subito. Puoi saltare in qualsiasi momento.") }
    static var obStart: String { s("Los geht’s", "Get started", fr: "Commencer", es: "Empezar", it: "Inizia") }
    static var obSkip: String { s("Überspringen", "Skip", fr: "Passer", es: "Omitir", it: "Salta") }
    static var obStepLabel: String { s("Probier es jetzt:", "Try it now:", fr: "Essaie maintenant :", es: "Pruébalo ahora:", it: "Provalo ora:") }
    static var obTripleTitle: String { s("Befehls-Overlay öffnen", "Open the command overlay", fr: "Ouvrir la liste des commandes", es: "Abrir la lista de comandos", it: "Apri la panoramica comandi") }
    static func obFixDesc(_ mod: String, _ n: Int, hold: Bool) -> String {
        hold
            ? s("Drück die \(mod)-Taste \(n)-mal kurz hintereinander und halt beim letzten Mal gedrückt.", "Press the \(mod) key \(n) times in a row and hold on the last press.", fr: "Appuie \(n) fois de suite sur la touche \(mod) et maintiens la dernière fois.", es: "Pulsa la tecla \(mod) \(n) veces seguidas y mantén la última vez.", it: "Premi il tasto \(mod) \(n) volte di seguito e tieni premuto l'ultima volta.")
            : s("Drück die \(mod)-Taste \(n)-mal kurz hintereinander.", "Press the \(mod) key \(n) times in a row.", fr: "Appuie \(n) fois de suite sur la touche \(mod).", es: "Pulsa la tecla \(mod) \(n) veces seguidas.", it: "Premi il tasto \(mod) \(n) volte di seguito.")
    }
    static var obPeekTitle: String { s("Kurzer Blick (Peek)", "Quick peek", fr: "Aperçu rapide", es: "Vistazo rápido", it: "Sguardo rapido") }
    static func obPeekDesc(_ mod: String, _ n: Int) -> String {
        s("Drück \(mod) \(n)-mal und halt beim letzten Mal gedrückt.", "Press \(mod) \(n) times and hold on the last press.", fr: "Appuie \(n) fois sur \(mod) et maintiens la dernière fois.", es: "Pulsa \(mod) \(n) veces y mantén la última vez.", it: "Premi \(mod) \(n) volte e tieni premuto l'ultima volta.")
    }
    static var obRebindTitle: String { s("Kürzel umbelegen", "Rebind a shortcut", fr: "Réattribuer un raccourci", es: "Reasignar un atajo", it: "Riassegna una scorciatoia") }
    static func obRebindDesc(_ t: String) -> String { s("Öffne irgendwo ein Menü, fahr über einen Eintrag und halt \(t) gedrückt.", "Open any menu, hover an item and hold \(t).", fr: "Ouvre un menu, survole un élément et maintiens \(t).", es: "Abre un menú, pasa sobre un elemento y mantén \(t).", it: "Apri un menu, passa su una voce e tieni premuto \(t).") }
    static var obSuccess: String { s("Geschafft!", "Nice!", fr: "Bravo !", es: "¡Bien!", it: "Fatto!") }
    static var obDoneTitle: String { s("Alles klar!", "All set!", fr: "C’est prêt !", es: "¡Todo listo!", it: "Tutto pronto!") }
    static var obDoneDesc: String { s("Du kennst jetzt alle drei Gesten. Viel Spass mit ShortKeyOrganiser!", "You now know all three gestures. Enjoy ShortKeyOrganiser!", fr: "Tu connais maintenant les trois gestes. Profite de ShortKeyOrganiser !", es: "Ya conoces los tres gestos. ¡Disfruta de ShortKeyOrganiser!", it: "Ora conosci tutti e tre i gesti. Buon divertimento con ShortKeyOrganiser!") }
    static var obClose: String { s("Fertig", "Done", fr: "Terminé", es: "Hecho", it: "Fatto") }

    // PDF-Export
    static var browsePdfTip: String { s("Als PDF exportieren", "Export as PDF", fr: "Exporter en PDF", es: "Exportar como PDF", it: "Esporta come PDF") }
    static var browseKmTip: String { s("Keyboard-Maestro-Makros anzeigen", "Show Keyboard Maestro macros", fr: "Afficher les macros Keyboard Maestro", es: "Mostrar macros de Keyboard Maestro", it: "Mostra macro di Keyboard Maestro") }
    static var browseCompactTip: String { s("Spalten kombinieren / entgruppieren", "Combine / ungroup columns", fr: "Combiner / dégrouper les colonnes", es: "Combinar / desagrupar columnas", it: "Combina / separa colonne") }
    static var browseCloseTip: String { s("Schließen (Esc)", "Close (Esc)", fr: "Fermer (Échap)", es: "Cerrar (Esc)", it: "Chiudi (Esc)") }
    static func ranCommand(_ title: String) -> String { s("Ausgeführt: \(title)", "Ran: \(title)", fr: "Exécuté : \(title)", es: "Ejecutado: \(title)", it: "Eseguito: \(title)") }
    static var pdfScopeTitle: String { s("Was exportieren?", "Export what?", fr: "Exporter quoi ?", es: "¿Qué exportar?", it: "Cosa esportare?") }
    static var pdfScopeAll: String { s("Alle Befehle", "All commands", fr: "Toutes les commandes", es: "Todos los comandos", it: "Tutti i comandi") }
    static var pdfScopeFavorites: String { s("Nur Favoriten", "Favourites only", fr: "Favoris uniquement", es: "Solo favoritos", it: "Solo preferiti") }
    static func pdfHeading(_ app: String) -> String { s("\(app) – Tastenkürzel", "\(app) – Keyboard Shortcuts") }
}
