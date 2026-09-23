# PPTA – Agent Reference Guide

Everything an agent needs to work on this codebase without asking questions.

*Last verified against `35b0362` (2026-09-20).*

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

## 2. File & Folder Structure

```
PPTAMinimal/
├── PPTAMinimalApp.swift              # Entry point, AppDelegate, root view logic
├── Models/
│   ├── User.swift                    # User struct (id, name, email, phone, fcmToken)
│   ├── UserSettings.swift            # Settings class + PressureLevel + MonitoredAppStat + PeerCoach
│   ├── TraineeStatus.swift           # Enum: allClear | attentionNeeded | cutOff | snoozedLock | noStatus
│   ├── Friendship.swift              # Friendship struct + FriendshipStatus enum
│   ├── RoleRequest.swift             # RoleRequest struct + RoleRequestRole/Status enums
│   ├── StatusCenterPerson.swift      # UI model for coach/trainee cards
│   ├── LocalSettingsStore.swift      # App group bridge (main app ↔ AppMonitor extension)
│   └── ShieldSharedStore.swift       # App group bridge (main app ↔ shield extensions) — Firebase-free
├── Services/
│   ├── AuthService.swift             # Firebase Auth wrapper
│   ├── AppleSignInService.swift      # Apple Sign-In with nonce
│   ├── GoogleSignInService.swift     # Google Sign-In
│   ├── FirestoreService.swift        # Legacy Firestore queries (being replaced by Repositories)
│   ├── UserRespository.swift         # User CRUD (async/await) — NOTE: filename is misspelled
│   ├── UserSettingsRepository.swift  # UserSettings Firestore fetch
│   ├── FriendshipRepository.swift    # Friendship request CRUD
│   ├── RoleRequestRepository.swift   # Role request CRUD (reads Firestore, writes via Cloud Functions)
│   ├── PendingCoachRequestStore.swift# Parks coach requests until a friendship is accepted
│   ├── ReinstallDetector.swift       # Keychain-vs-UserDefaults reinstall detection
│   ├── MercyRequestService.swift     # VESTIGIAL — old broadcast mercy flow, no-ops
│   ├── CloudRunConfig.swift          # Cloud Run URL config
│   └── CloudRunHTTPClient.swift      # HTTP client for Cloud Run endpoints
├── ViewModels/
│   ├── AuthViewModel.swift           # userSession, currentUser, onboarding + reconfigure gating
│   ├── DashboardViewModel.swift      # limitHours, limitMinutes, streakDays
│   ├── FriendsViewModel.swift        # friends, incoming/outgoing requests, real-time listener
│   ├── StatusCenterViewModel.swift   # trainees, coaches, isCurrentUserCutOff (drives Home, not a tab)
│   ├── FriendProfileViewModel.swift  # Friend detail + lock/snooze/role actions
│   └── RoleRequestsInboxViewModel.swift # Incoming + outgoing role requests, real-time listener
├── Managers/
│   ├── DeviceActivityManager.swift   # Monitoring, remote lock/snooze, grace period, ring reset
│   ├── UserSettingsManager.swift     # Singleton: load/save settings to Firestore + app group
│   ├── NotificationManager.swift     # Local notifications + in-app banners
│   └── UnlockService.swift           # HMAC-signed Cloud Run URLs for lock/unlock
├── Views/
│   ├── HomeView.swift                # Setup card, status banner, screen-time ring, coach/trainee grid
│   ├── TabNavigator.swift            # TabView with 2 tabs (Home, Friends)
│   ├── ReportView.swift              # DeviceActivityReport sheet (weekly trend + total activity)
│   ├── ContactsPickerView.swift
│   ├── Auth/                         # LoginView, AppleSignInButton, PhoneView
│   ├── Dashboard/                    # DashboardCellView, SetupCardView, TraineeCircleView, TraineeCoachView
│   ├── Home/                         # NoAppLimits / NoCoaches / NoTrainees / PressureOff empty-state cards
│   ├── StatusCenter/                 # ⚠️ DEAD CODE — see §14
│   ├── Friends/                      # FriendsView, FriendProfileView, FriendProfileSheetView, contact pickers
│   ├── Settings/                     # SettingsView, AppLimitsView, TimeLimitSheetView
│   ├── Onboarding/                   # OnboardingContainerView, OnboardingCoordinator, OnboardingScaffold,
│   │                                 #   IntroKeyView, CreateProfileView, FindCoachView
│   ├── Profile/                      # ProfileView
│   ├── Components/                   # AppAlert, AvatarView, InputView, PrimaryButton, PressureLevelCard,
│   │                                 #   InAppBannerView, PageIndicator, WobblyStroke, ShareSheet, etc.
│   └── Extensions/                   # TraineeStatus+UI.swift (colors/icons)
├── Extensions/
│   ├── String+FirstName.swift        # `.firstNameOnly` — used all over notification copy
│   └── ViewModifiers/BorderedContainer.swift
├── Utilities/StreakCalculator.swift
└── Assets/Assets.xcassets/

AppMonitor/                           # DeviceActivity monitor extension target
└── DeviceActivityMonitorExtension.swift

PPTAShieldConfiguration/              # Shield UI extension target (the lock screen)
└── ShieldConfigurationExtension.swift

PPTAShieldAction/                     # Shield button-tap extension target
└── ShieldActionExtension.swift

PPTAReport/                           # ScreenTime report extension target
├── PPTAReport.swift                  # Registers the three scenes
├── ScreenTimeActivityReport.swift    # ActivityReport / AppDeviceActivity / WeeklyReport / RingSession
├── TotalActivityReport.swift         # .totalActivity scene
├── SummaryRingReport.swift           # .summaryRing scene
├── WeeklyTrendReport.swift           # .weeklyTrend scene
└── TotalActivityView.swift           # ProgressRingView, AppActivityRow, ReportSectionHeader

docs/                                 # onboarding-redesign.md, onboarding-asset-prompts.md
scripts/                              # check-onboarding-assets.py, import-onboarding-assets.py
```

