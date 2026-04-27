import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - TutorialContent Static Data Tests

/// Tests for TutorialContent static data and the pure filtering/lookup logic in
/// TutorialService. TutorialService.init requires DataService (which requires a
/// ModelContainer), so service-layer tests that need full DI setup are left as
/// integration tests. All logic below is exercised directly on TutorialContent
/// and the pure methods replicated from TutorialService.
@Suite("TutorialContent Corpus Tests")
struct TutorialContentCorpusTests {

    // MARK: - Collection Integrity

    @Test("getAllTutorials returns non-empty list")
    func testAllTutorialsNonEmpty() {
        let tutorials = TutorialContent.allTutorials
        #expect(!tutorials.isEmpty)
    }

    @Test("getAllTutorials contains at least five tutorials")
    func testAllTutorialsMinimumCount() {
        let tutorials = TutorialContent.allTutorials
        #expect(tutorials.count >= 5)
    }

    @Test("All tutorial IDs are unique — no duplicates")
    func testAllTutorialIDsAreUnique() {
        let tutorials = TutorialContent.allTutorials
        let ids = tutorials.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(uniqueIDs.count == ids.count,
                "Expected \(ids.count) unique IDs but found \(uniqueIDs.count)")
    }

    @Test("All tutorials have non-empty titles")
    func testAllTutorialsHaveNonEmptyTitles() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.title.isEmpty,
                    "Tutorial '\(tutorial.id)' has an empty title")
        }
    }

    @Test("All tutorials have non-empty descriptions")
    func testAllTutorialsHaveNonEmptyDescriptions() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.description.isEmpty,
                    "Tutorial '\(tutorial.id)' has an empty description")
        }
    }

    @Test("All tutorials have at least one step")
    func testAllTutorialsHaveAtLeastOneStep() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.steps.isEmpty,
                    "Tutorial '\(tutorial.id)' has no steps")
        }
    }

    @Test("All tutorial steps have non-empty titles and content")
    func testAllStepsHaveNonEmptyContent() {
        for tutorial in TutorialContent.allTutorials {
            for (index, step) in tutorial.steps.enumerated() {
                #expect(!step.title.isEmpty,
                        "Tutorial '\(tutorial.id)' step \(index) has empty title")
                #expect(!step.content.isEmpty,
                        "Tutorial '\(tutorial.id)' step \(index) has empty content")
            }
        }
    }

    @Test("All tutorial steps have positive duration")
    func testAllStepsHavePositiveDuration() {
        for tutorial in TutorialContent.allTutorials {
            for (index, step) in tutorial.steps.enumerated() {
                #expect(step.duration > 0,
                        "Tutorial '\(tutorial.id)' step \(index) has zero/negative duration")
            }
        }
    }

    @Test("All tutorial estimated durations are positive")
    func testAllTutorialsHavePositiveDuration() {
        for tutorial in TutorialContent.allTutorials {
            #expect(tutorial.estimatedDuration > 0,
                    "Tutorial '\(tutorial.id)' has zero/negative estimatedDuration")
        }
    }

    // MARK: - Category Coverage

    @Test("Tutorials span all five expected categories")
    func testAllCategoriesRepresented() {
        let tutorials = TutorialContent.allTutorials
        let presentCategories = Set(tutorials.map(\.category))
        let expectedCategories: Set<TutorialCategory> = [
            .planning, .preparation, .care, .environment, .problemSolving
        ]
        for category in expectedCategories {
            #expect(presentCategories.contains(category),
                    "No tutorial found for category '\(category.rawValue)'")
        }
    }

    @Test("Planning category contains at least one tutorial")
    func testPlanningCategoryHasTutorials() {
        let count = TutorialContent.allTutorials.filter { $0.category == .planning }.count
        #expect(count >= 1)
    }

    @Test("Preparation category contains at least one tutorial")
    func testPreparationCategoryHasTutorials() {
        let count = TutorialContent.allTutorials.filter { $0.category == .preparation }.count
        #expect(count >= 1)
    }

    @Test("Care category contains at least one tutorial")
    func testCareCategoryHasTutorials() {
        let count = TutorialContent.allTutorials.filter { $0.category == .care }.count
        #expect(count >= 1)
    }

    @Test("Environment category contains at least one tutorial")
    func testEnvironmentCategoryHasTutorials() {
        let count = TutorialContent.allTutorials.filter { $0.category == .environment }.count
        #expect(count >= 1)
    }

    @Test("ProblemSolving category contains at least one tutorial")
    func testProblemSolvingCategoryHasTutorials() {
        let count = TutorialContent.allTutorials.filter { $0.category == .problemSolving }.count
        #expect(count >= 1)
    }
}

