import SwiftUI

// MARK: - Step Header

/// Reusable header used across all onboarding step screens.
struct OnboardingStepHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
    }
}

// MARK: - Permission Card

/// Used on Location and Notification screens to display a permission CTA.
struct PermissionGrantedBadge: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.2))
                    .frame(width: 34, height: 34)

                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.brandForest)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CultivationTheme.Colors.brandMint.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(CultivationTheme.Colors.brandLeaf.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Benefit Row

/// A styled benefit row used on permission request screens.
struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Privacy Note

struct PrivacyNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.brandLeaf)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(CultivationTheme.Colors.brandMint.opacity(0.20))
        )
    }
}
