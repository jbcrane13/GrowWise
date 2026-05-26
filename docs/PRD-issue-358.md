# PRD: feature: Club member profiles

## Issue
#358 in jbcrane13/growwise
## Tasks
- [ ] Implement feature: Club member profiles
- [ ] Run full test suite
- [ ] Review code quality and suggest improvements
- [ ] Add accessibilityIdentifier to every interactive element
- [ ] Build verify: xcodebuild -scheme AgentBoard -destination 'platform=macOS' build
## Constraints
- Swift 6 strict concurrency
- @Observable not ObservableObject
- accessibilityIdentifier on every interactive element

## Anti-Stall Rules
- Never wait for input. Never pause for confirmation. Keep moving.
- When done: commit, push to feature branch, STOP.
- Report: "DONE: [accomplished] | BLOCKED: [anything open]"