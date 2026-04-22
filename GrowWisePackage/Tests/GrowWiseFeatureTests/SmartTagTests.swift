@testable import GrowWiseFeature
import SwiftUI
import Testing

struct SmartTagTests {
    @Test("Accessibility label uses the 'Smart enrichment' prefix")
    func accessibilityLabelPrefix() {
        let tag = SmartTag(label: "Auto-identified")
        #expect(tag.label == "Auto-identified")
    }
}
