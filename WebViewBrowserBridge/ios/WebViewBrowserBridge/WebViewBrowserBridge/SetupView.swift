import SwiftUI

struct SetupView: View {
    @Binding var hasConfig: Bool
    @State private var subdomain = "mhc"
    @State private var folder = "apps2"
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Server Setup")
                .font(.title.bold())
            Text("Configure your GenieMD environment (saved on this device)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                Text("Subdomain")
                TextField("mhc", text: $subdomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Text("Full domain: https://{subdomain}.geniemd.net")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Folder")
                TextField("apps2", text: $folder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Text("e.g. apps, apps2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            Button("Save & Continue") {
                let sub = subdomain.trimmingCharacters(in: .whitespacesAndNewlines)
                let fold = folder.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sub.isEmpty, !fold.isEmpty else {
                    error = "Subdomain and folder are required"
                    return
                }
                AppPreferences.shared.saveConfig(subdomain: sub, folder: fold)
                hasConfig = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
    }
}
