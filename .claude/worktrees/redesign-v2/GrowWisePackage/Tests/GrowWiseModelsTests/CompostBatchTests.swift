import Foundation
@testable import GrowWiseModels
import Testing

struct CompostBatchTests {
    // MARK: - Initialization

    @Test("Init sets name and generates non-nil UUID")
    func initSetsNameAndID() {
        let batch = CompostBatch(name: "Spring Pile")
        #expect(batch.name == "Spring Pile")
        #expect(batch.id != nil)
    }

    @Test("Init records the provided startDate")
    func initSetsProvidedStartDate() {
        let specificDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let batch = CompostBatch(name: "Autumn Batch", startDate: specificDate)
        #expect(batch.startDate == specificDate)
    }

    @Test("Init defaults startDate to approximately now when not provided")
    func initDefaultsStartDateToNow() throws {
        let before = Date()
        let batch = CompostBatch(name: "Now Pile")
        let after = Date()
        let startDate = try #require(batch.startDate)
        #expect(startDate >= before)
        #expect(startDate <= after)
    }

    @Test("Each init call produces a unique UUID")
    func initProducesUniqueIDs() {
        let a = CompostBatch(name: "Pile A")
        let b = CompostBatch(name: "Pile B")
        #expect(a.id != b.id)
    }

    // MARK: - Default Values

    @Test("isComplete defaults to false")
    func isCompleteDefaultsFalse() {
        let batch = CompostBatch(name: "Fresh Pile")
        #expect(batch.isComplete == false)
    }

    @Test("greensRatio defaults to 0.5")
    func greensRatioDefaultsToHalf() {
        let batch = CompostBatch(name: "Balanced Pile")
        #expect(batch.greensRatio == 0.5)
    }

    @Test("greenMaterials starts as empty array")
    func greenMaterialsStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.greenMaterials.isEmpty)
    }

    @Test("brownMaterials starts as empty array")
    func brownMaterialsStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.brownMaterials.isEmpty)
    }

    @Test("logDates starts as empty array")
    func logDatesStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.logDates.isEmpty)
    }

    @Test("temperatures starts as empty array")
    func temperaturesStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.temperatures.isEmpty)
    }

    @Test("moistureLevels starts as empty array")
    func moistureLevelsStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.moistureLevels.isEmpty)
    }

    @Test("turnDates starts as empty array")
    func turnDatesStartsEmpty() {
        let batch = CompostBatch(name: "Empty Pile")
        #expect(batch.turnDates.isEmpty)
    }

    // MARK: - Optional Properties Nil by Default

    @Test("estimatedReadyDate is nil by default")
    func estimatedReadyDateNilByDefault() {
        let batch = CompostBatch(name: "Unscheduled Pile")
        #expect(batch.estimatedReadyDate == nil)
    }

    @Test("notes is nil by default")
    func notesNilByDefault() {
        let batch = CompostBatch(name: "Silent Pile")
        #expect(batch.notes == nil)
    }

    @Test("garden is nil by default")
    func gardenNilByDefault() {
        let batch = CompostBatch(name: "Unassigned Pile")
        #expect(batch.garden == nil)
    }

    // MARK: - Property Mutation

    @Test("isComplete can be set to true to mark batch finished")
    func markingBatchComplete() {
        let batch = CompostBatch(name: "Ripening Pile")
        batch.isComplete = true
        #expect(batch.isComplete == true)
    }

    @Test("greenMaterials accumulates appended items")
    func appendingGreenMaterials() {
        let batch = CompostBatch(name: "Green Pile")
        batch.greenMaterials.append("Coffee grounds")
        batch.greenMaterials.append("Grass clippings")
        #expect(batch.greenMaterials.count == 2)
        #expect(batch.greenMaterials.contains("Coffee grounds"))
        #expect(batch.greenMaterials.contains("Grass clippings"))
    }

    @Test("brownMaterials accumulates appended items")
    func appendingBrownMaterials() {
        let batch = CompostBatch(name: "Brown Pile")
        batch.brownMaterials.append("Cardboard")
        batch.brownMaterials.append("Dried leaves")
        #expect(batch.brownMaterials.count == 2)
        #expect(batch.brownMaterials.contains("Cardboard"))
        #expect(batch.brownMaterials.contains("Dried leaves"))
    }

    @Test("temperatures array records multiple readings in order")
    func appendingTemperatures() {
        let batch = CompostBatch(name: "Hot Pile")
        batch.temperatures.append(130.0)
        batch.temperatures.append(145.5)
        batch.temperatures.append(120.0)
        #expect(batch.temperatures.count == 3)
        #expect(batch.temperatures[0] == 130.0)
        #expect(batch.temperatures[1] == 145.5)
        #expect(batch.temperatures[2] == 120.0)
    }

    @Test("moistureLevels array records percentage readings in order")
    func appendingMoistureLevels() {
        let batch = CompostBatch(name: "Moist Pile")
        batch.moistureLevels.append(55.0)
        batch.moistureLevels.append(62.5)
        #expect(batch.moistureLevels.count == 2)
        #expect(batch.moistureLevels[0] == 55.0)
        #expect(batch.moistureLevels[1] == 62.5)
    }

    @Test("logDates and temperatures stay in sync when added together")
    func parallelLogArraysStayInSync() {
        let batch = CompostBatch(name: "Logged Pile")
        let date1 = Date(timeIntervalSinceNow: -86400)
        let date2 = Date()
        batch.logDates.append(date1)
        batch.temperatures.append(128.0)
        batch.moistureLevels.append(50.0)
        batch.logDates.append(date2)
        batch.temperatures.append(141.0)
        batch.moistureLevels.append(58.0)
        #expect(batch.logDates.count == batch.temperatures.count)
        #expect(batch.logDates.count == batch.moistureLevels.count)
    }

    @Test("turnDates records turning events")
    func appendingTurnDates() {
        let batch = CompostBatch(name: "Turned Pile")
        let turn1 = Date(timeIntervalSinceNow: -604_800) // 7 days ago
        let turn2 = Date()
        batch.turnDates.append(turn1)
        batch.turnDates.append(turn2)
        #expect(batch.turnDates.count == 2)
        #expect(batch.turnDates.first == turn1)
        #expect(batch.turnDates.last == turn2)
    }

    @Test("greensRatio can be adjusted to reflect custom mix")
    func adjustingGreensRatio() {
        let batch = CompostBatch(name: "Custom Ratio Pile")
        batch.greensRatio = 0.3
        #expect(batch.greensRatio == 0.3)
    }

    @Test("estimatedReadyDate can be set to a future date")
    func settingEstimatedReadyDate() {
        let batch = CompostBatch(name: "Scheduled Pile")
        let futureDate = Date(timeIntervalSinceNow: 60 * 24 * 3600) // ~60 days
        batch.estimatedReadyDate = futureDate
        #expect(batch.estimatedReadyDate == futureDate)
    }

    @Test("notes can be assigned a non-nil string")
    func settingNotes() {
        let batch = CompostBatch(name: "Noted Pile")
        batch.notes = "Smells earthy, turning weekly."
        #expect(batch.notes == "Smells earthy, turning weekly.")
    }
}
