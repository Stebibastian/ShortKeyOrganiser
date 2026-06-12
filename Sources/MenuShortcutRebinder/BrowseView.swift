import SwiftUI
import AppKit
import ApplicationServices
import UniformTypeIdentifiers

/// Eine laufende App zur Auswahl im Popup.
struct AppChoice: Identifiable {
    let id: Int          // = pid
    let name: String
    let pid: pid_t
    let bundleID: String?
    let icon: NSImage?
}

/// Threadsicherer Zähler für Scan-Generationen: nur der jüngste Scan darf
/// Ergebnisse anzeigen (ältere laufen ggf. noch im Hintergrund).
final class ScanToken {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    var current: Int { lock.lock(); defer { lock.unlock() }; return value }
}

/// Zustand der „Befehle durchsuchen"-Ansicht.
final class BrowseModel: ObservableObject {
    @Published var apps: [AppChoice] = []
    @Published var selectedPid: pid_t = 0
    @Published var items: [BrowseItem] = []
    @Published var query: String = "" { didSet { selectedID = filteredItems.first?.id } }
    @Published var selectedID: UUID?
    @Published var loading = false
    @Published var pendingMenus: [String] = []   // Menüs, deren Scan noch läuft (Skeleton-Spalten)
    @Published var refreshing = false            // Cache wird gezeigt, frischer Scan läuft im Hintergrund
    @Published var truncatedMenus: Set<String> = []   // Menüs, bei denen die Sicherheitsgrenze griff
    @Published var trusted = true
    @Published var customAppTitles: Set<String> = []
    @Published var customGlobalTitles: Set<String> = []
    @Published var heldMods: Set<Character> = []
    @Published var columnWidth: Double = Settings.browseColumnWidth
    @Published var zebra: Bool = Settings.browseZebra
    @Published var searchActive: Bool = false
    @Published var favorites: Set<String> = BrowsePrefs.favorites
    @Published var hidden: Set<String> = BrowsePrefs.hidden
    @Published var collapsed: Set<String> = BrowsePrefs.collapsed
    @Published var showHidden: Bool = false
    @Published var showFavorites: Bool = true
    @Published var showRecents: Bool = Settings.browseShowRecents
    @Published var recents: [String] = []   // Menüpfade der zuletzt ausgeführten Befehle (aktuelle App)
    @Published var showDisabled: Bool = false
    @Published var kmMode: Bool = false   // Keyboard-Maestro-Makros statt App-Menüs anzeigen
    @Published var highlightEnabled: Bool = Settings.browseHighlight
    @Published var backgroundStyle: Int = Settings.browseBackgroundStyle
    @Published var opaqueRows: Bool = Settings.browseOpaqueRows
    @Published var fontSize: Double = Settings.browseFontSize
    @Published var keyLeft: Bool = Settings.browseKeyLeft
    @Published var compactSections: Bool = Settings.browseCompactSections

    var onEdit: ((BrowseItem, AppChoice) -> Void)?
    var onDelete: ((BrowseItem, AppChoice) -> Void)?
    var onPerform: ((BrowseItem, AppChoice) -> Void)?
    var onActivateSearch: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onManage: (() -> Void)?

    private let scanToken = ScanToken()

    /// Letzter vollständiger Scan pro App (im Speicher): beim Wiederöffnen sofort
    /// anzeigen, im Hintergrund frisch scannen. An die pid gebunden – nach einem
    /// Neustart der Ziel-App wären die AX-Referenzen tot, dann verfällt der Eintrag.
    private struct CacheEntry {
        let pid: pid_t
        let items: [BrowseItem]
        let truncated: Set<String>
        let date: Date
    }
    private static var cache: [String: CacheEntry] = [:]

    var currentApp: AppChoice? { apps.first { $0.pid == selectedPid } }

    /// Schlüssel-Präfix für Favoriten/Verlauf/Cache der aktuellen Quelle.
    var appKey: String { kmMode ? "KM" : (currentApp?.bundleID ?? "") }

