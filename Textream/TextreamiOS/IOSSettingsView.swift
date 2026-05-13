import SwiftUI

struct IOSSettingsView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Reader") {
                    Stepper(value: $model.readerFontSize, in: 20...56, step: 2) {
                        HStack {
                            Text("Font size")
                            Spacer()
                            Text("\(Int(model.readerFontSize))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $model.scrollSpeedWordsPerSecond, in: 0.5...6.0, step: 0.5) {
                        HStack {
                            Text("Classic speed")
                            Spacer()
                            Text(String(format: "%.1f w/s", model.scrollSpeedWordsPerSecond))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Modes") {
                    Text("Classic mode is implemented first in this Ralph pass.")
                    Text("Voice-Activated and Word Tracking UI is in place; speech pipeline migration comes next.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    IOSSettingsView(model: IOSTeleprompterModel())
}
