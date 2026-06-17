import SwiftUI
import AppKit

/// Live-Anzeige für das Auslöser-Test-Feld: leuchtet auf, wenn eine Geste erkannt wurde,
/// solange das Einstellungs-Fenster im Vordergrund ist (dann öffnet sich kein Overlay).
final class TriggerTestModel: ObservableObject {
    enum Event { case peek, fix, release }

    @Published var peekActive = false    // Kurzblick wird gerade gehalten
    @Published var lastFired: String?    // zuletzt erkannte Geste (verblasst nach kurzer Zeit)
    private var clearTask: DispatchWorkItem?

    func flash(_ event: Event) {
        switch event {
        case .peek:
            peekActive = true
            show(Strings.setTestPeek)
        case .release:
            peekActive = false
        case .fix:
            show(Strings.setTestFix)
        }
    }

    private func show(_ text: String) {
        lastFired = text
        clearTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.lastFired = nil }
        clearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: task)
    }
}

/// Zentrales Einstellungs-Fenster: feste Seitenleiste links (kein Ein-/Ausblenden), Inhalt rechts.
struct SettingsView: View {
    @ObservedObject var test: TriggerTestModel
    @State var rebindKeyCode: Int
    @State var rebindHoldMs: Double
    @State var peekEnabled: Bool
    @State var peekPressCount: Int
    @State var fixEnabled: Bool
    @State var fixPressCount: Int
    @State var fixHold: Bool
    @State var peekModifierIndex: Int
    @State var peekHoldMs: Double
    @State var favEnabled: Bool
    @State var favModifierIndex: Int
    @State var favPressCount: Int
    @State var favHold: Bool
    @State var screenPercent: Double
    @State var heightPercent: Double
    @State var sizeLinked: Bool
    @State var columnWidth: Double
    @State var fontSize: Double
    @State var zebra: Bool
    @State var keyLeft: Bool
    @State var showRecents: Bool
    @State var compactSections: Bool
    @State var anchor: Int
    @State var transparency: Double
    @State var backgroundStyle: Int
    @State var opaqueRows: Bool
    @State var launchAtLogin: Bool
    @State var autoUpdate: Bool
    @State var appLanguage: String

    let onChange: () -> Void
    let onToggleLogin: (Bool) -> Void
    let onManage: () -> Void
    let onDiagnose: () -> Void
    let onHelp: () -> Void
    let onCheckUpdate: () -> Void
    let onLanguageChange: (String) -> Void
    let onLiveView: () -> Void   // leichte Live-Aktualisierung der Ansicht (ohne Detektor-Neustart)
    let onReset: () -> Void      // „Auf Standard zurücksetzen" (fragt nach, setzt um, baut das Fenster neu auf)

    @State private var selection: Section = .keyboard

