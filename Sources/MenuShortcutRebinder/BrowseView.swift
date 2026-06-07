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

/// Zustand der „Befehle durchsuchen"-Ansicht.
final class BrowseModel: ObservableObject {
    @Published var apps: [AppChoice] = []
    @Published var selectedPid: pid_t = 0
    @Published var items: [BrowseItem] = []
    @Published var query: String = "" { didSet { selectedID = filteredItems.first?.id } }
    @Published var selectedID: UUID?
    @Published var loading = false
    @Published var trusted = true
    @Published var customAppTitles: Set<String> = []
    @Published var customGlobalTitles: Set<String> = []
    @Published var heldMods: Set<Character> = []
    @Published var columnWidth: Double = Settings.browseColumnWidth
    @Published var zebra: Bool = Settings.browseZebra
    @Published var searchActive: Bool = false
    @Published var favorites: Set<String> = BrowsePrefs.favorites
    @Published var hidden: Set<String> = BrowsePrefs.hidden
    @Published var collapsed: Set<String> = []
    @Published var showHidden: Bool = false
    @Published var showFavorites: Bool = true
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

    private var scanToken = 0

    var currentApp: AppChoice? { apps.first { $0.pid == selectedPid } }

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

    func loadItems() {
        trusted = AXIsProcessTrusted()
        if kmMode {
            items = KeyboardMaestro.scan()
            customAppTitles = []; customGlobalTitles = []
            loading = false
            return
        }
        guard let app = currentApp else { items = []; return }
        scanToken += 1
        let token = scanToken
        loading = true
        let pid = app.pid
        let bundleID = app.bundleID
        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = FullMenuScanner.scan(pid: pid)
            DispatchQueue.main.async {
                guard token == self.scanToken else { return }
                self.items = scanned
                self.customAppTitles = Set(Preferences.current(scope: .app, bundleID: bundleID).keys)
                self.customGlobalTitles = Set(Preferences.current(scope: .global, bundleID: nil).keys)
                self.loading = false
            }
        }
    }

    func isCustom(_ item: BrowseItem) -> Bool {
        !kmMode && (customAppTitles.contains(item.title) || customGlobalTitles.contains(item.title))
    }

    /// Keyboard-Maestro-Modus an/aus und Liste neu laden.
    func toggleKM() {
        kmMode.toggle()
        query = ""
        collapsed = []
        loadItems()
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
    func isCollapsed(_ cat: String) -> Bool { collapsed.contains(cat) }
    func toggleCollapsed(_ cat: String) {
        if collapsed.contains(cat) { collapsed.remove(cat) } else { collapsed.insert(cat) }
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
        guard let id = selectedID, let item = filteredItems.first(where: { $0.id == id }),
              let app = currentApp else { return }
        onPerform?(item, app)
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

    /// Favoriten zuoberst als eigene Gruppe, dann die Menü-Kategorien.
    private var grouped: [(String, [BrowseItem])] {
        let f = filtered
        var result: [(String, [BrowseItem])] = []
        if model.showFavorites {
            let favs = f.filter { model.isFavorite($0) }
            if !favs.isEmpty { result.append((Strings.browseFavorites, favs)) }
        }
        // Favoriten bleiben zusätzlich in ihrer normalen Kategorie.
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
        .frame(minWidth: 520, minHeight: 360)
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

            if KeyboardMaestro.isInstalled {
                navIcon("k.square", active: model.kmMode, tip: Strings.browseKmTip) { model.toggleKM() }
            }
            navIcon("square.and.arrow.up", active: false, tip: Strings.browsePdfTip) { exportPDF() }
            navIcon("list.bullet", active: false, tip: Strings.browseManageTip) { model.manage() }
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
            info(Strings.browseNoAccess)
        } else if model.loading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            info(model.items.isEmpty ? Strings.browseEmpty : Strings.browseNoMatch)
        } else {
            GeometryReader { geo in
                let cols = packedColumns(geo.size)
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(cols.enumerated()), id: \.offset) { ci, colGroups in
                            if ci > 0 { Divider() }
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(Array(colGroups.enumerated()), id: \.element.0) { _, group in
                                    column(group.0, group.1)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height,
                           alignment: .topLeading)   // immer oben-links bündig (nicht zentriert)
                }
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
        let rowH = model.fontSize + 7
        let totalRows = groups.reduce(0) { $0 + sectionRows($1) }
        let maxCols = max(1, Int(size.width / model.columnWidth))
        let availRows = max(8, Int(size.height / rowH))
        let neededCols = max(1, Int((Double(totalRows) / Double(availRows)).rounded(.up)))
        let count = max(1, min(maxCols, neededCols))
        guard count > 1 else { return [groups] }
        let target = max(1, totalRows / count)
        var cols: [[(String, [BrowseItem])]] = []
        var cur: [(String, [BrowseItem])] = []
        var curH = 0
        for g in groups {
            let h = sectionRows(g)
            if curH > 0, curH + h > target, cols.count < count - 1 {
                cols.append(cur); cur = []; curH = 0
            }
            cur.append(g); curH += h
        }
        if !cur.isEmpty { cols.append(cur) }
        return cols
    }

    @ViewBuilder private func column(_ cat: String, _ items: [BrowseItem]) -> some View {
        if model.isCollapsed(cat) {
            collapsedColumn(cat)
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

    /// Eingeklappte Spalte: schmal; der Titel als Ganzes um 90° gedreht (von oben nach unten).
    /// Eingeklappte Sektion: nur die Überschrift (im Masonry-Layout sitzt sie in einer Spalte mit anderen).
    private func collapsedColumn(_ cat: String) -> some View {
        Button { model.toggleCollapsed(cat) } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                Text(cat).font(.system(size: 12, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.secondary).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: model.columnWidth, alignment: .leading)
        .padding(.horizontal, 9)
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

    private func info(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
