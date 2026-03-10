import SwiftUI

struct CompletionView: View {
    @Binding var userProfile: UserProfile
    @State private var heroVisible = false
    @State private var summaryVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero checkmark
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.botanicalLeaf.opacity(0.08))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(Color.botanicalLeaf.opacity(0.14))
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.botanicalForest, Color.botanicalLeaf],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.botanicalForest.opacity(0.45), radius: 20, y: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.75)

                VStack(spacing: 8) {
                    Text("Your garden awaits!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Everything's set up. Let's grow.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 12)
            }

            Spacer().frame(height: 32)

            // Profile summary card — glass, 4 rows
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Color.botanicalLeaf)
                    Text("Your Profile")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().overlay(Color.white.opacity(0.07))

                CompletionSummaryRow(
                    icon: "graduationcap.fill",
                    iconColor: Color.botanicalLeaf,
                    label: "Experience",
                    value: userProfile.skillLevel.displayName
                )

                if let firstGoal = userProfile.goals.first {
                    Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                    CompletionSummaryRow(
                        icon: "scope",
                        iconColor: Color.botanicalLeaf.opacity(0.80),
                        label: "Goal",
                        value: firstGoal.displayName
                    )
                }

                Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                CompletionSummaryRow(
                    icon: "leaf.fill",
                    iconColor: Color.botanicalLeaf.opacity(0.70),
                    label: "Garden",
                    value: userProfile.gardenType.displayName
                )

                Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                CompletionSummaryRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: .white.opacity(0.45),
                    label: "Space",
                    value: userProfile.spaceSize.displayName
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65, bounce: 0.2).delay(0.1)) { heroVisible = true }
            withAnimation(.spring(duration: 0.55).delay(0.55)) { summaryVisible = true }
        }
    }
}

// MARK: - Summary Row

private struct CompletionSummaryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CompletionView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
