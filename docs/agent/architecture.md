Covers §3 Architecture from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

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
