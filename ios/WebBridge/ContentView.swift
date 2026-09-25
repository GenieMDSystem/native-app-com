import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
            case .splash:
                SplashView()
            case .setup:
                SetupView(appState: appState)
            case .login:
                LoginView(appState: appState)
            case .home:
                HomeView(appState: appState)
            case .webView(let url):
                WebViewScreen(appState: appState, urlString: url)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: routeKey)
        .overlay(alignment: .bottom) {
            if let message = appState.toastMessage {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.title.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            if appState.toastMessage == message {
                                appState.toastMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: appState.toastMessage)
        .task {
            if appState.route == .splash {
                await appState.resolveInitialRoute()
            }
        }
    }

    private var routeKey: String {
        switch appState.route {
        case .splash: return "splash"
        case .setup: return "setup"
        case .login: return "login"
        case .home: return "home"
        case .webView: return "webview"
        }
    }
}

#Preview {
    ContentView(appState: AppState())
}
