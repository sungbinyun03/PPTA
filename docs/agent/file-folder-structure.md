Covers §2 File & Folder Structure from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

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
│   ├── StatusCenter/                 # ⚠️ DEAD CODE — see ../../CLAUDE.md §14 (Known Issues & TODOs)
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
├── ScreenTimeActivityReport.swift    # ActivityReport / AppDeviceActivity / WeeklyReport
├── TotalActivityReport.swift         # .totalActivity scene
├── SummaryRingReport.swift           # .summaryRing scene
├── WeeklyTrendReport.swift           # .weeklyTrend scene
└── TotalActivityView.swift           # ProgressRingView, AppActivityRow, ReportSectionHeader

docs/                                 # onboarding-redesign.md, onboarding-asset-prompts.md
scripts/                              # check-onboarding-assets.py, import-onboarding-assets.py
```

**Xcode targets (7):** `PPTAMinimal`, `AppMonitor`, `PPTAReport`, `PPTAShieldConfiguration`, `PPTAShieldAction`, `PPTAMinimalTests`, `PPTAMinimalUITests`.

---
