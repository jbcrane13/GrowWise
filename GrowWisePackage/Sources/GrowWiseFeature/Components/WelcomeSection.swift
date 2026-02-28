import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// A reusable welcome section component that displays a time-based greeting
/// and the current user's name.
public struct WelcomeSection: View {
    @Environment(DataService.self) private var dataService

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(welcomeMessage)
                .font(.title2)
                .fontWeight(.semibold)

            if let currentUser = dataService.getCurrentUser() {
                Text(verbatim: "Welcome back, \(currentUser.displayName ?? "Gardener")!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var welcomeMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0 ..< 12:
            return "Good Morning"

        case 12 ..< 17:
            return "Good Afternoon"

        case 17 ..< 21:
            return "Good Evening"

        default:
            return "Good Night"
        }
    }

    private var accessibilityLabel: String {
        var label = welcomeMessage
        if let currentUser = dataService.getCurrentUser() {
            label += ", Welcome back, \(currentUser.displayName ?? "Gardener")"
        }
        return label
    }
}

#Preview {
    WelcomeSection()
        .padding()
}
