# Onboarding Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign all 6 onboarding screens to use the dark glass design language, eliminate all scrolling by splitting overloaded screens, and add a dedicated Garden Setup step.

**Architecture:** 7-step flow (Welcome → Skill → Goals → Garden Setup → Location → Notifications → Completion). No `ScrollView` on any step — all content fits in the visible viewport. All shared components rewritten for dark theme. Navigation and progress bar updated to match.

**Tech Stack:** Swift 6, SwiftUI, iOS 18+, `@Observable`, `CultivationTheme` / `botanicalX` color tokens.

---

## Design Reference

### Dark Glass Token Mapping
| Token | Value | Usage |
|---|---|---|
| Background | `Color.black` / `#0c0c0c` | All step backgrounds |
| Card surface | `.ultraThinMaterial` or `Color.white.opacity(0.05)` | Card fills |
| Card border | `Color.white.opacity(0.08)` | Card strokes |
| Primary text | `Color.white` | Headlines |
| Secondary text | `Color.white.opacity(0.55)` | Subtitles, captions |
| CTA gradient | `#2d6a4f → #52b788` (botanicalForest → botanicalLeaf) | All primary buttons + selected states |
| Progress active | `Color.white` | Current step dot |
| Progress done | `Color(hex: "#52b788")` | Completed step dots |
| Progress inactive | `Color.white.opacity(0.25)` | Upcoming dots |

### Layout Contract (all interior steps)
```
┌─────────────────────────────┐
│  ← [back]    ●●●●○○○  [  ] │  ← Progress bar, top-safe-area, fixed
│                              │
│  [icon bubble]               │
│  Headline (≤2 lines)         │  ← Header: ~20% of height
│  Subtitle (1 line)           │
│                              │
│  ┌──────────────────────┐    │
│  │                      │    │  ← Choices: flex fill remaining space
│  │     choices /        │    │    frame(maxWidth:.infinity,
│  │     cards            │    │          maxHeight:.infinity)
│  └──────────────────────┘    │
│                              │
│  [        Continue       ]   │  ← CTA, bottom-safe-area, fixed
└─────────────────────────────┘
```

### Accessibility Identifiers Convention
- Progress dots: `onboarding_step_<rawValue>`
- Back: `onboarding_nav_back`
- Next/CTA: `onboarding_nav_next`
- Step items: `onboarding_<step>_<itemRawValue>` (e.g. `onboarding_skill_beginner`)

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `OnboardingView.swift` | Modify | Add `.gardenSetup` step, dark background, update TabView |
| `OnboardingSharedComponents.swift` | Rewrite | Dark-themed shared atoms: `OnboardingStepHeader`, `PermissionGrantedBadge`, `OnboardingGlassCard`, `OnboardingPermissionScreen` |
| `OnboardingProgressView.swift` | Rewrite | Dark dots/connector, include gardenSetup in visible steps |
| `OnboardingNavigationView.swift` | Modify | Dark background/transparent, update colors |
| `WelcomeStepView.swift` | Modify | Remove feature card list; pure hero |
| `SkillAssessmentView.swift` | Rewrite | No ScrollView; cards fill viewport with `.frame(maxHeight:.infinity)` |
| `GardeningGoalsView.swift` | Rewrite | No ScrollView; 2×3 goal grid only (remove garden type + space size sections) |
| `GardenSetupView.swift` | **Create** | Garden type selector + space size selector, no ScrollView |
| `LocationSetupView.swift` | Rewrite | Centered permission screen, no scroll, no benefit list |
| `NotificationPermissionView.swift` | Rewrite | Centered permission screen, no scroll, no benefit list |
| `CompletionView.swift` | Rewrite | No ScrollView; hero + 3-row summary card only |

---

## Chunk 1: Foundation — Step Enum + Shared Components + Progress Bar