    enum Section: String, CaseIterable, Identifiable {
        case keyboard, view, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .keyboard: return Strings.setSecKeyboard
            case .view:     return Strings.setSecView
            case .about:    return Strings.setSecAbout
            }
        }
        var icon: String {
            switch self {
            case .keyboard: return "command"
            case .view:     return "rectangle.split.3x1"
            case .about:    return "info.circle"
            }
        }
    }

    private let triggerKeys: [(Int, String)] = [
        (62, "Rechte ⌃ (Control)"), (59, "Linke ⌃ (Control)"),
        (61, "Rechte ⌥ (Option)"),  (58, "Linke ⌥ (Option)"),
        (54, "Rechte ⌘ (Command)"), (55, "Linke ⌘ (Command)"),
        (60, "Rechte ⇧ (Shift)"),   (56, "Linke ⇧ (Shift)"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            detail.padding(26).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 620)   // Höhe richtet sich nach dem Inhalt (Fenster passt sich je Tab an)
    }

    // Tab-Leiste oben (Icon + Titel je Bereich), Stil wie die macOS-Einstellungen.
    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { sec in
                Button { selection = sec } label: {
                    VStack(spacing: 3) {
                        Image(systemName: sec.icon).font(.system(size: 17))
                        Text(sec.title).font(.caption)
                    }
                    .frame(width: 88, height: 48)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(selection == sec ? Color.accentColor.opacity(0.18) : Color.clear))
                    .foregroundStyle(selection == sec ? Color.accentColor : Color.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .keyboard: keyboardSection
        case .view:     viewSection
        case .about:    aboutSection
        }
    }

    // MARK: Tastenkürzel (zwei klar getrennte Funktionen)

    /// Konflikt: beide Gesten wären identisch (gleiche Druckzahl UND beide mit Halten).
    private var triggerConflict: Bool {
        peekEnabled && fixEnabled && fixHold && peekPressCount == fixPressCount
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(Strings.setSecKeyboard).font(.title2.bold())

            // Overlay: eine gemeinsame Taste, zwei Gesten (Kurzblick + fix öffnen).
            featureBlock(Strings.setFeatureOverlay, Strings.setFeatureOverlayDesc) {
                row(Strings.setPeekTrigger) { modifierPicker($peekModifierIndex) }
                Divider()
                Text(Strings.setGesturePeek).font(.callout.weight(.semibold))
                triggerControls(mode: peekModeBinding, count: $peekPressCount, allowTapOnly: false)
                slider(Strings.setHold, $peekHoldMs, 50...500, 10, "ms", disabled: peekModeBinding.wrappedValue == 0)
                Divider()
                Text(Strings.setGestureFix).font(.callout.weight(.semibold))
                triggerControls(mode: modeBinding($fixEnabled, $fixHold, $fixPressCount),
                                count: $fixPressCount, allowTapOnly: true)
                if triggerConflict {
                    Label(Strings.setTriggerConflict, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.orange)
                }
                Divider()
                testField
            }

            featureBlock(Strings.setFeatureFavorites, Strings.setFeatureFavoritesDesc) {
                row(Strings.setFavTrigger) { modifierPicker($favModifierIndex) }
                Divider()
                triggerControls(mode: modeBinding($favEnabled, $favHold, $favPressCount),
                                count: $favPressCount, allowTapOnly: true)
            }

            featureBlock(Strings.setFeatureRebind, Strings.setFeatureRebindDesc) {
                row(Strings.setRebindTrigger) {
                    Picker("", selection: $rebindKeyCode) {
                        ForEach(triggerKeys, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .labelsHidden().frame(width: 210)
                    .onChange(of: rebindKeyCode) { _ in commit() }
                }
                slider(Strings.setHold, $rebindHoldMs, 300...1500, 50, "ms")
            }
        }
    }

    private func modifierPicker(_ sel: Binding<Int>) -> some View {
        Picker("", selection: sel) {
            Text(Strings.bsModCommand).tag(0)
            Text(Strings.bsModOption).tag(1)
            Text(Strings.bsModControl).tag(2)
        }
        .labelsHidden().frame(width: 150)
        .onChange(of: sel.wrappedValue) { _ in commit() }
    }

    /// Modus 0=aus, 1=nur halten, 2=tippen, 3=tippen+halten – kapselt enabled/hold/count einer Geste.
    private func modeBinding(_ enabled: Binding<Bool>, _ hold: Binding<Bool>, _ count: Binding<Int>) -> Binding<Int> {
        Binding(
            get: {
                if !enabled.wrappedValue { return 0 }
                if hold.wrappedValue && count.wrappedValue <= 1 { return 1 }
                return hold.wrappedValue ? 3 : 2
            },
            set: { m in
                switch m {
                case 1: enabled.wrappedValue = true; hold.wrappedValue = true; count.wrappedValue = 1
                case 2: enabled.wrappedValue = true; hold.wrappedValue = false; if count.wrappedValue < 2 { count.wrappedValue = 2 }
                case 3: enabled.wrappedValue = true; hold.wrappedValue = true; if count.wrappedValue < 2 { count.wrappedValue = 2 }
                default: enabled.wrappedValue = false
                }
                commit()
            })
    }

    /// Kurzblick ist immer mit Halten (kein „nur Tippen"): 0=aus, 1=nur halten, 3=N×+halten.
    private var peekModeBinding: Binding<Int> {
        Binding(
            get: { !peekEnabled ? 0 : (peekPressCount <= 1 ? 1 : 3) },
            set: { m in
                switch m {
                case 1: peekEnabled = true; peekPressCount = 1
                case 3: peekEnabled = true; if peekPressCount < 2 { peekPressCount = 2 }
                default: peekEnabled = false
                }
                commit()
            })
    }

    /// Modus-Picker + (bei den Tippen-Modi) Anzahl. Die Taste steht separat im Block.
    @ViewBuilder
    private func triggerControls(mode: Binding<Int>, count: Binding<Int>, allowTapOnly: Bool) -> some View {
        row(Strings.setTriggerMode) {
            Picker("", selection: mode) {
                Text(Strings.setModeOff).tag(0)
                Text(Strings.setModeHold).tag(1)
                if allowTapOnly { Text(Strings.setModeTap).tag(2) }
                Text(Strings.setModeTapHold).tag(3)
            }
            .labelsHidden().frame(width: 200)
        }
        if mode.wrappedValue >= 2 {
            row(Strings.setPressCount) {
                Picker("", selection: count) {
                    ForEach(2...5, id: \.self) { Text("\($0)×").tag($0) }
                }
                .labelsHidden().frame(width: 70)
                .onChange(of: count.wrappedValue) { _ in commit() }
            }
        }
    }

    /// Auswahl „2× … 5×"; mit `holdSuffix` steht „+ halten" dahinter.
    private func pressCountPicker(_ value: Binding<Int>, holdSuffix: Bool) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: value) {
                ForEach(2...5, id: \.self) { n in
                    Text("\(n)×").tag(n)
                }
            }
            .labelsHidden().frame(width: 70)
            .onChange(of: value.wrappedValue) { _ in commit() }
            Text(holdSuffix ? Strings.setPlusHold : " ")
                .font(.callout).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
        }
    }

    /// Live-Test: Geste ausführen, solange dieses Fenster vorne ist → hier leuchtet das Ergebnis auf.
    private var testField: some View {
        let active = test.peekActive || test.lastFired != nil
        return HStack(spacing: 10) {
            Image(systemName: test.peekActive ? "eye.fill" : (test.lastFired != nil ? "checkmark.circle.fill" : "hand.tap"))
                .font(.system(size: 17))
                .foregroundStyle(active ? Color.green : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.setTestTitle).font(.callout.weight(.medium))
                Text(test.lastFired ?? Strings.setTestHint)
                    .font(.caption)
                    .foregroundStyle(active ? Color.green : Color.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(active ? Color.green.opacity(0.13) : Color.secondary.opacity(0.07)))
        .animation(.easeOut(duration: 0.18), value: test.peekActive)
        .animation(.easeOut(duration: 0.18), value: test.lastFired)
    }

    // MARK: Ansicht

    private var viewSection: some View {
        section(Strings.setSecView) {
            toggleRow(Strings.setSizeLinked, $sizeLinked)
            if sizeLinked {
                slider(Strings.setWindowSize, $screenPercent, 0.4...1.0, 0.05, "%", scale: 100, live: true)
            } else {
                slider(Strings.setWidth, $screenPercent, 0.4...1.0, 0.05, "%", scale: 100, live: true)
                slider(Strings.setHeight, $heightPercent, 0.4...1.0, 0.05, "%", scale: 100, live: true)
            }
            slider(Strings.setColWidth, $columnWidth, 160...520, 10, "pt", live: true)
            slider(Strings.setFontSize, $fontSize, 11...18, 1, "pt", live: true)
            row(Strings.setBackground) {
                Picker("", selection: $backgroundStyle) {
                    Text(Strings.setBgOpaque).tag(0)
                    Text(Strings.setBgTransparent).tag(1)
                    Text(Strings.setBgBlur).tag(2)
                }
                .labelsHidden().frame(width: 180)
                .onChange(of: backgroundStyle) { _ in commit() }
            }
            if backgroundStyle == 1 {
                slider(Strings.setTransparency, $transparency, 0...0.30, 0.01, "%", scale: 100, live: true)
                toggleRow(Strings.setOpaqueRows, $opaqueRows)
            }
            toggleRow(Strings.setCompactSections, $compactSections)
            row(Strings.setPosition) { positionGrid }
            toggleRow(Strings.setZebra, $zebra)
            toggleRow(Strings.setKeyLeft, $keyLeft)
            toggleRow(Strings.setShowRecents, $showRecents)
        }
    }

    // MARK: Über (App-Info + Werkzeuge + Updates)

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("ShortKeyOrganiser").font(.title.bold())
                    Text("Version \(UpdateChecker.currentVersion)").foregroundStyle(.secondary)
                    Text(Strings.aboutTagline).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            row(Strings.setLanguage) {
                Picker("", selection: $appLanguage) {
                    Text(Strings.setLangSystem).tag("system")
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                    Text("Français").tag("fr")
                    Text("Español").tag("es")
                    Text("Italiano").tag("it")
                }
                .labelsHidden().frame(width: 160)
                .onChange(of: appLanguage) { onLanguageChange($0) }
            }

            GroupBox(Strings.aboutTools) {
                VStack(alignment: .leading, spacing: 12) {
                    Button(Strings.menuShortcuts) { onManage() }
                    Button(Strings.menuDiagnose) { onDiagnose() }
                    Button(Strings.menuHelp) { onHelp() }
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(Strings.aboutUpdates) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Button(Strings.menuCheckUpdate) { onCheckUpdate() }; Spacer() }
                    toggleRow(Strings.setAutoUpdate, $autoUpdate)
                    row(Strings.setLogin) {
                        Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
                            .onChange(of: launchAtLogin) { onToggleLogin($0) }
                    }
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(Strings.reset) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(Strings.setReset) { onReset() }
                    Text(Strings.setResetNote).font(.caption).foregroundStyle(.secondary)
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(Strings.aboutCopyright).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: Bausteine

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.title2.bold())
            VStack(alignment: .leading, spacing: 16) { content() }
        }
    }

    /// Funktionsblock mit Titel + Erklärung (für die zwei Tastenkürzel-Funktionen).
    private func featureBlock<C: View>(_ title: String, _ desc: String,
                                       @ViewBuilder _ content: () -> C) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(desc).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 14) { content() }
            }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack { Text(label); Spacer(minLength: 16); control() }
    }

    /// Schalter-Zeile: Label links, Switch rechtsbündig (einheitlich mit den Auswahlmenüs).
    private func toggleRow(_ label: String, _ value: Binding<Bool>) -> some View {
        row(label) {
            Toggle("", isOn: value).labelsHidden().toggleStyle(.switch)
                .onChange(of: value.wrappedValue) { _ in commit() }
        }
    }

    /// 3×3-Raster zur Wahl der Fensterposition (Mitte / Kanten / Ecken).
    private var positionGrid: some View {
        let codes = [5, 1, 6, 3, 0, 4, 7, 2, 8]   // oben-links, oben, oben-rechts, links, Mitte, …
        return VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { c in
                        let a = codes[r * 3 + c]
                        Button { anchor = a; commit() } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(anchor == a ? Color.accentColor : Color.secondary.opacity(0.18))
                                .frame(width: 28, height: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                        _ step: Double, _ unit: String, scale: Double = 1, disabled: Bool = false,
                        live: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(label).frame(width: 150, alignment: .leading)
            Slider(value: value, in: range, step: step) { e in if !e { commit() } }
                .onChange(of: value.wrappedValue) { _ in if live { commit(live: true) } }
            Text("\(Int((value.wrappedValue * scale).rounded())) \(unit)")
                .monospacedDigit().foregroundStyle(.secondary).frame(width: 54, alignment: .trailing)
        }
        .disabled(disabled)
    }

    private func commit(live: Bool = false) {
        Settings.triggerKeyCode = rebindKeyCode
        Settings.holdDuration = rebindHoldMs / 1000.0
        Settings.peekEnabled = peekEnabled
        Settings.peekPressCount = peekPressCount
        Settings.fixOpenEnabled = fixEnabled
        Settings.fixPressCount = fixPressCount
        Settings.fixHoldAtEnd = fixHold
        Settings.peekModifierIndex = peekModifierIndex
        Settings.favEnabled = favEnabled
        Settings.favModifierIndex = favModifierIndex
        Settings.favPressCount = favPressCount
        Settings.favHoldAtEnd = favHold
        Settings.peekHoldDuration = peekHoldMs / 1000.0
        if sizeLinked { heightPercent = screenPercent }
        Settings.browseScreenPercent = screenPercent
        Settings.browseHeightPercent = heightPercent
        Settings.browseSizeLinked = sizeLinked
        Settings.browseColumnWidth = columnWidth
        Settings.browseFontSize = fontSize
        Settings.browseZebra = zebra
        Settings.browseKeyLeft = keyLeft
        Settings.browseShowRecents = showRecents
        Settings.browseCompactSections = compactSections
        Settings.browseAnchor = anchor
        Settings.browseTransparency = transparency
        Settings.browseBackgroundStyle = backgroundStyle
        Settings.browseOpaqueRows = opaqueRows
        Settings.autoUpdate = autoUpdate
        if live { onLiveView() } else { onChange() }
    }
}

