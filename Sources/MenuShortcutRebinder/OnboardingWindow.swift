import AppKit
import SwiftUI

final class OnboardingModel: ObservableObject {
    @Published var step = 0          // 0=Intro, 1=Triple-⌘, 2=Peek, 3=Rebind, 4=Done
    @Published var justSucceeded = false

    func reset() { step = 0; justSucceeded = false }

    /// Vom erkannten Trigger gerufen: schaltet weiter, wenn der erwartete Schritt aktiv ist.
    func success(for expected: Int) {
        guard step == expected, !justSucceeded else { return }
        justSucceeded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.justSucceeded = false
            self.step += 1
        }
    }
}

/// Interaktives Onboarding im Raycast-Stil: führt durch die drei Gesten und erkennt,
/// sobald sie geklappt haben (die Trigger werden vom AppDelegate hierher umgeleitet).
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()
    private var window: NSWindow?
    let model = OnboardingModel()
    var isActive: Bool { window?.isVisible == true }

    func present() {
        if window == nil { build() }
        model.reset()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// step: 1 = ⌘⌘⌘, 2 = Peek (⌘⌘+halten), 3 = Umbelegen-Trigger.
    func register(trigger step: Int) {
        guard isActive else { return }
        model.success(for: step)
    }

    private func finish() {
        Settings.onboardingDone = true
        window?.orderOut(nil)
    }

    private func build() {
        let view = OnboardingView(model: model,
                                  trigger: TriggerKey.shortName(for: Settings.triggerKeyCode),
                                  onFinish: { [weak self] in self?.finish() })
        let host = NSHostingController(rootView: view)
        host.sizingOptions = [.preferredContentSize]
        let win = NSWindow(contentViewController: host)
        win.styleMask = [.titled, .closable]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.delegate = self
        window = win
    }

    func windowWillClose(_ notification: Notification) { Settings.onboardingDone = true }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let trigger: String
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch model.step {
            case 0: intro
            case 1: gesture(Strings.obTripleTitle,
                            Strings.obFixDesc(Settings.peekModifierSymbol,
                                              Settings.fixPressCount, hold: Settings.fixHoldAtEnd),
                            icon: "command")
            case 2: gesture(Strings.obPeekTitle,
                            Strings.obPeekDesc(Settings.peekModifierSymbol, Settings.peekPressCount),
                            icon: "command")
            case 3: gesture(Strings.obRebindTitle, Strings.obRebindDesc(trigger), icon: "cursorarrow.rays")
            default: done
            }
        }
        .frame(width: 440)
        .padding(30)
        .animation(.easeInOut(duration: 0.25), value: model.step)
        .animation(.easeInOut(duration: 0.2), value: model.justSucceeded)
        .onAppear { skipDisabledSteps() }
        .onChange(of: model.step) { _ in skipDisabledSteps() }
    }

    /// Abgeschaltete Gesten im Tutorial überspringen (sie könnten nie erkannt werden).
    private func skipDisabledSteps() {
        if model.step == 1 && !Settings.fixOpenEnabled { model.step = 2 }
        if model.step == 2 && !Settings.peekEnabled { model.step = 3 }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            appIcon(64)
            Text(Strings.obIntroTitle).font(.title2.bold())
            Text(Strings.obIntroDesc).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button(Strings.obSkip) { onFinish() }
                Button(Strings.obStart) { model.step = 1 }.keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
    }

    private func gesture(_ title: String, _ desc: String, icon: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(model.justSucceeded ? Color.green.opacity(0.18) : Color.accentColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: model.justSucceeded ? "checkmark" : icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(model.justSucceeded ? Color.green : Color.accentColor)
            }
            Text(title).font(.title3.bold())
            Text(desc).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(model.justSucceeded ? Strings.obSuccess : Strings.obStepLabel)
                .font(.callout.weight(.medium))
                .foregroundStyle(model.justSucceeded ? Color.green : Color.secondary)
            stepDots
            Button(Strings.obSkip) { onFinish() }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 58)).foregroundStyle(Color.green)
            Text(Strings.obDoneTitle).font(.title2.bold())
            Text(Strings.obDoneDesc).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button(Strings.obClose) { onFinish() }.keyboardShortcut(.defaultAction).padding(.top, 6)
        }
    }

    private var stepDots: some View {
        HStack(spacing: 7) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= model.step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func appIcon(_ size: CGFloat) -> some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon).resizable().frame(width: size, height: size)
            }
        }
    }
}
