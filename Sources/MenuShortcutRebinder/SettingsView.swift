import SwiftUI
import AppKit

/// Zentrales Einstellungs-Fenster im macOS-Stil: Seitenleiste links, Inhalt rechts.
struct SettingsView: View {
    @State var rebindKeyCode: Int
    @State var rebindHoldMs: Double
    @State var peekEnabled: Bool
    @State var peekModifierIndex: Int
    @State var peekHoldMs: Double
    @State var screenPercent: Double
    @State var columnWidth: Double
    @State var zebra: Bool
    @State var transparency: Double
    @State var launchAtLogin: Bool

    let onChange: () -> Void
    let onToggleLogin: (Bool) -> Void
    let onManage: () -> Void
    let onDiagnose: () -> Void
    let onHelp: () -> Void

    @State private var selection: Section? = .rebind

    enum Section: String, CaseIterable, Identifiable {
        case rebind, browse, view, tools
        var id: String { rawValue }
        var title: String {
            switch self {
            case .rebind: return Strings.setSecRebind
            case .browse: return Strings.setSecBrowse
            case .view:   return Strings.setSecView
            case .tools:  return Strings.setSecTools
            }
        }
        var icon: String {
            switch self {
            case .rebind: return "pencil"
            case .browse: return "magnifyingglass"
            case .view:   return "rectangle.split.3x1"
            case .tools:  return "wrench.and.screwdriver"
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
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { sec in
                Label(sec.title, systemImage: sec.icon).tag(sec)
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            ScrollView {
                detail.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 640, minHeight: 460)
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .rebind {
        case .rebind: rebindSection
        case .browse: browseSection
        case .view:   viewSection
        case .tools:  toolsSection
        }
    }

    private var rebindSection: some View {
        section(Strings.setSecRebind) {
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

    private var browseSection: some View {
        section(Strings.setSecBrowse) {
            Toggle(Strings.setPeekEnable, isOn: $peekEnabled)
                .toggleStyle(.switch).onChange(of: peekEnabled) { _ in commit() }
            row(Strings.setPeekTrigger) {
                Picker("", selection: $peekModifierIndex) {
                    Text(Strings.bsModCommand).tag(0)
                    Text(Strings.bsModOption).tag(1)
                    Text(Strings.bsModControl).tag(2)
                }
                .labelsHidden().frame(width: 150)
                .onChange(of: peekModifierIndex) { _ in commit() }
                .disabled(!peekEnabled)
            }
            slider(Strings.setHold, $peekHoldMs, 50...500, 10, "ms", disabled: !peekEnabled)
            Text(Strings.setPeekHint).font(.callout).foregroundStyle(.secondary)
        }
    }

    private var viewSection: some View {
        section(Strings.setSecView) {
            slider(Strings.setWindowSize, $screenPercent, 0.5...1.0, 0.05, "%", scale: 100)
            slider(Strings.setColWidth, $columnWidth, 160...520, 10, "pt")
            slider(Strings.setTransparency, $transparency, 0...0.85, 0.05, "%", scale: 100)
            Toggle(Strings.setZebra, isOn: $zebra)
                .toggleStyle(.switch).onChange(of: zebra) { _ in commit() }
        }
    }

    private var toolsSection: some View {
        section(Strings.setSecTools) {
            Button(Strings.menuShortcuts) { onManage() }
            Button(Strings.menuDiagnose) { onDiagnose() }
            Button(Strings.menuHelp) { onHelp() }
            Divider().padding(.vertical, 6)
            Toggle(Strings.setLogin, isOn: $launchAtLogin)
                .toggleStyle(.switch).onChange(of: launchAtLogin) { onToggleLogin($0) }
        }
    }

    // MARK: Bausteine

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.title2.bold())
            VStack(alignment: .leading, spacing: 16) { content() }
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(label)
            Spacer()
            control()
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                        _ step: Double, _ unit: String, scale: Double = 1, disabled: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(label).frame(width: 150, alignment: .leading)
            Slider(value: value, in: range, step: step) { e in if !e { commit() } }
            Text("\(Int((value.wrappedValue * scale).rounded())) \(unit)")
                .monospacedDigit().foregroundStyle(.secondary).frame(width: 54, alignment: .trailing)
        }
        .disabled(disabled)
    }

    private func commit() {
        Settings.triggerKeyCode = rebindKeyCode
        Settings.holdDuration = rebindHoldMs / 1000.0
        Settings.peekEnabled = peekEnabled
        Settings.peekModifierIndex = peekModifierIndex
        Settings.peekHoldDuration = peekHoldMs / 1000.0
        Settings.browseScreenPercent = screenPercent
        Settings.browseColumnWidth = columnWidth
        Settings.browseZebra = zebra
        Settings.browseTransparency = transparency
        onChange()
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
            columnWidth: Settings.browseColumnWidth,
            zebra: Settings.browseZebra,
            transparency: Settings.browseTransparency,
            launchAtLogin: loginEnabled(),
            onChange: { [weak self] in self?.onChange?() },
            onToggleLogin: { [weak self] on in self?.onToggleLogin?(on) },
            onManage: { [weak self] in self?.onManage?() },
            onDiagnose: { [weak self] in self?.onDiagnose?() },
            onHelp: { [weak self] in self?.onHelp?() })
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
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
