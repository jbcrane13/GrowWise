import SwiftUI

/// Garden tab — grouped plant list hero screen.
/// Full implementation in Phase 3 (Task 6).
public struct GardenView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: "52B788"))
                Text("Garden")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Coming in Phase 3")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Garden")
        }
        .accessibilityIdentifier("garden_view_stub")
    }
}
