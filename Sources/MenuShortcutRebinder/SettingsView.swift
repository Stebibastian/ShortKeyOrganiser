import SwiftUI
import AppKit

/// Zentrales Einstellungs-Fenster: feste Seitenleiste links (kein Ein-/Ausblenden), Inhalt rechts.
struct SettingsView: View {
    @State var rebindKeyCode: Int
    @State var rebindHoldMs: Double
    @State var peekEnabled: Bool
    @State var peekModifierIndex: Int
    @State var peekHoldMs: Double
    @State var screenPercent: Double
    @State var heightPercent: Double
    @State var sizeLinked: Bool
    @State var columnWidth: Double
    @State var fontSize: Double
    @State var zebra: Bool
    @State var transparency: Double
    @State var backgroundStyle: Int
    @State var opaqueRows: Bool
    @State var launchAtLogin: Bool

    let onChange: () -> Void
    let onToggleLogin: (Bool) -> Void
    let onManage: () -> Void
    let onDiagnose: () -> Void
    let onHelp: () -> Void
    let onLiveView: () -> Void   // leichte Live-Aktualisierung der Ansicht (ohne Detektor-Neustart)

    @State private var selection: Section = .keyboard

    enum Section: String, CaseIterable, Identifiable {
        case keyboard, view, tools
        var id: String { rawValue }
        var title: String {
            switch self {
            case .keyboard: return Strings.setSecKeyboard
            case .view:     return Strings.setSecView
            case .tools:    return Strings.setSecTools
            }
        }
        var icon: String {
            switch self {
            case .keyboard: return "command"
            case .view:     return "rectangle.split.3x1"
            case .tools:    return "wrench.and.screwdriver"
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
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                detail.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 760, height: 560)
    }

    // Feste Seitenleiste (immer sichtbar, eigener Auswahl-Stil).
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Section.allCases) { sec in
                Button { selection = sec } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sec.icon).frame(width: 20)
                        Text(sec.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(selection == sec ? Color.accentColor : Color.clear))
                    .foregroundStyle(selection == sec ? Color.white : Color.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .keyboard: keyboardSection
        case .view:     viewSection
        case .tools:    toolsSection
        }
    }

    // MARK: Tastenkürzel (zwei klar getrennte Funktionen)

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(Strings.setSecKeyboard).font(.title2.bold())

            featureBlock(Strings.setFeatureOverlay, Strings.setFeatureOverlayDesc) {
                toggleRow(Strings.setPeekEnable, $peekEnabled)
                row(Strings.setPeekTrigger) {
                    Picker("", selection: $peekModifierIndex) {
                        Text(Strings.bsModCommand).tag(0)
                        Text(Strings.bsModOption).tag(1)
                        Text(Strings.bsModControl).tag(2)
                    }
                    .labelsHidden().frame(width: 150)
                    .onChange(of: peekModifierIndex) { _ in commit() }.disabled(!peekEnabled)
                }
                slider(Strings.setHold, $peekHoldMs, 50...500, 10, "ms", disabled: !peekEnabled)
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
            toggleRow(Strings.setZebra, $zebra)
        }
    }

    // MARK: Verwaltung & Hilfe

    private var toolsSection: some View {
        section(Strings.setSecTools) {
            Button(Strings.menuShortcuts) { onManage() }
            Button(Strings.menuDiagnose) { onDiagnose() }
            Button(Strings.menuHelp) { onHelp() }
            Divider().padding(.vertical, 6)
            row(Strings.setLogin) {
                Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { onToggleLogin($0) }
            }
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
        Settings.peekModifierIndex = peekModifierIndex
        Settings.peekHoldDuration = peekHoldMs / 1000.0
        if sizeLinked { heightPercent = screenPercent }
        Settings.browseScreenPercent = screenPercent
        Settings.browseHeightPercent = heightPercent
        Settings.browseSizeLinked = sizeLinked
        Settings.browseColumnWidth = columnWidth
        Settings.browseFontSize = fontSize
        Settings.browseZebra = zebra
        Settings.browseTransparency = transparency
        Settings.browseBackgroundStyle = backgroundStyle
        Settings.browseOpaqueRows = opaqueRows
        if live { onLiveView() } else { onChange() }
    }
}

final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    var onChange: (() -> Void)?
    var onToggleLogin: ((Bool) -> Void)?
    var onManage: (() -> Void)?
    var onDiagnose: (() -> Void)?
    var onHelp: (() -> Void)?
    var onLiveView: (() -> Void)?
    var loginEnabled: () -> Bool = { false }

    func present() {
        window?.orderOut(nil)
        let view = SettingsView(
            rebindKeyCode: Settings.triggerKeyCode,
            rebindHoldMs: Settings.holdDuration * 1000,
            peekEnabled: Settings.peekEnabled,
            peekModifierIndex: Settings.peekModifierIndex,
            peekHoldMs: Settings.peekHoldDuration * 1000,
            screenPercent: Settings.browseScreenPercent,
            heightPercent: Settings.browseHeightPercent,
            sizeLinked: Settings.browseSizeLinked,
            columnWidth: Settings.browseColumnWidth,
            fontSize: Settings.browseFontSize,
            zebra: Settings.browseZebra,
            transparency: Settings.browseTransparency,
            backgroundStyle: Settings.browseBackgroundStyle,
            opaqueRows: Settings.browseOpaqueRows,
            launchAtLogin: loginEnabled(),
            onChange: { [weak self] in self?.onChange?() },
            onToggleLogin: { [weak self] on in self?.onToggleLogin?(on) },
            onManage: { [weak self] in self?.onManage?() },
            onDiagnose: { [weak self] in self?.onDiagnose?() },
            onHelp: { [weak self] in self?.onHelp?() },
            onLiveView: { [weak self] in self?.onLiveView?() })
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = Strings.setWinTitle
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: view)
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
        win.center()
        win.makeKeyAndOrderFront(nil)
    }
}
