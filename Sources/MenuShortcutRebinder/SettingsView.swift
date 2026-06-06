import SwiftUI
import AppKit

/// Zentrales Einstellungs-Fenster: Umbelegen-Auslöser, Befehle-durchsuchen-Auslöser,
/// Ansicht und Allgemeines - alles an einem Ort.
struct SettingsView: View {
    @State var rebindKeyCode: Int
    @State var rebindHoldMs: Double
    @State var peekEnabled: Bool
    @State var peekModifierIndex: Int
    @State var peekHoldMs: Double
    @State var screenPercent: Double
    @State var columnWidth: Double
    @State var zebra: Bool
    @State var launchAtLogin: Bool

    let onChange: () -> Void
    let onToggleLogin: (Bool) -> Void

    private let triggerKeys: [(Int, String)] = [
        (62, "Rechte ⌃ (Control)"), (59, "Linke ⌃ (Control)"),
        (61, "Rechte ⌥ (Option)"),  (58, "Linke ⌥ (Option)"),
        (54, "Rechte ⌘ (Command)"), (55, "Linke ⌘ (Command)"),
        (60, "Rechte ⇧ (Shift)"),   (56, "Linke ⇧ (Shift)"),
    ]

    var body: some View {
        Form {
            Section(Strings.setSecRebind) {
                Picker(Strings.setRebindTrigger, selection: $rebindKeyCode) {
                    ForEach(triggerKeys, id: \.0) { Text($0.1).tag($0.0) }
                }
                .onChange(of: rebindKeyCode) { _ in commit() }
                slider(Strings.setHold, value: $rebindHoldMs, range: 300...1500, step: 50, unit: "ms")
            }

            Section(Strings.setSecBrowse) {
                Toggle(Strings.setPeekEnable, isOn: $peekEnabled)
                    .onChange(of: peekEnabled) { _ in commit() }
                Picker(Strings.setPeekTrigger, selection: $peekModifierIndex) {
                    Text(Strings.bsModCommand).tag(0)
                    Text(Strings.bsModOption).tag(1)
                    Text(Strings.bsModControl).tag(2)
                }
                .onChange(of: peekModifierIndex) { _ in commit() }
                .disabled(!peekEnabled)
                slider(Strings.setHold, value: $peekHoldMs, range: 50...500, step: 10, unit: "ms",
                       disabled: !peekEnabled)
                Text(Strings.setPeekHint).font(.caption).foregroundStyle(.secondary)
            }

            Section(Strings.setSecView) {
                slider(Strings.setWindowSize, value: $screenPercent, range: 0.5...1.0, step: 0.05,
                       unit: "%", scale: 100)
                slider(Strings.setColWidth, value: $columnWidth, range: 160...520, step: 10, unit: "pt")
                Toggle(Strings.setZebra, isOn: $zebra).onChange(of: zebra) { _ in commit() }
            }

            Section(Strings.setSecGeneral) {
                Toggle(Strings.setLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { onToggleLogin($0) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 540)
    }

    @ViewBuilder
    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                        step: Double, unit: String, scale: Double = 1, disabled: Bool = false) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range, step: step) { editing in if !editing { commit() } }
            Text("\(Int((value.wrappedValue * scale).rounded())) \(unit)")
                .monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
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
        onChange()
    }
}

final class SettingsWindow: NSObject {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    var onChange: (() -> Void)?
    var onToggleLogin: ((Bool) -> Void)?
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
            launchAtLogin: loginEnabled(),
            onChange: { [weak self] in self?.onChange?() },
            onToggleLogin: { [weak self] on in self?.onToggleLogin?(on) })
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
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