// MARK: - TutorialCategory Display Names

@Suite("TutorialCategory Display Name Tests")
struct TutorialCategoryDisplayNameTests {

    @Test("Planning category display name is correct")
    func testPlanningDisplayName() {
        #expect(TutorialCategory.planning.displayName == "Garden Planning")
    }

    @Test("Preparation category display name is correct")
    func testPreparationDisplayName() {
        #expect(TutorialCategory.preparation.displayName == "Soil & Setup")
    }

    @Test("Care category display name is correct")
    func testCareDisplayName() {
        #expect(TutorialCategory.care.displayName == "Plant Care")
    }

    @Test("Environment category display name is correct")
    func testEnvironmentDisplayName() {
        #expect(TutorialCategory.environment.displayName == "Environment")
    }

    @Test("ProblemSolving category display name is correct")
    func testProblemSolvingDisplayName() {
        #expect(TutorialCategory.problemSolving.displayName == "Problem Solving")
    }

    @Test("All TutorialCategory cases have non-empty display names")
    func testAllCategoriesHaveDisplayNames() {
        for category in TutorialCategory.allCases {
            #expect(!category.displayName.isEmpty,
                    "Category '\(category.rawValue)' has an empty displayName")
        }
    }
}

// MARK: - Lookup Logic (replicating getTutorial(by:))

@Suite("Tutorial Lookup Logic Tests")
struct TutorialLookupLogicTests {

    private func getTutorial(by id: String) -> TutorialTopic? {
        TutorialContent.allTutorials.first { $0.id == id }
    }

    @Test("getTutorial returns correct tutorial for known ID: getting-started-indoor-plants")
    func testGetTutorialByKnownIDGettingStarted() {
        let tutorial = getTutorial(by: "getting-started-indoor-plants")
        #expect(tutorial != nil)
        #expect(tutorial?.id == "getting-started-indoor-plants")
        #expect(tutorial?.title == "Getting Started with Indoor Plants")
    }

    @Test("getTutorial returns correct tutorial for known ID: watering-correctly")
    func testGetTutorialByKnownIDWatering() {
        let tutorial = getTutorial(by: "watering-correctly")
        #expect(tutorial != nil)
        #expect(tutorial?.category == .care)
    }

    @Test("getTutorial returns correct tutorial for known ID: light-requirements")
    func testGetTutorialByKnownIDLight() {
        let tutorial = getTutorial(by: "light-requirements")
        #expect(tutorial != nil)
        #expect(tutorial?.category == .environment)
    }

    @Test("getTutorial returns correct tutorial for known ID: soil-fertilizing-basics")
    func testGetTutorialByKnownIDSoil() {
        let tutorial = getTutorial(by: "soil-fertilizing-basics")
        #expect(tutorial != nil)
        #expect(tutorial?.category == .preparation)
    }

    @Test("getTutorial returns correct tutorial for known ID: plant-problems-solutions")
    func testGetTutorialByKnownIDProblems() {
        let tutorial = getTutorial(by: "plant-problems-solutions")
        #expect(tutorial != nil)
        #expect(tutorial?.category == .problemSolving)
    }

    @Test("getTutorial returns nil for nonexistent ID")
    func testGetTutorialByNonexistentIDReturnsNil() {
        let tutorial = getTutorial(by: "this-id-does-not-exist")
        #expect(tutorial == nil)
    }

    @Test("getTutorial returns nil for empty string ID")
    func testGetTutorialByEmptyIDReturnsNil() {
        let tutorial = getTutorial(by: "")
        #expect(tutorial == nil)
    }

    @Test("getTutorial returns nil for whitespace-only ID")
    func testGetTutorialByWhitespaceIDReturnsNil() {
        let tutorial = getTutorial(by: "   ")
        #expect(tutorial == nil)
    }

    @Test("All known tutorial IDs resolve to non-nil tutorials")
    func testAllKnownIDsResolve() {
        for tutorial in TutorialContent.allTutorials {
            let found = getTutorial(by: tutorial.id)
            #expect(found != nil, "ID '\(tutorial.id)' failed to resolve")
            #expect(found?.id == tutorial.id)
        }
    }
}

// MARK: - Skill Level Filtering Logic (replicating getTutorialsForSkillLevel)

@Suite("Tutorial Skill Level Filter Tests")
struct TutorialSkillLevelFilterTests {

