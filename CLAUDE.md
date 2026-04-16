# PPTA – Agent Reference Guide

Everything an agent needs to work on this codebase without asking questions.

## Agent Working Rules

- **Explain before changing**: Before making any code changes, explain the plan and what specifically will change. Get implicit or explicit buy-in.
- **Understand before changing**: Read and fully understand existing code — including *why* it exists — before modifying or deleting it.
- **Use SwiftUI MCPs extensively**: Prefer `mcp__swiftlens__*` tools (swift_get_symbols_overview, swift_get_symbol_definition, swift_find_symbol_references_files, swift_validate_file, etc.) for semantic Swift analysis over raw file reads. Use `mcp__apple-docs__*` for API/framework documentation lookups before implementing anything with Apple frameworks.

---

## 1. Project Overview

**PPTA** (Peer Pressure The App) is a peer accountability iOS app for digital wellness and screen time reduction.

**Core loop:**
- Users select apps to monitor and set a daily time limit (e.g., 1h 30m)
- Users invite friends as **coaches** (who can lock/unlock apps) or **trainees** (who they monitor)
- When a trainee exceeds their limit, coaches are notified and can remotely lock the trainee's apps
- Pressure levels (Off / Standard / Hardcore) control enforcement strictness
- Daily streaks track accountability progress; streaks reset on cutoff events

**Users:** Friend groups and accountability pairs; parent-child relationships are a use case but the model is peer-based.

**Platform:** iOS only. SwiftUI. No UIKit.

---

## 2. File & Folder Structure

```
PPTAMinimal/
├── PPTAMinimalApp.swift              # Entry point, AppDelegate, root view logic
├── Models/
│   ├── User.swift                    # User struct (id, name, email, phone, fcmToken)
│   ├── UserSettings.swift            # Settings class (apps, limits, pressureLevel, coachIds/traineeIds, status, streak)
│   ├── TraineeStatus.swift           # Enum: allClear | attentionNeeded | cutOff | noStatus
│   ├── Friendship.swift              # Friendship struct + FriendshipStatus enum
│   ├── RoleRequest.swift             # RoleRequest struct + RoleRequestRole/Status enums
│   ├── StatusCenterPerson.swift      # UI model for status center cards
│   └── LocalSettingsStore.swift      # App group bridge (main app ↔ extension)
├── Services/
│   ├── AuthService.swift             # Firebase Auth wrapper
│   ├── AppleSignInService.swift      # Apple Sign-In with nonce
│   ├── GoogleSignInService.swift     # Google Sign-In
│   ├── FirestoreService.swift        # Legacy Firestore queries (being replaced by Repositories)
│   ├── UserRepository.swift          # User CRUD (async/await)
│   ├── UserSettingsRepository.swift  # UserSettings Firestore fetch
│   ├── FriendshipRepository.swift    # Friendship request CRUD
│   ├── RoleRequestRepository.swift   # Role request CRUD
│   ├── CloudRunConfig.swift          # Cloud Run URL config
│   └── CloudRunHTTPClient.swift      # HTTP client for Cloud Run endpoints
├── ViewModels/
│   ├── AuthViewModel.swift           # userSession, currentUser; sign in/up/out
│   ├── DashboardViewModel.swift      # limitHours, limitMinutes, streakDays
│   ├── FriendsViewModel.swift        # friends, incoming/outgoing requests, real-time listener
│   ├── StatusCenterViewModel.swift   # trainees, coaches, isCurrentUserCutOff
│   ├── FriendProfileViewModel.swift  # Individual friend detail
│   └── RoleRequestsInboxViewModel.swift # Incoming role requests with real-time listener
├── Managers/
│   ├── DeviceActivityManager.swift   # DeviceActivity monitoring, remote lock/unlock
│   ├── UserSettingsManager.swift     # Singleton: load/save settings to Firestore + app group
│   ├── NotificationManager.swift     # Local notifications + in-app banners
│   └── UnlockService.swift           # HMAC-signed Cloud Run URLs for lock/unlock
├── Views/
│   ├── HomeView.swift                # Dashboard: profile, stats, streak, report button
│   ├── TabNavigator.swift            # TabView with 3 tabs
│   ├── ReportView.swift              # DeviceActivityReport (ScreenTime API)
│   ├── Auth/                         # LoginView, RegistrationView, AppleSignInButton, PhoneView
│   ├── Dashboard/                    # DashboardView, DashboardCellView, TraineeCircleView, TraineeCoachView
│   ├── StatusCenter/                 # StatusCenterView, TraineeCellView, CoachCellView, stats views
│   ├── Friends/                      # FriendsView, FriendProfileView, FriendProfileSheetView, contact pickers
│   ├── Settings/                     # SettingsView, PressureLevelView, AppLimitsView, TimeLimitSheetView
│   ├── Onboarding/                   # OnboardingContainerView, OnboardingCoordinator, 7 step views
│   ├── Profile/                      # ProfileView, EditProfileView
│   ├── Components/                   # InputView, PrimaryButton, InAppBannerView, PageIndicator, etc.
│   └── Extensions/                   # TraineeStatus+UI.swift (colors/icons)
├── Extensions/
│   └── ViewModifiers/
│       └── BorderedContainer.swift
├── Utilities/
│   └── StreakCalculator.swift
└── Assets/Assets.xcassets/

AppMonitor/                           # DeviceActivity extension target
├── DeviceActivityMonitorExtension.swift
└── SettingsLoader.swift

PPTAReport/                           # ScreenTime report extension target
├── PPTAReport.swift
├── TotalActivityReport.swift
├── ScreenTimeActivityReport.swift
└── TotalActivityView.swift
```