### Task 1: Add `gardenSetup` step to OnboardingStep enum

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/OnboardingView.swift`

The `OnboardingStep` enum currently has 6 cases. Add `.gardenSetup` between `.goals` and `.location`. Also update `OnboardingView.body` background to use `Color.black` for all steps (remove the `botanicalCream` branch).

- [ ] Open `OnboardingView.swift`
- [ ] In `OnboardingStep` enum, insert `.gardenSetup` between `.goals` and `.location`:
```swift
public enum OnboardingStep: String, CaseIterable {
    case welcome
    case skillAssessment
    case goals
    case gardenSetup       // NEW
    case location
    case notifications
    case completion
    ...
}
```
- [ ] Add title for gardenSetup:
```swift
case .gardenSetup: "Setup"
```
- [ ] In `OnboardingView.body`, replace the `if/else` background block with a single dark background:
```swift
Color.black.ignoresSafeArea()
```
(Remove the `Color.botanicalCream` branch entirely — all steps use black.)
- [ ] In the `TabView` inside `OnboardingView`, add the new step between goals and location:
```swift
GardenSetupView(userProfile: $userProfile)
    .tag(OnboardingStep.gardenSetup)
```
- [ ] Build to confirm it compiles (will fail until `GardenSetupView` is created — that's fine; stub it out):
```swift
// Temporary stub — replace in Task 8
struct GardenSetupView: View {
    @Binding var userProfile: UserProfile
    var body: some View { Color.clear }
}
```
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/OnboardingView.swift
git commit -m "feat(onboarding): add gardenSetup step to OnboardingStep enum"
```

---

### Task 2: Rewrite OnboardingSharedComponents for dark theme

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingSharedComponents.swift`

Replace all light-mode colors with dark glass equivalents. Add new `OnboardingGlassCard` wrapper and `OnboardingPermissionScreen` template used by Location and Notifications steps.

- [ ] Replace the entire file with:

```swift
import SwiftUI

// MARK: - Step Header (Dark)

/// Compact header for interior onboarding steps.
/// Keeps height small so choices can fill the remaining space.
struct OnboardingStepHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            // Tinted icon bubble
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(iconColor.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }
}

// MARK: - Glass Card Wrapper

/// Wraps content in a glass-morphism card surface.
struct OnboardingGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Permission Granted Badge (Dark)

struct PermissionGrantedBadge: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#52b788").opacity(0.20))
                    .frame(width: 34, height: 34)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#52b788"))
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#52b788").opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#52b788").opacity(0.30), lineWidth: 1)
                )
        )
    }
}

// MARK: - Privacy Note (Dark)

struct PrivacyNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#52b788"))

            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - BenefitRow is intentionally removed.
// Location and Notification screens no longer use benefit lists —
// they use the centered OnboardingPermissionScreen layout instead.
```

- [ ] Build to confirm shared components compile
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingSharedComponents.swift
git commit -m "feat(onboarding): rewrite shared components for dark glass theme"
```

---

### Task 3: Rewrite OnboardingProgressView for dark theme + 7 steps

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingProgressView.swift`

Progress bar uses dots + connectors. Active = white filled, done = green filled with checkmark, upcoming = white 25% opacity outline. Include `gardenSetup` in visible steps.

- [ ] Replace the entire file with:

```swift
import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep

    // Welcome and completion are full-screen moments — no dots shown
    private let visibleSteps: [OnboardingStep] = [
        .skillAssessment, .goals, .gardenSetup, .location, .notifications,
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, step in
                StepDot(state: dotState(for: step))
                    .accessibilityIdentifier("onboarding_step_\(step.rawValue)")

                if index < visibleSteps.count - 1 {
                    Capsule()
                        .fill(
                            step.stepNumber < currentStep.stepNumber
                                ? Color(hex: "#52b788")
                                : Color.white.opacity(0.20)
                        )
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .animation(.spring(duration: 0.4), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
    }

    private func dotState(for step: OnboardingStep) -> StepDotState {
        if step.stepNumber < currentStep.stepNumber { return .completed }
        if step == currentStep { return .active }
        return .upcoming
    }
}

// MARK: - Supporting Types

enum StepDotState { case completed, active, upcoming }

private struct StepDot: View {
    let state: StepDotState

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(border, lineWidth: 1.5))
                .frame(width: 24, height: 24)

            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else if state == .active {
                Circle()
                    .fill(Color(hex: "#2d6a4f"))
                    .frame(width: 8, height: 8)
            }
        }
        .scaleEffect(state == .active ? 1.1 : 1.0)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: state)
    }

    private var fill: Color {
        switch state {
        case .completed: Color(hex: "#52b788")
        case .active: .white
        case .upcoming: .clear
        }
    }

    private var border: Color {
        switch state {
        case .completed: Color(hex: "#52b788")
        case .active: .white
        case .upcoming: Color.white.opacity(0.30)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            ForEach([OnboardingStep.skillAssessment, .goals, .gardenSetup, .location], id: \.self) { step in
                OnboardingProgressView(currentStep: step)
            }
        }
    }
}
```

- [ ] Build to confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingProgressView.swift
git commit -m "feat(onboarding): dark progress bar, 5 visible steps including gardenSetup"
```