    func refreshApps(preferredPid: pid_t?) {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "")
                == .orderedAscending }
        apps = running.map {
            AppChoice(id: Int($0.processIdentifier),
                      name: $0.localizedName ?? $0.bundleIdentifier ?? "?",
                      pid: $0.processIdentifier, bundleID: $0.bundleIdentifier, icon: $0.icon)
        }
        if let preferredPid, apps.contains(where: { $0.pid == preferredPid }) {
            selectedPid = preferredPid
        } else if !apps.contains(where: { $0.pid == selectedPid }) {
            selectedPid = apps.first?.pid ?? 0
        }
    }

    func loadItems(forceReload: Bool = false) {
        trusted = AXIsProcessTrusted()
        let token = scanToken.next()   // macht laufende Scans ungültig
        recents = BrowsePrefs.recents(for: appKey)
        if kmMode {
            items = KeyboardMaestro.scan()
            customAppTitles = []; customGlobalTitles = []
            loading = false; refreshing = false
            pendingMenus = []; truncatedMenus = []
            return
        }
        guard let app = currentApp else {
            items = []; pendingMenus = []; loading = false; refreshing = false
            return
        }
        let pid = app.pid
        let bundleID = app.bundleID
        let cacheKey = bundleID ?? "pid-\(pid)"

        if !forceReload, let cached = Self.cache[cacheKey], cached.pid == pid {
            // Cache sofort zeigen, im Hintergrund komplett frisch scannen und austauschen.
            items = cached.items
            truncatedMenus = cached.truncated
            loading = false; refreshing = true
            pendingMenus = []
        } else {
            items = []; truncatedMenus = []
            loading = true; refreshing = false
            pendingMenus = []
        }
        customAppTitles = Set(Preferences.current(scope: .app, bundleID: bundleID).keys)
        customGlobalTitles = Set(Preferences.current(scope: .global, bundleID: nil).keys)

        let incremental = !refreshing   // ohne Cache: Menü für Menü anzeigen, mit Skeletons
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let menus = FullMenuScanner.topMenus(pid: pid)
            if incremental {
                let names = menus.map(\.name)
                DispatchQueue.main.async {
                    guard token == self.scanToken.current else { return }
                    self.pendingMenus = names
                    self.loading = false   // ab jetzt zeigen Skeleton-Spalten den Fortschritt
                }
            }
            var all: [BrowseItem] = []
            var truncated: Set<String> = []
            for m in menus {
                guard token == self.scanToken.current else { return }   // veralteter Scan
                let result = FullMenuScanner.scanMenu(m.menu, named: m.name)
                all += result.items
                if result.truncated { truncated.insert(m.name) }
                if incremental {
                    let snapshot = all
                    let trunc = truncated
                    DispatchQueue.main.async {
                        guard token == self.scanToken.current else { return }
                        self.items = snapshot
                        self.truncatedMenus = trunc
                        self.pendingMenus.removeAll { $0 == m.name }
                    }
                }
            }
            let finalItems = all
            let trunc = truncated
            DispatchQueue.main.async {
                guard token == self.scanToken.current else { return }
                self.items = finalItems
                self.truncatedMenus = trunc
                self.pendingMenus = []
                self.loading = false
                self.refreshing = false
                Self.cache[cacheKey] = CacheEntry(pid: pid, items: finalItems,
                                                  truncated: trunc, date: Date())
            }
        }
    }

    /// Aktualisieren-Knopf: Cache der aktuellen App verwerfen und frisch einlesen.
    func reload() {
        if let app = currentApp { Self.cache.removeValue(forKey: app.bundleID ?? "pid-\(app.pid)") }
        loadItems(forceReload: true)
    }

    func isCustom(_ item: BrowseItem) -> Bool {
        !kmMode && (customAppTitles.contains(item.title) || customGlobalTitles.contains(item.title))
    }

    /// Keyboard-Maestro-Modus an/aus und Liste neu laden.
    func toggleKM() {
        kmMode.toggle()
        query = ""
        loadItems()
    }

    /// Spalten kombinieren (kompakt) ⇄ entgruppieren (klassisch) – wie der Schalter in den Einstellungen.
    func toggleCompact() {
        compactSections.toggle()
        Settings.browseCompactSections = compactSections
    }

    // MARK: Favoriten / Ausblenden / Einklappen
    func itemKey(_ item: BrowseItem) -> String { (kmMode ? "KM" : (currentApp?.bundleID ?? "")) + "|" + item.pathDisplay }
    func isFavorite(_ item: BrowseItem) -> Bool { favorites.contains(itemKey(item)) }
    func isHidden(_ item: BrowseItem) -> Bool { hidden.contains(itemKey(item)) }
    func toggleFavorite(_ item: BrowseItem) {
        let k = itemKey(item)
        if favorites.contains(k) { favorites.remove(k) } else { favorites.insert(k) }
        BrowsePrefs.favorites = favorites
    }
    func toggleHidden(_ item: BrowseItem) {
        let k = itemKey(item)
        if hidden.contains(k) { hidden.remove(k) } else { hidden.insert(k) }
        BrowsePrefs.hidden = hidden
    }
    func collapseKey(_ cat: String) -> String { (kmMode ? "KM" : (currentApp?.bundleID ?? "")) + "|" + cat }
    func isCollapsed(_ cat: String) -> Bool { collapsed.contains(collapseKey(cat)) }
    func toggleCollapsed(_ cat: String) {
        let k = collapseKey(cat)
        if collapsed.contains(k) { collapsed.remove(k) } else { collapsed.insert(k) }
        BrowsePrefs.collapsed = collapsed
    }

    var filteredItems: [BrowseItem] {
        var base = showHidden ? items : items.filter { !isHidden($0) }
        if !showDisabled { base = base.filter { $0.enabled } }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        let tokens = q.split(separator: " ").map(String.init)
        return base.filter { item in
            let hay = (item.pathDisplay + " " + item.shortcut).lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
    }

    func edit(_ item: BrowseItem) { if !kmMode, let app = currentApp { onEdit?(item, app) } }
    func requestDelete(_ item: BrowseItem) { if !kmMode, let app = currentApp { onDelete?(item, app) } }
    func perform(_ item: BrowseItem) {
        BrowsePrefs.addRecent(item.pathDisplay, for: appKey)
        recents = BrowsePrefs.recents(for: appKey)
        if kmMode { KeyboardMaestro.run(item.title); return }
        if let app = currentApp { onPerform?(item, app) }
    }
    func activateSearch() { onActivateSearch?(); searchActive = true }
    func openSettings() { onOpenSettings?() }
    func manage() { onManage?() }

    func moveSelection(_ delta: Int) {
        let list = filteredItems
        guard !list.isEmpty else { selectedID = nil; return }
        let cur = list.firstIndex { $0.id == selectedID } ?? 0
        selectedID = list[min(list.count - 1, max(0, cur + delta))].id
    }
    func performSelected() {
        guard let id = selectedID, let item = filteredItems.first(where: { $0.id == id }) else { return }
        perform(item)   // gleicher Weg wie der Klick (inkl. Verlauf + Keyboard-Maestro-Modus)
    }

    func setColumnWidth(_ w: Double) {
        let clamped = min(520, max(160, w))
        columnWidth = clamped
        Settings.browseColumnWidth = clamped
    }
    func toggleHighlight() {
        highlightEnabled.toggle()
        Settings.browseHighlight = highlightEnabled
    }
}