**Xcode targets (7):** `PPTAMinimal`, `AppMonitor`, `PPTAReport`, `PPTAShieldConfiguration`, `PPTAShieldAction`, `PPTAMinimalTests`, `PPTAMinimalUITests`.

---

## 3. Architecture

**Pattern:** MVVM + SwiftUI with singletons for cross-cutting concerns.

| Layer | Type | Examples |
|---|---|---|
| Models | Codable structs/classes | User, UserSettings, Friendship, RoleRequest |
| Repositories | Async/await Firestore CRUD | UserRepository, FriendshipRepository |
| ViewModels | @ObservableObject + @Published | AuthViewModel, FriendsViewModel, StatusCenterViewModel |
| Managers | Singletons | UserSettingsManager, DeviceActivityManager, NotificationManager |
| Views | SwiftUI only | All in Views/ |

**Framework stack:**
- SwiftUI (all UI)
- Firebase Auth, Firestore, Cloud Messaging (FCM), Storage (profile images)
- FamilyControls + DeviceActivity + ManagedSettings + ManagedSettingsUI (ScreenTime)
- CryptoKit (HMAC-SHA256 for Cloud Run request signing)
- Security / Keychain (reinstall detection)
- Combine (reactive bindings between managers and viewmodels)

### Target isolation rule (important)

The **shield extensions must stay Firebase-free.** `ShieldSharedStore.swift` carries the full
rationale: shield processes are short-lived and memory-capped, and `UserSettings` drags in
FirebaseFirestore via `@DocumentID`. Anything crossing into `PPTAShieldConfiguration` /
`PPTAShieldAction` is Foundation + ManagedSettings only. That's why the App Group ID is spelled out
in both `LocalSettingsStore` and `ShieldSharedStore` rather than shared.

Files compiled into **multiple** targets: `ShieldSharedStore.swift`, `TraineeStatus.swift`,
`LocalSettingsStore.swift`, and the `UnlockGrace` / `LimitEvent` / `LockCause` enums out of
`DeviceActivityManager.swift`.

---

## 4. App Entry Point & Startup

**File:** `PPTAMinimal/PPTAMinimalApp.swift`

**AppDelegate responsibilities:**
- `didFinishLaunchingWithOptions`: Firebase init, **unconditional** APNs registration (required for Phone Auth silent push regardless of notification permission), notification permission request, FCM delegate
- `didRegisterForRemoteNotificationsWithDeviceToken`: APNs token → Auth (`.sandbox` in DEBUG, `.prod` otherwise) + Messaging
- `didReceiveRemoteNotification`: dispatches all FCM types (see §9)
- `userNotificationCenter(willPresent:)`: syncs pending extension status when a local notification fires in foreground
- `messaging(_:didReceiveRegistrationToken:)`: FCM token registration

**Root view decision tree:**
```
AuthViewModel.userSession == nil            →  LoginView
!viewModel.isOnboardingComplete             →  OnboardingContainerView()            (fresh flow)
viewModel.needsScreenTimeReconfigure        →  OnboardingContainerView(reconfigure: true)
otherwise                                   →  TabNavigator
```

