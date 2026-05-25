import CloudKit
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct PublicGardenCardView: View {
    let garden: PublicGarden
    let onLike: () -> Void

    @State private var isLiked = false

    private var presentation: PublicGardenShowcasePresentation {
        PublicGardenShowcasePresentation(garden: garden, isLiked: isLiked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gardenImage
            gardenInfo
            statsBar
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("community_garden_card_\(garden.id)")
        .accessibilityLabel(presentation.cardAccessibilityLabel)
    }

    // MARK: - Garden Image

    private var gardenImage: some View {
        Group {
            if let asset = garden.imageAsset, let url = asset.fileURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)

                    default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card - 4))
    }

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CultivationTheme.Radius.card - 4)
                .fill(CultivationTheme.Colors.backgroundSecondary)
                .overlay {
                    CultivationTheme.Gradients.hero
                        .opacity(0.7)
                }
            VStack(spacing: 8) {
                Image(systemName: "camera.macro")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.55))
                Text(presentation.typeLabel)
                    .font(CultivationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Garden Info

    private var gardenInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(garden.name)
                        .font(CultivationTheme.Fonts.display(19, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        Text("By \(garden.authorName)")
                            .font(CultivationTheme.Fonts.body(13, weight: .medium))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                typeBadge
            }

            if let description = presentation.descriptionText {
                Text(description)
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.accentAmber)
                Text("Shared")
                Text(garden.publishedDate, style: .relative)
            }
            .font(CultivationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(CultivationTheme.Animation.card) {
                    isLiked = true
                }
                onLike()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))

                    VStack(alignment: .leading, spacing: 0) {
                        Text(presentation.likeDisplayCount)
                            .font(CultivationTheme.Fonts.body(13, weight: .bold))
                        Text("Likes")
                            .font(CultivationTheme.Fonts.body(9, weight: .semibold))
                            .textCase(.uppercase)
                    }
                }
                .foregroundStyle(isLiked ? CultivationTheme.Colors.accentCoral : CultivationTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(CultivationTheme.Colors.accentCoral.opacity(isLiked ? 0.12 : 0.06))
                }
            }
            .buttonStyle(.plain)
            .disabled(isLiked)
            .accessibilityIdentifier("community_like_button_\(garden.id)")
            .accessibilityLabel(presentation.likeButtonAccessibilityLabel)
            .accessibilityValue(presentation.likeButtonAccessibilityValue)

            showcaseMetric(
                systemName: "eye",
                value: presentation.viewDisplayCount,
                label: "Views",
                accessibilityLabel: presentation.viewAccessibilityLabel
            )
            .accessibilityIdentifier("community_view_count_\(garden.id)")

            Spacer()
        }
    }

    private var typeBadge: some View {
        Text(presentation.typeLabel)
            .font(CultivationTheme.Fonts.body(10, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(CultivationTheme.Colors.brandForest)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(CultivationTheme.Colors.brandLeaf.opacity(0.14))
            }
            .accessibilityIdentifier("community_garden_type_badge_\(garden.id)")
    }

    private func showcaseMetric(
        systemName: String,
        value: String,
        label: String,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(CultivationTheme.Fonts.body(13, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                Text(label)
                    .font(CultivationTheme.Fonts.body(9, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
