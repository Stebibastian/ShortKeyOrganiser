# Menü-Kurzbefehl-Umbieger

Über einen **Menüpunkt hovern**, die **rechte ⌃-Taste lange halten** (~0,6 s) → ein
Fenster fragt „Tastenkürzel anpassen?" und bietet die Wahl **nur diese App** oder
**alle Programme**. Bestätigen → das Kürzel wird gesetzt.

Genau die „hover + Taste halten"-Mechanik, gebaut auf den nativen macOS-Bordmitteln.

## Bauen & Starten

```bash
./install.sh            # baut + installiert nach /Applications + startet
```

oder ohne Installation:

```bash
./make-app.sh           # baut MenuShortcutRebinder.app (mit Icon, signiert ad-hoc)
open MenuShortcutRebinder.app
```

Zum Entwickeln ohne Bundle: `swift run`. Das Icon allein neu bauen: `./make-icon.sh`.

Die App läuft als **Menüleisten-Agent** mit ⌘-Icon. Über das Menü:
**Auslöser-Taste ändern**, **Gesetzte Kürzel verwalten** (zurücksetzen),
**Diagnose & Verbindung**, **Beim Anmelden starten** (Schalter), **Kurzanleitung**,
**Beenden**. Kein Dock-Icon (per `LSUIElement`); wer eins will, entfernt `LSUIElement`
aus [`AppSupport/Info.plist`](AppSupport/Info.plist).

### Kürzel zurücksetzen

⌘-Menü → **Gesetzte Kürzel verwalten …** listet alle über dieses Tool gesetzten
Kürzel; einzeln **Zurücksetzen** oder **Alle zurücksetzen**. Es werden nur die
eigenen Einträge angezeigt/entfernt – fremde (z. B. selbst angelegte) bleiben
unberührt. Nach dem Zurücksetzen die betroffene App neu starten.

### Beim ersten Start: Rechte erteilen

1. Es erscheint ein Hinweis → **Systemeinstellungen → Datenschutz & Sicherheit →
   Bedienungshilfen** → MenuShortcutRebinder aktivieren.
2. Nach dem Aktivieren **startet sich die App automatisch neu** – ein frischer
   Prozess bekommt den Tastatur-Tap zuverlässig (eine im laufenden Prozess neu
   erteilte Freigabe greift sonst oft nicht). Falls der Selbst-Neustart mal
   ausbleibt: ⌘-Menü → Beenden, dann wieder öffnen.
3. Falls der Auslöser dann immer noch nicht reagiert, zusätzlich unter
   **Eingabeüberwachung** freigeben.

Das Tool läuft als Menüleisten-Agent (kein Dock-Icon). Beenden über das ⌘-Icon.

## Bedienung

1. Beliebige App, Menü öffnen (z. B. **Bearbeiten**).
2. Mit der Maus über den gewünschten Eintrag fahren (z. B. **Suchen**).
3. **Rechte ⌃** ~0,6 s halten → Menü schließt sich, Fenster erscheint.
4. Gewünschtes Kürzel drücken (z. B. ⌘⇧F), Bereich wählen, **Anpassen**.
5. Bei „nur diese App": auf Wunsch die App neu starten, damit das Menü das neue
   Kürzel zeigt.

### Warum rechte ⌃ als Auslöser?

- Modifier lösen in offenen Menüs **keine Tipp-Auswahl** aus (eine Buchstabentaste
  würde im Menü herumspringen).
- Anders als ⌥/⌘ blendet ⌃ **keine alternativen Menüeinträge** ein – der Punkt unter
  dem Cursor bleibt also der, den du meinst.

**Auslöser & Haltedauer ändern:** ⌘-Menü → **Auslöser-Taste ändern …** → im Dialog
die gewünschte Modifier-Taste drücken (L/R von ⌃ ⌥ ⌘ ⇧) und die Haltedauer per
Regler setzen. Wird sofort übernommen und dauerhaft gespeichert (UserDefaults).

## Wie es speichert

Geschrieben wird die native Voreinstellung **`NSUserKeyEquivalents`** – exakt der
Mechanismus von *Systemeinstellungen → Tastatur → Tastaturkurzbefehle →
App-Kurzbefehle*. Deine Änderung taucht also dort auf und ist voll kompatibel
(auch mit Tools wie CustomShortcuts).

Prüfen / rückgängig machen:

```bash
defaults read com.example.app NSUserKeyEquivalents     # pro App
defaults read -g NSUserKeyEquivalents                  # alle Programme
defaults delete com.example.app NSUserKeyEquivalents   # zurücksetzen
```

Oder einfach in den **App-Kurzbefehlen** den Eintrag wieder löschen.

## Grenzen & Stolperfallen

- **Nur echte Menübefehle.** Es funktioniert für Einträge, die als Menüpunkt unter
  dem Cursor liegen. Der Titel wird direkt ausgelesen → kein fehleranfälliges
  Abtippen wie bei den System-App-Kurzbefehlen.
