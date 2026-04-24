import CloudKit
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct PublicGardenCardView: View {
    let garden: PublicGarden
    let onLike: () -> Void

    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gardenImage
            gardenInfo
            statsBar
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("community_garden_card_\(garden.id)")
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
                .fill(CultivationTheme.Colors.brandLeaf.opacity(0.1))
            VStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.brandLeaf.opacity(0.4))
                Text(garden.gardenType ?? "Garden")
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Garden Info

    private var gardenInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(garden.name)
                .font(.system(.headline, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text(garden.authorName)
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }

            if let description = garden.description, !description.isEmpty {
                Text(description)
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Text(garden.publishedDate, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            // Like button
            Button {
                withAnimation(CultivationTheme.Animation.card) {
                    isLiked = true
                }
                onLike()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isLiked ? .red : CultivationTheme.Colors.textSecondary)
                    Text("\(garden.likeCount + (isLiked ? 1 : 0))")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLiked)
            .accessibilityIdentifier("community_like_button_\(garden.id)")

            // View count
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                Text("\(garden.viewCount)")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
            .accessibilityIdentifier("community_view_count_\(garden.id)")

            Spacer()

            // Garden type badge
            if let gardenType = garden.gardenType {
                Text(gardenType)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.brandForest)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(CultivationTheme.Colors.brandLeaf.opacity(0.12))
                    }
                    .accessibilityIdentifier("community_garden_type_badge_\(garden.id)")
            }
        }
    }
}
