import SwiftUI

struct WelcomeStepView: View {
    @State private var logoVisible = false
    @State private var featuresVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)

            // Brand hero
            brandHero
                .opacity(logoVisible ? 1 : 0)
                .offset(y: logoVisible ? 0 : 28)

            Spacer()

            // Feature cards
            featureCards
                .opacity(featuresVisible ? 1 : 0)
                .offset(y: featuresVisible ? 0 : 20)

            Spacer(minLength: 100)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.1).delay(0.1)) {
                logoVisible = true
            }
            withAnimation(.spring(duration: 0.65, bounce: 0.05).delay(0.45)) {
                featuresVisible = true
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
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 130, height: 130)

                // Mid ring
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 108, height: 108)

                // Core circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )

                // Leaf icon
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.botanicalMint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // App name + tagline
            VStack(spacing: 10) {
                Text("Cultivation")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-0.5)

                Text("Your garden, beautifully managed")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 10) {
            ForEach(welcomeFeatures, id: \.title) { feature in
                WelcomeFeatureRow(
                    icon: feature.icon,
                    title: feature.title,
                    subtitle: feature.subtitle,
                    accentColor: feature.color
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private struct WelcomeFeature {
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
    }

    private var welcomeFeatures: [WelcomeFeature] {
        [
            WelcomeFeature(icon: "drop.fill", title: "Smart Watering", subtitle: "Personalized schedules for every plant", color: .botanicalLeaf),
            WelcomeFeature(icon: "book.pages.fill", title: "10,000+ Plant Guides", subtitle: "Expert care for any species", color: Color(red: 0.275, green: 0.565, blue: 0.898)),
            WelcomeFeature(icon: "camera.fill", title: "Visual Garden Journal", subtitle: "Track growth with photos & notes", color: .botanicalEarth),
            WelcomeFeature(icon: "cloud.sun.fill", title: "Live Weather Tips", subtitle: "Care advice based on your climate", color: .botanicalGold),
        ]
    }
}

// MARK: - Feature Row

struct WelcomeFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            // Icon bubble
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accentColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.botanicalForest, Color(red: 0.094, green: 0.235, blue: 0.188)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WelcomeStepView()
    }
}