    private func getTutorialsForSkillLevel(_ skillLevel: GardeningSkillLevel) -> [TutorialTopic] {
        TutorialContent.allTutorials.filter { tutorial in
            switch skillLevel {
            case .beginner:
                return tutorial.difficultyLevel == .beginner
            case .intermediate:
                return tutorial.difficultyLevel == .beginner || tutorial.difficultyLevel == .intermediate
            case .advanced, .expert:
                return true
            }
        }
    }

    @Test("Beginner filter returns only beginner-difficulty tutorials")
    func testBeginnerFilterReturnsOnlyBeginnerTutorials() {
        let results = getTutorialsForSkillLevel(.beginner)
        for tutorial in results {
            #expect(tutorial.difficultyLevel == .beginner,
                    "Tutorial '\(tutorial.id)' is not beginner-level but was returned for beginner filter")
        }
    }

    @Test("Beginner filter is non-empty (corpus has beginner tutorials)")
    func testBeginnerFilterIsNonEmpty() {
        let results = getTutorialsForSkillLevel(.beginner)
        #expect(!results.isEmpty)
    }

    @Test("Intermediate filter includes beginner tutorials")
    func testIntermediateFilterIncludesBeginner() {
        let beginnerResults = getTutorialsForSkillLevel(.beginner)
        let intermediateResults = getTutorialsForSkillLevel(.intermediate)
        // Every beginner tutorial must appear in intermediate results
        for tutorial in beginnerResults {
            #expect(intermediateResults.contains { $0.id == tutorial.id },
                    "Beginner tutorial '\(tutorial.id)' missing from intermediate results")
        }
    }

    @Test("Intermediate filter is a superset of beginner filter")
    func testIntermediateIsSupersetOfBeginner() {
        let beginnerCount = getTutorialsForSkillLevel(.beginner).count
        let intermediateCount = getTutorialsForSkillLevel(.intermediate).count
        #expect(intermediateCount >= beginnerCount)
    }

    @Test("Advanced filter returns all tutorials")
    func testAdvancedFilterReturnsAll() {
        let allCount = TutorialContent.allTutorials.count
        let advancedCount = getTutorialsForSkillLevel(.advanced).count
        #expect(advancedCount == allCount)
    }

    @Test("Expert filter returns all tutorials")
    func testExpertFilterReturnsAll() {
        let allCount = TutorialContent.allTutorials.count
        let expertCount = getTutorialsForSkillLevel(.expert).count
        #expect(expertCount == allCount)
    }

    @Test("Advanced and expert filters produce identical results")
    func testAdvancedAndExpertFiltersMatch() {
        let advancedIDs = Set(getTutorialsForSkillLevel(.advanced).map(\.id))
        let expertIDs = Set(getTutorialsForSkillLevel(.expert).map(\.id))
        #expect(advancedIDs == expertIDs)
    }

    @Test("Beginner filter result is subset of intermediate filter result")
    func testBeginnerIsSubsetOfIntermediate() {
        let beginnerIDs = Set(getTutorialsForSkillLevel(.beginner).map(\.id))
        let intermediateIDs = Set(getTutorialsForSkillLevel(.intermediate).map(\.id))
        #expect(beginnerIDs.isSubset(of: intermediateIDs))
    }

    @Test("Intermediate filter result is subset of advanced filter result")
    func testIntermediateIsSubsetOfAdvanced() {
        let intermediateIDs = Set(getTutorialsForSkillLevel(.intermediate).map(\.id))
        let advancedIDs = Set(getTutorialsForSkillLevel(.advanced).map(\.id))
        #expect(intermediateIDs.isSubset(of: advancedIDs))
    }
}

// MARK: - getRecommendedTutorials Logic (replicated pure logic)

@Suite("Tutorial Recommendation Logic Tests")
struct TutorialRecommendationLogicTests {

    /// Replicates the pure recommendation logic from TutorialService.getRecommendedTutorials.
    /// The service uses a hardcoded "container" gardenType; we test the same logic here.
    private func getRecommendedTutorials(skillLevel: GardeningSkillLevel) -> [TutorialTopic] {
        let gardenType = "container" // matches hardcoded value in TutorialService
        let filtered = TutorialContent.allTutorials.filter { tutorial in
            switch skillLevel {
            case .beginner:
                return tutorial.difficultyLevel == .beginner
            case .intermediate:
                return tutorial.difficultyLevel == .beginner || tutorial.difficultyLevel == .intermediate
            case .advanced, .expert:
                return true
            }
        }
        return filtered
            .filter { $0.relevantGardenTypes.contains(gardenType) || $0.relevantGardenTypes.contains("all") }
            .sorted { $0.estimatedDuration < $1.estimatedDuration }
    }

