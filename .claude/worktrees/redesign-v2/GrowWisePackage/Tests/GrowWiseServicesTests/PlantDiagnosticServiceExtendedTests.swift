import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - PlantDiagnosticService Extended Tests

@MainActor
struct PlantDiagnosticServiceExtendedTests {
    // MARK: - Helpers

    private func makeService() -> PlantDiagnosticService {
        PlantDiagnosticService()
    }

    /// Returns both the DataService and User. Callers MUST retain the DataService for the
    /// lifetime of the test — releasing it destroys the ModelContext and invalidates the User.
    private func makeUserWithContext(
        tier: SubscriptionTier = .free,
        diagnosesUsed: Int = 0,
        lastReset: Date? = Date()
    ) throws -> (dataService: DataService, user: User) {
        let dataService = try DataService.makeForTesting()
        let user = try dataService.createUser(
            email: "diagtest@growwise.test",
            displayName: "Diag Tester",
            skillLevel: .beginner
        )
        user.subscriptionTier = tier
        user.aiDiagnosesUsed = diagnosesUsed
        user.lastDiagnosisReset = lastReset
        return (dataService, user)
    }

    // MARK: - summarize: Confidence Thresholds

    @Test("Low confidence with unknown label produces .unknown severity")
    func summarizeLowConfidenceUnknownLabelProducesUnknownSeverity() {
        let service = makeService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_condition_xyz", confidence: 0.30),
        ])

        #expect(diagnosis.severity == .unknown)
        #expect(diagnosis.primaryLabel == "unknown_condition_xyz")
    }

    @Test("Medium confidence with known label uses knowledge base severity")
    func summarizeMediumConfidenceKnownLabelUsesKnowledgeBaseSeverity() {
        let service = makeService()
        // leaf_spot has .mild severity in the knowledge base
        // confidence 0.55 is in the 0.45-0.65 medium range but known label takes precedence
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.55),
        ])

        #expect(diagnosis.severity == .mild) // knowledge base severity for leaf_spot
        #expect(diagnosis.condition != nil)
        #expect(diagnosis.condition?.label == "leaf_spot")
    }

    @Test("High confidence with unknown label returns .severe severity")
    func summarizeHighConfidenceUnknownLabelReturnsSevere() {
        let service = makeService()
        // Confidence >= 0.85 with no knowledge base entry falls through to .severe
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "totally_unknown_disease_xyz", confidence: 0.90),
        ])

        #expect(diagnosis.severity == .severe)
        #expect(diagnosis.condition == nil)
    }

    @Test("Known label with high confidence includes condition info and treatment-based recommendation")
    func summarizeKnownLabelHighConfidenceIncludesConditionAndTreatmentRecommendation() {
        let service = makeService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.92),
        ])

        #expect(diagnosis.condition != nil)
        #expect(diagnosis.condition?.commonName == "Powdery Mildew")
        // Recommendation should include the common name and at least one treatment
        #expect(diagnosis.recommendation.contains("Powdery Mildew"))
        // Should reference treatment steps, not a generic fallback message
        #expect(!diagnosis.recommendation.contains("Retake photo"))
    }

    // MARK: - summarize: Alternatives

    @Test("Alternatives are limited to 3 entries")
    func summarizeAlternativesLimitedToThree() {
        let service = makeService()
        let candidates = [
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.80),
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.50),
            PlantClassificationCandidate(label: "rust", confidence: 0.40),
            PlantClassificationCandidate(label: "aphids", confidence: 0.30),
            PlantClassificationCandidate(label: "root_rot", confidence: 0.20),
        ]
        let diagnosis = service.summarize(candidates)

        #expect(diagnosis.alternatives.count <= 3)
    }

    @Test("Alternatives exclude the primary candidate")
    func summarizeAlternativesExcludePrimaryCandidate() {
        let service = makeService()
        let candidates = [
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.80),
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.50),
            PlantClassificationCandidate(label: "rust", confidence: 0.40),
        ]
        let diagnosis = service.summarize(candidates)

        let alternativeLabels = diagnosis.alternatives.map(\.label)
        #expect(!alternativeLabels.contains("powdery_mildew"))
    }

    @Test("Alternatives with exactly 4 candidates yields 3 alternatives")
    func summarizeAlternativesWithFourCandidatesYieldsThree() {
        let service = makeService()
        let candidates = [
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.80),
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.50),
            PlantClassificationCandidate(label: "rust", confidence: 0.40),
            PlantClassificationCandidate(label: "aphids", confidence: 0.30),
        ]
        let diagnosis = service.summarize(candidates)

        #expect(diagnosis.alternatives.count == 3)
    }

    // MARK: - canDiagnose / remainingDiagnoses

    @Test("Free tier user with 0 uses can diagnose")
    func freeTierUserWithZeroUsesCanDiagnose() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .free, diagnosesUsed: 0)
        _ = dataService // retain to keep ModelContext alive

        #expect(diagnosticService.canDiagnose(user: user) == true)
        #expect(diagnosticService.remainingDiagnoses(user: user) == 3)
    }

    @Test("Free tier user at limit (3 uses) cannot diagnose")
    func freeTierUserAtLimitCannotDiagnose() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .free, diagnosesUsed: 3)
        _ = dataService

        #expect(diagnosticService.canDiagnose(user: user) == false)
        #expect(diagnosticService.remainingDiagnoses(user: user) == 0)
    }

    @Test("Free tier user with 2 uses has 1 remaining diagnosis")
    func freeTierUserWithTwoUsesHasOneRemaining() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .free, diagnosesUsed: 2)
        _ = dataService

        #expect(diagnosticService.canDiagnose(user: user) == true)
        #expect(diagnosticService.remainingDiagnoses(user: user) == 1)
    }

    @Test("Premium user always can diagnose and returns -1 (unlimited)")
    func premiumUserAlwaysCanDiagnose() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .premium, diagnosesUsed: 100)
        _ = dataService

        #expect(diagnosticService.canDiagnose(user: user) == true)
        #expect(diagnosticService.remainingDiagnoses(user: user) == -1)
    }

    @Test("Pro user always can diagnose and returns -1 (unlimited)")
    func proUserAlwaysCanDiagnose() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .pro, diagnosesUsed: 50)
        _ = dataService

        #expect(diagnosticService.canDiagnose(user: user) == true)
        #expect(diagnosticService.remainingDiagnoses(user: user) == -1)
    }

    @Test("Monthly reset: user with uses from previous month gets full quota")
    func monthlyResetAllowsFullQuotaAfterNewMonth() throws {
        let diagnosticService = makeService()
        // Set lastReset to a date in a prior month
        let pastMonth = try #require(Calendar.current.date(byAdding: .month, value: -1, to: Date()))
        let (dataService, user) = try makeUserWithContext(tier: .free, diagnosesUsed: 3, lastReset: pastMonth)
        _ = dataService

        // Even though aiDiagnosesUsed == 3, it was set last month, so effectively 0 used this month
        #expect(diagnosticService.canDiagnose(user: user) == true)
        #expect(diagnosticService.remainingDiagnoses(user: user) == 3)
    }

    @Test("User with nil lastDiagnosisReset counts all recorded uses against quota")
    func nilLastResetCountsAllUsesAgainstQuota() throws {
        let diagnosticService = makeService()
        let (dataService, user) = try makeUserWithContext(tier: .free, diagnosesUsed: 3, lastReset: nil)
        _ = dataService

        // No reset date means we can't confirm a month boundary — all uses count
        #expect(diagnosticService.canDiagnose(user: user) == false)
        #expect(diagnosticService.remainingDiagnoses(user: user) == 0)
    }

    // MARK: - setSampleDiagnosis

    @Test("setSampleDiagnosis sets lastDiagnosis to a non-nil value")
    func setSampleDiagnosisSetsLastDiagnosis() {
        let service = makeService()
        #expect(service.lastDiagnosis == nil)

        service.setSampleDiagnosis()

        #expect(service.lastDiagnosis != nil)
    }

    @Test("setSampleDiagnosis sets primaryLabel to leaf_spot")
    func setSampleDiagnosisSetsLeafSpotAsPrimary() {
        let service = makeService()
        service.setSampleDiagnosis()

        #expect(service.lastDiagnosis?.primaryLabel == "leaf_spot")
    }

    @Test("setSampleDiagnosis produces a diagnosis with a known condition attached")
    func setSampleDiagnosisProducesDiagnosisWithKnownCondition() {
        let service = makeService()
        service.setSampleDiagnosis()

        #expect(service.lastDiagnosis?.condition != nil)
        #expect(service.lastDiagnosis?.condition?.commonName == "Leaf Spot")
    }

    @Test("setSampleDiagnosis produces diagnosis with at least one alternative")
    func setSampleDiagnosisProducesAlternatives() {
        let service = makeService()
        service.setSampleDiagnosis()

        // powdery_mildew (0.42 confidence) should appear in alternatives
        let alternatives = service.lastDiagnosis?.alternatives ?? []
        #expect(!alternatives.isEmpty)
        let alternativeLabels = alternatives.map(\.label)
        #expect(alternativeLabels.contains("powdery_mildew"))
    }

    // MARK: - Initial State

    @Test("New PlantDiagnosticService starts with no diagnosis, no error, not analyzing")
    func initialStateIsClean() {
        let service = makeService()

        #expect(service.lastDiagnosis == nil)
        #expect(service.lastError == nil)
        #expect(service.isAnalyzing == false)
    }
}