/// Tastenkürzel mit farbigen Modifier-Glyphen (⌘ blau, ⇧ grün, ⌥ orange, ⌃ pink).
struct KeyCapView: View {
    let shortcut: String
    var fontSize: Double = 13
    private static let modColor: [Character: Color] = ["⌃": .pink, "⌥": .orange, "⇧": .green, "⌘": .blue]
    var body: some View {
        let (mods, base) = Self.split(shortcut)
        HStack(spacing: 2) {
            ForEach(Array(mods.enumerated()), id: \.offset) { _, m in
                Text(String(m)).foregroundStyle(Self.modColor[m] ?? .secondary)
            }
            if !base.isEmpty { Text(base).foregroundStyle(.primary) }
        }
        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
    }
    static func split(_ s: String) -> ([Character], String) {
        let modSet: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
        var mods: [Character] = []
        var rest = Substring(s)
        while let f = rest.first, modSet.contains(f) { mods.append(f); rest = rest.dropFirst() }
        return (mods, String(rest))
    }
}

/// Eine Befehlszeile. Klick = ausführen; rechts (Hover) Favorit ★, Ausblenden 👁,
/// Anpassen ✏️, Löschen 🗑️ (bei selbst gesetzten).
struct BrowseRowView: View {
    let item: BrowseItem
    let isCustom: Bool
    let isFavorite: Bool
    let isHidden: Bool
    let keyHighlight: Bool   // Modifier-Treffer → gelb
    let selected: Bool       // Tastatur-Auswahl bei Suche → Akzent
    let zebra: Bool
    let solidBackground: Bool   // deckender Zeilen-Hintergrund (Lesbarkeit bei Transparenz)
    let fontSize: Double
    let keyLeft: Bool   // true = Kürzel links (rechtsbündig) + Name rechts (linksbündig)
    let onPerform: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleHidden: () -> Void
    @State private var hover = false

