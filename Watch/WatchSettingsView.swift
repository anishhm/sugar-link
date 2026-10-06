import SwiftUI

struct WatchSettingsView: View {
    @Environment(GlucoseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        let settings = model.settings
        // Thresholds are stored in mg/dL: one press is 5 mg/dL or 0.2 mmol/L.
        let step = settings.unit == .mgdl ? 5.0 : 0.2 * DisplaySettings.mmolFactor

        List {
            Section("Unit") {
                Picker("Unit", selection: $model.settings.unit) {
                    ForEach(GlucoseUnit.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("Thresholds (\(settings.unit.label))") {
                Stepper(value: $model.settings.low, in: 50...(settings.elevated - 10), step: step) {
                    thresholdRow("Red below", settings.low, .low)
                }
                Stepper(value: $model.settings.elevated, in: (settings.low + 10)...settings.high, step: step) {
                    thresholdRow("Orange from", settings.elevated, .elevated)
                }
                Stepper(value: $model.settings.high, in: settings.elevated...300, step: step) {
                    thresholdRow("Purple above", settings.high, .high)
                }
            }

            Section("Display") {
                Toggle("Show chart", isOn: $model.settings.showChart)
                Toggle("Show steps", isOn: $model.settings.showSteps)
            }

            Section {
                Button(role: .destructive) {
                    model.logOut()
                    dismiss()
                } label: {
                    Text("Log Out")
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func thresholdRow(_ title: String, _ value: Double, _ range: GlucoseRange) -> some View {
        let settings = model.settings
        return HStack {
            Circle().fill(range.color).frame(width: 8, height: 8)
            Text(title).font(.footnote)
            Spacer()
            Text("\(settings.format(value))")
                .font(.system(.footnote, design: .rounded, weight: .bold))
        }
    }
}
