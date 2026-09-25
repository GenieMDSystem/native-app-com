import SwiftUI

struct HomeView: View {
    let config: AppConfig
    let session: UserSession
    var onLogout: () -> Void

    @State private var webURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Welcome, \(session.profile.displayName)")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text(config.environmentUrl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Choose an option to continue in WebView")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                Button("Visit Doctor Now") {
                    open(AppDestinations.visitDoctorUrl(config: config, profile: session.profile))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Schedule Visit Now") {
                    open(AppDestinations.scheduleVisitUrl(config: config, profile: session.profile))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Schedules List") {
                    open(AppDestinations.schedulesListUrl(config: config, profile: session.profile))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Logout", role: .destructive, action: onLogout)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
        .fullScreenCover(item: $webURL) { url in
            WebViewScreen(url: url) {
                webURL = nil
            }
            .ignoresSafeArea()
        }
    }

    private func open(_ urlString: String) {
        print("[WebViewBridge] open \(urlString)")
        webURL = URL(string: urlString)
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