---

### Task 4: Update OnboardingNavigationView for dark theme

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingNavigationView.swift`

Update background to `Color.clear` (transparent over dark bg), text/border colors to white variants, add `.gardenSetup` to the `canProceed` switch.

- [ ] In `canProceed`, add `.gardenSetup: true` (always can proceed — both fields have defaults):
```swift
case .welcome, .skillAssessment, .gardenSetup, .location, .notifications, .completion:
    true
```
- [ ] Replace the back button background logic — remove `currentStep == .welcome` branching, use single dark style:
```swift
// Back button
Circle()
    .fill(Color.white.opacity(0.10))
    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
```
- [ ] Update back button chevron color to `.white.opacity(0.85)` unconditionally
- [ ] Update the navigation container background:
```swift
.background(Color.clear)  // transparent over the dark screen bg
```
- [ ] Update the divider color to `Color.white.opacity(0.08)` unconditionally
- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/OnboardingNavigationView.swift
git commit -m "feat(onboarding): dark nav bar, add gardenSetup to canProceed"
```

---

## Chunk 2: Step Views — Welcome + Skill + Goals

### Task 5: Simplify WelcomeStepView — hero only, no feature list

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/WelcomeStepView.swift`

Remove the 4 feature-card rows entirely. The welcome screen is a brand moment — just logo + name + tagline. The existing green gradient background stays; it already matches the dark theme intent.

- [ ] Delete `featureCards` computed property and `welcomeFeatures` array
- [ ] Delete `WelcomeFeatureRow` struct
- [ ] Remove `featureCards` from `body`; replace with a single `Spacer()` so the hero sits centered:
```swift
var body: some View {
    VStack(spacing: 0) {
        Spacer()
        brandHero
            .opacity(logoVisible ? 1 : 0)
            .offset(y: logoVisible ? 0 : 28)
        Spacer()
        // Subtle "swipe to begin" hint
        Image(systemName: "chevron.down")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.40))
            .padding(.bottom, 100)
    }
    .onAppear {
        withAnimation(.spring(duration: 0.75, bounce: 0.1).delay(0.1)) {
            logoVisible = true
        }
    }
}
```
- [ ] Remove `featuresVisible` state variable (no longer used)
- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/WelcomeStepView.swift
git commit -m "feat(onboarding): welcome step — pure hero, remove feature list"
```

---

### Task 6: Rewrite SkillAssessmentView — no scroll, cards fill viewport

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/SkillAssessmentView.swift`

Remove `ScrollView`. Remove the "interests" section (it's secondary — can be collected in Profile later). Use `GeometryReader` or `.frame(maxHeight:.infinity)` on the card stack so the 4 cards expand to fill available space between header and CTA.

- [ ] Replace the entire file with:

```swift
import GrowWiseModels
import SwiftUI

