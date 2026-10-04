Covers §7 State Management from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

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
`coachActions` (`[coachUid: CoachActionDisplay]`), a read-only raw listener on the user's own
`userSettings` doc (feeds `coachActions` + the live `isCurrentUserCutOff`; never writes, because
`lockedByUID` is in the `UserSettings` Codable and a full-doc save could write a stale locker back),
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
