import SwiftUI

/// Provides the current SwiftUI scene phase as an observable property.
/// Used by `CultivationApp` to detect app activation for activation milestone checks.
@MainActor
@Observable
public final class ScenePhaseProvider {
    public static let shared = ScenePhaseProvider()

    public var scenePhase: ScenePhase = .background

    private init() {}

    /// Call once from the app's root view to start observing scene phase changes.
    /// After calling this, `scenePhase` will be kept up-to-date automatically.
    @MainActor
    public func startObserving() {
        // No-op: actual observation is done via the `.onChange` modifier in GrowWiseApp
        // using this singleton as the source of truth. The modifier keeps `scenePhase` current.
    }
}

extension ScenePhaseProvider {
    /// Updates the scene phase. Called by the `.onChange` modifier in `GrowWiseApp`.
    public func updateScenePhase(_ phase: ScenePhase) {
        self.scenePhase = phase
    }
}