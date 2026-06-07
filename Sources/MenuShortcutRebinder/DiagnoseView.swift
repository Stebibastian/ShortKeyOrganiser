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
