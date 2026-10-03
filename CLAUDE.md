# PPTA – Agent Reference Guide

Everything an agent needs to work on this codebase without asking questions.

*Last verified against HEAD `bdd06cf` plus uncommitted action-messages work (2026-10-02).*

## Where to look

This guide is split so an agent can read the core plus only the section it needs, instead of the
whole thing. The core (this file) has the rules every agent needs regardless of task; everything
else lives in `docs/agent/`.

| Topic | File |
|---|---|
| Agent working rules, project overview, coding conventions, known issues & TODOs, design system | `CLAUDE.md` (this file) |
| File & folder structure | `docs/agent/file-folder-structure.md` |
| Architecture | `docs/agent/architecture.md` |
| App entry point & startup | `docs/agent/app-entry-point.md` |
| View hierarchy | `docs/agent/view-hierarchy.md` |
| Data models | `docs/agent/data-models.md` |
| State management | `docs/agent/state-management.md` |
| Services & Managers API | `docs/agent/services-managers.md` |
| Firebase / Firestore | `docs/agent/firebase-firestore.md` |
| DeviceActivity & ScreenTime | `docs/agent/device-activity.md` |
| Navigation | `docs/agent/navigation.md` |
| Key enums & constants | `docs/agent/key-enums-constants.md` |
| Pre-launch status | `docs/agent/pre-launch-status.md` |

---

## Agent Working Rules

- **Explain before changing**: Before making any code changes, explain the plan and what specifically will change. Get implicit or explicit buy-in.
- **Understand before changing**: Read and fully understand existing code — including *why* it exists — before modifying or deleting it.
- **Use SwiftUI MCPs extensively**: Prefer `mcp__swiftlens__*` tools (swift_get_symbols_overview, swift_get_symbol_definition, swift_find_symbol_references_files, swift_validate_file, etc.) for semantic Swift analysis over raw file reads. Use `mcp__apple-docs__*` for API/framework documentation lookups before implementing anything with Apple frameworks.
- **Comments here carry design rationale.** Many files (`ShieldSharedStore`, `ReinstallDetector`, `PendingCoachRequestStore`, `OnboardingCoordinator`, `DeviceActivityManager`) have long header comments explaining *why* a thing is shaped the way it is, usually because the obvious alternative was a bug. Read them before rewriting.

---

## 1. Project Overview

**PPTA** (Peer Pressure The App) is a peer accountability iOS app for digital wellness and screen time reduction.

**Core loop:**
- Users select apps to monitor and set a daily time limit (e.g., 1h 30m)
- Users invite friends as **coaches** (who can lock/snooze their apps) or **trainees** (who they monitor)
- When a trainee exceeds their limit, coaches are notified and can remotely lock the trainee's apps
- Pressure levels (Off / Standard / Hardcore) control enforcement strictness
- A locked trainee can ask a specific coach to **snooze** the lock, buying 10 minutes of monitored-app usage
- Commitment Streak tracks how long the user has kept their App Limits unchanged

**Users:** Friend groups and accountability pairs; parent-child relationships are a use case but the model is peer-based.

**Platform:** iOS only. SwiftUI. No UIKit (except `UITabBarAppearance` styling in `TabNavigator`).

---

## 13. Coding Conventions

| Concern | Convention |
|---|---|
| Types | PascalCase |
| Properties/functions | camelCase |
| Private | `private` modifier (no `_` prefix) |
| Sections | `// MARK: - SectionName` |
| Async | `async throws` + `try await`, NOT callbacks (new code) |
| Main thread | `Task { @MainActor in ... }` |
| Concurrent Firestore | `withThrowingTaskGroup` |
| State binding | `@StateObject` (owns), `@ObservedObject`/`@EnvironmentObject` (references) |
| Loading | `.task { }` modifier |
| Reactive | `.onChange(of:)`, `.onReceive(manager.$published)` |
| Modals | `.sheet()` / `.fullScreenCover()` |
| Names in copy | always `String.firstNameOnly` |

**Error handling:** `do/catch` with `AuthViewModel.userFacingMessage(for:)` for user-facing messages.
Print statements throughout (debug-only, not removed yet).