final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    let testModel = TriggerTestModel()
    var onChange: (() -> Void)?
    var onReset: (() -> Void)?

    /// Solange das Einstellungs-Fenster vorne ist, landen erkannte Auslöser-Gesten
    /// im Test-Feld statt das Overlay zu öffnen.
    var isTestingTriggers: Bool { window?.isKeyWindow == true }

    func flashTest(_ event: TriggerTestModel.Event) {
        DispatchQueue.main.async { self.testModel.flash(event) }
    }
    var onToggleLogin: ((Bool) -> Void)?
    var onManage: (() -> Void)?
    var onDiagnose: (() -> Void)?
    var onHelp: (() -> Void)?
    var onCheckUpdate: (() -> Void)?
    var onLanguageChange: ((String) -> Void)?
    var onLiveView: (() -> Void)?
    var loginEnabled: () -> Bool = { false }

    func present() {
        window?.orderOut(nil)
        let view = SettingsView(
            test: testModel,
            rebindKeyCode: Settings.triggerKeyCode,
            rebindHoldMs: Settings.holdDuration * 1000,
            peekEnabled: Settings.peekEnabled,
            peekPressCount: Settings.peekPressCount,
            fixEnabled: Settings.fixOpenEnabled,
            fixPressCount: Settings.fixPressCount,
            fixHold: Settings.fixHoldAtEnd,
            peekModifierIndex: Settings.peekModifierIndex,
            peekHoldMs: Settings.peekHoldDuration * 1000,
            favEnabled: Settings.favEnabled,
            favModifierIndex: Settings.favModifierIndex,
            favPressCount: Settings.favPressCount,
            favHold: Settings.favHoldAtEnd,
            screenPercent: Settings.browseScreenPercent,
            heightPercent: Settings.browseHeightPercent,
            sizeLinked: Settings.browseSizeLinked,
            columnWidth: Settings.browseColumnWidth,
            fontSize: Settings.browseFontSize,
            zebra: Settings.browseZebra,
            keyLeft: Settings.browseKeyLeft,
            showRecents: Settings.browseShowRecents,
            compactSections: Settings.browseCompactSections,
            anchor: Settings.browseAnchor,
            transparency: Settings.browseTransparency,
            backgroundStyle: Settings.browseBackgroundStyle,
            opaqueRows: Settings.browseOpaqueRows,
            launchAtLogin: loginEnabled(),
            autoUpdate: Settings.autoUpdate,
            appLanguage: Settings.appLanguage,
            onChange: { [weak self] in self?.onChange?() },
            onToggleLogin: { [weak self] on in self?.onToggleLogin?(on) },
            onManage: { [weak self] in self?.onManage?() },
            onDiagnose: { [weak self] in self?.onDiagnose?() },
            onHelp: { [weak self] in self?.onHelp?() },
            onCheckUpdate: { [weak self] in self?.onCheckUpdate?() },
            onLanguageChange: { [weak self] l in self?.onLanguageChange?(l) },
            onLiveView: { [weak self] in self?.onLiveView?() },
            onReset: { [weak self] in self?.onReset?() })
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]   // Fenster passt sich je Tab an
        let win = NSWindow(contentViewController: controller)
        win.styleMask = [.titled, .closable]
        win.title = Strings.setWinTitle
        win.level = .floating
        win.isReleasedWhenClosed = false
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
        win.center()
        win.makeKeyAndOrderFront(nil)
    }
}
