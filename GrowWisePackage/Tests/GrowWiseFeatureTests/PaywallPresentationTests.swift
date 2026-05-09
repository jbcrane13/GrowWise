import Foundation
import Testing

@Suite("Paywall presentation")
struct PaywallPresentationTests {
    @Test("1.0 paywall comparison does not advertise Pro")
    func onePointZeroPaywallComparisonDoesNotAdvertisePro() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let paywallURL = packageRoot
            .appendingPathComponent("Sources/GrowWiseFeature/Views/PaywallView.swift")
        let contents = try String(contentsOf: paywallURL, encoding: .utf8)

        #expect(!contents.contains("Text(\"Pro\")"))
        #expect(!contents.contains("Expert Consults"))
        #expect(contents.contains("Garden Clubs"))
    }
}
