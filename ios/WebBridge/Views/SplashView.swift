import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)

                Text("WebBridge")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("GenieMD Care")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                ProgressView()
                    .tint(.white)
                    .padding(.top, 24)
            }
        }
    }
}

#Preview {
    SplashView()
}
