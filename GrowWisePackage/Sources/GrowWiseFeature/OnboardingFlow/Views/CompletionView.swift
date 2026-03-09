import SwiftUI

struct CompletionView: View {
    @Binding var userProfile: UserProfile
    @State private var celebrationVisible = false
    @State private var summaryVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 24)

                // Celebration hero
                celebrationHero
                    .opacity(celebrationVisible ? 1 : 0)
                    .scaleEffect(celebrationVisible ? 1 : 0.85)

                // Profile summary card
                profileSummaryCard
                    .opacity(summaryVisible ? 1 : 0)
                    .offset(y: summaryVisible ? 0 : 24)

                // Next steps
                nextStepsSection
                    .opacity(summaryVisible ? 1 : 0)
                    .offset(y: summaryVisible ? 0 : 16)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65, bounce: 0.2).delay(0.1)) {
                celebrationVisible = true
            }
            withAnimation(.spring(duration: 0.55).delay(0.5)) {
                summaryVisible = true
            }
        }
    }

    // MARK: - Celebration Hero

    private var celebrationHero: some View {
        VStack(spacing: 20) {
            // Animated success mark
            ZStack {
                // Outer ring
                Circle()
                    .fill(Color.botanicalMint.opacity(0.30))
                    .frame(width: 120, height: 120)

                // Mid ring
                Circle()
                    .fill(Color.botanicalLeaf.opacity(0.25))
                    .frame(width: 92, height: 92)

                // Core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.botanicalForest, Color.botanicalLeaf],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.botanicalForest.opacity(0.30), radius: 12, y: 4)

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Your garden awaits!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.botanicalForest)
                    .multilineTextAlignment(.center)

                Text("Everything is set up and ready.\nLet's grow something beautiful.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Profile Summary Card

    private var profileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                Label("Your Profile", systemImage: "person.crop.circle.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.botanicalForest)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.botanicalMint.opacity(0.30))

            Divider()
                .overlay(Color.botanicalSage.opacity(0.25))

            // Summary rows
            VStack(spacing: 0) {
                SummaryRow(
                    icon: "graduationcap.fill",
                    iconColor: Color.botanicalForest,
                    label: "Experience",
                    value: userProfile.skillLevel.displayName
                )

                if !userProfile.goals.isEmpty {
                    Divider().padding(.leading, 52).overlay(Color.botanicalSage.opacity(0.20))
                    SummaryRow(
                        icon: "scope",
                        iconColor: Color.botanicalLeaf,
                        label: "Top Goal",
                        value: userProfile.goals.first?.displayName ?? ""
                    )
                }

                Divider().padding(.leading, 52).overlay(Color.botanicalSage.opacity(0.20))
                SummaryRow(
                    icon: "leaf.fill",
                    iconColor: Color.botanicalLeaf,
                    label: "Garden Type",
                    value: userProfile.gardenType.displayName
                )

                Divider().padding(.leading, 52).overlay(Color.botanicalSage.opacity(0.20))
                SummaryRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: Color.botanicalSage,
                    label: "Space",
                    value: userProfile.spaceSize.displayName
                )

                if userProfile.hasLocationPermission {
                    Divider().padding(.leading, 52).overlay(Color.botanicalSage.opacity(0.20))
                    SummaryRow(
                        icon: "location.fill",
                        iconColor: Color(red: 0.275, green: 0.565, blue: 0.898),
                        label: "Location",
                        value: "Enabled"
                    )
                }

                if userProfile.hasNotificationPermission {
                    Divider().padding(.leading, 52).overlay(Color.botanicalSage.opacity(0.20))
                    SummaryRow(
                        icon: "bell.fill",
                        iconColor: Color.botanicalGold,
                        label: "Reminders",
                        value: "Enabled"
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.07), radius: 12, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.botanicalSage.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Next Steps

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("First steps")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color.botanicalForest)

            VStack(spacing: 10) {
                NextStepCard(
                    icon: "plus.circle.fill",
                    iconColor: Color.botanicalLeaf,
                    title: "Add Your First Plant",
                    description: "Browse 10,000+ species or add your existing plants"
                )
                NextStepCard(
                    icon: "bell.badge.fill",
                    iconColor: Color.botanicalGold,
                    title: "Set Up Care Reminders",
                    description: "Smart watering and care schedules for every plant"
                )
                NextStepCard(
                    icon: "book.pages.fill",
                    iconColor: Color(red: 0.275, green: 0.565, blue: 0.898),
                    title: "Explore Plant Guides",
                    description: "Expert tips and tutorials for your growing goals"
                )
            }
        }
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor)
            }

            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.botanicalForest)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

// MARK: - Next Step Card

private struct NextStepCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.botanicalForest)

                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.botanicalSage.opacity(0.6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.botanicalSage.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.botanicalCream.ignoresSafeArea()
        CompletionView(userProfile: .constant(UserProfile()))
    }
}