struct SkillAssessmentView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "graduationcap.fill",
                iconColor: Color(hex: "#52b788"),
                title: "Your experience level?",
                subtitle: "We'll tailor guides to match your skill."
            )

            // Cards fill remaining space between header and CTA
            VStack(spacing: 10) {
                ForEach(GardeningSkillLevel.allCases, id: \.self) { level in
                    SkillLevelCard(
                        level: level,
                        isSelected: userProfile.skillLevel == level
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            userProfile.skillLevel = level
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // flex fill
                    .accessibilityIdentifier("onboarding_skill_\(level.rawValue)")
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Skill Level Card (Dark Glass)

private struct SkillLevelCard: View {
    let level: GardeningSkillLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon bubble
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.white.opacity(0.18) : Color(hex: "#52b788").opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: level.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color(hex: "#52b788"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(level.description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(isSelected ? 0.80 : 0.45))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection ring
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color(hex: "#52b788") : Color.white.opacity(0.25),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#52b788"))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "#2d6a4f"), Color(hex: "#52b788").opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color(hex: "#2d6a4f").opacity(0.4) : .clear,
                        radius: 12, y: 4
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.displayName)
    }
}

extension GardeningSkillLevel {
    var iconName: String {
        switch self {
        case .beginner: "sprout.fill"
        case .intermediate: "leaf.fill"
        case .advanced: "tree"
        case .expert: "tree.fill"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            SkillAssessmentView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80) // simulate nav bar space
        }
    }
}
```

- [ ] Build and confirm — verify no references to removed `InterestTag` or `FlexibleView` exist elsewhere
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/SkillAssessmentView.swift
git commit -m "feat(onboarding): skill step — dark glass cards, no scroll, fills viewport"
```

---

### Task 7: Rewrite GardeningGoalsView — goals only, no scroll

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardeningGoalsView.swift`

Remove garden type and space size sections (moved to GardenSetupView). Keep the 6-goal 2×3 grid. No `ScrollView` — grid fills available height.

- [ ] Replace the entire file with:

```swift
import GrowWiseModels
import SwiftUI

struct GardeningGoalsView: View {
    @Binding var userProfile: UserProfile

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "scope",
                iconColor: Color(hex: "#52b788"),
                title: "What brings you\nto gardening?",
                subtitle: "Pick everything that resonates."
            )

            // Grid fills remaining space
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GardeningGoal.allCases) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: userProfile.goals.contains(goal)
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            if userProfile.goals.contains(goal) {
                                userProfile.goals.remove(goal)
                            } else {
                                userProfile.goals.insert(goal)
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding_goal_\(goal.rawValue)")
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Goal Card (Dark Glass)

private struct GoalCard: View {
    let goal: GardeningGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.18) : goal.accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: goal.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : goal.accentColor)
                }

                Text(goal.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [goal.accentColor.opacity(0.60), goal.accentColor.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? goal.accentColor.opacity(0.50) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? goal.accentColor.opacity(0.30) : .clear,
                        radius: 10, y: 3
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.displayName)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            GardeningGoalsView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
```

- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardeningGoalsView.swift
git commit -m "feat(onboarding): goals step — dark glass grid, no scroll, goals only"
```

---

## Chunk 3: Step Views — Garden Setup + Permission Screens + Completion

### Task 8: Create GardenSetupView — garden type + space size

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardenSetupView.swift`
- Remove: the temporary `GardenSetupView` stub from `OnboardingView.swift`

Two sections stacked vertically: garden type (horizontal chip scroll — compact height) + space size (3 most common sizes as large tappable rows). No `ScrollView`.

Note: `SpaceSize` has 5 cases (.tiny → .acreage). Show all 5 as compact rows — they fit without scrolling.

- [ ] Create the file:

```swift
import GrowWiseModels
import SwiftUI

struct GardenSetupView: View {
    @Binding var userProfile: UserProfile

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                icon: "square.split.2x1.fill",
                iconColor: Color(hex: "#52b788"),
                title: "Tell us about\nyour garden",
                subtitle: "Helps us give you the right plant advice."
            )

            VStack(spacing: 16) {
                // Garden type — horizontal chip row
                VStack(alignment: .leading, spacing: 10) {
                    Text("GARDEN TYPE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1.0)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GardenType.allCases, id: \.self) { type in
                                GardenTypeChip(
                                    type: type,
                                    isSelected: userProfile.gardenType == type
                                ) {
                                    withAnimation(.spring(duration: 0.25)) {
                                        userProfile.gardenType = type
                                    }
                                }
                                .accessibilityIdentifier("onboarding_gardentype_\(type.rawValue)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Space size — vertical list, fills remaining height
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR SPACE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1.0)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        ForEach(SpaceSize.allCases, id: \.self) { size in
                            SpaceSizeRow(
                                size: size,
                                isSelected: userProfile.spaceSize == size
                            ) {
                                withAnimation(.spring(duration: 0.25)) {
                                    userProfile.spaceSize = size
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(maxHeight: .infinity) // flex fill
                            .accessibilityIdentifier("onboarding_space_\(size.rawValue)")
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Garden Type Chip (Dark)

private struct GardenTypeChip: View {
    let type: GardenType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color(hex: "#52b788"))
                Text(type.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "#2d6a4f"), Color(hex: "#52b788")],
                                startPoint: .leading, endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.white.opacity(0.05)],
                                startPoint: .leading, endPoint: .trailing
                            )
                    )
                    .overlay(
                        Capsule().stroke(
                            isSelected ? Color.clear : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
    }
}

// MARK: - Space Size Row (Dark)

private struct SpaceSizeRow: View {
    let size: SpaceSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#52b788").opacity(0.20) : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: size.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? Color(hex: "#52b788") : .white.opacity(0.65))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(size.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.30))
                        Text(size.subtitle)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#52b788"))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? Color(hex: "#52b788").opacity(0.10)
                            : Color.white.opacity(0.04)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? Color(hex: "#52b788").opacity(0.35) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.displayName), \(size.subtitle)")
    }
}

extension GardenType {
    var iconName: String {
        switch self {
        case .outdoor: "sun.max.fill"
        case .indoor: "house.fill"
        case .container: "rectangle.3.offgrid.fill"
        case .raised: "rectangle.stack.fill"
        case .hydroponic: "drop.circle.fill"
        case .greenhouse: "leaf.fill"
        case .balcony: "building.2.fill"
        case .windowsill: "window.horizontal"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            GardenSetupView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
```

- [ ] Remove the temporary stub from `OnboardingView.swift`
- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/GardenSetupView.swift \
        GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/OnboardingView.swift
git commit -m "feat(onboarding): garden setup step — dark glass, no scroll, fits viewport"
```

---

### Task 9: Rewrite LocationSetupView — centered permission card, no scroll

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/LocationSetupView.swift`

No benefit list. Single centered card: large icon → title → 1-line why → enable button. Skip link below. When granted, show a success state. Full screen fits with no scrolling.

- [ ] Replace the entire file with:

```swift
import GrowWiseServices
import SwiftUI

struct LocationSetupView: View {
    @Binding var userProfile: UserProfile
    @Environment(LocationService.self) private var locationService
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Central permission card
            VStack(spacing: 28) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#52b788").opacity(0.12))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle().stroke(Color(hex: "#52b788").opacity(0.20), lineWidth: 1)
                        )
                    Circle()
                        .fill(Color(hex: "#52b788").opacity(0.18))
                        .frame(width: 80, height: 80)
                    Image(systemName: "location.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Color(hex: "#52b788"))
                }

                VStack(spacing: 10) {
                    Text("Know your climate")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Get weather-aware care tips and\nseasonal planting guidance.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Granted vs. request state
                if locationService.hasLocationPermission {
                    VStack(spacing: 12) {
                        PermissionGrantedBadge(message: "Location access granted")
                        if let zone = locationService.hardinessZone {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(hex: "#52b788"))
                                Text("Hardiness Zone: \(zone)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 14) {
                        Button(action: requestLocation) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView().scaleEffect(0.85).tint(.white)
                                } else {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isRequesting ? "Requesting…" : "Enable Location")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#2d6a4f"), Color(hex: "#52b788")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(hex: "#2d6a4f").opacity(0.40), radius: 12, y: 4)
                            )
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding_location_enable")

                        Button("Skip for Now") {
                            userProfile.hasLocationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.40))
                        .accessibilityIdentifier("onboarding_location_skip")
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            PrivacyNote(
                icon: "lock.shield.fill",
                text: "Location is only used for gardening features and never shared."
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 90) // above CTA button
        }
        .onAppear { userProfile.hasLocationPermission = locationService.hasLocationPermission }
        .onChange(of: locationService.authorizationStatus) { _, status in
            #if os(iOS)
            userProfile.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
            #elseif os(macOS)
            userProfile.hasLocationPermission = status == .authorizedAlways
            #else
            userProfile.hasLocationPermission = false
            #endif
            isRequesting = false
        }
    }

    private func requestLocation() {
        isRequesting = true
        locationService.requestLocationPermission()
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LocationSetupView(userProfile: .constant(UserProfile()))
    }
}
```

- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/LocationSetupView.swift
git commit -m "feat(onboarding): location step — centered card, no scroll, dark theme"
```

---

### Task 10: Rewrite NotificationPermissionView — centered card, no scroll

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/NotificationPermissionView.swift`

Same layout pattern as Location. Remove benefit list. When authorized, show time picker inside a compact glass card.

- [ ] Replace the entire file with:

```swift
import GrowWiseServices
import SwiftUI

struct NotificationPermissionView: View {
    @Binding var userProfile: UserProfile
    @Environment(NotificationService.self) private var notificationService
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Hero icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E9C46A").opacity(0.10))
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(Color(hex: "#E9C46A").opacity(0.18), lineWidth: 1))
                    Circle()
                        .fill(Color(hex: "#E9C46A").opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Color(hex: "#E9C46A"))
                }

                VStack(spacing: 10) {
                    Text("Never miss a care moment")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Smart reminders keep your plants\nthriving and on schedule.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                if notificationService.isAuthorized {
                    VStack(spacing: 14) {
                        PermissionGrantedBadge(message: "Notifications enabled")

                        // Time picker in glass card
                        VStack(spacing: 8) {
                            Text("Best time for reminders?")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))

                            DatePicker(
                                "Time",
                                selection: $userProfile.preferredNotificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .gwWheelDatePickerStyle()
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxHeight: 120)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 14) {
                        Button(action: requestNotifications) {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView().scaleEffect(0.85).tint(.white)
                                } else {
                                    Image(systemName: "bell.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isRequesting ? "Requesting…" : "Enable Notifications")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#2d6a4f"), Color(hex: "#52b788")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color(hex: "#2d6a4f").opacity(0.40), radius: 12, y: 4)
                            )
                        }
                        .disabled(isRequesting)
                        .accessibilityIdentifier("onboarding_notifications_enable")

                        Button("Maybe Later") {
                            userProfile.hasNotificationPermission = false
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.40))
                        .accessibilityIdentifier("onboarding_notifications_skip")
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            PrivacyNote(
                icon: "moon.fill",
                text: "You can set quiet hours so reminders never interrupt your sleep."
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .onAppear { userProfile.hasNotificationPermission = notificationService.isAuthorized }
        .onChange(of: notificationService.isAuthorized) { _, isAuthorized in
            userProfile.hasNotificationPermission = isAuthorized
            isRequesting = false
        }
    }

    private func requestNotifications() {
        isRequesting = true
        Task {
            let granted = await notificationService.requestNotificationPermissions()
            await MainActor.run {
                userProfile.hasNotificationPermission = granted
                isRequesting = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NotificationPermissionView(userProfile: .constant(UserProfile()))
    }
}
```

- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/NotificationPermissionView.swift
git commit -m "feat(onboarding): notifications step — centered card, no scroll, dark theme"
```

---

### Task 11: Rewrite CompletionView — no scroll, dark, simplified

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/CompletionView.swift`

Remove "next steps" list. Keep: hero checkmark with glow rings + profile summary card (3-4 rows max). No `ScrollView`.

- [ ] Replace the entire file with:

```swift
import SwiftUI

struct CompletionView: View {
    @Binding var userProfile: UserProfile
    @State private var heroVisible = false
    @State private var summaryVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero checkmark
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#52b788").opacity(0.08))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(Color(hex: "#52b788").opacity(0.14))
                        .frame(width: 104, height: 104)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#2d6a4f"), Color(hex: "#52b788")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color(hex: "#2d6a4f").opacity(0.45), radius: 20, y: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.75)

                VStack(spacing: 8) {
                    Text("Your garden awaits!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Everything's set up. Let's grow.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 12)
            }

            Spacer().frame(height: 32)

            // Profile summary card — glass, 3-4 rows
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Color(hex: "#52b788"))
                    Text("Your Profile")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().overlay(Color.white.opacity(0.07))

                CompletionSummaryRow(icon: "graduationcap.fill", iconColor: Color(hex: "#52b788"), label: "Experience", value: userProfile.skillLevel.displayName)

                if let firstGoal = userProfile.goals.first {
                    Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                    CompletionSummaryRow(icon: "scope", iconColor: Color(hex: "#52b788").opacity(0.80), label: "Goal", value: firstGoal.displayName)
                }

                Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                CompletionSummaryRow(icon: "leaf.fill", iconColor: Color(hex: "#52b788").opacity(0.70), label: "Garden", value: userProfile.gardenType.displayName)

                Divider().padding(.leading, 48).overlay(Color.white.opacity(0.06))
                CompletionSummaryRow(icon: "square.grid.2x2.fill", iconColor: Color.white.opacity(0.45), label: "Space", value: userProfile.spaceSize.displayName)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65, bounce: 0.2).delay(0.1)) { heroVisible = true }
            withAnimation(.spring(duration: 0.55).delay(0.55)) { summaryVisible = true }
        }
    }
}

