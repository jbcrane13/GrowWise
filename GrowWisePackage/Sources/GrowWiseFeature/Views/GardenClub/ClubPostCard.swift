import SwiftUI

struct ClubPostCard: View {
    let post: GardenClubFeedView.ClubActivityViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let caption = post.caption {
                Text(caption)
                    .font(CultivationTheme.Fonts.body(13))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    .lineLimit(nil)
            }

            photo
            actionRow
        }
        .padding(14)
        .paperCard()
        .accessibilityIdentifier("club_post_\(post.id.uuidString)")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandMint, CultivationTheme.Colors.brandLeaf],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(initials(of: post.authorDisplayName))
                        .font(CultivationTheme.Fonts.display(13, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorDisplayName)
                    .font(CultivationTheme.Fonts.body(13, weight: .bold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                subtitle
            }
            Spacer()
        }
    }

    private var subtitle: some View {
        HStack(spacing: 5) {
            if let zone = post.zoneTag {
                Text("Zone \(zone)")
                    .foregroundStyle(CultivationTheme.Colors.smartTagForeground)
                    .fontWeight(.bold)
            }
            if let when = post.relativeTimeLabel {
                Text(post.zoneTag == nil ? when : "\u{00B7} \(when)")
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
        .font(CultivationTheme.Fonts.body(10))
    }

    @ViewBuilder private var photo: some View {
        if let photoURL = post.photoURL {
            #if canImport(UIKit)
            ClubPostPhoto(photoURL: photoURL, postID: post.id)
            #else
            AsyncImage(url: URL(string: photoURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Club post photo")
            .accessibilityIdentifier("club_post_photo_\(post.id.uuidString)")
            #endif
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            if post.likeCount > 0 {
                Label("\(post.likeCount)", systemImage: "heart")
            }
            if post.commentCount > 0 {
                Label("\(post.commentCount)", systemImage: "bubble.right")
            }
            Label("Share", systemImage: "arrow.up.right")
        }
        .font(CultivationTheme.Fonts.body(11, weight: .semibold))
        .foregroundStyle(CultivationTheme.Colors.textTertiary)
    }

    private func initials(of name: String) -> String {
        String(name.prefix(1)).uppercased()
    }
}