**Onboarding completion key:** `"onboardingComplete_<uid>"` in UserDefaults (per-user; a one-time
migration folds the old device-wide `"onboardingComplete"` key into it).
**Resume key:** `"onboardingStep_<uid>"` — the current step, cleared on completion.

**On every `scenePhase == .active`:**
1. `UserSettingsManager.applyPendingStatusIfNeeded()` — consume extension status writes
2. `UserSettingsManager.refreshSharedAppStatsIfNeeded()` — pull app names/block counts the shield harvested
3. `PendingCoachRequestStore.drainUsingCurrentFriendships()` — fire parked coach requests

---

## 5. View Hierarchy

```
PPTAMinimalApp
├── LoginView
├── OnboardingContainerView  (OnboardingCoordinator state machine)
│   ├── IntroKeyView
│   ├── CreateProfileView          (skipped when Apple/Google supplied a display name)
│   ├── AppLimitsView              (shared with Settings — apps + limit + pressure)
│   ├── FindCoachView              (ContactsPicker; the only skippable step)
│   └── .completed
└── TabNavigator                    (TabView, 2 tabs)
    ├── HomeView                            tag 0, badged with attentionNeeded trainee count
    │   ├── ProfileView                     (header)
    │   ├── SetupCardView                   → NoAppLimits / NoCoaches / NoTrainees / PressureOff cards
    │   ├── statusCard                      (status banner)
    │   ├── reportSection                   (Commitment Streak + inline DeviceActivityReport ring)
    │   │   └── ReportView                  (sheet)
    │   └── TraineeCoachView                (coach/trainee grid of TraineeCircleView)
    │       └── FriendProfileSheetView      (sheet)
    └── FriendsView                         tag 1, badged with incoming friend + role requests
        ├── FriendsContactsImportView / FriendsContactsPickerView
        ├── Role request cards (Accept/Decline)
        ├── Incoming friend request cards
        ├── Pending outgoing cards (friend + coach/trainee, cancellable)
        └── FriendProfileView / FriendProfileSheetView

Global overlay: InAppBannerView (from NotificationManager, on TabNavigator)

Sheets:
- ReportView (HomeView)
- SettingsView → AppLimitsView → TimeLimitSheetView
- FriendProfileSheetView (Home, Friends)
- PhoneVerificationView (Onboarding, at the findCoach step only)
```

**There is no Status Center tab.** It was removed; `Views/StatusCenter/` is dead code (§14).
`StatusCenterViewModel` survives and is very much alive — it backs `TraineeCoachView` on Home
via `@EnvironmentObject`, injected by `TabNavigator`.

---

## 6. Data Models

### PressureLevel
```swift
enum PressureLevel: String, Codable, CaseIterable {
    case off = "Off", standard = "Standard", hardcore = "Hardcore"
    var isTracking: Bool { self != .off }
    init(decodingFirestore raw: String)   // maps legacy "Chill"/"Coach"→standard, "Hard"→hardcore
}
```
It is a real enum now, **not** a `String`. Always decode via `init(decodingFirestore:)`.

### User
```swift
struct User: Identifiable, Codable, Equatable {
    let id: String           // Firebase UID
    let name: String
    let email: String
    var phoneNumber: String? // Normalized to 10 digits (US)
    var fcmToken: String?
    var initials: String { /* computed */ }
}
```

### UserSettings
```swift
final class UserSettings: Codable {
    @DocumentID var id: String?
    var applications: FamilyActivitySelection
    var thresholdHour: Int
    var thresholdMinutes: Int
    var pressureLevel: PressureLevel        // Firestore CodingKey: "selectedMode"
    var onboardingCompleted: Bool
    var peerCoaches/coaches/trainees: [PeerCoach]   // Legacy phone-based (migrating out)
    var coachIds: [String]                  // New: UID-based
    var traineeIds: [String]                // New: UID-based
    var profileImageURL: URL?
    var startDailyStreakDate: Date?         // now backs the COMMITMENT streak — see below
    var isTracking: Bool                    // derived from pressureLevel, on decode and on save
    var traineeStatus: TraineeStatus
    var lockedByUID: String?                // coach who currently has them locked
    var lockedByName: String?
    var snoozeRequestedCoachIds: [String]   // coaches this cut-off user has asked for a snooze
    var monitoredAppNames: [String]         // harvested by the shield extension
    var monitoredAppStats: [MonitoredAppStat]

    static func appLimitsAreViable(thresholdHour:thresholdMinutes:applications:) -> Bool
    var hasViableAppLimits: Bool            // limit > 0 AND ≥1 app or category
}

struct MonitoredAppStat: Codable, Hashable, Identifiable {
    let name: String
    let blocks30d: Int
}
```

