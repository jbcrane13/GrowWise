import SwiftUI

struct WelcomeStepView: View {
    @State private var logoVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            brandHero
                .opacity(logoVisible ? 1 : 0)
                .offset(y: logoVisible ? 0 : 28)
            Spacer()
            // Subtle "swipe to begin" hint
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.1).delay(0.1)) {
                logoVisible = true
            }
        }
    }

    // MARK: - Brand Hero

    private var brandHero: some View {
        VStack(spacing: 22) {
            // Logo mark
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(CultivationTheme.Colors.accentCoral.opacity(0.04))
                    .frame(width: 130, height: 130)

                // Mid ring
                Circle()
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.06))
                    .frame(width: 108, height: 108)

                // Core circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                CultivationTheme.Colors.brandMint,
                                CultivationTheme.Colors.brandLeaf.opacity(0.30),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                    )

                // Leaf icon
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CultivationTheme.Colors.brandForest, CultivationTheme.Colors.brandLeaf],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // App name + tagline
            VStack(spacing: 10) {
                Text("Cultivation")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .tracking(-0.5)

                Text("Your garden, beautifully managed")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [CultivationTheme.Colors.brandForest, Color(red: 0.094, green: 0.235, blue: 0.188)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WelcomeStepView()
    }
}
