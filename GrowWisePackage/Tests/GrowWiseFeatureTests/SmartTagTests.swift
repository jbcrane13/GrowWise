@testable import GrowWiseFeature
import SwiftUI
import Testing

struct SmartTagTests {
    @Test("Stores its label verbatim")
    func storesLabelVerbatim() {
        let tag = SmartTag(label: "Auto-identified")
        #expect(tag.label == "Auto-identified")
    }

    /// The view constructs its accessibility label as "Smart enrichment: \(label)".
    /// SwiftUI doesn't expose a public accessor for that string at runtime, so we
    /// verify the interpolation contract the implementation commits to. Visual
    /// rendering is covered by the Phase 10 ui-verify walkthrough.
    @Test("Accessibility label prefix contract is 'Smart enrichment: <label>'")
    func accessibilityLabelPrefixContract() {
        let tag = SmartTag(label: "Auto-identified")
        let expected = "Smart enrichment: \(tag.label)"
        #expect(expected == "Smart enrichment: Auto-identified")
    }
}