Decoding is deliberately defensive — every field is `try?` with a fallback, because live Firestore
docs predate most of these keys.

**`startDailyStreakDate` is mid-refactor.** It is now the **Commitment Streak**: days since the user
last changed their App Limits, reset in `AppLimitsView.saveToFirebase`. Hitting your limit no longer
resets it. A future **Clean Streak** (days since last cut off) needs its own field; at that point
this should be renamed (e.g. `limitsSetAt`).

### TraineeStatus
```swift
enum TraineeStatus: String, Codable, Hashable {
    case allClear           // Within limit
    case attentionNeeded    // Standard-mode limit reached; coaches decide
    case cutOff             // Locked (Hardcore auto-lock, coach lock, or snooze expiry)
    case snoozedLock        // Coach granted a 10-minute grace window; re-locks on expiry
    case noStatus           // pressureLevel == .off
}
```

### Friendship / RoleRequest
```swift
enum FriendshipStatus: String, Codable { case pending, accepted, declined }
struct Friendship: Identifiable, Codable {
    var id, requesterId, requesteeId: String
    var status: FriendshipStatus
    var createdAt: Date
}

enum RoleRequestRole: String, Codable { case coach, trainee }
enum RoleRequestStatus: String, Codable { case pending, accepted, declined, cancelled }
struct RoleRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let requesterId, targetId: String
    let role: RoleRequestRole
    let status: RoleRequestStatus
    let createdAt, resolvedAt: Date?
}
```

⚠️ **`RoleRequestRole` describes the REQUESTER's role, not the target's.** To ask someone to coach
you, send `.trainee`. Getting this backwards inverts every relationship the flow creates. See
`RoleRequestRepository.removeRelationship` and `FriendProfileViewModel.performCoachPrimary()`.

---

## 7. State Management

```
Firestore / App Group
      ↓
UserSettingsManager (@Published var userSettings)
      ↓ (Combine binding / .onReceive)
DashboardViewModel, StatusCenterViewModel, HomeView, AppLimitsView
      ↓ (@Published properties)
SwiftUI Views (auto re-render)
```

**AuthViewModel** (`AuthViewModel.shared` singleton, also injected as `@EnvironmentObject`):
- `userSession`, `currentUser` — drive the root switch
- `isOnboardingComplete` — per-uid flag, mirrored as `@Published`
- `needsScreenTimeReconfigure` — set when `ReinstallDetector` / auth flow finds a set-up account whose Screen Time authorization didn't survive
- `markOnboardingComplete()`, `deleteAccount()`, `deleteIncompleteAccount()`, `userFacingMessage(for:)`

**StatusCenterViewModel**: `trainees`, `coaches` (`[StatusCenterPerson]`), `isCurrentUserCutOff`,
plus real-time per-trainee Firestore listeners and `performAction(url:traineeId:)` for lock/release.

**FriendProfileViewModel**: the big one — `traineeStatus`, `pressureLevel`, `lockedByName`,
`isRequestingSnoozeFromMe`, `iAmCutOff`, `iHaveRequestedSnoozeFromThem`, `monitoredAppStats`,
`coachAction`/`traineeAction` (`ActionConfig`), plus `performLock`, `performUnlock`,
`requestSnooze`, `unfriend`, and the role-request primaries/secondaries.

**RoleRequestsInboxViewModel**: `incoming` **and** outgoing pending, both live.

### Persistence layers
1. **Firestore**: `users`, `userSettings`, `friendships`, `roleRequests`
2. **App Group UserDefaults** (`group.com.sungbinyun.com.PPTADev`): UserSettings, current uid, pending status, ring reset timestamp, learned app names + block counts, shield context
3. **Device UserDefaults**: `onboardingComplete_<uid>`, `onboardingStep_<uid>`, `pendingCoachRequests_<uid>`, `ringResetAt`, `ppta.installMirrorPresent`
4. **Keychain**: `com.sungbinyun.PPTA.install` / `installMarkerUID` — survives uninstall, powers reinstall detection

---

## 8. Services & Managers API

### UserRepository (`Services/UserRespository.swift`)
`fetchUser(by:)`, `findUserByPhone(_:)`, `saveUser(_:)`, `userExists(_:)`,
`updateUserField(uid:field:value:)`, `normalizePhoneNumber(_:)` (static).