    @Test("Recommended tutorials for beginner are a subset of all tutorials")
    func testBeginnerRecommendationsAreSubsetOfAll() {
        let all = Set(TutorialContent.allTutorials.map(\.id))
        let recommended = Set(getRecommendedTutorials(skillLevel: .beginner).map(\.id))
        #expect(recommended.isSubset(of: all))
    }

    @Test("Recommended tutorials are sorted by estimatedDuration ascending")
    func testRecommendedTutorialsSortedByDuration() {
        for skillLevel in GardeningSkillLevel.allCases {
            let recommended = getRecommendedTutorials(skillLevel: skillLevel)
            let durations = recommended.map(\.estimatedDuration)
            let sorted = durations.sorted()
            #expect(durations == sorted,
                    "Recommended tutorials for \(skillLevel) are not sorted by duration ascending")
        }
    }

    @Test("Recommended tutorials contain only tutorials relevant to 'container' or 'all' garden types")
    func testRecommendedTutorialsRelevantGardenTypes() {
        for skillLevel in GardeningSkillLevel.allCases {
            let recommended = getRecommendedTutorials(skillLevel: skillLevel)
            for tutorial in recommended {
                let isRelevant = tutorial.relevantGardenTypes.contains("container")
                    || tutorial.relevantGardenTypes.contains("all")
                #expect(isRelevant,
                        "Tutorial '\(tutorial.id)' is not relevant to 'container' or 'all' garden types")
            }
        }
    }

    @Test("getRecommendedTutorials for advanced returns non-empty list")
    func testAdvancedRecommendationsNonEmpty() {
        let recommended = getRecommendedTutorials(skillLevel: .advanced)
        #expect(!recommended.isEmpty)
    }
}

// MARK: - TutorialProgress Logic

@Suite("TutorialProgress Logic Tests")
struct TutorialProgressLogicTests {

    @Test("progressPercentage is 0 when totalSteps is 0")
    func testProgressPercentageZeroTotalSteps() {
        let progress = TutorialProgress(
            tutorialId: "test", completedSteps: 0, totalSteps: 0, isCompleted: false
        )
        #expect(progress.progressPercentage == 0)
    }

    @Test("progressPercentage is 100 when all steps completed")
    func testProgressPercentageAllCompleted() {
        let progress = TutorialProgress(
            tutorialId: "test", completedSteps: 4, totalSteps: 4, isCompleted: true
        )
        #expect(progress.progressPercentage == 100.0)
    }

    @Test("progressPercentage is 50 when half steps completed")
    func testProgressPercentageHalfCompleted() {
        let progress = TutorialProgress(
            tutorialId: "test", completedSteps: 2, totalSteps: 4, isCompleted: false
        )
        #expect(progress.progressPercentage == 50.0)
    }

    @Test("progressPercentage is 0 when no steps completed")
    func testProgressPercentageNoneCompleted() {
        let progress = TutorialProgress(
            tutorialId: "test", completedSteps: 0, totalSteps: 4, isCompleted: false
        )
        #expect(progress.progressPercentage == 0.0)
    }

    @Test("isCompleted reflects constructor argument correctly")
    func testIsCompletedFlag() {
        let completed = TutorialProgress(tutorialId: "t1", completedSteps: 4, totalSteps: 4, isCompleted: true)
        let notCompleted = TutorialProgress(tutorialId: "t2", completedSteps: 2, totalSteps: 4, isCompleted: false)
        #expect(completed.isCompleted == true)
        #expect(notCompleted.isCompleted == false)
    }

    @Test("progressPercentage for unknown tutorial ID returns 0")
    func testProgressForUnknownTutorialID() {
        // Mirrors the getTutorialProgress guard-else path in TutorialService
        let progress = TutorialProgress(
            tutorialId: "nonexistent-id", completedSteps: 0, totalSteps: 0, isCompleted: false
        )
        #expect(progress.progressPercentage == 0.0)
    }
}

// MARK: - TutorialAnalytics Logic

@Suite("TutorialAnalytics Logic Tests")
struct TutorialAnalyticsLogicTests {

    @Test("completionRate is 0 when totalSteps is 0")
    func testCompletionRateZeroTotalSteps() {
        let analytics = TutorialAnalytics(
            totalTutorials: 0, completedTutorials: 0,
            totalSteps: 0, completedSteps: 0, completionRate: 0
        )
        #expect(analytics.completionRate == 0.0)
    }

