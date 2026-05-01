import SwiftUI

/// Holds top-level tab selection for `MainAppView`.
///
/// Injected into the environment so descendants can switch tabs without
/// threading a `@Binding` down the view tree.
@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: TabSelection

    public init(selectedTab: TabSelection = .home) {
        self.selectedTab = selectedTab
    }
}
