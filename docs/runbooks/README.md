# GrowWise Runbooks

Operational playbooks for common incidents and maintenance procedures.

## Index

| Runbook | Scenario |
|---------|----------|
| [cloudkit-sync-failure.md](cloudkit-sync-failure.md) | CloudKit sync stops working or data not appearing across devices |
| [keychain-data-loss.md](keychain-data-loss.md) | User loses access to encrypted data / Keychain errors on launch |
| [app-crash-on-launch.md](app-crash-on-launch.md) | App crashes immediately after update |
| [swiftdata-migration-failure.md](swiftdata-migration-failure.md) | SwiftData model migration fails after schema change |
| [key-rotation-failure.md](key-rotation-failure.md) | Encryption key rotation fails or leaves data in inconsistent state |

## Severity Levels

| Level | Response Time | Example |
|-------|--------------|---------|
| P0 | Immediate | App crashes on launch for all users |
| P1 | < 4 hours | Data loss for subset of users |
| P2 | < 24 hours | Feature broken for specific device/OS combination |
| P3 | Next sprint | Degraded performance, non-critical UI issue |

## General Incident Process

1. **Identify** — Reproduce the issue locally or collect crash logs from Xcode Organizer
2. **Triage** — Assign severity, file a beads issue: `bd add "P0: [description]" --label "P0: Critical,bug"`
3. **Mitigate** — Apply hotfix or rollback via TestFlight if available
4. **Resolve** — Merge fix, verify in TestFlight build
5. **Post-mortem** — Document cause and prevention in the relevant runbook
