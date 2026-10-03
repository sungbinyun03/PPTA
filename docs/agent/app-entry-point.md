Covers §4 App Entry Point & Startup from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 4. App Entry Point & Startup

**File:** `PPTAMinimal/PPTAMinimalApp.swift`

**AppDelegate responsibilities:**
- `didFinishLaunchingWithOptions`: Firebase init, **unconditional** APNs registration (required for Phone Auth silent push regardless of notification permission), notification permission request, FCM delegate
- `didRegisterForRemoteNotificationsWithDeviceToken`: APNs token → Auth (`.sandbox` in DEBUG, `.prod` otherwise) + Messaging
- `didReceiveRemoteNotification`: dispatches all FCM types (see `firebase-firestore.md`)
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
