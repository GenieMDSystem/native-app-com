import SwiftUI

struct LoginView: View {
    let config: AppConfig
    var onLoggedIn: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?

    private let api = GenieMdApi()

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign In")
                .font(.title.bold())
            Text(config.environmentUrl)
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await login() }
            } label: {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(loading)

            Spacer()
        }
        .padding(24)
    }

    private func login() async {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else {
            error = "Username and password are required"
            return
        }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let result = try await api.validateLogin(config: config, username: user, password: password)
            let profile = try await api.fetchProfile(config: config, token: result.token)
            AppPreferences.shared.saveSession(token: result.token, profile: profile)
            onLoggedIn()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