private struct CompletionSummaryRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CompletionView(userProfile: .constant(UserProfile()))
            Spacer().frame(height: 80)
        }
    }
}
```

- [ ] Build and confirm
- [ ] Commit:
```bash
git add GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow/Views/CompletionView.swift
git commit -m "feat(onboarding): completion step — dark glass, no scroll, simplified summary"
```

---

## Chunk 4: Final Build + Push

### Task 12: Full build verification + push

- [ ] Run full build on mac-mini:
```bash
ssh mac-mini "cd ~/Projects/GrowWise && xcodebuild build -scheme GrowWise -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] Check for any remaining references to removed components (`BenefitRow`, `FlexibleView`, `InterestTag`, `FlexibleViewLayout`, `SizePreferenceKey`):
```bash
grep -r "BenefitRow\|FlexibleView\|InterestTag\|SizePreferenceKey" GrowWisePackage/Sources/ --include="*.swift"
```
Expected: No results (or only in files where they're defined to be deleted)

- [ ] If any orphan references exist, remove or update them

- [ ] Close beads issues for this task:
```bash
bd close <issue-id> --reason "Onboarding flow fully redesigned — dark glass, no scroll, 7 steps"
```

- [ ] Final commit + push:
```bash
git push
```

---

## Notes for Implementer

1. **`Color(hex:)` extension** — the codebase already has this via `CultivationTheme`. Confirm with `grep -r "Color(hex:" GrowWisePackage/Sources/` before assuming it exists. If not present, use `Color(red:green:blue:)` literals or add the extension to `CultivationTheme.swift`.

2. **`.gwWheelDatePickerStyle()`** — used in `NotificationPermissionView`. Defined in `ViewModifiers.swift`. Keep this reference; don't replace it.

3. **`.gwPagingTabStyle()`** — used in `OnboardingView`. Keep this reference.

4. **`.gwNavigationBarHidden(true)`** — keep on `OnboardingView`.

5. **No `@Published` or `ObservableObject`** — follow `@Observable` only.

6. **`Color(hex: "#52b788")`** maps to `Color.botanicalLeaf` and `Color(hex: "#2d6a4f")` maps to `Color.botanicalForest`. Either reference is fine since the token definitions already exist in `CultivationTheme`.
