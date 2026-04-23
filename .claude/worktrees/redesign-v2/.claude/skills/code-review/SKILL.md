---
name: code-review
description: Run the GrowWise code-reviewer droid on staged/uncommitted changes or a specific branch. Use before merging any feature branch. Also useful ad-hoc anytime Blake or an agent wants a quick review pass.
---

# Code Review — GrowWise

Invokes the `code-reviewer` droid with context about what changed.

## Pre-merge review (staged + uncommitted changes)

```bash
cd ~/Projects/GrowWise
droid "Use the code-reviewer droid. Review all staged and uncommitted changes against main. Focus on: MV architecture compliance, Swift 6 concurrency, SwiftData/CloudKit safety, force unwraps, and print statements. Produce a structured report with PASS/WARN/FAIL per category."
```

## Review specific branch vs main

```bash
cd ~/Projects/GrowWise
droid "Use the code-reviewer droid. Review the diff between HEAD and main (git diff main...HEAD). Same checklist — MV pattern, Swift 6, SwiftData, security. List any blocking issues."
```

## Ad-hoc quick review (last commit)

```bash
cd ~/Projects/GrowWise
droid "Use the code-reviewer droid on the last commit (git show HEAD). Flag any issues."
```

## When to run
- ✅ Before merging any feature branch
- ✅ After a large refactor or AI-generated code change
- ✅ Before releasing
- ✅ Anytime Blake asks for a review pass

## CI integration
The `agent-code-review.yml` workflow runs an automated version on every PR.
The droid review above is for deeper, interactive pre-merge checks.
