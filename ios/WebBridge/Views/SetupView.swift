import SwiftUI

struct SetupView: View {
    @Bindable var appState: AppState

    @State private var subdomain = AppDefaults.subdomain
    @State private var folder = AppDefaults.folder

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Server Setup")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("Configure your GenieMD environment (saved on this device)")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Subdomain")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.title)
                    TextField("mhc", text: $subdomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    Text("Full domain: https://{subdomain}.geniemd.net")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitle)
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.title)
                    TextField("apps2", text: $folder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    Text("e.g. apps, apps2")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitle)
                }
                .padding(.bottom, 24)

                Button {
                    let sub = subdomain.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fold = folder.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !sub.isEmpty, !fold.isEmpty else {
                        appState.showToast("Subdomain and folder are required")
                        return
                    }
                    appState.saveSetup(subdomain: sub, folder: fold)
                } label: {
                    Text("Save & Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
            .padding(24)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
