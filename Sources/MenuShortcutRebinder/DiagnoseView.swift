import SwiftUI

/// Hübsch formatierte Diagnose: pro Zeile Label links, Status rechtsbündig (Haken/Kreuz),
/// mit Trennlinien. Wird als accessoryView in den Diagnose-Dialog gehängt.
struct DiagnoseView: View {
    let accessibility: Bool
    let tapActive: Bool
    let trigger: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow(Strings.diagAccessibility, accessibility, Strings.diagAxOk, Strings.diagAxBad)
            Divider()
            statusRow(Strings.diagTap, tapActive, Strings.diagTapOk, Strings.diagTapBad)
            Divider()
            HStack {
                Text(Strings.diagTrigger)
                Spacer(minLength: 12)
                Text(trigger).foregroundStyle(.secondary)
            }
            .padding(.vertical, 9)

            if !accessibility || !tapActive {
                Divider()
                Text(Strings.diagFix)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .font(.system(size: 13))
        .frame(width: 330)
        .padding(.horizontal, 2)
    }

    private func statusRow(_ label: String, _ ok: Bool, _ okText: String, _ badText: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(ok ? okText : badText)
            }
            .foregroundStyle(ok ? Color.green : Color.red)
        }
        .padding(.vertical, 9)
    }
}

/// Kurzanleitung als nummerierte Schritte (für den Hilfe-Dialog, Stil wie die Diagnose).
struct HelpView: View {
    let trigger: String
    let seconds: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(1, Strings.help1)
            stepRow(2, Strings.help2)
            stepRow(3, Strings.help3(trigger: trigger, seconds: seconds))
            stepRow(4, Strings.help4)
            Divider()
            Text(Strings.helpNote).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .frame(width: 380)
        .padding(.horizontal, 2)
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
                .foregroundStyle(Color.accentColor)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// Update-Hinweis mit sauber gerenderten Release-Notes (Markdown formatiert, ohne Install-/Signatur-Zeilen).
struct UpdateView: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if items.isEmpty {
                Text(Strings.updateBody).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(Strings.updateAvailableLabel)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 13))
        .frame(width: 420, alignment: .leading)
        .padding(.horizontal, 2)
    }

    /// Release-Notes ohne Installations-/Signatur-Zeilen; Überschriften (#) fett, „- " als „• ",
    /// inline-Markdown (**fett** usw.) korrekt gerendert; sehr lange Notes werden gekappt.
    private var items: [AttributedString] {
        let all: [AttributedString] = notes.split(separator: "\n").map(String.init).compactMap { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            let l = t.lowercased()
            if t.isEmpty || t == "```" || l.contains("install") || l.contains("curl ")
                || l.contains("notarized") || l.contains("signed with") || l.contains("one-liner") { return nil }
            if t.hasPrefix("#") {
                let text = String(t.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                var a = Self.inline(text)
                a.font = .system(size: 13, weight: .semibold)
                return a
            }
            if t.hasPrefix("- ") {
                return AttributedString("•  ") + Self.inline(String(t.dropFirst(2)))
            }
            return Self.inline(t)
        }
        let maxLines = 16
        guard all.count > maxLines else { return all }
        return Array(all.prefix(maxLines)) + [AttributedString("…")]
    }

    /// Parst inline-Markdown (Fett/Kursiv/Code) und behält Leerzeichen.
    private static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

/// Kleines Fortschritts-Fenster während des Updates (unbestimmter Balken, läuft hin und her).
struct UpdateProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text(Strings.updateInstalling).font(.system(size: 13, weight: .medium))
            ProgressView().progressViewStyle(.linear).frame(width: 260)
            Text(Strings.updateRelaunchHint)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(26)
        .frame(width: 320)
    }
}
