import Foundation
import SwiftData

@Model
public final class GardenBed {
    public var id: UUID?
    public var name: String?
    public var bedType: BedType?
    public var notes: String?
    public var createdDate: Date?
    public var garden: Garden?
    @Relationship(deleteRule: .cascade, inverse: \Plant.bed)
    public var plants: [Plant]? = []

    public init(name: String, bedType: BedType, garden: Garden? = nil) {
        id = UUID()
        self.name = name
        self.bedType = bedType
        self.garden = garden
        createdDate = Date()
    }
}

// MARK: - BedType

public enum BedType: String, CaseIterable, Codable, Sendable {
    case raisedBed = "raised_bed"
    case planterBox = "planter_box"
    case inGroundRow = "in_ground_row"
    case pot
    case greenhouseBench = "greenhouse_bench"
    case windowBox = "window_box"
    case hangingBasket = "hanging_basket"
    case trellisVertical = "trellis_vertical"

    public var displayName: String {
        switch self {
        case .raisedBed: "Raised Bed"
        case .planterBox: "Planter Box"
        case .inGroundRow: "In-Ground Row"
        case .pot: "Pot"
        case .greenhouseBench: "Greenhouse Bench"
        case .windowBox: "Window Box"
        case .hangingBasket: "Hanging Basket"
        case .trellisVertical: "Trellis / Vertical"
        }
    }

    public var iconName: String {
        switch self {
        case .raisedBed: "rectangle.split.3x1.fill"
        case .planterBox: "shippingbox.fill"
        case .inGroundRow: "line.3.horizontal"
        case .pot: "cup.and.saucer.fill"
        case .greenhouseBench: "building.2.fill"
        case .windowBox: "rectangle.fill"
        case .hangingBasket: "circle.dotted"
        case .trellisVertical: "arrow.up.and.down.square.fill"
        }
    }
}
