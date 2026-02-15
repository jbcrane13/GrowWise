# Claude Code Configuration - SPARC Development Environment

## Key Documents

- **`docs/ADR.md`** — Architecture Decision Records. Read before making structural changes. Append when making new decisions.
- **`docs/SECURITY_AUDIT_FINAL.md`** — Security audit results.
- **`docs/JWT_Implementation_Guide.md`** — JWT auth implementation details.

## 🚨 CRITICAL: CONCURRENT EXECUTION & FILE MANAGEMENT

**ABSOLUTE RULES**:
1. ALL operations MUST be concurrent/parallel in a single message
2. **NEVER save working files, text/mds and tests to the root folder**
3. ALWAYS organize files in appropriate subdirectories
4. **USE CLAUDE CODE'S TASK TOOL** for spawning agents concurrently, not just MCP

### ⚡ GOLDEN RULE: "1 MESSAGE = ALL RELATED OPERATIONS"

**MANDATORY PATTERNS:**
- **TodoWrite**: ALWAYS batch ALL todos in ONE call (5-10+ todos minimum)
- **Task tool (Claude Code)**: ALWAYS spawn ALL agents in ONE message with full instructions
- **File operations**: ALWAYS batch ALL reads/writes/edits in ONE message
- **Bash commands**: ALWAYS batch ALL terminal operations in ONE message
- **Memory operations**: ALWAYS batch ALL memory store/retrieve in ONE message

### 🎯 CRITICAL: Claude Code Task Tool for Agent Execution

**Claude Code's Task tool is the PRIMARY way to spawn agents:**
```javascript
// ✅ CORRECT: Use Claude Code's Task tool for parallel agent execution
[Single Message]:
  Task("Research agent", "Analyze requirements and patterns...", "researcher")
  Task("Coder agent", "Implement core features...", "coder")
  Task("Tester agent", "Create comprehensive tests...", "tester")
  Task("Reviewer agent", "Review code quality...", "reviewer")
  Task("Architect agent", "Design system architecture...", "system-architect")
```

**MCP tools are ONLY for coordination setup:**
- `mcp__claude-flow__swarm_init` - Initialize coordination topology
- `mcp__claude-flow__agent_spawn` - Define agent types for coordination
- `mcp__claude-flow__task_orchestrate` - Orchestrate high-level workflows

### 📁 File Organization Rules

**NEVER save to root folder. Use these directories:**
- `/src` - Source code files
- `/tests` - Test files
- `/docs` - Documentation and markdown files
- `/config` - Configuration files
- `/scripts` - Utility scripts
- `/examples` - Example code
# GrowWise - iOS Gardening App

## Project Overview

GrowWise is a SwiftUI-based iOS gardening application that helps users manage their gardens, track plant care, and monitor growth progress.

## Technology Stack

- **Platform**: iOS 18+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Concurrency**: Swift Async/Await
- **Testing**: XCTest, XCUITest

## Project Structure

```
GrowWise/
├── GrowWise/              # Main app target
│   ├── Views/            # SwiftUI views
│   ├── Models/           # SwiftData models
│   ├── ViewModels/       # View models and business logic
│   └── Services/         # API and data services
├── GrowWisePackage/       # Swift Package with shared code
├── GrowWiseUITests/       # UI tests
├── tests/                 # Unit tests
├── docs/                  # Documentation
└── scripts/               # Build and utility scripts
```

## File Organization Rules

**NEVER save working files to the root folder. Use these directories:**
- `/GrowWise/` - Swift source code files
- `/tests/` - Test files
- `/docs/` - Documentation and markdown files
- `/scripts/` - Utility scripts
- `/config/` - Configuration files

## Code Style & Best Practices

### Swift/SwiftUI Standards
- Use `@Observable` instead of `ObservableObject`
- Use SwiftData for persistence (not CoreData)
- Use async/await for concurrency (not DispatchQueue)
- All interactive UI elements must have `.accessibilityIdentifier()`
- Follow modern iOS 18+ patterns

### Architecture
- **Modular Design**: Keep files focused and under 500 lines
- **Clean Architecture**: Separate views, view models, models, and services
- **Environment Safety**: Never hardcode secrets or API keys
- **Test-First**: Write tests before implementation (TDD)

### Accessibility Requirements

Every interactive element MUST have an accessibility identifier following this pattern:
```swift
// Pattern: {screen}_{element}_{descriptor}
Button("Save") { }
    .accessibilityIdentifier("settings_button_save")

TextField("Name", text: $name)
    .accessibilityIdentifier("profile_textfield_name")

Toggle("Notifications", isOn: $enabled)
    .accessibilityIdentifier("settings_toggle_notifications")

// List items include unique ID
ForEach(plants) { plant in
    PlantRow(plant: plant)
        .accessibilityIdentifier("garden_cell_plant_\(plant.id)")
}
```