    private var fill: Color {
        if keyHighlight { return Color.yellow.opacity(0.35) }
        if selected { return Color.accentColor.opacity(0.30) }
        if hover { return Color.accentColor.opacity(0.12) }
        if solidBackground { return Color(nsColor: .windowBackgroundColor) }
        if zebra { return Color.secondary.opacity(0.08) }
        return .clear
    }

    private var titleText: Text {
        // Der Submenü-Pfad steht jetzt als Gruppen-Überschrift in der Spalte, nicht mehr als Präfix.
        Text(item.title).foregroundColor(item.enabled ? .primary : .secondary)
    }

    var body: some View {
        HStack(spacing: 5) {
            if isFavorite {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 8)).frame(width: 8)
            } else {
                Circle().fill(isCustom ? Color.accentColor : Color.clear).frame(width: 6, height: 6)
            }

            Button(action: onPerform) {
                HStack(spacing: 8) {
                    if keyLeft {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            if !item.shortcut.isEmpty { KeyCapView(shortcut: item.shortcut, fontSize: fontSize) }
                        }
                        .frame(width: fontSize * 5.5)   // feste Kürzel-Spalte (auch leer) → Namen fluchten
                        titleText.lineLimit(1).truncationMode(.middle)
                            .fontWeight(isCustom ? .semibold : .regular)
                        Spacer(minLength: 0)
                    } else {
                        titleText.lineLimit(1).truncationMode(.middle)
                            .fontWeight(isCustom ? .semibold : .regular)
                        Spacer(minLength: 6)
                        if !item.shortcut.isEmpty { KeyCapView(shortcut: item.shortcut, fontSize: fontSize) }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Strings.browsePerformTip)

            if hover {
                iconBtn(isFavorite ? "star.fill" : "star", .yellow, Strings.browseFavTip, onToggleFavorite)
                iconBtn(isHidden ? "eye" : "eye.slash", .secondary,
                        isHidden ? Strings.browseUnhideTip : Strings.browseHideTip, onToggleHidden)
                iconBtn("pencil", .secondary, Strings.browseEditTip, onEdit)
                if isCustom { iconBtn("trash", .red, Strings.browseDeleteTip, onDelete) }
            }
        }
        .padding(.vertical, 3).padding(.horizontal, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5).fill(fill))
        .contentShape(Rectangle())
        .opacity(isHidden ? 0.45 : 1)
        .font(.system(size: fontSize))
        .help(item.pathDisplay)
        .onHover { hover = $0 }
    }

    private func iconBtn(_ symbol: String, _ color: Color, _ tip: String,
                         _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.plain).foregroundStyle(color).help(tip)
    }
}

/// Nativer macOS-Blur (Milchglas) als Fensterhintergrund (Modus „Milchglas").
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Druckbare Cheatsheet-Darstellung (für den PDF-Export): Titel + Kategorien + Kürzel.
struct CheatsheetView: View {
    let appName: String
    let groups: [(String, [BrowseItem])]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Strings.pdfHeading(appName)).font(.system(size: 22, weight: .bold))
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                let items = group.1.filter { !$0.shortcut.isEmpty }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.0).font(.system(size: 14, weight: .bold))
                        ForEach(items) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title).font(.system(size: 12))
                                Spacer(minLength: 24)
                                Text(item.shortcut).font(.system(size: 12, weight: .semibold))
                            }
                        }
                    }
                }
            }
        }
        .padding(36)
        .frame(width: 560, alignment: .leading)
        .background(Color.white)
        .foregroundColor(.black)
    }
}

struct BrowseView: View {
    @ObservedObject var model: BrowseModel
    @FocusState private var searchFocused: Bool
    @State private var showAppPicker = false

    private var filtered: [BrowseItem] { model.filteredItems }

