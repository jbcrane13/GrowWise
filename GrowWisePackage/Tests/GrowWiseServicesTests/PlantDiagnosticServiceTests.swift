@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
struct PlantDiagnosticServiceTests {
    // MARK: - Summarize: Healthy Classification

    @Test("Healthy leaf with high confidence returns healthy severity")
    func summarizeHealthyHighConfidence() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "healthy_leaf", confidence: 0.93),
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.24),
        ])

        #expect(diagnosis.primaryLabel == "healthy_leaf")
        #expect(diagnosis.severity == .healthy)
        #expect(diagnosis.confidence == 0.93)
        #expect(diagnosis.recommendation.contains("No obvious disease"))
        #expect(diagnosis.condition == nil) // "healthy_leaf" is not in the knowledge base
    }

    @Test("Healthy label at low confidence still resolves to healthy via label match")
    func summarizeHealthyLowConfidence() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "healthy", confidence: 0.30),
        ])

        // Label contains "healthy" so severity is .healthy regardless of confidence
        #expect(diagnosis.severity == .healthy)
        #expect(diagnosis.recommendation.contains("No obvious disease"))
    }

    // MARK: - Summarize: Known Conditions from Knowledge Base

    @Test("Powdery mildew at high confidence uses knowledge base severity (.moderate)")
    func summarizeKnownConditionPowderyMildew() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.89),
            PlantClassificationCandidate(label: "leaf_rust", confidence: 0.33),
        ])

        #expect(diagnosis.severity == .moderate)
        #expect(diagnosis.condition != nil)
        #expect(diagnosis.condition?.commonName == "Powdery Mildew")
        #expect(diagnosis.recommendation.contains("Powdery Mildew detected"))
        // Recommendation includes treatment from knowledge base
        #expect(diagnosis.recommendation.contains("Remove and destroy"))
        #expect(diagnosis.alternatives.count == 1)
        #expect(diagnosis.alternatives.first?.label == "leaf_rust")
    }

    @Test("Leaf spot at confident threshold uses knowledge base severity (.mild)")
    func summarizeKnownConditionLeafSpot() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.81),
        ])

        #expect(diagnosis.severity == .mild)
        #expect(diagnosis.condition?.commonName == "Leaf Spot")
        #expect(diagnosis.recommendation.contains("Leaf Spot detected"))
        #expect(diagnosis.alternatives.isEmpty)
    }

    @Test("Known condition below 0.45 confidence ignores knowledge base, uses generic severity")
    func summarizeKnownConditionBelowThreshold() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.30),
        ])

        // Below 0.45 threshold: knowledge base is NOT used for severity
        // Confidence 0.30 < 0.45 => .unknown severity
        #expect(diagnosis.severity == .unknown)
        #expect(diagnosis.recommendation.contains("Low-confidence result"))
    }

    // MARK: - Summarize: Generic Severity Tiers (Unknown Labels)

    @Test("Unknown label at >= 0.85 confidence maps to .severe")
    func summarizeUnknownLabelSevere() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "exotic_fungus_xyz", confidence: 0.90),
        ])

        #expect(diagnosis.severity == .severe)
        #expect(diagnosis.condition == nil) // Not in knowledge base
        #expect(diagnosis.recommendation.contains("Quarantine plant"))
    }

    @Test("Unknown label at >= 0.65 but < 0.85 confidence maps to .moderate")
    func summarizeUnknownLabelModerate() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_disease", confidence: 0.72),
        ])

        #expect(diagnosis.severity == .moderate)
        #expect(diagnosis.recommendation.contains("Remove affected tissue"))
    }

    @Test("Unknown label at >= 0.45 but < 0.65 confidence maps to .mild")
    func summarizeUnknownLabelMild() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_disease", confidence: 0.50),
        ])

        #expect(diagnosis.severity == .mild)
        #expect(diagnosis.recommendation.contains("Isolate affected leaves"))
    }

    @Test("Unknown label below 0.45 confidence maps to .unknown")
    func summarizeUnknownLabelUnknown() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_disease", confidence: 0.20),
        ])

        #expect(diagnosis.severity == .unknown)
        #expect(diagnosis.recommendation.contains("Low-confidence result"))
    }

    // MARK: - Summarize: Empty Input

    @Test("Empty candidates returns Unknown with .unknown severity")
    func summarizeNoCandidates() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([])

        #expect(diagnosis.primaryLabel == "Unknown")
        #expect(diagnosis.confidence == 0)
        #expect(diagnosis.severity == .unknown)
        #expect(diagnosis.recommendation.contains("Retake photo"))
        #expect(diagnosis.alternatives.isEmpty)
        #expect(diagnosis.condition == nil)
    }

    // MARK: - Summarize: Alternatives Capping

    @Test("Alternatives are capped at 3 entries, excluding primary")
    func summarizeAlternativesCappedAtThree() {
        let service = PlantDiagnosticService()
        let candidates = [
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.80),
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.60),
            PlantClassificationCandidate(label: "leaf_rust", confidence: 0.40),
            PlantClassificationCandidate(label: "aphids", confidence: 0.30),
            PlantClassificationCandidate(label: "root_rot", confidence: 0.10),
        ]
        let diagnosis = service.summarize(candidates)

        #expect(diagnosis.primaryLabel == "leaf_spot")
        #expect(diagnosis.alternatives.count == 3)
        // First 3 after primary
        #expect(diagnosis.alternatives[0].label == "powdery_mildew")
        #expect(diagnosis.alternatives[1].label == "leaf_rust")
        #expect(diagnosis.alternatives[2].label == "aphids")
    }

    @Test("Single candidate produces no alternatives")
    func summarizeSingleCandidate() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "leaf_spot", confidence: 0.75),
        ])

        #expect(diagnosis.alternatives.isEmpty)
    }

    // MARK: - Summarize: Confidence Passthrough

    @Test("Primary candidate confidence is passed through to diagnosis")
    func summarizeConfidencePassthrough() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.67),
        ])

        #expect(diagnosis.confidence == 0.67)
    }

    // MARK: - Sample Diagnosis

    @Test("setSampleDiagnosis populates lastDiagnosis with leaf_spot sample")
    func setSampleDiagnosisPopulatesResult() {
        let service = PlantDiagnosticService()

        #expect(service.lastDiagnosis == nil)

        service.setSampleDiagnosis()

        #expect(service.lastDiagnosis != nil)
        #expect(service.lastDiagnosis?.primaryLabel == "leaf_spot")
        #expect(service.lastDiagnosis?.severity == .mild)
        #expect(service.lastDiagnosis?.condition?.commonName == "Leaf Spot")
    }

    // MARK: - Subscription Tier Enforcement

    @Test("Free tier user with no usage can diagnose")
    func canDiagnoseFreeUserNoUsage() {
        let user = User(email: "test@example.com", displayName: "Test")
        // Default: subscriptionTier = .free, aiDiagnosesUsed = 0

        let service = PlantDiagnosticService()
        #expect(service.canDiagnose(user: user) == true)
    }

    @Test("Free tier user remaining diagnoses starts at 3")
    func remainingDiagnosesFreeUserFull() {
        let user = User(email: "test@example.com", displayName: "Test")
        let service = PlantDiagnosticService()

        #expect(service.remainingDiagnoses(user: user) == 3)
    }

    @Test("Free tier user with 2 uses has 1 remaining")
    func remainingDiagnosesFreeUserPartialUsage() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.aiDiagnosesUsed = 2
        user.lastDiagnosisReset = Date()

        let service = PlantDiagnosticService()
        #expect(service.remainingDiagnoses(user: user) == 1)
    }

    @Test("Free tier user at limit cannot diagnose")
    func canDiagnoseFreeUserAtLimit() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.aiDiagnosesUsed = 3
        user.lastDiagnosisReset = Date()

        let service = PlantDiagnosticService()
        #expect(service.canDiagnose(user: user) == false)
        #expect(service.remainingDiagnoses(user: user) == 0)
    }

    @Test("Missing current user reports setup required before image analysis")
    func diagnoseWithMissingCurrentUserRequiresSetup() async {
        let service = PlantDiagnosticService()
        #if canImport(UIKit)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        #elseif canImport(AppKit)
        let image = PlatformImage(size: CGSize(width: 1, height: 1))
        #endif

        await service.diagnose(image: image, currentUser: nil)

        #expect(service.lastDiagnosis == nil)
        #expect(service.isAnalyzing == false)
        #expect(service.lastError?.localizedCaseInsensitiveContains("finish setup") == true)
        #expect(service.lastError?.localizedCaseInsensitiveContains("plant health check") == true)
    }

    @Test("Free tier user exceeding limit is clamped to 0 remaining")
    func remainingDiagnosesFreeUserExceedingLimit() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.aiDiagnosesUsed = 10
        user.lastDiagnosisReset = Date()

        let service = PlantDiagnosticService()
        #expect(service.remainingDiagnoses(user: user) == 0)
    }

    @Test("Premium tier returns -1 (unlimited) remaining diagnoses")
    func remainingDiagnosesPremiumUser() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.subscriptionTier = .premium

        let service = PlantDiagnosticService()
        #expect(service.remainingDiagnoses(user: user) == -1)
        #expect(service.canDiagnose(user: user) == true)
    }

    @Test("Pro tier returns -1 (unlimited) remaining diagnoses")
    func remainingDiagnosesProUser() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.subscriptionTier = .pro

        let service = PlantDiagnosticService()
        #expect(service.remainingDiagnoses(user: user) == -1)
        #expect(service.canDiagnose(user: user) == true)
    }

    @Test("Monthly reset: usage from previous month resets to 0")
    func monthlyResetRestoresQuota() throws {
        let user = User(email: "test@example.com", displayName: "Test")
        user.aiDiagnosesUsed = 3

        // Set lastDiagnosisReset to a previous month
        let calendar = Calendar.current
        let lastMonth = try #require(calendar.date(byAdding: .month, value: -1, to: Date()))
        user.lastDiagnosisReset = lastMonth

        let service = PlantDiagnosticService()
        // Previous month usage is ignored — effective usage is 0
        #expect(service.remainingDiagnoses(user: user) == 3)
        #expect(service.canDiagnose(user: user) == true)
    }

    @Test("No lastDiagnosisReset uses all recorded aiDiagnosesUsed")
    func neverResetUsesAllRecordedUsage() {
        let user = User(email: "test@example.com", displayName: "Test")
        user.aiDiagnosesUsed = 2
        // lastDiagnosisReset is nil — never reset

        let service = PlantDiagnosticService()
        #expect(service.remainingDiagnoses(user: user) == 1)
    }

    // MARK: - PlantDiagnosticError

    @Test("health check limit error includes tier name and limit without diagnosis copy")
    func diagnosisLimitReachedErrorDescription() {
        let error = PlantDiagnosticError.diagnosisLimitReached(remaining: 0, tier: .free)
        let description = error.localizedDescription

        #expect(description.contains("Free"))
        #expect(description.contains("3 per month"))
        #expect(description.contains("Upgrade"))
        #expect(description.localizedCaseInsensitiveContains("plant health check"))
        #expect(!description.localizedCaseInsensitiveContains("diagnosis"))
        #expect(!description.contains("AI"))
    }

    @Test("invalidImage error describes plant health check")
    func invalidImageErrorDescription() {
        let error = PlantDiagnosticError.invalidImage
        #expect(error.localizedDescription.localizedCaseInsensitiveContains("plant health check"))
        #expect(!error.localizedDescription.localizedCaseInsensitiveContains("diagnosis"))
    }

    @Test("noClassification error describes plant health guidance")
    func noClassificationErrorDescription() {
        let error = PlantDiagnosticError.noClassification
        #expect(error.localizedDescription.contains("No plant health guidance"))
        #expect(!error.localizedDescription.localizedCaseInsensitiveContains("diagnosis"))
    }

    // MARK: - Initial State

    @Test("Service initializes with no diagnosis, no error, not analyzing")
    func initialState() {
        let service = PlantDiagnosticService()

        #expect(service.isAnalyzing == false)
        #expect(service.lastDiagnosis == nil)
        #expect(service.lastError == nil)
    }

    // MARK: - Severity Boundary Tests

    @Test("Known condition at exactly 0.45 confidence uses knowledge base severity")
    func summarizeKnownConditionAtExactThreshold() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "powdery_mildew", confidence: 0.45),
        ])

        // At exactly 0.45, knowledge base IS used
        #expect(diagnosis.severity == .moderate)
        #expect(diagnosis.condition != nil)
    }

    @Test("Unknown label at exactly 0.85 maps to .severe")
    func summarizeUnknownAtExactSevereBoundary() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_xyz", confidence: 0.85),
        ])

        #expect(diagnosis.severity == .severe)
    }

    @Test("Unknown label at exactly 0.65 maps to .moderate")
    func summarizeUnknownAtExactModerateBoundary() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_xyz", confidence: 0.65),
        ])

        #expect(diagnosis.severity == .moderate)
    }

    @Test("Unknown label at exactly 0.45 maps to .mild")
    func summarizeUnknownAtExactMildBoundary() {
        let service = PlantDiagnosticService()
        let diagnosis = service.summarize([
            PlantClassificationCandidate(label: "unknown_xyz", confidence: 0.45),
        ])

        #expect(diagnosis.severity == .mild)
    }

    // MARK: - Integration Gaps

    // INTEGRATION GAP: diagnose(image:user:) calls classify() which requires
    // CoreML/Vision runtime with a real image. Cannot unit test the full pipeline
    // without a CoreML model bundle. The classify → summarize flow is covered by
    // testing summarize() directly with synthetic candidates.

    // INTEGRATION GAP: diagnose(image:) (legacy, no user) similarly depends on
    // Vision framework classification. Tested indirectly via summarize().

    // INTEGRATION GAP: Custom CoreML model loading (loadCustomModel/resolveCustomModel)
    // requires a .mlmodelc bundle in the test target. The fallback to generic Vision
    // classifier is architecture-level behavior verified via manual testing.
}
