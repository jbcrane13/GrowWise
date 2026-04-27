import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        }
        #if canImport(UIKit)
        return Color(UIColor.systemGray5)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