    /// Favoriten und Verlauf zuoberst als eigene Gruppen, dann die Menü-Kategorien.
    private var grouped: [(String, [BrowseItem])] {
        let f = filtered
        var result: [(String, [BrowseItem])] = []
        if model.showFavorites {
            let favs = f.filter { model.isFavorite($0) }
            if !favs.isEmpty { result.append((Strings.browseFavorites, favs)) }
        }
        if model.showRecents && !model.recents.isEmpty {
            let byPath = Dictionary(grouping: f, by: \.pathDisplay)
            let recent = model.recents.compactMap { byPath[$0]?.first }
            if !recent.isEmpty { result.append((Strings.browseRecents, recent)) }
        }
        // Favoriten/Verlauf bleiben zusätzlich in ihrer normalen Kategorie.
        var order: [String] = []
        var dict: [String: [BrowseItem]] = [:]
        for it in f {
            let cat = it.menuPath.first ?? "—"
            if dict[cat] == nil { order.append(cat) }
            dict[cat, default: []].append(it)
        }
        result += order.map { ($0, dict[$0]!) }
        return result
    }

    /// Exportiert die Befehlsübersicht als mehrseitiges PDF-Cheatsheet. Fragt vorher: alle oder nur Favoriten.
    @MainActor private func exportPDF() {
        let scope = NSAlert()
        scope.messageText = Strings.pdfScopeTitle
        scope.addButton(withTitle: Strings.pdfScopeAll)
        scope.addButton(withTitle: Strings.pdfScopeFavorites)
        scope.addButton(withTitle: Strings.cancel)
        let onlyFavorites: Bool
        switch scope.runModal() {
        case .alertFirstButtonReturn:  onlyFavorites = false
        case .alertSecondButtonReturn: onlyFavorites = true
        default: return
        }

        let app = model.currentApp?.name ?? "App"
        let groups: [(String, [BrowseItem])]
        if onlyFavorites {
            let favs = filtered.filter { model.isFavorite($0) }
            groups = favs.isEmpty ? [] : [(Strings.browseFavorites, favs)]
        } else {
            groups = grouped
        }
        guard !groups.isEmpty else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(app) Shortcuts.pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let renderer = ImageRenderer(content: CheatsheetView(appName: app, groups: groups))
        renderer.scale = 2
        renderer.render { size, renderInContext in
            let totalH = size.height
            let pageH = min(totalH, size.width * 1.414)   // A4-Verhältnis (Höhe = Breite × √2)
            let pages = max(1, Int(ceil(totalH / pageH)))
            var mediaBox = CGRect(x: 0, y: 0, width: size.width, height: pageH)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            for p in 0..<pages {
                ctx.beginPDFPage(nil)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: -(totalH - CGFloat(p + 1) * pageH))   // Seite p von oben zeigen
                renderInContext(ctx)
                ctx.restoreGState()
                ctx.endPDFPage()
            }
            ctx.closePDF()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 520)   // Höhe folgt dem Fenster (Mindesthöhe wird am Fenster selbst gesetzt)
        .background(backdrop)
    }

    /// Hintergrund je nach Modus: Milchglas-Blur; sonst durchscheinen lassen (Fensterfarbe).
    @ViewBuilder private var backdrop: some View {
        if model.backgroundStyle == 2 {
            VisualEffectBlur().ignoresSafeArea()
        } else {
            Color.clear
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Spacer().frame(width: 30)   // Platz für die Fenster-Ampeln (randloser Titel)
            appChooser

            // Dezentes Lade-Feedback: dreht sich, solange gescannt oder im Hintergrund aktualisiert wird.
            if model.refreshing || !model.pendingMenus.isEmpty || model.loading {
                ProgressView().controlSize(.small)
                    .help(Strings.browseUpdating)
            }

            if model.searchActive {
                searchField
            } else {
                navIcon("magnifyingglass", active: false, tip: Strings.browseSearchPlaceholder) {
                    model.activateSearch()
                }
            }

            Divider().frame(height: 18)

            navIcon("star", active: model.showFavorites, tip: Strings.browseShowFavorites) {
                model.showFavorites.toggle()
            }
            navIcon(model.showHidden ? "eye" : "eye.slash", active: !model.showHidden,
                    tip: Strings.browseShowHidden) { model.showHidden.toggle() }
            navIcon("highlighter", active: model.highlightEnabled, tip: Strings.browseHighlightTip) {
                model.toggleHighlight()
            }
            navIcon("circle.dashed", active: !model.showDisabled, tip: Strings.browseShowDisabledTip) {
                model.showDisabled.toggle()
            }
            navIcon("minus", active: false, tip: "Schmälere Spalten") {
                model.setColumnWidth(model.columnWidth - 30)
            }
            navIcon("plus", active: false, tip: "Breitere Spalten") {
                model.setColumnWidth(model.columnWidth + 30)
            }

            Divider().frame(height: 18)

            navIcon("arrow.clockwise", active: false, tip: Strings.browseRefreshTip) { model.reload() }
            if KeyboardMaestro.isInstalled {
                navIcon("k.square", active: model.kmMode, tip: Strings.browseKmTip) { model.toggleKM() }
            }
            navIcon("square.and.arrow.up", active: false, tip: Strings.browsePdfTip) { exportPDF() }
            navIcon("list.bullet", active: false, tip: Strings.browseManageTip) { model.manage() }
            navIcon("rectangle.grid.1x2", active: model.compactSections, tip: Strings.browseCompactTip) { model.toggleCompact() }
            navIcon("gearshape", active: false, tip: Strings.browseSettingsTip) { model.openSettings() }

            Spacer()
        }
        .frame(height: 34)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// App-Auswahl: grosses Icon + Name als Überschrift; Klick öffnet die Liste der laufenden Apps mit Icons.
    private var appChooser: some View {
        Button { showAppPicker.toggle() } label: {
            HStack(spacing: 9) {
                if let icon = model.currentApp?.icon {
                    Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                }
                Text(model.currentApp?.name ?? "—")
                    .font(.title3.weight(.semibold)).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showAppPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(model.apps) { app in
                    Button {
                        model.selectedPid = app.pid
                        model.query = ""; model.searchActive = false; model.loadItems()
                        showAppPicker = false
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            } else {
                                Color.clear.frame(width: 18, height: 18)
                            }
                            Text(app.name)
                            Spacer(minLength: 16)
                            if app.pid == model.selectedPid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .frame(width: 250, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// Einheitlicher Leisten-Knopf (gut klickbare Fläche), aktiver Zustand farbig hinterlegt.
    private func navIcon(_ symbol: String, active: Bool, tip: String,
                         _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .frame(width: 30, height: 26)
                // Knopf bleibt deckend (eigener Hintergrund), auch wenn der Leisten-Grund transparent ist.
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(active ? Color.accentColor.opacity(0.22) : Color.clear))
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .windowBackgroundColor)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.accentColor : .secondary)
        .help(tip)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(Strings.browseSearchPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            Button { model.query = ""; model.searchActive = false } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    @ViewBuilder private var content: some View {
        if !model.trusted {
            emptyState(icon: "lock.shield",
                       title: Strings.browseNoAccess,
                       hint: Strings.browseNoAccessHint,
                       button: (Strings.openSettings, {
                           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                           NSWorkspace.shared.open(url)
                       }))
        } else if filtered.isEmpty && model.pendingMenus.isEmpty && !model.loading {
            if model.items.isEmpty {
                emptyState(icon: "menubar.rectangle",
                           title: Strings.browseEmpty,
                           hint: Strings.browseEmptyHint,
                           button: (Strings.browseRetry, { model.reload() }))
            } else {
                emptyState(icon: "magnifyingglass",
                           title: Strings.browseNoMatch,
                           hint: Strings.browseNoMatchHint)
            }
        } else {
            GeometryReader { geo in
                let cols = packedColumns(geo.size)
                ScrollView([.horizontal, .vertical]) {   // beide Richtungen; ohne erzwungene minHeight kein Teufelskreis, aber nichts wird abgeschnitten
                    ScrollViewReader { proxy in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(cols.enumerated()), id: \.offset) { ci, colGroups in
                                if ci > 0 { Divider() }
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(Array(colGroups.enumerated()), id: \.element.0) { _, group in
                                        column(group.0, group.1)
                                    }
                                }
                            }
                            // Noch ladende Menüs als Skeleton-Spalten (füllen sich von links nach rechts).
                            ForEach(model.pendingMenus, id: \.self) { name in
                                SkeletonColumn(name: name, width: model.columnWidth,
                                               rowHeight: model.fontSize + 8)
                            }
                            if model.loading && model.pendingMenus.isEmpty {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonColumn(name: nil, width: model.columnWidth,
                                                   rowHeight: model.fontSize + 8)
                                }
                            }
                        }
                        .padding(12)
                        // Oben-links bündig: minHeight füllt das Fenster (kein Zentrieren), aber 20px Reserve
                        // lassen Platz für den horizontalen Scrollbalken → er löst keinen vertikalen aus (kein Teufelskreis).
                        .frame(minWidth: geo.size.width,
                               minHeight: max(0, geo.size.height - 20),
                               alignment: .topLeading)
                        .onChange(of: model.selectedID) { id in
                            if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
                        }
                    }
                }
                .scrollIndicators(.hidden, axes: .vertical)   // kein vertikaler Balken → löst keinen Teufelskreis aus; vertikal scrollen geht weiter per Trackpad
                .animation(.easeOut(duration: 0.18), value: model.collapsed)
                .animation(.easeOut(duration: 0.2), value: model.pendingMenus)
            }
        }
    }

    private func sectionRows(_ g: (String, [BrowseItem])) -> Int {
        if model.isCollapsed(g.0) { return 2 }
        let subs = Set(g.1.map { $0.subPath.joined(separator: "▸") }).filter { !$0.isEmpty }.count
        return 2 + g.1.count + subs   // Kategorie-Überschrift + Einträge + Submenü-Überschriften
    }

    /// Packt die Sektionen kompakt in Spalten (KeyClu-Stil): die Spaltenzahl richtet sich nach der
    /// HÖHE (so wenige Spalten wie nötig, damit jede ~ die Fensterhöhe füllt), nicht nach der Breite.
    /// Dadurch werden auch bei breitem Fenster mehrere Sektionen gestapelt statt nebeneinandergelegt.
    private func packedColumns(_ size: CGSize) -> [[(String, [BrowseItem])]] {
        let groups = grouped
        guard groups.count > 1 else { return [groups] }
        if !model.compactSections { return groups.map { [$0] } }   // alte Anordnung: jede Sektion eine eigene Spalte
        // Spaltenweise bis zur Fensterhöhe füllen, dann die nächste Spalte beginnen – so wird bei
        // langen Listen horizontal weitergeblättert statt eine Spalte über den Fensterrand zu schieben.
        let rowH = model.fontSize + 7
        // Reserve für Padding + horizontalen Scrollbalken, damit jede Spalte sicher in die Fensterhöhe passt
        // (es gibt kein vertikales Scrollen mehr, also darf nichts überlaufen).
        let availRows = max(8, Int((size.height - 52) / rowH))
        // Überlange Sektionen vorab in mehrere Teile splitten, damit keine höher als das Fenster ist.
        // (Submenü-Überschriften erscheinen im Folgeteil automatisch wieder, da pro Spalte neu gruppiert.)
        var blocks: [(String, [BrowseItem])] = []
        for g in groups where !g.1.isEmpty {
            if sectionRows(g) <= availRows {
                blocks.append(g)
            } else {
                let perCol = max(1, availRows - 2)   // minus Kategorie-Überschrift
                var i = 0
                while i < g.1.count {
                    blocks.append((g.0, Array(g.1[i..<min(i + perCol, g.1.count)])))
                    i += perCol
                }
            }
        }
        // Blöcke spaltenweise bis zur Fensterhöhe füllen, dann nächste Spalte.
        var cols: [[(String, [BrowseItem])]] = []
        var cur: [(String, [BrowseItem])] = []
        var curH = 0
        for b in blocks {
            let h = sectionRows(b)
            if curH > 0, curH + h > availRows {
                cols.append(cur); cur = []; curH = 0
            }
            cur.append(b); curH += h
        }
        if !cur.isEmpty { cols.append(cur) }
        return cols
    }

    @ViewBuilder private func column(_ cat: String, _ items: [BrowseItem]) -> some View {
        if model.isCollapsed(cat) {
            if model.compactSections {
                collapsedHeader(cat)          // kompakt: nur die Überschrift, Spalte bleibt mit anderen Sektionen
            } else {
                collapsedColumnNarrow(cat)    // klassisch: ganze Spalte schmal, Titel gedreht
            }
        } else {
            expandedColumn(cat, items)
        }
    }

    private func expandedColumn(_ cat: String, _ items: [BrowseItem]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Button { model.toggleCollapsed(cat) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    Text(cat).font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(.secondary).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.bottom, 3)

            ForEach(submenuGroups(items), id: \.0) { sub, subItems in
                if !sub.isEmpty {
                    // Submenü-Überschrift: nicht anwählbar (wie ein echtes Submenü), Einträge eingerückt.
                    Text(sub)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 5).padding(.bottom, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(subItems.enumerated()), id: \.element.id) { idx, item in
                    row(item, idx).padding(.leading, 10)   // alle Einträge gleich eingerückt; Überschriften sitzen weiter links
                }
            }

            if model.truncatedMenus.contains(cat) {
                Text(Strings.browseCapped(FullMenuScanner.maxItemsPerMenu)
                        .trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 10)).italic().foregroundStyle(.tertiary)
                    .padding(.top, 3).padding(.leading, 10)
            }
        }
        .frame(width: model.columnWidth, alignment: .leading)
        .padding(.horizontal, 9)
    }

    /// Einträge einer Spalte nach Submenü-Pfad gruppieren: direkte Einträge zuerst, dann je Submenü eine Gruppe.
    private func submenuGroups(_ items: [BrowseItem]) -> [(String, [BrowseItem])] {
        var order: [String] = []
        var dict: [String: [BrowseItem]] = [:]
        for it in items {
            let key = it.subPath.joined(separator: " ▸ ")   // "" = direkt im Hauptmenü
            if dict[key] == nil { order.append(key) }
            dict[key, default: []].append(it)
        }
        let direct = order.filter { $0.isEmpty }
        let subs   = order.filter { !$0.isEmpty }
        return (direct + subs).map { ($0, dict[$0]!) }
    }

    /// Kompakt-Modus: eingeklappte Sektion = nur die hervorgehobene Überschrift (die Spalte bleibt bestehen).
    private func collapsedHeader(_ cat: String) -> some View {
        Button { model.toggleCollapsed(cat) } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                Text(cat).font(.system(size: 12, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.14)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: model.columnWidth, alignment: .leading)
        .padding(.horizontal, 9)
    }

    /// Klassisch-Modus: eingeklappte Spalte = schmal, Titel um 90° gedreht, leicht hervorgehoben.
    private func collapsedColumnNarrow(_ cat: String) -> some View {
        Button { model.toggleCollapsed(cat) } label: {
            VStack(spacing: 8) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                Text(cat)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1).fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 16, height: 140)
                    .clipped()
            }
            .frame(width: 30)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.14)))
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func row(_ item: BrowseItem, _ idx: Int) -> some View {
        let held = model.highlightEnabled ? model.heldMods : []
        let keyHighlight = !held.isEmpty && !item.baseKey.isEmpty && item.modifiers == held
        let selected = !model.query.isEmpty && item.id == model.selectedID
        return BrowseRowView(item: item,
                             isCustom: model.isCustom(item),
                             isFavorite: model.isFavorite(item),
                             isHidden: model.isHidden(item),
                             keyHighlight: keyHighlight,
                             selected: selected,
                             zebra: model.zebra && idx % 2 == 1,
                             solidBackground: model.backgroundStyle == 1 && model.opaqueRows,
                             fontSize: model.fontSize,
                             keyLeft: model.keyLeft,
                             onPerform: { model.perform(item) },
                             onEdit: { model.edit(item) },
                             onDelete: { model.requestDelete(item) },
                             onToggleFavorite: { model.toggleFavorite(item) },
                             onToggleHidden: { model.toggleHidden(item) })
    }

    /// Freundlicher Leer-/Fehlerzustand: Symbol, Titel, optional Hinweis und Aktions-Knopf.
    private func emptyState(icon: String, title: String, hint: String? = nil,
                            button: (String, () -> Void)? = nil) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(title).font(.headline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let hint {
                Text(hint).font(.callout).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            if let button {
                Button(button.0, action: button.1).padding(.top, 6)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Platzhalter-Spalte für ein Menü, dessen Scan noch läuft: Titel + pulsierende Balken.
struct SkeletonColumn: View {
    let name: String?
    let width: Double
    let rowHeight: Double
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                ProgressView().controlSize(.small).scaleEffect(0.55).frame(width: 12, height: 12)
                Text(name ?? "…").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 3)
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: max(60, width * (i % 2 == 0 ? 0.85 : 0.6)), height: rowHeight)
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 9)
        .opacity(pulse ? 0.45 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