- **Neustart nötig.** Apps lesen `NSUserKeyEquivalents` beim Aufbau des Menüs – das
  Kürzel erscheint i. d. R. erst nach App-Neustart.
- **Electron-Apps** (Claude, VS Code, Slack …): Die App-Menüs sind native `NSMenu`
  und übernehmen `NSUserKeyEquivalents` meist – manche Electron-Apps bauen ihr Menü
  aber selbst und überschreiben es. Klassische AppKit-Apps (Finder, Mail, Vorschau,
  Safari, Pages …) funktionieren zuverlässig.
- **Globaler Bereich:** höhere Konfliktgefahr mit bestehenden Kürzeln.
- **Konflikte:** Zwei Menüpunkte können sich dasselbe Kürzel nicht teilen.
- **Sondertasten** (F-Tasten, Pfeile, Return …) sind best-effort kodiert; die
  häufigen Fälle ⌘/⌥/⌃/⇧ + Buchstabe/Ziffer sind solide.

## Aufbau

| Datei | Aufgabe |
|---|---|
| `LongPressDetector.swift` | Globaler Event-Tap, erkennt langes Halten der Auslöser-Taste |
| `MenuInspector.swift` | Liest per Accessibility den Menüpunkt unter dem Cursor, schließt Menüs |
| `RecorderPanel.swift` | Fenster „Anpassen?" mit Kürzel-Aufnahme + Bereichswahl |
| `Shortcut.swift` | Kodierung in das `NSUserKeyEquivalents`-Format (`@~^$` + Taste) |
| `Preferences.swift` | Schreibt/liest `NSUserKeyEquivalents` (pro App / global) |
| `AppDelegate.swift` | Menüleisten-Icon, Rechte-Anfrage, Ablaufsteuerung |
| `Strings.swift` | Alle benutzersichtbaren Texte an einer Stelle (Lokalisierung) |
| `Settings.swift` / `SettingsPanel.swift` | Auslöser-Taste & Haltedauer einstellbar |
| `Registry.swift` / `ManagerPanel.swift` | gesetzte Kürzel merken & zurücksetzen |

## Auf einem anderen Mac installieren

### Empfohlen: aus dem Quellcode bauen (keine Gatekeeper-Warnung)

Weil dabei lokal gebaut **und** lokal signiert wird, läuft die App sofort.

```bash
# Einmalig: Xcode Command Line Tools (falls noch nicht vorhanden)
xcode-select --install

git clone https://github.com/Stebibastian/MenuShortcutRebinder.git
cd MenuShortcutRebinder
./install.sh       # Signatur einrichten + bauen + installieren + starten
```

`install.sh` erledigt alles in einem Rutsch und **lautlos** – es legt einen eigenen
Signier-Schlüsselbund an, daher **keine Passwort- oder Schlüsselbund-Dialoge**.
Danach einmal **Bedienungshilfen** freigeben – die App startet sich dann von selbst
neu. Fertig.

### Alternative: fertige App herunterladen

Falls du die gebaute `MenuShortcutRebinder.app` direkt weitergibst (z. B. als ZIP):
Sie ist nur **selbstsigniert**, daher meldet sich Gatekeeper. Auf dem Zielmac:

```bash
xattr -dr com.apple.quarantine /Pfad/zu/MenuShortcutRebinder.app
```

…dann nach `/Applications` ziehen und öffnen. (Oder Rechtsklick → „Öffnen" bzw.
Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen".) Für eine
**warnungsfreie** Weitergabe an Dritte braucht es Notarisierung — siehe unten.

## Verteilung / App Store

**Mac App Store ist für dieses Tool nicht möglich.** Der App Store verlangt die
*App-Sandbox*, und dieses Tool braucht genau die Dinge, die die Sandbox verbietet:
globaler Tastatur-Tap, Bedienungshilfen-Zugriff auf fremde Apps und das Schreiben
fremder App-Voreinstellungen (`NSUserKeyEquivalents`). Deshalb sind auch alle
vergleichbaren Tools (CustomShortcuts, BetterTouchTool, Karabiner, Keyboard Maestro)
**außerhalb** des App Stores.

Der reguläre Weg für so ein Tool ist **Entwickler-ID + Notarisierung**:
Apple-Developer-Programm (99 $/Jahr) → „Developer ID Application"-Zertifikat →
`codesign` damit → `xcrun notarytool submit` → `xcrun stapler staple`. Ergebnis ist
eine signierte, notarisierte `.app`/`.dmg`, die auf jedem Mac ohne Gatekeeper-Warnung
läuft. Aktuell signieren wir mit einem **selbstsignierten** Zertifikat – läuft auf
deinem Mac, auf fremden Macs gäbe es eine Gatekeeper-Warnung.