---

## 3. Architecture

**Pattern:** MVVM + SwiftUI with singletons for cross-cutting concerns.

| Layer | Type | Examples |
|---|---|---|
| Models | Codable structs/classes | User, UserSettings, Friendship, RoleRequest |
| Repositories | Async/await Firestore CRUD | UserRepository, FriendshipRepository |
| ViewModels | @ObservableObject + @Published | AuthViewModel, FriendsViewModel, StatusCenterViewModel |
| Managers | Singletons | UserSettingsManager, DeviceActivityManager, NotificationManager |
| Views | SwiftUI only (no UIKit) | All in Views/ |

**Framework stack:**
- SwiftUI (all UI)
- Firebase Auth, Firestore, Cloud Messaging (FCM)
- FamilyControls + DeviceActivity + ManagedSettings (ScreenTime)
- CryptoKit (HMAC-SHA256 for Cloud Run request signing)
- Combine (reactive bindings between managers and viewmodels)

---

## 4. App Entry Point & Startup

**File:** `PPTAMinimal/PPTAMinimalApp.swift`

**AppDelegate responsibilities:**
- `didFinishLaunchingWithOptions`: Firebase init, notification permissions, remote notification registration
- `didRegisterForRemoteNotificationsWithDeviceToken`: Sets APNs token
- `didReceiveRemoteNotification`: Dispatches lock/unlock/trainee-status FCM notifications
- `messaging(_:didReceiveRegistrationToken:)`: FCM token registration

**Root view decision tree:**
```
AuthViewModel.userSession == nil  →  LoginView
onboardingComplete (per UID in UserDefaults) == false  →  OnboardingContainerView
otherwise  →  TabNavigator
```

**Onboarding completion key:** `"onboardingComplete_<uid>"` in UserDefaults (per-user, supports multiple accounts on one device).

---

## 5. View Hierarchy

```
PPTAMinimalApp
├── LoginView
│   └── NavigationLink → RegistrationView
├── OnboardingContainerView  (OnboardingCoordinator state machine)
│   ├── WelcomeView
│   ├── SignInOrSignUpView
│   ├── CreateProfileView
│   ├── EnableTrackingView          (FamilyActivityPicker)
│   ├── EnableNotificationsView
│   ├── FindFriendsView             (ContactsPicker)
│   └── .completed → HomeView
└── TabNavigator                    (TabView, 3 tabs)
    ├── HomeView
    │   ├── ProfileView
    │   ├── DashboardView
    │   │   └── DashboardCellView (×4 stat cards)
    │   ├── StreakBannerView
    │   └── ReportView              (sheet, DeviceActivityReport)
    ├── StatusCenterView
    │   ├── TraineeCellView (per trainee)  → lock/unlock buttons
    │   └── CoachCellView (per coach)      → sheet: FriendProfileSheetView
    └── FriendsView
        ├── FriendsContactsPickerView
        └── Friendship request cards (Accept/Decline inline)

Global overlay: InAppBannerView (from NotificationManager, on TabNavigator)

Sheets (non-stack):
- ReportView (HomeView)
- SettingsView → PressureLevelView, AppLimitsView → TimeLimitSheetView
- FriendProfileSheetView (StatusCenter, Friends)
- PhoneVerificationView (Onboarding)
```

