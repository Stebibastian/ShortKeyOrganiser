import AppKit
import SwiftUI
import ApplicationServices

/// Lädt die als Favorit markierten Befehle der aktiven App und führt sie per AXPress aus.
/// Randloses Fenster, das Key werden darf – sonst greifen Esc und das Resign-Schliessen nicht.
private final class KeyablePanel: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class FavoritesPopupModel: ObservableObject {
    @Published var appName = ""
    @Published var items: [BrowseItem] = []
    @Published var loading = true

    func load(app: NSRunningApplication) {
        appName = app.localizedName ?? "?"
        items = []
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? ""
        // Favoriten-Pfade dieser App (ohne "bundleID|"-Präfix).
        let prefix = bundleID + "|"
        let favPaths = BrowsePrefs.favorites
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
        guard !favPaths.isEmpty else {          // keine Favoriten → sofort, gar kein Scan
            items = []; loading = false; return
        }
        loading = true
        // Nur die Top-Menüs scannen, in denen Favoriten liegen (erster Pfad-Teil vor " ▸ ").
        // Spart bei grossen Apps wie FileMaker den Scan riesiger Menüs (z. B. "Skripte").
        let favTopNames = Set(favPaths.compactMap { $0.components(separatedBy: " ▸ ").first })
        let favPathSet = Set(favPaths)
        DispatchQueue.global(qos: .userInitiated).async {
            let menus = FullMenuScanner.topMenus(pid: pid).filter { favTopNames.contains($0.name) }
            let scanned = menus.flatMap { FullMenuScanner.scanMenu($0.menu, named: $0.name).items }
            let favItems = scanned.filter { favPathSet.contains($0.pathDisplay) }
            DispatchQueue.main.async {
                self.items = favItems
                self.loading = false
            }
        }
    }

    func perform(_ item: BrowseItem) {
        guard let el = item.element else { return }
        AXUIElementPerformAction(el, kAXPressAction as CFString)
        HUD.show(Strings.ranCommand(item.title))
    }
}

/// Kleines, randloses Popup direkt neben der Maus mit den Favoriten der aktuell aktiven App.
/// Eigener Auslöser (Settings.fav…); schliesst bei Auswahl, Esc oder Klick daneben.
final class FavoritesPopupWindow: NSObject, NSWindowDelegate {
    static let shared = FavoritesPopupWindow()
    private var window: NSWindow?
    private let model = FavoritesPopupModel()

    private var clickMonitor: Any?

    func present(app: NSRunningApplication?) {
        guard let app else { return }
        model.load(app: app)
        if window == nil { build() }
        positionAtMouse()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { self.positionAtMouse() }
        // Backup zum Resign-/Esc-Schliessen: jeder Klick ausserhalb (andere App) schliesst.
        if clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.close()
            }
        }
    }

    func close() {
        window?.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func build() {
        let host = NSHostingController(rootView:
            FavoritesPopupView(model: model, onClose: { [weak self] in self?.close() }))
        host.sizingOptions = [.preferredContentSize]
        let win = KeyablePanel(contentViewController: host)
        win.styleMask = [.borderless]
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.delegate = self
        window = win
    }

    /// Popup rechts-unterhalb des Mauszeigers, immer komplett auf dem Bildschirm.
    private func positionAtMouse() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let size = window.frame.size
        let vf = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame
            ?? .init(x: 0, y: 0, width: 1440, height: 900)
        var x = mouse.x + 14
        var y = mouse.y - size.height - 14
        x = min(max(x, vf.minX + 8), vf.maxX - size.width - 8)
        if y < vf.minY + 8 { y = mouse.y + 14 }                    // unten kein Platz → über die Maus
        y = min(max(y, vf.minY + 8), vf.maxY - size.height - 8)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResignKey(_ notification: Notification) { close() }   // Klick daneben schliesst
}

struct FavoritesPopupView: View {
    @ObservedObject var model: FavoritesPopupModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 10))
                Text(model.appName).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            if model.loading {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(Strings.browseLoading).font(.system(size: 12)).foregroundStyle(.secondary) }
                    .padding(.vertical, 6)
            } else if model.items.isEmpty {
                Text(Strings.favPopupEmpty).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 240, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(model.items) { item in
                    FavRow(item: item) { model.perform(item); onClose() }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 220, maxWidth: 340, alignment: .leading)
        .background(VisualEffectBlur().clipShape(RoundedRectangle(cornerRadius: 11)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5))
        .onExitCommand { onClose() }
    }
}

private struct FavRow: View {
    let item: BrowseItem
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(item.title).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 16)
                if !item.shortcut.isEmpty { KeyCapView(shortcut: item.shortcut, fontSize: 12) }
            }
            .padding(.vertical, 3).padding(.horizontal, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.accentColor.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
