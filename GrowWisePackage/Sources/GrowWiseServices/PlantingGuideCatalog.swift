import Foundation
import GrowWiseModels

// MARK: - PlantingGuide

public enum PlantingGuideAction: String, CaseIterable, Sendable, Hashable {
    case startIndoors = "start_indoors"
    case directSow = "direct_sow"
    case transplant

    public var displayName: String {
        switch self {
        case .startIndoors: "Start indoors"
        case .directSow: "Direct sow"
        case .transplant: "Transplant"
        }
    }

    public var icon: String {
        switch self {
        case .startIndoors: "light.recessed.3.fill"
        case .directSow: "sprout"
        case .transplant: "arrow.up.right.and.arrow.down.left.rectangle.fill"
        }
    }

    fileprivate var sortPriority: Int {
        switch self {
        case .startIndoors: 0
        case .directSow: 1
        case .transplant: 2
        }
    }
}

public struct PlantingGuideItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let plantName: String
    public let plantType: PlantType
    public let action: PlantingGuideAction
    public let month: Int
    public let beginnerFriendly: Bool
    public let timingSummary: String
    public let whyNow: String
    public let nextStep: String
    public let tutorialID: String?

    public init(
        plantName: String,
        plantType: PlantType,
        action: PlantingGuideAction,
        month: Int,
        beginnerFriendly: Bool,
        timingSummary: String,
        whyNow: String,
        nextStep: String,
        tutorialID: String?
    ) {
        self.plantName = plantName
        self.plantType = plantType
        self.action = action
        self.month = month
        self.beginnerFriendly = beginnerFriendly
        self.timingSummary = timingSummary
        self.whyNow = whyNow
        self.nextStep = nextStep
        self.tutorialID = tutorialID
        id = "\(action.rawValue)-\(plantName.lowercased().replacingOccurrences(of: " ", with: "-"))-\(month)"
    }
}

enum PlantingGuideCatalog {
    private struct Template {
        let plantName: String
        let plantType: PlantType
        let beginnerFriendly: Bool
        let startIndoorsMonths: [Int]
        let directSowMonths: [Int]
        let transplantMonths: [Int]
        let timingSummary: String
        let whyNow: String

        func months(for action: PlantingGuideAction) -> [Int] {
            switch action {
            case .startIndoors: startIndoorsMonths
            case .directSow: directSowMonths
            case .transplant: transplantMonths
            }
        }

        func nextStep(for action: PlantingGuideAction) -> String {
            switch action {
            case .startIndoors:
                "Sow in a clean tray with bright light, gentle warmth, and labels for each variety."

            case .directSow:
                "Prepare a weed-free row, water first, sow at packet depth, and keep the bed evenly moist."

            case .transplant:
                "Harden seedlings off for 7 days, then transplant on a cloudy afternoon or calm evening."
            }
        }

        func tutorialID(for action: PlantingGuideAction) -> String {
            switch action {
            case .startIndoors: "seed-starting-indoors"
            case .directSow: "direct-sowing-basics"
            case .transplant: "transplanting-hardening-off"
            }
        }
    }

