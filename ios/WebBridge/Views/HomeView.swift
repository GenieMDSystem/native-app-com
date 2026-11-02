import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState
    @State private var flags = VisitDoctorFlags()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Welcome, \(appState.session?.profile.displayName ?? "")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                    .padding(.bottom, 4)

                Text(appState.useLocalWebHost && AppDestinations.isLocalHostEnabled
                     ? "Local: localhost:4201"
                     : (appState.config?.environmentUrl ?? ""))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Open Visit Doctor in WebView")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                if AppDestinations.isLocalHostEnabled {
                    HStack(spacing: 12) {
                        Text("Live")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appState.useLocalWebHost ? AppTheme.subtitle : AppTheme.title)
                        Toggle("Local WebView host", isOn: $appState.useLocalWebHost)
                            .labelsHidden()
                            .tint(AppTheme.primary)
                        Text("Local")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appState.useLocalWebHost ? AppTheme.title : AppTheme.subtitle)
                    }
                    .padding(.bottom, 24)
                }

                Toggle(isOn: $appState.useLegacyWebView) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Legacy WebView (reproduce hang)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.title)
                        Text("Uses old UIImagePickerController and encodes the photo on the main thread after dismiss.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.subtitle)
                    }
                }
                .tint(AppTheme.primary)
                .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional query params")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.title)
                    flagToggle("dependent=true", isOn: $flags.dependent)
                    flagToggle("ignoreLocationCheck=true", isOn: $flags.ignoreLocationCheck)
                    flagToggle("disableCamera=true", isOn: $flags.disableCamera)
                    flagToggle("forWR=true", isOn: $flags.forWR)
                }
                .padding(.bottom, 16)

                Button {
                    openVisitDoctor()
                } label: {
                    Text("Visit Doctor")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .padding(.bottom, 24)

                Button {
                    appState.logout()
                } label: {
                    Text("Logout")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.primary)
            }
            .padding(24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            flags = AppPreferences.shared.visitDoctorFlags
        }
        .onChange(of: flags) { _, newFlags in
            AppPreferences.shared.visitDoctorFlags = newFlags
        }
    }

    private func flagToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.title)
            .tint(AppTheme.primary)
    }

    private func persistFlags() {
        AppPreferences.shared.visitDoctorFlags = flags
    }

    private func openVisitDoctor() {
        guard let config = appState.config, let profile = appState.session?.profile else { return }
        persistFlags()
        let url = AppDestinations.visitDoctorUrl(
            config: config,
            profile: profile,
            useLocal: appState.useLocalWebHost,
            flags: flags
        )
        print("[WebViewBridge] Opening: \(url)")
        appState.openWebView(url: url)
    }
}
