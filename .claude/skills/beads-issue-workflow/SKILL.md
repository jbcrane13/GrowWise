---
name: beads-issue-workflow
description: Use when creating, updating, tracking, or closing beads (bd) issues in GrowWise. Ensures consistent issue management, proper labeling, and session handoff hygiene.
---

# Beads Issue Workflow Skill

GrowWise uses **beads** (`bd`) as its primary issue tracker — local-first, git-native, no browser required.

## Core Commands

```bash
# View current issues
bd show                          # All open issues
bd show --status in_progress     # In-progress only
bd show --filter "label:bug"     # Filtered by label

# Create issues
bd add "Fix crash in DataService when model is nil"
bd add "Refactor KeyRotationManager" --label chore
bd add "P0 security issue in token validation" --label "P0: Critical,security"

# Update issues
bd start GW-42          # Mark in_progress
bd close GW-42          # Mark closed
bd block GW-42          # Mark blocked
bd edit GW-42           # Open in editor

# Session workflow
bd ready                # Show what's ready to work on
bd sync                 # Push beads state to git remote
```

## Issue Lifecycle

```
open → in_progress → closed
         ↓
       blocked → in_progress
```

Always move an issue to `in_progress` before starting work:
```bash
bd start GW-XXX
```

## Filing Issues for Unfinished Work

At the end of every session, file issues for anything not completed:

```bash
# Quick issue filing
bd add "Implement plant deletion confirmation dialog" --label enhancement
bd add "Add unit tests for CompanionPlantingService" --label "area: services"
bd add "SwiftLint violations in DataService.swift" --label chore
```

## Linking Issues in Code

Always reference beads issues in code comments:
```swift
// TODO(GW-123): Extract this into a separate service after refactoring
// FIXME(GW-456): Memory leak in this subscription chain
```

## Session Handoff Checklist

Before ending any session:

```bash
# 1. File remaining issues
bd add "description of unfinished work"

# 2. Close completed issues
bd close GW-XXX

# 3. Sync beads state
bd sync

# 4. Push to remote
git push
```

Verify sync:
```bash
git status   # Must show "up to date with origin"
```

## Label Conventions

| Label | Use For |
|-------|---------|
| `P0: Critical` | Production-breaking or security issue |
| `P1: High` | Significant user impact |
| `P2: Medium` | Notable issue, backlog priority |
| `P3: Low` | Nice-to-have |
| `bug` | Something broken |
| `enhancement` | New feature or improvement |
| `chore` | Maintenance, refactoring |
| `security` | Security-sensitive change |
| `area: models` | SwiftData model changes |
| `area: services` | Service layer changes |
| `area: ui` | SwiftUI view changes |
| `area: sync` | CloudKit sync issues |
