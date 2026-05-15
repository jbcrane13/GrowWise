import Foundation
import Testing

@Suite("Perenual experience integration")
struct PerenualExperienceIntegrationTests {
    @Test("Plant detail renders the reusable Perenual encyclopedia card")
    func plantDetailIncludesPerenualEncyclopediaCard() throws {
        let source = try readFeatureSource("Views/MyGardenPlantDetailView.swift")

        #expect(
            source.contains("PerenualEnrichmentCard(plant: plant)"),
            "Plant detail should show the reusable Perenual encyclopedia card for saved plants."
        )
    }

    @Test("Perenual thumbnail awaits async enrichment instead of only checking the cold cache")
    func thumbnailAwaitsAsyncEnrichment() throws {
        let source = try readFeatureSource("Components/PerenualEnrichmentCard.swift")

        #expect(
            source.contains(".task(id: plant.scientificName) {\n            await loadEnrichment()"),
            "Thumbnail should await enrichment work when it appears."
        )
        #expect(
            source.contains("private func loadEnrichment() async"),
            "Thumbnail should use an async loader so cold-cache fetches can update the image."
        )
        #expect(
            source.contains("await enrichment.loadEnrichment(for: plant)"),
            "Thumbnail should use the service async load API instead of a one-shot cache read."
        )
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