---

## 6. Data Models

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
class UserSettings: Codable {
    @DocumentID var id: String?
    var applications: FamilyActivitySelection
    var thresholdHour: Int
    var thresholdMinutes: Int
    var pressureLevel: String          // "Off" | "Standard" | "Hardcore"
                                       // Firestore CodingKey: "selectedMode"
    var onboardingCompleted: Bool
    var peerCoaches: [PeerCoach]       // Legacy phone-based (migrating out)
    var coaches: [PeerCoach]           // Legacy
    var trainees: [PeerCoach]          // Legacy
    var coachIds: [String]             // New: UID-based coach relationships
    var traineeIds: [String]           // New: UID-based trainee relationships
    var profileImageURL: URL?
    var startDailyStreakDate: Date?
    var isTracking: Bool               // Derived: pressureLevel != "Off"
    var traineeStatus: TraineeStatus
}

struct PeerCoach: Codable, Identifiable {
    let id: UUID
    let givenName: String
    let familyName: String
    let phoneNumber: String
    var fcmToken: String?
}
```

### TraineeStatus
```swift
enum TraineeStatus: String, Codable, Hashable {
    case allClear           // Within limit
    case attentionNeeded    // Warning threshold hit; Standard: coaches decide
    case cutOff             // Limit hit in Hardcore, or coach remotely locked
    case noStatus           // pressureLevel == "Off"
}
```

### Friendship
```swift
enum FriendshipStatus: String, Codable { case pending, accepted, declined }

struct Friendship: Identifiable, Codable {
    var id: String
    var requesterId: String
    var requesteeId: String
    var status: FriendshipStatus
    var createdAt: Date
}
```

### RoleRequest
```swift
enum RoleRequestRole: String, Codable { case coach, trainee }
enum RoleRequestStatus: String, Codable { case pending, accepted, declined, cancelled }

struct RoleRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let requesterId: String
    let targetId: String
    let role: RoleRequestRole
    let status: RoleRequestStatus
    let createdAt: Date?
    let resolvedAt: Date?
}
```

### StatusCenterPerson
```swift
struct StatusCenterPerson: Identifiable, Equatable {
    let id: String                 // UID
    let name: String
    let profileImageURL: URL?
    let isCoach: Bool
    let isTrainee: Bool
    let traineeStatus: TraineeStatus?
    let streakDays: Int
    let timeLimitMinutes: Int
}
```

---

## 7. State Management

### Flow
```
Firestore / App Group
      ↓
UserSettingsManager (@Published var userSettings)
      ↓ (Combine binding)
DashboardViewModel, StatusCenterViewModel
      ↓ (@Published properties)