### FriendshipRepository
`sendFriendRequest(from:to:)`, `acceptRequest(_:)`, `declineOrCancelRequest(_:)`,
`fetchIncomingRequests(for:)`, `fetchOutgoingRequests(for:)`, `fetchAcceptedFriendships(for:)`,
`areFriends(_:_:)`.

### RoleRequestRepository
Reads hit Firestore; **writes go through Cloud Functions**:
`fetchIncomingPending(for:)`, `fetchOutgoingPending(for:)`, `deleteAllInvolving(uid:)`,
`createRoleRequest(targetId:role:)`, `accept(id:)`, `decline(id:)`, `cancel(id:)`,
`removeRelationship(otherId:role:)`.

### PendingCoachRequestStore
Role requests can't be sent to strangers — the client and server both require an accepted
friendship. Onboarding asks anyway, so the coach request is **parked** here and fires when the
friendship lands. `queue(_:)`, `pending()`, `remove(_:)`, `clear()`, `drain(acceptedFriendIds:)`,
`drainUsingCurrentFriendships()`. Drained by `FriendsViewModel.refresh()` and on foreground.

### ReinstallDetector
`handleAuthenticated(uid:)`, once per launch. Keychain marker survives uninstall; the UserDefaults
mirror doesn't — marker present + mirror gone = reinstall. Reports to coaches via
`DeviceActivityManager.sendReinstallNotice(uid:)` only when the **same** uid returns.

### UserSettingsManager (singleton)
`loadSettings(completion:)`, `loadSettingsSyncFromDefaults()`, `saveSettings(_:)`,
`update(_ transform:)`, `applyPendingStatusIfNeeded()`, `refreshSharedAppStatsIfNeeded()`
(resolves App-Group-harvested names/counts into `monitoredAppNames`/`monitoredAppStats`).

### DeviceActivityManager (singleton)
- `startDeviceActivityMonitoring(appTokens:hour:minute:completion:)` — arms `LimitEvent.reached` plus the tiered warnings
- `stopMonitoring()` — stops the daily `AppUsageMonitoring` activity **only**; grace survives
- `stopAllMonitoring()` — teardown, including grace (use for Off)
- `handleRemoteLock(from:coachUID:)` / `handleRemoteUnlock(from:coachUID:)`
- `cancelUnlockGracePeriod()`
- `sendMercyRequest(uid:targetCoach:)`, `sendSettingsChanged(uid:change:)`, `sendReinstallNotice(uid:)`
- `static markRingReset()` — stamps `ringResetAt` in both UserDefaults and the App Group

### UnlockService
`makeUnlockURL(childUID:coachUID:)`, `makeLockURL(childUID:coachUID:)` — HMAC-SHA256.
Signature message: `"<uid>|<coach>|<timestamp>"`.

### NotificationManager (singleton)
`showInAppMessage(title:body:dismissAfter:)`, `sendNotification(title:body:)`, `requestAuthorization()`.

### MercyRequestService — vestigial
The `mercyRequests` collection is no longer written. Both helpers query an empty collection and are
no-ops, kept only so the dead `StatusCenterView` still compiles. Don't build on it; per-coach
snoozes live in `UserSettings.snoozeRequestedCoachIds`.

---

## 9. Firebase / Firestore

### Collections

| Collection | Doc ID | Key Fields |
|---|---|---|
| `users` | Firebase UID | id, name, email, phoneNumber, fcmToken |
| `userSettings` | Firebase UID | applications, thresholdHour, thresholdMinutes, **selectedMode** (= pressureLevel), coachIds, traineeIds, isTracking, traineeStatus, startDailyStreakDate, lockedByUID, lockedByName, snoozeRequestedCoachIds, monitoredAppNames, monitoredAppStats |
| `friendships` | Auto | requesterId, requesteeId, status, createdAt |
| `roleRequests` | Auto | requesterId, targetId, role, status, createdAt, resolvedAt |
| `mercyRequests` | — | **dead**, no longer written |

**Important:** `pressureLevel` is stored under the key `"selectedMode"` (CodingKeys migration artifact).

### Auth providers
Email/password, Google OAuth, Apple OAuth. (Phone is verification-only, not a sign-in provider.)

### FCM notification types (all handled in `AppDelegate.didReceiveRemoteNotification`)

| `type` | Effect |
|---|---|
| `unlock` | `handleRemoteUnlock(from:coachUID:)` — clears shield, arms grace |
| `lock` | `handleRemoteLock(from:coachUID:)` |
| `traineeStatus` | Local notification to the coach; copy chosen by `status` + `cause` (see `LockCause`), with "You…" when `by` is the receiving coach |
| `traineeReinstalled` | Local notification: trainee deleted + reinstalled the app |
| `roleRequestReceived` | Local notification: someone wants to be your coach/trainee |
| `roleRequestAccepted` | Local notification: your request was accepted |
| `relationshipsChanged` | **Silent** — just reloads settings so stale coaches/trainees disappear |

