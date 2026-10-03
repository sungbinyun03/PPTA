Covers §8 Services & Managers API from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

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
- `sendMercyRequest(uid:targetCoach:message:)` — message is optional, cleaned via `ActionMessage.clean()` before sending
- `sendSettingsChanged(uid:change:)`, `sendReinstallNotice(uid:)`
- `static markRingReset()` — stamps `ringResetAt` in UserDefaults (forces report re-query; no usage math)

### UnlockService
`makeUnlockURL(childUID:coachUID:)`, `makeLockURL(childUID:coachUID:message:)` — HMAC-SHA256.
Signature message: `"<uid>|<coach>|<timestamp>"`. Optional `message` param (unsigned query param `msg`, cleaned via `ActionMessage.clean()` before URL construction).

### LocalSettingsStore
App Group container for shared state between main app and shield extension. Stores the current lock's message (when present) for display on the shield screen.
- `lockMessage` — optional `String`, set when a coach-caused lock command is applied (via `LockReconciler`), cleared on an unlock, on a lock that is not applied, and on each new lock that arrives without a message (all in `LockReconciler`). It is NOT cleared when status leaves `.cutOff`; display is gated on `lockedByName` being non-empty. Used by `ShieldContext` to show the message on the shield.

### ShieldContext
- `lockMessage` — reads from `LocalSettingsStore.lockMessage` to display the current lock's message on the shield screen (when coach-caused and present).

### NotificationManager (singleton)
`showInAppMessage(title:body:dismissAfter:)`, `sendNotification(title:body:)`, `requestAuthorization()`.

### MercyRequestService — vestigial
The `mercyRequests` collection is no longer written. Both helpers query an empty collection and are
no-ops, kept only so the dead `StatusCenterView` still compiles. Don't build on it; per-coach
snoozes live in `UserSettings.snoozeRequestedCoachIds`.

---