SwiftUI Views (auto re-render)
```

### Key @Published properties by class

**AuthViewModel:**
- `userSession: FirebaseAuth.User?` — drives root view switch
- `currentUser: User?` — loaded from Firestore after auth

**DashboardViewModel:**
- `limitHours: Int`, `limitMinutes: Int`, `streakDays: Int?`
- Bound to `UserSettingsManager.$userSettings` via Combine

**FriendsViewModel:**
- `friends: [User]`, `incomingRequests: [(Friendship, User)]`, `outgoingRequests: [(Friendship, User)]`
- `isLoading: Bool`, `errorMessage: String?`
- Real-time Firestore listener on `friendships`

**StatusCenterViewModel:**
- `trainees: [StatusCenterPerson]`, `coaches: [StatusCenterPerson]`
- `isCurrentUserCutOff: Bool`

**RoleRequestsInboxViewModel:**
- `incoming: [IncomingPair]` — real-time listener on `roleRequests`

**UserSettingsManager (singleton):**
- `userSettings: UserSettings` — source of truth for app + extension

**NotificationManager (singleton):**
- `inAppBanner: InAppBanner?` — drives global banner overlay

### Persistence layers
1. **Firestore**: `users`, `userSettings`, `friendships`, `roleRequests`
2. **App Group UserDefaults** (`group.com.sungbinyun.com.PPTADev`): UserSettings for extension access
3. **Device UserDefaults**: onboarding flags (`onboardingComplete_<uid>`), FCM token (temp)

---

## 8. Services & Managers API

### AuthService
- `signIn(withEmail:password:)` → FirebaseAuth.User
- `createUser(withEmail:password:)` → FirebaseAuth.User
- `signIn(with: AuthCredential)` → FirebaseAuth.User
- `signOut()` throws

### UserRepository
- `fetchUser(by uid:)` → User? (async throws)
- `findUserByPhone(_ phone:)` → User? (normalized 10-digit)
- `saveUser(_ user:)` (async throws)
- `userExists(_ uid:)` → Bool (async throws)
- `updateUserField(uid:field:value:)` (async throws)
- `normalizePhoneNumber(_:)` → String (static)

### FriendshipRepository
- `sendFriendRequest(from:to:)`, `acceptRequest(_:)`, `declineOrCancelRequest(_:)`
- `fetchIncomingRequests(for:)`, `fetchOutgoingRequests(for:)`, `fetchAcceptedFriendships(for:)`
- `areFriends(_ a:_ b:)` → Bool (bidirectional check)

### RoleRequestRepository
- `fetchIncomingPending(for uid:)` → [RoleRequest]
- `accept(id:)`, `decline(id:)` (async throws)

### UserSettingsManager (singleton)
- `loadSettings(completion:)` — Firestore → @Published + app group
- `saveSettings(_ settings:)` — @Published + Firestore + app group
- `update(_ transform:)` — mutable transform + save
- `applyPendingStatusIfNeeded()` — consume extension's status writes, persist to Firestore

### DeviceActivityManager (singleton)
- `startDeviceActivityMonitoring(appTokens:hour:minute:completion:)`
- `stopMonitoring()`
- `handleRemoteLock(from:)` — sets `ManagedSettingsStore().shield.applications`
- `handleRemoteUnlock(from:)` — clears shield

### NotificationManager (singleton)
- `showInAppMessage(title:body:dismissAfter:)` — updates `@Published inAppBanner`
- `sendNotification(title:body:)` — local push (2s delay)
- `requestAuthorization()`

### UnlockService
- `makeUnlockURL(childUID:coachUID:)` → URL? — HMAC-SHA256 signed
- `makeLockURL(childUID:coachUID:)` → URL? — HMAC-SHA256 signed
- Signature message: `"<uid>|<coach>|<timestamp>"`

---

## 9. Firebase / Firestore

### Collections

| Collection | Doc ID | Key Fields |
|---|---|---|
| `users` | Firebase UID | id, name, email, phoneNumber, fcmToken |
| `userSettings` | Firebase UID | applications, thresholdHour, thresholdMinutes, selectedMode (= pressureLevel), coachIds, traineeIds, isTracking, traineeStatus, startDailyStreakDate |
| `friendships` | Auto | requesterId, requesteeId, status, createdAt |
| `roleRequests` | Auto | requesterId, targetId, role, status, createdAt, resolvedAt |

**Important:** `pressureLevel` is stored in Firestore under the key `"selectedMode"` (CodingKeys migration artifact).

### Auth providers
- Email/password
- Google OAuth
- Apple OAuth

### FCM notification types (received by AppDelegate)
- `type: "unlock"` → `DeviceActivityManager.handleRemoteUnlock()`
- `type: "lock"` → `DeviceActivityManager.handleRemoteLock()`
- `type: "traineeStatus"` → local notification shown to coach

### Cloud Run endpoints
- **Unlock:** `https://unlockapp-iy4j75c7pq-uc.a.run.app`
- **Lock:** `https://lockapp-iy4j75c7pq-uc.a.run.app`
- **Status update:** `https://statusupdate-538124351649.us-central1.run.app`
- **Shared HMAC secret:** `"a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"` (raw string bytes, not hex-decoded)

