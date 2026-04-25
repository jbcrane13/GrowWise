import SwiftUI

/// A reusable stat card component for displaying an individual statistic.
public struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(CultivationTheme.Fonts.display(22, weight: .semibold))
                Text(title)
                    .font(CultivationTheme.Fonts.body(12))
                    .foregroundStyle(CultivationTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .background(CultivationTheme.Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.statCard))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint("Displays the number of \(title.lowercased())")
    }
}