Notification copy lives **app-side**, not on the server, so it can be reworded without a redeploy.
All names run through `String.firstNameOnly`.

### Cloud Run endpoints
- **Unlock:** `https://unlockapp-iy4j75c7pq-uc.a.run.app`
- **Lock:** `https://lockapp-iy4j75c7pq-uc.a.run.app`
- **Status update:** `https://statusupdate-538124351649.us-central1.run.app`
- **Shared HMAC secret:** `"a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"` (raw string bytes, not hex-decoded)

`statusUpdate` signs `"<uid>|<status>|<ts>"`, or `"<uid>|<status>|<ts>|<cause>"` when a `LockCause`
is present. `LockCause` raw values are mirrored server-side as `LOCK_CAUSE`.

---

## 10. DeviceActivity & ScreenTime

### Monitoring setup (DeviceActivityManager)
- Daily activity name: `AppUsageMonitoring`; schedule 00:00–23:59:59, repeating (no `warningTime`)
- Events include **both** `applicationTokens` AND `categoryTokens`
- `isMonitoringActive` is cross-checked against `DeviceActivityCenter().activities` on every start, so a device restart or OS suspension can't permanently block restarts
- Shielding: `ManagedSettingsStore().shield.applications`

### Tiered limit warnings (`enum LimitEvent`)
Events armed by `warningThresholds(forLimitMinutes:)`, in minutes of cumulative usage:

| Daily limit | Events armed |
|---|---|
| `< 2` | none |
| `2...4` | 2-minute |
| `5...10` | halfway + 2-minute |
| `> 10` | halfway + 5-minute + 2-minute |

A tier is emitted only when its threshold lands in `1 ..< limit`. These are **trainee-only nudges**:
local notification, no status change, no shield, no backend call.

`eventWillReachThresholdWarning` is now an explicit **no-op**. It depended on the schedule's
`warningTime` (never set), fired unreliably, and used to flip trainees to `.attentionNeeded` before
they'd actually hit the limit — telling coaches they were in trouble early.

### Snooze / unlock grace period (`enum UnlockGrace`)
When a coach releases a trainee, `handleRemoteUnlock` clears the shield and arms a **second**
DeviceActivity activity (`UnlockGracePeriod`) with a `graceExpired` event at 10 minutes. The
threshold measures **monitored-app usage, not wall clock** — the grace only burns down while the
trainee is actually in the shielded apps. On expiry the extension re-shields in every mode and sets
`.cutOff` with `cause: .snoozeEnded`, so the trainee reappears to their coaches with Release enabled
again — coaches can release repeatedly, 10 minutes at a time. During the window the status is
`.snoozedLock`.

Three non-obvious constraints, all easy to reintroduce as bugs:
- **`stopMonitoring()` must never stop the grace activity.** A trainee mid-grace reads as unlocked, so `AppLimitsView`'s `guard !isLocked` lets their save through; if that save stopped every activity, tapping Save would cancel their own re-lock and leave them unlocked all day. Use `stopAllMonitoring()` only for teardown and for Off.
- The grace schedule **must start at `now`**, not midnight. Thresholds count usage from the interval's start, so a midnight-anchored interval is already past 10 minutes and fires instantly. The interval ends one minute *before* it starts, wrapping around midnight to a ~24h window that clears the system's undocumented ~15-minute minimum.
- Every `intervalDidStart` / `intervalDidEnd` / `eventWillReachThresholdWarning` override must ignore `UnlockGrace.activityName`, or the grace activity's own interval boundaries clear the shield or fire spurious status updates.

### Extension event handlers (`AppMonitor/DeviceActivityMonitorExtension.swift`)

| Event | Off | Standard | Hardcore |
|---|---|---|---|
| `intervalDidStart` | (guarded by `isTracking`) | status → allClear, **at most once per calendar day** | same |
| `intervalDidEnd` | — | clear shield | same |
| `LimitEvent` warnings | — | local notification only | same |
| `LimitEvent.reached` | — | status → attentionNeeded + local notif | shield apps, status → cutOff (`cause: .hardcoreLimit`) |
| `graceExpired` (UnlockGrace) | n/a | re-shield, status → cutOff (`cause: .snoozeEnded`) | same |

