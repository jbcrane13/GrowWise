import Foundation
import Testing

@Suite("Plant scanner presentation")
struct PlantScannerPresentationTests {
    @Test("scanner routes photos through tier-aware Plant Health checks")
    func scannerUsesTierAwareDiagnosticPath() throws {
        let source = try readFeatureSource("Views/PlantScannerView.swift")

        #expect(
            source.contains("@Environment(DataService.self)"),
            "PlantScannerView should read the current user through the injected DataService."
        )
        #expect(
            source.contains("dataService.getCurrentUser()"),
            "PlantScannerView should use the persisted user context for health-check limits."
        )
        #expect(
            source.contains("diagnose(image: image, currentUser:"),
            "Photo checks should use the tier-aware diagnostic overload."
        )
        #expect(
            !source.contains("await diagnosticService.diagnose(image: image)\n"),
            "The release scanner should not call the legacy unmetered diagnostic path."
        )
    }

    @Test("scanner does not expose sample guidance controls in release UI")
    func scannerHidesSampleGuidanceControl() throws {
        let source = try readFeatureSource("Views/PlantScannerView.swift")

        #expect(!source.contains("Show Sample Guidance"))
        #expect(!source.contains("scannerRunSampleButton"))
    }

    private func readFeatureSource(_ relativePath: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let sourceURL = packageRoot.appendingPathComponent("Sources/GrowWiseFeature/\(relativePath)")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
