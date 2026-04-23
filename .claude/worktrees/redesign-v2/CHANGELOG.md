# Changelog

All notable changes to GrowWise are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- SwiftLint configuration for enforced code style (`.swiftlint.yml`)
- SwiftFormat configuration for consistent code formatting (`.swiftformat`)
- Pre-commit hook infrastructure with quality checks (`scripts/install-hooks.sh`)
- GitHub Actions CI pipeline (lint, format, tests, tech debt scan, large file detection)
- GitHub Issue templates (bug report, feature request, task)
- Pull request template with GrowWise-specific checklist
- CODEOWNERS file for code ownership and review assignment
- Dependabot configuration for automated dependency updates
- Agent skills for iOS development and beads issue workflow (`.factory/skills/`)
- Code reviewer droid configuration (`.factory/droids/code-reviewer.md`)
- Architecture diagrams in Mermaid format (`docs/architecture/diagrams/`)
- Environment variable documentation (`.env.example`)
- Log scrubbing and data redaction guidelines (`docs/security/log-scrubbing.md`)
- GitHub label definitions (`.github/labels.yml`)
- Release notes automation workflow
- AGENTS.md validation CI workflow

---

## Version History

Versions prior to CI automation were not formally tracked. See git log for history.
