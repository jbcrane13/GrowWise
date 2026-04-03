import Foundation
import SwiftData

@Model
public final class Seed {
    public var id: UUID? = UUID()
    public var varietyName: String?
    public var brand: String?
    public var quantity: Int? = 1
    public var expirationYear: Int?
    public var plantType: PlantType?

    // Growing requirements
    public var sunRequirement: SunExposure?
    public var wateringFrequency: WateringFrequency?
    public var spaceRequirement: SpaceRequirement?
    public var plantingDepthInches: Double?
    public var seedSpacingInches: Double?
    public var daysToGermination: Int?
    public var daysToHarvest: Int?
    public var indoorStartWeeks: Int?

    // Companion planting (fallback when no plant database link)
    public var companionPlants: [String]?
    public var incompatiblePlants: [String]?

    /// Plant database link
    public var plantDatabaseID: String?

    // Metadata
    public var packetPhotoURL: String?
    public var notes: String?
    public var dateAdded: Date?

    // Relationships
    public var garden: Garden?
    public var gardenBed: GardenBed?

    public init(
        varietyName: String,
        plantType: PlantType = .vegetable,
        quantity: Int = 1
    ) {
        id = UUID()
        self.varietyName = varietyName
        self.plantType = plantType
        self.quantity = quantity
        dateAdded = Date()
        companionPlants = []
        incompatiblePlants = []
    }
}