    @Test("completionRate of 1.0 represents full completion")
    func testCompletionRateFull() {
        let totalSteps = 20
        let completedSteps = 20
        let rate = totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
        let analytics = TutorialAnalytics(
            totalTutorials: 5, completedTutorials: 5,
            totalSteps: totalSteps, completedSteps: completedSteps, completionRate: rate
        )
        #expect(analytics.completionRate == 1.0)
    }

    @Test("completionRate of 0.5 represents half completion")
    func testCompletionRateHalf() {
        let totalSteps = 20
        let completedSteps = 10
        let rate = Double(completedSteps) / Double(totalSteps)
        let analytics = TutorialAnalytics(
            totalTutorials: 5, completedTutorials: 2,
            totalSteps: totalSteps, completedSteps: completedSteps, completionRate: rate
        )
        #expect(analytics.completionRate == 0.5)
    }

    @Test("totalTutorials matches TutorialContent.allTutorials count when fresh")
    func testTotalTutorialsMatchesCorpus() {
        let expected = TutorialContent.allTutorials.count
        let analytics = TutorialAnalytics(
            totalTutorials: expected, completedTutorials: 0,
            totalSteps: 0, completedSteps: 0, completionRate: 0
        )
        #expect(analytics.totalTutorials == expected)
    }

    @Test("totalSteps equals sum of all tutorial steps in corpus")
    func testTotalStepsSumMatchesCorpus() {
        let expected = TutorialContent.allTutorials.reduce(0) { $0 + $1.steps.count }
        #expect(expected > 0)
        let analytics = TutorialAnalytics(
            totalTutorials: TutorialContent.allTutorials.count, completedTutorials: 0,
            totalSteps: expected, completedSteps: 0, completionRate: 0
        )
        #expect(analytics.totalSteps == expected)
    }
}

// MARK: - TutorialTopic and TutorialStep Model Tests

@Suite("TutorialTopic and TutorialStep Model Tests")
struct TutorialTopicModelTests {

    @Test("TutorialStep IDs are unique within a tutorial")
    func testStepIDsUniqueWithinTutorial() {
        for tutorial in TutorialContent.allTutorials {
            let stepIDs = tutorial.steps.map(\.id)
            let uniqueIDs = Set(stepIDs)
            #expect(uniqueIDs.count == stepIDs.count,
                    "Tutorial '\(tutorial.id)' has duplicate step IDs")
        }
    }

    @Test("TutorialStep tips arrays are non-nil (may be empty)")
    func testStepTipsArrayExists() {
        // Tips is a [String], so it's always non-nil; verify at least one tutorial has tips
        let tutorialsWithTips = TutorialContent.allTutorials.filter { tutorial in
            tutorial.steps.contains { !$0.tips.isEmpty }
        }
        #expect(!tutorialsWithTips.isEmpty)
    }

    @Test("TutorialStep commonMistakes arrays are non-nil (may be empty)")
    func testStepCommonMistakesArrayExists() {
        let tutorialsWithMistakes = TutorialContent.allTutorials.filter { tutorial in
            tutorial.steps.contains { !$0.commonMistakes.isEmpty }
        }
        #expect(!tutorialsWithMistakes.isEmpty)
    }

    @Test("All relevantGardenTypes arrays are non-empty")
    func testRelevantGardenTypesNonEmpty() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.relevantGardenTypes.isEmpty,
                    "Tutorial '\(tutorial.id)' has no relevantGardenTypes")
        }
    }

    @Test("All tutorials define imageURL (non-empty)")
    func testAllTutorialsHaveImageURL() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.imageURL.isEmpty,
                    "Tutorial '\(tutorial.id)' has empty imageURL")
        }
    }

    @Test("TutorialTopic is Hashable — equal topics hash equally")
    func testTutorialTopicHashable() {
        let t1 = TutorialContent.allTutorials[0]
        let t2 = TutorialContent.allTutorials[0]
        // Same value-type content, must produce same hash
        var set = Set<TutorialTopic>()
        set.insert(t1)
        set.insert(t2)
        #expect(set.count == 1)
    }

    @Test("TutorialTopic subtitle is non-empty")
    func testAllTutorialsHaveSubtitles() {
        for tutorial in TutorialContent.allTutorials {
            #expect(!tutorial.subtitle.isEmpty,
                    "Tutorial '\(tutorial.id)' has empty subtitle")
        }
    }
}
