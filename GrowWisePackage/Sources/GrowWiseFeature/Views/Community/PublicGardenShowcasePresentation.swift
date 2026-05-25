import Foundation
import GrowWiseServices

struct PublicGardenShowcasePresentation {
    let garden: PublicGarden
    let isLiked: Bool

    var typeLabel: String {
        Self.trimmedNonEmpty(garden.gardenType) ?? "Garden"
    }

    var descriptionText: String? {
        Self.trimmedNonEmpty(garden.description)
    }

    var currentLikeCount: Int {
        Self.optimisticCount(garden.likeCount, isIncremented: isLiked)
    }

    var likeDisplayCount: String {
        Self.displayCount(currentLikeCount)
    }

    var viewDisplayCount: String {
        Self.displayCount(garden.viewCount)
    }

    var likeAccessibilityLabel: String {
        Self.pluralizedCount(currentLikeCount, singular: "like")
    }

    var viewAccessibilityLabel: String {
        Self.pluralizedCount(garden.viewCount, singular: "view")
    }

    var likeAccessibilityValue: String {
        isLiked ? "Liked" : "Not liked"
    }

    var likeButtonAccessibilityLabel: String {
        "\(isLiked ? "Liked" : "Like") \(garden.name)"
    }

    var likeButtonAccessibilityValue: String {
        "\(likeAccessibilityValue), \(likeAccessibilityLabel)"
    }

    var cardAccessibilityLabel: String {
        var parts = [
            "\(garden.name) by \(garden.authorName).",
            typeSummarySentence,
        ]

        if let descriptionText {
            parts.append(Self.sentence(descriptionText))
        }

        parts.append("\(likeAccessibilityLabel).")
        parts.append("\(viewAccessibilityLabel).")

        return parts.joined(separator: " ")
    }

    static func displayCount(_ count: Int) -> String {
        let sanitizedCount = max(0, count)

        switch sanitizedCount {
        case 0 ..< 1000:
            return "\(sanitizedCount)"

        case 1000 ..< 1_000_000:
            return compactValue(Double(sanitizedCount) / 1000, suffix: "K")

        default:
            return compactValue(Double(sanitizedCount) / 1_000_000, suffix: "M")
        }
    }

    private var typeSummarySentence: String {
        if typeLabel == "Garden" {
            return "Garden."
        }
        return "\(typeLabel) garden."
    }

    private static func compactValue(_ value: Double, suffix: String) -> String {
        let truncated = (value * 10).rounded(.down) / 10
        let wholeNumber = truncated.rounded(.down)

        if truncated >= 10 || truncated == wholeNumber {
            return "\(Int(wholeNumber))\(suffix)"
        }

        return String(format: "%.1f%@", truncated, suffix)
    }

    private static func pluralizedCount(_ count: Int, singular: String) -> String {
        let sanitizedCount = max(0, count)
        let suffix = sanitizedCount == 1 ? "" : "s"
        return "\(groupedCount(sanitizedCount)) \(singular)\(suffix)"
    }

    private static func optimisticCount(_ count: Int, isIncremented: Bool) -> Int {
        let sanitizedCount = max(0, count)
        guard isIncremented else { return sanitizedCount }
        guard sanitizedCount < Int.max else { return Int.max }
        return sanitizedCount + 1
    }

    private static func groupedCount(_ count: Int) -> String {
        let digits = Array(String(max(0, count)))
        var result = ""

        for (offset, digit) in digits.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) {
                result.insert(",", at: result.startIndex)
            }
            result.insert(digit, at: result.startIndex)
        }

        return result
    }

    private static func sentence(_ value: String) -> String {
        guard let last = value.last, ".!?".contains(last) else {
            return "\(value)."
        }
        return value
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
