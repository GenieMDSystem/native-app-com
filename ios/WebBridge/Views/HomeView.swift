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

                Text(appState.config?.environmentUrl ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Choose an option to continue in WebView")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

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

    private enum Destination {
        case visitDoctor, scheduleVisit, schedulesList
    }

    private func open(_ destination: Destination) {
        guard let config = appState.config, let profile = appState.session?.profile else { return }
        let url: String
        switch destination {
        case .visitDoctor:
            url = AppDestinations.visitDoctorUrl(config: config, profile: profile)
        case .scheduleVisit:
            url = AppDestinations.scheduleVisitUrl(config: config, profile: profile)
        case .schedulesList:
            url = AppDestinations.schedulesListUrl(config: config, profile: profile)
        }
        print("[WebViewBridge] Opening: \(url)")
        appState.openWebView(url: url)
    }
}
