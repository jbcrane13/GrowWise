#if canImport(UIKit)
import GrowWiseServices
import SwiftUI
import UIKit

struct ClubPostPhoto: View {
    @Environment(PhotoService.self)
    private var photoService

    let photoURL: String
    let postID: UUID

    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didLoad {
                unavailableState
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Club post photo")
        .accessibilityIdentifier("club_post_photo_\(postID.uuidString)")
        .task(id: photoURL) {
            image = await photoService.loadImage(from: photoURL)
            didLoad = true
        }
    }

    private var unavailableState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(CultivationTheme.Colors.backgroundSecondary)
            Label("Photo unavailable", systemImage: "photo")
                .font(CultivationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
    }
}
#endif
