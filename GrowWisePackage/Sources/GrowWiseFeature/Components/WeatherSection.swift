import SwiftUI

/// Model representing weather information for display.
public struct WeatherInfo: Sendable {
    public let temperature: Double
    public let humidity: Double
    public let uvIndex: Int
    public let description: String
    public let iconName: String
    public let isGoodForGardening: Bool

    public init(
        temperature: Double,
        humidity: Double,
        uvIndex: Int,
        description: String,
        iconName: String,
        isGoodForGardening: Bool
    ) {
        self.temperature = temperature
        self.humidity = humidity
        self.uvIndex = uvIndex
        self.description = description
        self.iconName = iconName
        self.isGoodForGardening = isGoodForGardening
    }

    public static let sample = WeatherInfo(
        temperature: 72.0,
        humidity: 65.0,
        uvIndex: 5,
        description: "Partly Cloudy",
        iconName: "cloud.sun.fill",
        isGoodForGardening: true
    )
}

/// A reusable weather section component that displays current weather conditions
/// and gardening suitability.
public struct WeatherSection: View {
    let weather: WeatherInfo

    public init(weather: WeatherInfo) {
        self.weather = weather
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weather.iconName)
                    .foregroundColor(.blue)
                Text("Today's Weather")
                    .font(.headline)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("\(Int(weather.temperature))°F")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(weather.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Label("Humidity: \(Int(weather.humidity))%", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("UV Index: \(weather.uvIndex)", systemImage: "sun.max.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if weather.isGoodForGardening {
                Label("Great day for gardening!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weatherAccessibilityLabel)
    }

    private var weatherAccessibilityLabel: String {
        var label = "Today's weather: \(weather.description), \(Int(weather.temperature)) degrees, humidity \(Int(weather.humidity)) percent, UV index \(weather.uvIndex)"
        if weather.isGoodForGardening {
            label += ". Great day for gardening"
        }
        return label
    }
}

#Preview {
    WeatherSection(weather: .sample)
        .padding()
}
