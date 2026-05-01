@testable import GrowWiseFeature
import Testing

@MainActor
@Suite("AppRouter")
struct AppRouterTests {
    @Test("Defaults to the home tab")
    func defaultsToHome() {
        let router = AppRouter()
        #expect(router.selectedTab == .home)
    }

    @Test("Honors a custom initial tab")
    func customInitialTab() {
        let router = AppRouter(selectedTab: .club)
        #expect(router.selectedTab == .club)
    }

    @Test("Mutating selectedTab updates the value")
    func mutatesTab() {
        let router = AppRouter()
        router.selectedTab = .garden
        #expect(router.selectedTab == .garden)
        router.selectedTab = .profile
        #expect(router.selectedTab == .profile)
    }
}
