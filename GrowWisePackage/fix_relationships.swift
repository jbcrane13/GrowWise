import Foundation

let plantPath = "Sources/GrowWiseModels/Plant.swift"
var plantContent = try! String(contentsOfFile: plantPath, encoding: .utf8)
plantContent = plantContent.replacingOccurrences(
    of: "public var companionPlants: [Plant]? // CloudKit: made optional or with default value",
    with: "@Relationship(inverse: \\Plant.companionPlants)\n    public var companionPlants: [Plant]? // CloudKit: made optional or with default value"
)
plantContent = plantContent.replacingOccurrences(
    of: "public var reminders: [PlantReminder]? // CloudKit: made optional or with default value",
    with: "@Relationship(deleteRule: .cascade, inverse: \\PlantReminder.plant)\n    public var reminders: [PlantReminder]? // CloudKit: made optional or with default value"
)
plantContent = plantContent.replacingOccurrences(
    of: "public var journalEntries: [JournalEntry]? // CloudKit: made optional or with default value",
    with: "@Relationship(deleteRule: .cascade, inverse: \\JournalEntry.plant)\n    public var journalEntries: [JournalEntry]? // CloudKit: made optional or with default value"
)
try! plantContent.write(toFile: plantPath, atomically: true, encoding: .utf8)
print("Updated Plant.swift")

let soilLogPath = "Sources/GrowWiseModels/SoilLog.swift"
var soilLogContent = try! String(contentsOfFile: soilLogPath, encoding: .utf8)
soilLogContent = soilLogContent.replacingOccurrences(
    of: "public var garden: Garden?",
    with: "@Relationship(inverse: \\Garden.soilLogs)\n    public var garden: Garden?"
)
soilLogContent = soilLogContent.replacingOccurrences(
    of: "public var plant: Plant?",
    with: "@Relationship(inverse: \\Plant.soilLogs)\n    public var plant: Plant?"
)
try! soilLogContent.write(toFile: soilLogPath, atomically: true, encoding: .utf8)
print("Updated SoilLog.swift")

let gardenPath = "Sources/GrowWiseModels/Garden.swift"
var gardenContent = try! String(contentsOfFile: gardenPath, encoding: .utf8)
gardenContent = gardenContent.replacingOccurrences(
    of: "public var plants: [Plant]? = []",
    with: "@Relationship(deleteRule: .cascade, inverse: \\Plant.garden)\n    public var plants: [Plant]? = []\n    \n    public var soilLogs: [SoilLog]? = []"
)
try! gardenContent.write(toFile: gardenPath, atomically: true, encoding: .utf8)
print("Updated Garden.swift")

let plantPath2 = "Sources/GrowWiseModels/Plant.swift"
var plantContent2 = try! String(contentsOfFile: plantPath2, encoding: .utf8)
plantContent2 = plantContent2.replacingOccurrences(
    of: "@Relationship(inverse: \\Plant.companionPlants)\n    public var companionPlants: [Plant]? // CloudKit: made optional or with default value",
    with: "@Relationship(inverse: \\Plant.companionPlants)\n    public var companionPlants: [Plant]? // CloudKit: made optional or with default value\n    \n    public var soilLogs: [SoilLog]? = []"
)
try! plantContent2.write(toFile: plantPath2, atomically: true, encoding: .utf8)
print("Updated Plant.swift with soilLogs")

let userPath = "Sources/GrowWiseModels/User.swift"
var userContent = try! String(contentsOfFile: userPath, encoding: .utf8)
userContent = userContent.replacingOccurrences(
    of: "public var gardens: [Garden]? = []",
    with: "@Relationship(deleteRule: .cascade, inverse: \\Garden.user)\n    public var gardens: [Garden]? = []"
)
try! userContent.write(toFile: userPath, atomically: true, encoding: .utf8)
print("Updated User.swift")

