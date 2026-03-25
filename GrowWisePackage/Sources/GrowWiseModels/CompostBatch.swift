import Foundation
import SwiftData

@Model
public final class CompostBatch {
    public var id: UUID?
    public var name: String?
    public var startDate: Date?
    public var estimatedReadyDate: Date?
    public var isComplete: Bool = false

    // Material tracking
    public var greenMaterials: [String] = [] // nitrogen-rich
    public var brownMaterials: [String] = [] // carbon-rich
    public var greensRatio: Double = 0.5 // 0-1 ratio of greens to total

    // Log entries stored as parallel arrays
    public var logDates: [Date] = []
    public var temperatures: [Double] = [] // Fahrenheit
    public var moistureLevels: [Double] = [] // 0-100 percentage
    public var turnDates: [Date] = []

    public var notes: String?

    public var garden: Garden?

    public init(name: String, startDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
    }
}
