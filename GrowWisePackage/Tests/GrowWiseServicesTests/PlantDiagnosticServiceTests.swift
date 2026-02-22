import XCTest
@testable import GrowWiseServices

final class PlantDiagnosticServiceTests: XCTestCase {
    @MainActor
    func testSummarizeHealthyClassification() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "healthy_leaf", confidence: 0.93),
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.24)
        ])

        XCTAssertEqual(diagnosis.primaryLabel, "healthy_leaf")
        XCTAssertEqual(diagnosis.severity, .healthy)
        XCTAssertTrue(diagnosis.recommendation.contains("No obvious disease"))
    }

    @MainActor
    func testSummarizeHighConfidenceIssue() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.89),
            PlantClassificationCandidate(label: "leaf_rust", confidence: 0.33)
        ])

        XCTAssertEqual(diagnosis.severity, .severe)
        XCTAssertEqual(diagnosis.alternatives.count, 1)
    }

    @MainActor
    func testSummarizeNoCandidates() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([])

        XCTAssertEqual(diagnosis.primaryLabel, "Unknown")
        XCTAssertEqual(diagnosis.severity, .unknown)
    }
}
