import GrowWiseModels

/// Resolve ambiguity between GrowWiseModels.User and Sentry's NS_SWIFT_NAME(User).
/// All GrowWiseServices code uses GrowWiseModels.User unless explicitly qualified.
public typealias User = GrowWiseModels.User
