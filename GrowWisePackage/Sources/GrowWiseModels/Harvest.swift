import Foundation
import SwiftData

@Model
public final class Harvest {
    public var id: UUID? = UUID()
    public var quantity: Double? = 0
    public var unit: HarvestUnit? = HarvestUnit.pieces
    public var date: Date? = Date()
    public var notes: String? = ""
    public var photoURL: String?

    // Relationships
    public var plant: Plant?
    public var user: User?

    public init(
        quantity: Double = 0,
        unit: HarvestUnit = .pieces,
        date: Date = Date(),
        notes: String = "",
        photoURL: String? = nil,
        plant: Plant? = nil,
        user: User? = nil
    ) {
        self.id = UUID()
        self.quantity = quantity
        self.unit = unit
        self.date = date
        self.notes = notes
        self.photoURL = photoURL
        self.plant = plant
        self.user = user
    }
}

public enum HarvestUnit: String, CaseIterable, Codable, Sendable {
    case pieces
    case pounds
    case ounces
    case grams
    case kilograms
    case bunches

    public var displayName: String {
        switch self {
        case .pieces: "pieces"
        case .pounds: "lb"
        case .ounces: "oz"
        case .grams: "g"
        case .kilograms: "kg"
        case .bunches: "bunches"
        }
    }

    public var displayNamePlural: String {
        switch self {
        case .pieces: "pieces"
        case .pounds: "lbs"
        case .ounces: "oz"
        case .grams: "g"
        case .kilograms: "kg"
        case .bunches: "bunches"
        }
    }
}