    private static let templates: [Template] = [
        Template(
            plantName: "Tomato",
            plantType: .vegetable,
            beginnerFriendly: false,
            startIndoorsMonths: [2, 3],
            directSowMonths: [],
            transplantMonths: [4, 5],
            timingSummary: "Warm-season crop; start early indoors and transplant after frost risk passes.",
            whyNow: "Tomatoes need a head start before warm nights arrive."
        ),
        Template(
            plantName: "Pepper",
            plantType: .vegetable,
            beginnerFriendly: false,
            startIndoorsMonths: [2, 3],
            directSowMonths: [],
            transplantMonths: [5],
            timingSummary: "Warm-season crop; start indoors early and wait for warm soil before transplanting.",
            whyNow: "Peppers grow slowly at first and reward an early indoor start."
        ),
        Template(
            plantName: "Basil",
            plantType: .herb,
            beginnerFriendly: true,
            startIndoorsMonths: [3, 4],
            directSowMonths: [5, 6],
            transplantMonths: [5],
            timingSummary: "Tender herb; plant after nights are reliably warm.",
            whyNow: "Basil is simple, fast, and useful for new gardeners."
        ),
        Template(
            plantName: "Lettuce",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [2, 3],
            directSowMonths: [3, 4, 8, 9],
            transplantMonths: [3, 4, 9],
            timingSummary: "Cool-season crop; sow in spring and again for fall harvests.",
            whyNow: "Lettuce germinates quickly and teaches harvest-as-you-grow confidence."
        ),
        Template(
            plantName: "Carrot",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [],
            directSowMonths: [3, 4, 5, 8],
            transplantMonths: [],
            timingSummary: "Root crop; direct sow into loose soil instead of transplanting.",
            whyNow: "Carrots are forgiving when soil stays moist through germination."
        ),
        Template(
            plantName: "Radish",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [],
            directSowMonths: [3, 4, 5, 9],
            transplantMonths: [],
            timingSummary: "Fast cool-season crop; direct sow for a quick first harvest.",
            whyNow: "Radishes show progress in weeks, which makes them ideal for beginners."
        ),
        Template(
            plantName: "Kale",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [2, 3, 7],
            directSowMonths: [3, 4, 8, 9],
            transplantMonths: [4, 8],
            timingSummary: "Cool-season green; grows well in spring and again in fall.",
            whyNow: "Kale tolerates cool weather and stays productive after light frosts."
        ),
        Template(
            plantName: "Zucchini",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [4],
            directSowMonths: [5, 6],
            transplantMonths: [5],
            timingSummary: "Warm-season squash; plant after soil warms.",
            whyNow: "Zucchini is vigorous and gives beginners visible daily growth."
        ),
        Template(
            plantName: "Cucumber",
            plantType: .vegetable,
            beginnerFriendly: true,
            startIndoorsMonths: [4],
            directSowMonths: [5, 6],
            transplantMonths: [5],
            timingSummary: "Warm-season vine; sow or transplant after frost danger has passed.",
            whyNow: "Cucumbers grow quickly once nights stay warm."
        ),
        Template(
            plantName: "Marigold",
            plantType: .flower,
            beginnerFriendly: true,
            startIndoorsMonths: [3, 4],
            directSowMonths: [5],
            transplantMonths: [5],
            timingSummary: "Easy annual flower; start indoors or direct sow after frost.",
            whyNow: "Marigolds add color and draw beneficial insects around vegetables."
        ),
    ]

    static func items(for month: Int, zone: String?) -> [PlantingGuideItem] {
        let normalizedMonth = normalizeMonth(month)
        let zoneNum = extractZoneNumber(from: zone) ?? 7
        let zoneOffset = max(-2, min(2, 7 - zoneNum))

        return templates.flatMap { template in
            PlantingGuideAction.allCases.compactMap { action in
                let months = template.months(for: action)
                guard !months.isEmpty else { return nil }
                guard shifted(months, by: zoneOffset).contains(normalizedMonth) else { return nil }

                return PlantingGuideItem(
                    plantName: template.plantName,
                    plantType: template.plantType,
                    action: action,
                    month: normalizedMonth,
                    beginnerFriendly: template.beginnerFriendly,
                    timingSummary: template.timingSummary,
                    whyNow: template.whyNow,
                    nextStep: template.nextStep(for: action),
                    tutorialID: template.tutorialID(for: action)
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.beginnerFriendly != rhs.beginnerFriendly {
                return lhs.beginnerFriendly && !rhs.beginnerFriendly
            }
            if lhs.action.sortPriority != rhs.action.sortPriority {
                return lhs.action.sortPriority < rhs.action.sortPriority
            }
            return lhs.plantName < rhs.plantName
        }
    }

    private static func extractZoneNumber(from zone: String?) -> Int? {
        guard let zone else { return nil }
        let digits = zone.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private static func shifted(_ months: [Int], by offset: Int) -> Set<Int> {
        Set(months.map { month in
            var shiftedMonth = month + offset
            if shiftedMonth < 1 { shiftedMonth += 12 }
            if shiftedMonth > 12 { shiftedMonth -= 12 }
            return shiftedMonth
        })
    }

    private static func normalizeMonth(_ month: Int) -> Int {
        if month < 1 { return 1 }
        if month > 12 { return 12 }
        return month
    }
}