## Development Workflow

### Starting New Features
1. Review requirements and user stories
2. Plan the implementation approach
3. Write failing tests first (TDD)
4. Implement minimal code to pass tests
5. Refactor while keeping tests green
6. Request code review before completion

### Quality Gates (Before Commit)
- [ ] All tests passing
- [ ] No legacy Swift patterns (`ObservableObject`, `@Published`, `CoreData`, etc.)
- [ ] All interactive UI has accessibility identifiers
- [ ] Build succeeds with zero warnings
- [ ] Code reviewed and approved

## Common Commands

### Build & Test
```bash
# Build the app
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -configuration Debug build

# Run unit tests
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run UI tests
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Simulator Management
```bash
# List available simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 15"

# Install app on simulator
xcrun simctl install booted /path/to/GrowWise.app
```

## Important Reminders

- **File Creation**: NEVER create files unless absolutely necessary
- **Editing First**: ALWAYS prefer editing existing files to creating new ones
- **No Documentation Sprawl**: NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- **Organized Files**: Never save working files, text/mds and tests to the root folder
- **Do What's Asked**: Nothing more, nothing less

## Resources

### ✅ CORRECT WORKFLOW: MCP Coordinates, Claude Code Executes

```javascript
// Step 1: MCP tools set up coordination (optional, for complex tasks)
[Single Message - Coordination Setup]:
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
  mcp__claude-flow__agent_spawn { type: "researcher" }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "tester" }

// Step 2: Claude Code Task tool spawns ACTUAL agents that do the work
[Single Message - Parallel Agent Execution]:
  // Claude Code's Task tool spawns real agents concurrently
  Task("Research agent", "Analyze API requirements and best practices. Check memory for prior decisions.", "researcher")
  Task("Coder agent", "Implement REST endpoints with authentication. Coordinate via hooks.", "coder")
  Task("Database agent", "Design and implement database schema. Store decisions in memory.", "code-analyzer")
  Task("Tester agent", "Create comprehensive test suite with 90% coverage.", "tester")
  Task("Reviewer agent", "Review code quality and security. Document findings.", "reviewer")
  
  // Batch ALL todos in ONE call
  TodoWrite { todos: [
    {id: "1", content: "Research API patterns", status: "in_progress", priority: "high"},
    {id: "2", content: "Design database schema", status: "in_progress", priority: "high"},
    {id: "3", content: "Implement authentication", status: "pending", priority: "high"},
    {id: "4", content: "Build REST endpoints", status: "pending", priority: "high"},
    {id: "5", content: "Write unit tests", status: "pending", priority: "medium"},
    {id: "6", content: "Integration tests", status: "pending", priority: "medium"},
    {id: "7", content: "API documentation", status: "pending", priority: "low"},
    {id: "8", content: "Performance optimization", status: "pending", priority: "low"}
  ]}
  
  // Parallel file operations
  Bash "mkdir -p app/{src,tests,docs,config}"
  Write "app/package.json"
  Write "app/src/server.js"
  Write "app/tests/server.test.js"
  Write "app/docs/API.md"
```

### ❌ WRONG (Multiple Messages):
```javascript
Message 1: mcp__claude-flow__swarm_init
Message 2: Task("agent 1")
Message 3: TodoWrite { todos: [single todo] }
Message 4: Write "file.js"
// This breaks parallel coordination!
```

## Performance Benefits

- **84.8% SWE-Bench solve rate**
- **32.3% token reduction**
- **2.8-4.4x speed improvement**
- **27+ neural models**

## Hooks Integration

### Pre-Operation
- Auto-assign agents by file type
- Validate commands for safety
- Prepare resources automatically
- Optimize topology by complexity
- Cache searches

### Post-Operation
- Auto-format code
- Train neural patterns
- Update memory
- Analyze performance
- Track token usage

### Session Management
- Generate summaries
- Persist state
- Track metrics
- Restore context
- Export workflows

## Advanced Features (v2.0.0)

- 🚀 Automatic Topology Selection
- ⚡ Parallel Execution (2.8-4.4x speed)
- 🧠 Neural Training
- 📊 Bottleneck Analysis
- 🤖 Smart Auto-Spawning
- 🛡️ Self-Healing Workflows
- 💾 Cross-Session Memory
- 🔗 GitHub Integration

## Integration Tips

1. Start with basic swarm init
2. Scale agents gradually
3. Use memory for context
4. Monitor progress regularly
5. Train patterns from success
6. Enable hooks automation
7. Use GitHub tools first

## Support

- Documentation: https://github.com/ruvnet/claude-flow
- Issues: https://github.com/ruvnet/claude-flow/issues

---

Remember: **Claude Flow coordinates, Claude Code creates!**

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
Never save working files, text/mds and tests to the root folder.

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`
- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
