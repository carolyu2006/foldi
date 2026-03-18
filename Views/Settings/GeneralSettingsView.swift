import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("backupLimit") private var backupLimit = 20

    var body: some View {
        Form {
            Section("Backups") {
                Stepper("Max backups: \(backupLimit)", value: $backupLimit, in: 5...100, step: 5)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Folder Icon", value: "Custom folder icon creator")
            }
        }
        .formStyle(.grouped)
    }
}