**Legacy vs new:** Phone-based `[PeerCoach]` (`coaches`, `trainees`, `peerCoaches`) is the old
system. `coachIds`/`traineeIds` (`[String]` UIDs) is the new one. Both coexist during migration.
Prefer UID-based for any new code.

---

## 14. Known Issues & TODOs

### Dead code (safe to delete, self-documented as such)
| Location | Note |
|---|---|
| `Views/StatusCenter/` (whole folder) | `StatusCenterView`, `TraineeCellView`, `CoachCellView`, `TraineeStatsCardView`, `TraineeStatsRowView` — the Status Center tab is gone. Each file has a header saying so. |
| `Services/MercyRequestService.swift` | Vestigial; exists only so `StatusCenterView` compiles. Deleting the folder above frees this too. |
| `Services/FirestoreService.swift` | Legacy, superseded by the repositories |

### Open issues
| Location | Issue |
|---|---|
| `UserSettings.startDailyStreakDate` | Overloaded — is the Commitment Streak, still named for the daily one. Needs splitting + renaming before Clean Streak ships |
| `Services/UserRespository.swift` | Filename typo (`Respository`); the type is `UserRepository` |
| `TraineeCircleView.swift` | Custom font `SatoshiVariable-Bold_Light` — unclear availability |
| `SettingsView.swift:209` | `inviteBanner` exists but the invite functionality is not implemented |
| `LoginView.swift` | Forgot password button is wired up but the action is empty |
| `AppleSignInService.swift:169,183` | CHECK comments for unverified assumptions |
| Phone normalization | Only handles US 10-digit; international formats may break |
| `MonitoredAppStat` coverage | Partial by design — a name is only learned once the user hits a lock screen for that app. Callers must handle absence |
| Various ViewModels | Debug `print()` statements throughout — not stripped |

---

## 16. Design System Notes

### Theme
- **Primary color**: `Color("primaryColor")` — olive/green, used for interactive elements, text accents, section headers
- **Background gray**: `Color("backgroundGray")` — soft matte fill for inputs and buttons (never use `.secondarySystemBackground` or system fills)
- **Primary button color**: `Color("primaryButtonColor")` — primary CTAs (Release, Save, etc.)
- **Matte button style**: `primaryColor.opacity(0.1)` fill + `primaryColor` text + `cornerRadius: 12` `.continuous`. No borders, no system button styles
- **Capsule pills**: inline actions (Accept/Decline, Pending, Cancel) — `primaryColor` fill for positive, `Color(.systemGray5)` for neutral/destructive
- **Section headers**: `.uppercased()` + `.system(size: 11, weight: .semibold)` + `primaryColor.opacity(0.6)`
- **Initials circles**: `primaryColor.opacity(0.12)` fill + `primaryColor` text — NOT `Color(.tertiarySystemFill)` + `.primary`
- **Cards**: `primaryColor.opacity(0.1)` fill + `RoundedRectangle(cornerRadius: 12, style: .continuous)`. Do NOT use `Color("backgroundGray")` for cards — it has no dark mode variant and disappears on dark backgrounds
- **Custom fonts**: `BambiBold` (headings, ring numbers), `Satoshi-Variable` (body, labels, stats). Use `.custom("BambiBold", size:)` / `.custom("Satoshi-Variable", size:)` with `.fontWeight()`. Registered in both the main app and PPTAReport targets
- **Info popovers**: `questionmark.circle` button + `.popover` with `.presentationCompactAdaptation(.popover)`, ~280pt wide — the standard way inline explanations are done (Home, App Limits)
- **Status color**: orange for `.attentionNeeded`, blue for `.snoozedLock`, red reserved for `cutOff`/errors
- **Portrait only**: locked via `UIInterfaceOrientationPortrait` in project.pbxproj

### Patterns to avoid
- `List` with `.insetGrouped` — looks stock, clashes with custom cards
- `.bordered` / `.borderedProminent` button styles — use custom matte buttons
- `Color(.tertiarySystemFill)` / `Color(.secondarySystemBackground)` for UI cards
- Showing email in friend rows — use name + initials only
- Red for `.attentionNeeded`
- Full display names in notification copy — always `.firstNameOnly`
