@testable import GrowWiseFeature
@testable import GrowWiseServices
import Testing

@Suite("Public Garden Showcase Presentation")
struct PublicGardenShowcasePresentationTests {
    @Test("Display count compacts large public garden metrics")
    func displayCountCompactsLargeMetrics() {
        #expect(PublicGardenShowcasePresentation.displayCount(0) == "0")
        #expect(PublicGardenShowcasePresentation.displayCount(999) == "999")
        #expect(PublicGardenShowcasePresentation.displayCount(1200) == "1.2K")
        #expect(PublicGardenShowcasePresentation.displayCount(12000) == "12K")
        #expect(PublicGardenShowcasePresentation.displayCount(1_200_000) == "1.2M")
    }

    @Test("Presentation adds optimistic like and accessible summary")
    func presentationAddsOptimisticLikeAndAccessibleSummary() {
        let garden = PublicGarden(
            name: "Rooftop Tomatoes",
            authorName: "Blake",
            gardenType: "Container",
            description: "Six tomato varieties on a sunny roof.",
            likeCount: 1200,
            viewCount: 42
        )

        let presentation = PublicGardenShowcasePresentation(garden: garden, isLiked: true)

        #expect(presentation.likeDisplayCount == "1.2K")
        #expect(presentation.likeAccessibilityLabel == "1,201 likes")
        #expect(presentation.likeAccessibilityValue == "Liked")
        #expect(presentation.likeButtonAccessibilityLabel == "Liked Rooftop Tomatoes")
        #expect(presentation.likeButtonAccessibilityValue == "Liked, 1,201 likes")
        let expectedSummary = "Rooftop Tomatoes by Blake. Container garden. " +
            "Six tomato varieties on a sunny roof. 1,201 likes. 42 views."
        #expect(presentation.cardAccessibilityLabel == expectedSummary)
    }

    @Test("Presentation falls back for missing garden type and blank description")
    func presentationFallsBackForMissingTypeAndBlankDescription() {
        let garden = PublicGarden(
            name: "Tiny Patio",
            authorName: "Avery",
            description: "   ",
            likeCount: 1,
            viewCount: 1
        )

        let presentation = PublicGardenShowcasePresentation(garden: garden, isLiked: false)

        #expect(presentation.typeLabel == "Garden")
        #expect(presentation.descriptionText == nil)
        #expect(presentation.cardAccessibilityLabel == "Tiny Patio by Avery. Garden. 1 like. 1 view.")
    }

    @Test("Presentation sanitizes invalid metrics before display and accessibility output")
    func presentationSanitizesInvalidMetrics() {
        let garden = PublicGarden(
            name: "Pocket Herb Bed",
            authorName: "Sam",
            likeCount: -5,
            viewCount: -10
        )

        let presentation = PublicGardenShowcasePresentation(garden: garden, isLiked: true)

        #expect(presentation.currentLikeCount == 1)
        #expect(presentation.likeDisplayCount == "1")
        #expect(presentation.viewDisplayCount == "0")
        #expect(presentation.likeAccessibilityLabel == "1 like")
        #expect(presentation.viewAccessibilityLabel == "0 views")
    }

    @Test("Presentation caps optimistic like count at integer maximum")
    func presentationCapsOptimisticLikeCount() {
        let garden = PublicGarden(
            name: "Community Orchard",
            authorName: "Mina",
            likeCount: .max
        )

        let presentation = PublicGardenShowcasePresentation(garden: garden, isLiked: true)

        #expect(presentation.currentLikeCount == .max)
    }
}