---

## 10. DeviceActivity & ScreenTime

### Monitoring setup (DeviceActivityManager)
- Schedule: daily 00:00–23:59, repeating
- Event: `timeLimitReached` at user-configured threshold
- Warning: 5 minutes before threshold → `eventWillReachThresholdWarning`
- Shielding: `ManagedSettingsStore().shield.applications`

### Extension event handlers (AppMonitor/DeviceActivityMonitorExtension.swift)
| Event | Off | Standard | Hardcore |
|---|---|---|---|
| `intervalDidStart` | reset status → allClear | same | same |
| `intervalDidEnd` | clear shield, reset status | same | same |
| `eventWillReachThreshold` | no-op | status → attentionNeeded | status → attentionNeeded |
| `eventDidReachThreshold` | status → allClear | status → attentionNeeded | shield apps, status → cutOff, reset streak |

### App group bridge (LocalSettingsStore)
- App group ID: `group.com.sungbinyun.com.PPTADev`
- Extension reads UserSettings via `LocalSettingsStore.load()`
- Extension writes pending status via `LocalSettingsStore.savePendingStatus(_:resetStartDate:)`
- Main app calls `UserSettingsManager.applyPendingStatusIfNeeded()` on launch to consume and sync to Firestore

### ScreenTime report (PPTAReport extension)
- Uses `DeviceActivityReport` API
- Accessed via "Daily Screen Time" button on HomeView as a sheet
- Shows filtered daily report based on user's selected apps

---

## 11. Navigation

### Root switches
- Auth check: `AuthViewModel.userSession`
- Onboarding check: `UserDefaults["onboardingComplete_<uid>"]`

### Onboarding (state machine)
Steps in order: `welcome → signInOrSignUp → createProfile → enableTracking → enableNotifications → findFriends → completed`
- `goBack()`: step -= 1
- `skipToMainApp()`: sets UserDefaults flag, jumps to `.completed`
- Sheet: `PhoneVerificationView` for users missing phone number

### Main app (TabNavigator)
- Tab 0: HomeView (NavigationStack)
- Tab 1: StatusCenterView (NavigationStack)
- Tab 2: FriendsView (NavigationStack)

### Modal sheets
Presented with `.sheet()` from their parent views — not pushed on NavigationStack:
- SettingsView, PressureLevelView, AppLimitsView, TimeLimitSheetView
- FriendProfileSheetView
- ReportView
- PhoneVerificationView

---

## 12. Key Enums & Constants

