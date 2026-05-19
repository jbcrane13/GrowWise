import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// Compact weather alert banner for the Home tab.
/// Displays frost, heat, or heavy-rain warnings returned by LocationService.
public struct WeatherAlertCard: View {
    let alert: WeatherAlert

    @State private var isDismissed = false

    public init(alert: WeatherAlert) {
        self.alert = alert
    }

    public var body: some View {
        if !isDismissed {
            HStack(alignment: .top, spacing: 12) {
                alertIcon
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(alertColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    Text(alert.message)
                        .font(.system(.caption))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer()

                Button {
                    withAnimation(CultivationTheme.Animation.card) {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss weather alert")
                .accessibilityIdentifier("weather_alert_button_dismiss_\(alert.id.uuidString)")
            }
            .padding(CultivationTheme.Spacing.screenPadding)
            .background(
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                    .fill(alertBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                            .stroke(alertColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.bottom, 4)
            .accessibilityIdentifier("weather_alert_card_\(alert.id.uuidString)")
        }
    }

    private var alertIcon: some View {
        switch alert.type {
        case .frost:
            Image(systemName: "thermometer.snowflake")
        case .heat:
            Image(systemName: "thermometer.sun.fill")
        case .heavyRain:
            Image(systemName: "cloud.heavyrain.fill")
        case .drought:
            Image(systemName: "sun.max.fill")
        case .wind:
            Image(systemName: "wind")
        case .storm:
            Image(systemName: "cloud.bolt.rain.fill")
        }
    }

    private var alertColor: Color {
        switch alert.type {
        case .frost:
            CultivationTheme.Colors.statusAlert
        case .heat:
            CultivationTheme.Colors.statusWarning
        case .heavyRain:
            CultivationTheme.Colors.accentSky
        case .drought:
            CultivationTheme.Colors.statusWarning
        case .wind:
            CultivationTheme.Colors.textTertiary
        case .storm:
            CultivationTheme.Colors.statusAlert
        }
    }

    private var alertBackgroundColor: Color {
        switch alert.type {
        case .frost:
            CultivationTheme.Colors.statusAlert.opacity(0.08)
        case .heat:
            CultivationTheme.Colors.statusWarning.opacity(0.08)
        case .heavyRain:
            CultivationTheme.Colors.accentSky.opacity(0.08)
        case .drought:
            CultivationTheme.Colors.statusWarning.opacity(0.08)
        case .wind:
            CultivationTheme.Colors.textTertiary.opacity(0.08)
        case .storm:
            CultivationTheme.Colors.statusAlert.opacity(0.08)
        }
    }
}

#Preview {
    WeatherAlertCard(alert: WeatherAlert(
        type: .frost,
        title: "Frost Warning",
        message: "Temperatures expected to drop below 32°F overnight. Cover sensitive plants.",
        severity: .high,
        expiryDate: Date().addingTimeInterval(86400)
    ))
}
