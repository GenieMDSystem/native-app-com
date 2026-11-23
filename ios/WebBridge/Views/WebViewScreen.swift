import SwiftUI

struct WebViewScreen: View {
    @Bindable var appState: AppState
    let urlString: String
    var showCloseButton: Bool = false

    var body: some View {
        ZStack {
            if let url = URL(string: urlString) {
                if appState.useLegacyWebView {
                    LegacyBridgeWebView(
                        url: url,
                        onClose: { appState.closeWebView() },
                        onMessage: { appState.showToast($0) }
                    )
                    .ignoresSafeArea()
                } else {
                    BridgeWebView(
                        url: url,
                        onClose: { appState.closeWebView() },
                        onMessage: { appState.showToast($0) }
                    )
                    .ignoresSafeArea()
                }
            } else {
                ContentUnavailableView(
                    "Invalid URL",
                    systemImage: "exclamationmark.triangle",
                    description: Text(urlString)
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            if showCloseButton {
                Button {
                    appState.closeWebView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255).opacity(0.8))
                        )
                }
                .accessibilityLabel("Close WebView")
                .padding(.top, 8)
                .padding(.trailing, 12)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }
}
