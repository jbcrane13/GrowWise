import Foundation
@testable import GrowWiseModels
@testable import GrowWiseServices
import Testing

// MARK: - PlantDiseaseKnowledge Tests

struct PlantDiseaseKnowledgeTests {
    // MARK: - Collection Completeness

    @Test("allConditions is not empty")
    func allConditionsNotEmpty() {
        #expect(!PlantDiseaseKnowledge.allConditions.isEmpty)
    }

    @Test("diseases array is not empty")
    func diseasesNotEmpty() {
        #expect(!PlantDiseaseKnowledge.diseases.isEmpty)
    }

    @Test("pests array is not empty")
    func pestsNotEmpty() {
        #expect(!PlantDiseaseKnowledge.pests.isEmpty)
    }

    @Test("deficiencies array is not empty")
    func deficienciesNotEmpty() {
        #expect(!PlantDiseaseKnowledge.deficiencies.isEmpty)
    }

    // MARK: - Dictionary Consistency

    @Test("conditions dictionary count matches allConditions count")
    func conditionsDictionaryCountMatchesAllConditions() {
        #expect(PlantDiseaseKnowledge.conditions.count == PlantDiseaseKnowledge.allConditions.count)
    }

    @Test("conditions dictionary keys match condition labels")
    func conditionsDictionaryKeysMatchLabels() {
        for (key, condition) in PlantDiseaseKnowledge.conditions {
            #expect(key == condition.label, "Dictionary key '\(key)' must match condition label '\(condition.label)'")
        }
    }

    // MARK: - Lookup

    @Test("condition(for:) returns known condition for powdery_mildew")
    func conditionLookupReturnsKnownCondition() {
        let result = PlantDiseaseKnowledge.condition(for: "powdery_mildew")
        #expect(result != nil)
        #expect(result?.label == "powdery_mildew")
        #expect(result?.commonName == "Powdery Mildew")
    }

    @Test("condition(for:) returns nil for unknown label")
    func conditionLookupReturnsNilForUnknownLabel() {
        let result = PlantDiseaseKnowledge.condition(for: "completely_unknown_label_xyz")
        #expect(result == nil)
    }

    @Test("condition(for:) is case-insensitive")
    func conditionLookupIsCaseInsensitive() {
        let lowerResult = PlantDiseaseKnowledge.condition(for: "powdery_mildew")
        let upperResult = PlantDiseaseKnowledge.condition(for: "Powdery_Mildew")
        let mixedResult = PlantDiseaseKnowledge.condition(for: "POWDERY_MILDEW")

        #expect(lowerResult != nil)
        #expect(upperResult != nil)
        #expect(mixedResult != nil)
        #expect(lowerResult == upperResult)
        #expect(lowerResult == mixedResult)
    }

    // MARK: - Data Integrity: Required String Fields

    @Test("Every condition has a non-empty label")
    func everyConditionHasNonEmptyLabel() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.label.isEmpty, "Condition with commonName '\(condition.commonName)' has an empty label")
        }
    }

    @Test("Every condition has a non-empty commonName")
    func everyConditionHasNonEmptyCommonName() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.commonName.isEmpty, "Condition with label '\(condition.label)' has an empty commonName")
        }
    }

    @Test("Every condition has a non-empty description")
    func everyConditionHasNonEmptyDescription() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.description.isEmpty, "Condition '\(condition.label)' has an empty description")
        }
    }

    // MARK: - Data Integrity: Arrays

    @Test("Every condition has at least one symptom")
    func everyConditionHasAtLeastOneSymptom() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.symptoms.isEmpty, "Condition '\(condition.label)' has no symptoms")
        }
    }

    @Test("Every condition has at least one treatment")
    func everyConditionHasAtLeastOneTreatment() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.treatments.isEmpty, "Condition '\(condition.label)' has no treatments")
        }
    }

    @Test("Every condition has at least one prevention tip")
    func everyConditionHasAtLeastOnePreventionTip() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(!condition.prevention.isEmpty, "Condition '\(condition.label)' has no prevention tips")
        }
    }

    // MARK: - Data Integrity: Severity

    @Test("Every condition has a non-unknown severity")
    func everyConditionHasKnownSeverity() {
        for condition in PlantDiseaseKnowledge.allConditions {
            #expect(
                condition.severity != .unknown,
                "Condition '\(condition.label)' has .unknown severity — assign a meaningful severity level"
            )
        }
    }

    // MARK: - Uniqueness

    @Test("All labels in allConditions are unique")
    func allLabelsAreUnique() {
        let labels = PlantDiseaseKnowledge.allConditions.map(\.label)
        let uniqueLabels = Set(labels)
        #expect(
            labels.count == uniqueLabels.count,
            "Duplicate labels found: \(labels.filter { label in labels.count(where: { $0 == label }) > 1 })"
        )
    }
}
