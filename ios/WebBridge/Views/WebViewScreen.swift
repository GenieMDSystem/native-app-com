import SwiftUI

struct WebViewScreen: View {
    @Bindable var appState: AppState
    let urlString: String

    var body: some View {
        ZStack(alignment: .top) {
            if let url = URL(string: urlString) {
                if appState.useLegacyWebView {
                    LegacyBridgeWebView(
                        url: url,
                        onClose: { appState.closeWebView() },
                        onMessage: { appState.showToast($0) }
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    BridgeWebView(
                        url: url,
                        onClose: { appState.closeWebView() },
                        onMessage: { appState.showToast($0) }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            } else {
                ContentUnavailableView(
                    "Invalid URL",
                    systemImage: "exclamationmark.triangle",
                    description: Text(urlString)
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    appState.closeWebView()
                } label: {
                    Label("Done", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(spacing: 2) {
                    Text(appState.useLegacyWebView ? "Legacy WebView" : "WebView")
                        .font(.headline)
                        .foregroundStyle(AppTheme.title)
                    if appState.useLegacyWebView {
                        Text("UIImagePicker + main-thread inject")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtitle)
                    }
                }

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.background.opacity(0.95))
        }
        .background(Color.white.ignoresSafeArea())
    }
}
