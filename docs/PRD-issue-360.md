# PRD: chore: refactor StarterPlanService.buildActiveRoadmap (function length)

## Issue
#360 in jbcrane13/growwise
## Tasks
- [x] Implement chore: refactor StarterPlanService.buildActiveRoadmap (function length)
- [x] Run full test suite
- [x] Review code quality and suggest improvements
- [x] Add accessibilityIdentifier to every interactive element
- [x] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"