The once-per-day allClear guard (`lastAllClearSentDate` in the App Group) exists because
`intervalDidStart` fires at genuine midnight **and** on every monitoring restart; without it each
restart spammed the coaches.

Hitting the limit passes `resetStartDate: nil` — `startDailyStreakDate` is the Commitment Streak now,
so a cutoff must not reset it.

### The screen-time ring reset marker
`DeviceActivityManager.ringResetKey` = `"ringResetAt"`, written to both `UserDefaults.standard`
(drives `@AppStorage` + `.id()` refresh) and the App Group (read by the report extension's
`RingSession`). Stamped **only** by App Limits / Pressure saves via `markRingReset()`.

It is deliberately **not** tied to the monitoring start/stop lifecycle. That coupling was the
"ring reads 0 after launch" bug: a cold launch briefly sees blank default settings
(`isTracking == false`), tears monitoring down, re-arms it, and used to re-stamp the baseline at
launch time — hiding the day's earlier usage. On days without a settings change the ring just shows
the full-day API value, which self-resets at midnight.

### Shield extensions
- **`PPTAShieldConfiguration`** draws the lock screen and is the *only* process that can read `localizedDisplayName` off a token. It harvests names into the App Group as it draws (`AppNameStore.record`) and counts bounce-offs (`noteBlockAttempt`, bucketed per day, 30-day retention). The main app can never resolve these itself.
- **`PPTAShieldAction`** handles taps. Primary → `.close`. Secondary ("Ask my coach for more time") → posts a local notification (`ShieldHandoff.askCoachIdentifier`) and returns `.defer`, keeping the shield up. A shield extension can't open the app or reach Firestore, so the notification's *tap* is the bridge in; the actual snooze request is made per-coach from that coach's profile.
- `ShieldContext` (in `ShieldSharedStore`) carries the slice of state the shield needs for specific copy: `lockedByName`, `isHardcore`, `streakStart`, `hasCoaches`. All primitives — see the target isolation rule in §3.

`AppNameStore.storageKey(for:)` derives its key from the token's `Codable` encoding, **never
`hashValue`** — Swift seeds hashing randomly per process, so an extension-written key would never
match one computed in the app.

### App group bridge (LocalSettingsStore)
- App group ID: `group.com.sungbinyun.com.PPTADev`
- `save(_:)` / `load()`, `saveCurrentUserId(_:)` / `loadCurrentUserId()`
- `savePendingStatus(_:resetStartDate:)` / `consumePendingStatus()`
- Main app calls `applyPendingStatusIfNeeded()` on app launch (HomeView.onAppear), on every foreground (scenePhase), and when a local notification presents in foreground

### ScreenTime report (PPTAReport extension)

| Context | Raw value | Filter | View | Purpose |
|---|---|---|---|---|
| `.totalActivity` | `"Total Activity"` | `.hourly()` today | `TotalActivityView` | Progress ring + hourly chart + per-app list |
| `.weeklyTrend` | `"Weekly Trend"` | `.daily()` last 7 days | `WeeklyTrendView` | 7-day bar chart |
| `.summaryRing` | `"Summary Ring"` | `.daily()` today | `SummaryRingView` | Ring only — inline on HomeView |

`HomeView.reportSection` shows the inline `"Summary Ring"`; tapping opens `ReportView`, which stacks
`.weeklyTrend` above `.totalActivity`.

**Fonts in PPTAReport**: `X_BAMBI.TTF` and `Satoshi-Variable.ttf` are in the target (via
`membershipExceptions` in project.pbxproj) and registered in `PPTAReport/Info.plist` under
`UIAppFonts`. Named colors from the main asset catalog are **not** available in extensions —
`primaryColor` is hardcoded via `Color.appPrimary(_:)` in `TotalActivityView.swift`:
`rgb(68, 86, 46)` light / `rgb(141, 147, 136)` dark.

---

## 11. Navigation

### Root switches
Auth → `AuthViewModel.userSession`; onboarding → `AuthViewModel.isOnboardingComplete`;
reconfigure → `AuthViewModel.needsScreenTimeReconfigure`.

### Onboarding (`OnboardingCoordinator`)
Order lives in `coordinator.steps`, **not** in a hand-written `advance()` switch — `PageIndicator`
derives its position from the same array, so dots can't drift out of sync.

```
.fresh flow:        intro → profile → appLimits → findCoach → completed
                    (profile dropped entirely when the user already has a display name)
.reconfigure flow:  appLimits only
```

