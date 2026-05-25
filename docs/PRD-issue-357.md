# PRD: feature: Public garden showcase polish

## Issue
#357 in jbcrane13/growwise
## Tasks
- [x] Implement feature: Public garden showcase polish
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