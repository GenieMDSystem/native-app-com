import SwiftUI

struct LoginView: View {
    @Bindable var appState: AppState

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Sign In")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text(appState.config?.environmentUrl ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.title)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.title)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding(.bottom, 24)

                Button {
                    Task { await submit() }
                } label: {
                    ZStack {
                        Text("Login")
                            .font(.system(size: 17, weight: .semibold))
                            .opacity(isLoading ? 0 : 1)
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .disabled(isLoading)
            }
            .padding(24)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    @MainActor
    private func submit() async {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password
        guard !user.isEmpty, !pass.isEmpty else {
            appState.showToast("Username and password are required")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.login(username: user, password: pass)
        } catch let error as ApiError {
            appState.showToast(error.localizedDescription)
        } catch {
            appState.showToast("Login failed. Check network and credentials.")
        }
    }
}
