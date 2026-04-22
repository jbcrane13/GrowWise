import SwiftUI

/// Tab-3 entry point for Garden Club. Stubbed in Phase 3 so MainAppView compiles;
/// real implementation lands in Phase 5.
public struct GardenClubFeedView: View {
    public init() {}

    public var body: some View {
        ZStack {
            CultivationTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Club feed")
                    .font(CultivationTheme.Fonts.display(22, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Text("Coming next in Phase 5")
                    .font(CultivationTheme.Fonts.body(14))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("club_feed_placeholder")
    }
}
