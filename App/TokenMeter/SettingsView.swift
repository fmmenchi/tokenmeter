import SwiftUI
import TokenMeterCore

struct SettingsView: View {
    @Bindable var meter: Meter

    var body: some View {
        Form {
            Section("Claude token budget (output + input + cache)") {
                limitField("5h window", value: $meter.limits.claudeSession)
                limitField("7d window", value: $meter.limits.claudeWeek)
            }
            Section("ChatGPT token budget (used when the log reports no quota)") {
                limitField("5h window", value: $meter.limits.chatgptSession)
                limitField("7d window", value: $meter.limits.chatgptWeek)
            }
            Text("Plan limits are not published in tokens. Leave empty to show consumption only.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    private func limitField(_ title: String, value: Binding<Int?>) -> some View {
        TextField(title, value: value, format: .number, prompt: Text("none"))
    }
}