- `advance()` / `goBack()` walk `steps`; `isGoingBack` drives the slide direction
- The step is persisted per-uid so an abandoned run resumes; **completion is not** — the `onboardingComplete_<uid>` flag is written only at the end of `findCoach`
- **There is no global Skip.** It used to mark onboarding complete without Screen Time permission, app selection, or a limit — an account that looks set up but can't monitor anything. Only the final step is skippable, and it says so.
- `PhoneVerificationView` appears only at the `findCoach` step, where the phone number actually matters (contact matching). It used to pop over any step the moment `currentUser` loaded, with `interactiveDismissDisabled(true)` making it an unskippable wall.

**Reconfigure flow:** Screen Time authorization doesn't survive an uninstall, but the Firestore
account does. Rather than replaying onboarding, a returning user re-grants Screen Time and
re-confirms apps + limit/pressure. Coaches and trainees are untouched.

### Main app (TabNavigator)
Tab 0 Home, tab 1 Friends. Both badged. `AppLimitsView` is shared verbatim between Settings and
the onboarding `appLimits` step.

---

## 12. Key Enums & Constants

```swift
// PressureLevel (Firestore key "selectedMode")
.off        // No monitoring, status = noStatus
.standard   // Coaches see status, can lock remotely
.hardcore   // Auto-lock at threshold. Coaches CAN still snooze — autolock is the only
            // difference from Standard (plus the app-limit edit lock while cut off).

// TraineeStatus: allClear | attentionNeeded | cutOff | snoozedLock | noStatus

// LockCause (mirrored server-side as LOCK_CAUSE)
.hardcoreLimit   // Hardcore auto-lock at the limit, no coach involved
.coach           // a coach locked or snoozed them — `by` names them
.snoozeEnded     // the grace timer ran out and re-locked them

// DeviceActivityName
"AppUsageMonitoring"   // DeviceActivityManager.dailyActivityName
"UnlockGracePeriod"    // UnlockGrace.activityName

// DeviceActivityEvent.Name
"timeLimitReached" | "limitHalfwayWarning" | "limitFiveMinuteWarning"
"limitTwoMinuteWarning" | "graceExpired"

UnlockGrace.durationMinutes = 10
AppNameStore.retentionDays  = 30

// App group
"group.com.sungbinyun.com.PPTADev"

// HMAC secret (DeviceActivityManager, UnlockService, AppMonitor extension)
"a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"

// UserDefaults keys
"onboardingComplete_<uid>" | "onboardingStep_<uid>" | "pendingCoachRequests_<uid>"
"ringResetAt" | "ppta.installMirrorPresent" | "lastAllClearSentDate" (app group)
"shield.context" | "shield.appName.<key>" | "shield.blockAttempts.<key>" (app group)
```

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

## 15. Pre-launch Status

### Done
- Auth (email/password, Google, Apple) + account deletion
- Friend requests; role requests with live incoming **and** outgoing/cancellable rows
- UID-based coach-trainee relationships
- DeviceActivity monitoring with tiered limit warnings
- Pressure levels (Off/Standard/Hardcore), consolidated into App Limits
- Custom shield lock screen (`PPTAShieldConfiguration`) + "Ask my coach" handoff (`PPTAShieldAction`)
- Per-app block-attempt stats surfaced on the coach's profile view
- Remote lock + per-coach snooze (10 min of monitored usage), with `LockCause` attribution
- Trainee status tracking (all 5 states)
- Commitment Streak
- Reinstall detection + coach notification
- System notifications for all coach/trainee events
- ScreenTime report (3 scenes) + settings-change-anchored ring reset
- Onboarding (5 steps, resumable, per-user) + trimmed post-reinstall reconfigure flow
- Contacts import; profile image upload (Settings)
- App group bridges (main app ↔ AppMonitor, main app ↔ shield extensions)

### Partially Done
- Phone number flows (legacy phone sign-in; UID migration in progress)
- Streak model — Commitment Streak ships, **Clean Streak is stubbed in the UI copy only** ("Coming soon")
- Extension ↔ main app sync (working, but untested under edge cases)

### Not Started / Missing
- Forgot password flow
- Clean Streak (days since last cut off) — needs its own field
- Invite flow (banner exists, does nothing)
- International phone number support
- Unit tests (`PPTAMinimalTests` empty) and UI tests (`PPTAMinimalUITests` empty)
- Offline-first sync (fully Firestore-dependent)

### Overall status
**Pre-beta.** Core loop is functional end-to-end including the shield and snooze flows. Blockers
before first TestFlight: forgot password, the streak field split, and deleting the dead Status
Center folder. The UID-based relationship model is the future; avoid adding to the legacy
phone-based system.

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