```swift
// Pressure levels (stored as String in Firestore key "selectedMode")
"Off"       // No monitoring, status = noStatus
"Standard"  // Coaches see status, can lock remotely
"Hardcore"  // Auto-lock at threshold, coaches cannot unlock

// TraineeStatus
.allClear           // Within limit
.attentionNeeded    // Warning or Standard-mode threshold
.cutOff             // Locked (Hardcore or remote)
.noStatus           // Off mode

// App group
"group.com.sungbinyun.com.PPTADev"

// HMAC secret (used in DeviceActivityManager, UnlockService, extension)
"a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"
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
| Reactive | `.onChange(of:)` |
| Modals | `.sheet()` / `.fullScreenCover()` |

**Error handling:** `do/catch` with `AuthViewModel.userFacingMessage(for:)` for user-facing messages. Print statements throughout (debug-only, not removed yet).

**Legacy vs new:** Phone-based `[PeerCoach]` (coaches, trainees, peerCoaches) is the old system. `coachIds`/`traineeIds` ([String] UIDs) is the new system. Both coexist during migration. Prefer UID-based for any new code.

---

## 14. Known Issues & TODOs

| Location | Issue |
|---|---|
| `PressureLevelView.swift:22` | Streak reset description is placeholder: `"(TODO) blah blah blah"` |
| `AppLimitsView.swift:27` | Same streak reset placeholder |
| `TraineeCircleView.swift:49` | Custom font `SatoshiVariable-Bold_Light` — unclear availability |
| `SettingsView.swift:30` | Invite banner commented out (functionality not implemented) |
| `LoginView.swift` | Forgot password button is wired up but action is empty |
| `EditProfileView.swift` | No profile image upload UI (profileImageURL is read-only) |
| Various ViewModels | Debug `print()` statements throughout — not stripped |
| `AppleSignInService.swift:169,183` | CHECK comments for unverified assumptions |
| Phone normalization | Only handles US 10-digit; international formats may break |

---

## 16. Design System Notes

### Theme
- **Primary color**: `Color("primaryColor")` — olive/green, used for interactive elements, text accents, section headers
- **Background gray**: `Color("backgroundGray")` — soft matte fill for cards, inputs, buttons (never use `.secondarySystemBackground` or system fills for UI cards)
- **Primary button color**: `Color("primaryButtonColor")` — for primary CTAs (Release, Save, etc.)
- **Matte button style**: `primaryColor.opacity(0.1)` fill + `primaryColor` text + `cornerRadius: 12` + `.continuous` style. No borders, no system button styles (`.bordered`, `.borderedProminent`)
- **Capsule pills**: Used for inline actions (Accept/Decline, Pending, Cancel) — `primaryColor` fill for positive, `Color(.systemGray5)` for neutral/destructive
- **Section headers**: `.uppercased()` + `.system(size: 11, weight: .semibold)` + `primaryColor.opacity(0.6)`
- **Initials circles**: `primaryColor.opacity(0.12)` fill + `primaryColor` text — NOT `Color(.tertiarySystemFill)` + `.primary`
- **Cards**: `primaryColor.opacity(0.1)` fill + `RoundedRectangle(cornerRadius: 12, style: .continuous)` — avoid `List` with `.insetGrouped`. Do NOT use `Color("backgroundGray")` for cards — it has no dark mode variant and disappears on dark backgrounds.
- **Custom fonts**: `BambiBold` (headings in ProfileView), `SatoshiVariable-Bold_Light` (subheadings)

### Patterns to avoid
- `List` with `.insetGrouped` — looks stock, clashes with custom cards
- `.bordered` / `.borderedProminent` button styles — use custom matte buttons instead
- `Color(.tertiarySystemFill)` / `Color(.secondarySystemBackground)` for UI cards
- Showing email in friend rows — use name + initials only
- Status color red for `.attentionNeeded` — use orange (red is reserved for cutOff/errors)

---

## 15. Pre-launch Status

### Done
- User auth (email/password, Google, Apple)
- Friend requests (send, accept, decline)
- Role requests (coach/trainee inbox with real-time listener)
- Coach-trainee UID-based relationships
- DeviceActivity monitoring (app selection, threshold, shielding)
- Pressure levels (Off/Standard/Hardcore) with correct extension behavior
- Remote lock/unlock (signed Cloud Run URLs + FCM dispatch)
- Trainee status tracking (all 4 states)
- Daily streak calculation
- In-app notifications + local push notifications
- ScreenTime report integration
- Onboarding (7 steps, per-user completion)
- Contacts import for adding friends
- Settings UI (pressure level, app limits, time limit picker)
- Status Center (coaches and trainees with stats)
- App group bridge (main app ↔ extension sync)

### Partially Done
- Phone number flows (sign in with phone legacy; UID migration in progress)
- Profile image (stored in Firestore, no upload UI)
- Extension ↔ main app sync (working, but untested under edge cases)

### Not Started / Missing
- Forgot password flow
- Profile image upload
- Trainee mercy request to coach (unlock request from trainee side)
- Streak reset documentation (exact conditions undefined)
- International phone number support
- Unit tests (test targets exist but empty)
- UI tests (empty)
- Offline-first sync (fully Firestore-dependent)
- Push notification payload completeness (basic structure only)

### Test targets
- `PPTAMinimalTests` — empty
- `PPTAMinimalUITests` — empty

### Overall status
**Pre-beta.** Core features are functional. Blockers before first TestFlight: forgot password, profile image upload optionally, and streak reset copy. The UID-based relationship model is the future; avoid adding to the legacy phone-based system.
