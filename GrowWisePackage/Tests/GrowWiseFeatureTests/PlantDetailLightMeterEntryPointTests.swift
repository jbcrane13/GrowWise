import Foundation
import Testing

@Suite("Plant detail light meter entry point")
struct PlantDetailLightMeterEntryPointTests {
    @Test("Plant detail offers Check light here and presents the light meter")
    func plantDetailPresentsLightMeter() throws {
        let source = try readFeatureSource("Views/MyGardenPlantDetailView.swift")

        #expect(
            source.contains("@State private var showingLightMeter = false"),
            "Plant detail should own local state for the light meter sheet."
        )
        #expect(
            source.contains(".sheet(isPresented: $showingLightMeter)"),
            "Plant detail should present the light meter as a sheet."
        )
        #expect(
            source.contains("LightMeterView()"),
            "Plant detail should reuse the existing LightMeterView utility."
        )
        #expect(
            source.contains("Check light here"),
            "Plant detail should expose a plant-contextual Check light here action."
        )
        #expect(
            source.contains("showingLightMeter = true"),
            "The Check light here action should open the light meter sheet."
        )
        #expect(
            source.contains(".accessibilityIdentifier(\"plantdetail_button_check_light_here\")"),
            "The Check light here action needs a stable accessibility identifier."
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
