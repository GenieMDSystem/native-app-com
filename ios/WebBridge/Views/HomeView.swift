import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Welcome, \(appState.session?.profile.displayName ?? "")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                    .padding(.bottom, 4)

                Text(hostLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Choose an option to continue in WebView")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                if let config = appState.config, config.hasFolder2 {
                    HStack(spacing: 12) {
                        Text(config.folder)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appState.useFolder2 ? AppTheme.subtitle : AppTheme.title)
                        Toggle("Folder switch", isOn: $appState.useFolder2)
                            .labelsHidden()
                            .tint(AppTheme.primary)
                        Text(config.folder2 ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appState.useFolder2 ? AppTheme.title : AppTheme.subtitle)
                    }
                    .padding(.bottom, 16)
                }

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

                Button {
                    open(.visitDoctor)
                } label: {
                    Text("Visit Doctor Now")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .padding(.bottom, 16)

                Button {
                    open(.scheduleVisit)
                } label: {
                    Text("Schedule Visit Now")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.primary)
                .padding(.bottom, 16)

                Button {
                    open(.schedulesList)
                } label: {
                    Text("Schedules List")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.primary)
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
    }

    private var hostLabel: String {
        if appState.useLocalWebHost && AppDestinations.isLocalHostEnabled {
            return "Local: localhost:4201 (visit) · localhost:4200/rpm (schedules)"
        }
        return appState.activeConfig?.environmentUrl ?? appState.config?.environmentUrl ?? ""
    }

    private enum Destination {
        case visitDoctor, scheduleVisit, schedulesList
    }

    private func open(_ destination: Destination) {
        guard let config = appState.activeConfig, let profile = appState.session?.profile else { return }
        let url: String
        let showClose: Bool
        switch destination {
        case .visitDoctor:
            url = AppDestinations.visitDoctorUrl(config: config, profile: profile, useLocal: appState.useLocalWebHost)
            showClose = true
        case .scheduleVisit:
            url = AppDestinations.scheduleVisitUrl(config: config, profile: profile, useLocal: appState.useLocalWebHost)
            showClose = true
        case .schedulesList:
            url = AppDestinations.schedulesListUrl(config: config, profile: profile, useLocal: appState.useLocalWebHost)
            showClose = false
        }
        print("[WebViewBridge] Opening: \(url)")
        appState.openWebView(url: url, showCloseButton: showClose)
    }
}
