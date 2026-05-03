import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable cyclomatic_complexity
#endif

public enum SystemColorToken {
    case systemBackground
    case secondarySystemBackground
    case tertiarySystemBackground
    case systemGroupedBackground
    case secondarySystemGroupedBackground
    case tertiarySystemGroupedBackground
    case systemGray4
    case systemGray5
    case systemGray6
    case quaternaryLabel
}

public extension Color {
    init(_ token: SystemColorToken) {
        #if canImport(UIKit)
        switch token {
        case .systemBackground:
            self.init(uiColor: .systemBackground)

        case .secondarySystemBackground:
            self.init(uiColor: .secondarySystemBackground)

        case .tertiarySystemBackground:
            self.init(uiColor: .tertiarySystemBackground)

        case .systemGroupedBackground:
            self.init(uiColor: .systemGroupedBackground)

        case .secondarySystemGroupedBackground:
            self.init(uiColor: .secondarySystemGroupedBackground)

        case .tertiarySystemGroupedBackground:
            self.init(uiColor: .tertiarySystemGroupedBackground)

        case .systemGray4:
            self.init(uiColor: .systemGray4)

        case .systemGray5:
            self.init(uiColor: .systemGray5)

        case .systemGray6:
            self.init(uiColor: .systemGray6)

        case .quaternaryLabel:
            self.init(uiColor: .quaternaryLabel)
        }
        #elseif canImport(AppKit)
        switch token {
        case .systemBackground, .systemGroupedBackground:
            self.init(nsColor: .windowBackgroundColor)

        case .secondarySystemBackground, .secondarySystemGroupedBackground:
            self.init(nsColor: .underPageBackgroundColor)

        case .tertiarySystemBackground, .tertiarySystemGroupedBackground:
            self.init(nsColor: .controlBackgroundColor)

        case .systemGray4:
            self = .gray.opacity(0.40)

        case .systemGray5:
            self = .gray.opacity(0.30)

        case .systemGray6:
            self = .gray.opacity(0.20)

        case .quaternaryLabel:
            self = .secondary.opacity(0.45)
        }
        #else
        self = .gray
        #endif
    }
}

public enum GWNavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

public enum GWPageIndexDisplayMode {
    case automatic
    case always
    case never
}

public enum GWTextInputAutocapitalization {
    case none
    case words
    case sentences
    case characters
}

public extension View {
    @ViewBuilder
    func gwNavigationBarTitleDisplayMode(_ displayMode: GWNavigationBarTitleDisplayMode) -> some View {
        #if os(iOS)
        switch displayMode {
        case .automatic:
            self.navigationBarTitleDisplayMode(.automatic)

        case .inline:
            self.navigationBarTitleDisplayMode(.inline)

        case .large:
            self.navigationBarTitleDisplayMode(.large)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func gwNavigationBarHidden(_ hidden: Bool) -> some View {
        #if os(iOS)
        navigationBarHidden(hidden)
        #else
        self
        #endif
    }

    @ViewBuilder
    func gwWheelPickerStyle() -> some View {
        #if os(iOS)
        pickerStyle(.wheel)
        #else
        pickerStyle(.menu)
        #endif
    }

    @ViewBuilder
    func gwPagingTabStyle(indexDisplayMode: GWPageIndexDisplayMode = .never) -> some View {
        #if os(iOS)
        switch indexDisplayMode {
        case .automatic:
            self.tabViewStyle(.page(indexDisplayMode: .automatic))

        case .always:
            self.tabViewStyle(.page(indexDisplayMode: .always))

        case .never:
            self.tabViewStyle(.page(indexDisplayMode: .never))
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func gwTextInputAutocapitalization(_ style: GWTextInputAutocapitalization) -> some View {
        #if os(iOS)
        switch style {
        case .none:
            self.textInputAutocapitalization(.never)

        case .words:
            self.textInputAutocapitalization(.words)

        case .sentences:
            self.textInputAutocapitalization(.sentences)

        case .characters:
            self.textInputAutocapitalization(.characters)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func gwWheelDatePickerStyle() -> some View {
        #if os(iOS)
        datePickerStyle(.wheel)
        #else
        datePickerStyle(.automatic)
        #endif
    }
}

#if os(macOS)
public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle {
        case light
        case medium
    }

    public init(style: FeedbackStyle) {}
    public func impactOccurred() {}
}

@MainActor
public final class UIApplication {
    public static let shared = UIApplication()
    public static let openSettingsURLString = "x-apple.systempreferences:"

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
#endif

// swiftlint:enable cyclomatic_complexity
