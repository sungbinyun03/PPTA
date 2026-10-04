Covers §6 Data Models from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 6. Data Models

### ActionMessage
```swift
enum ActionMessage {
    static let maxLength = 60          // chars (grapheme clusters); client-side cap
    static func clean(_ raw: String?) -> String?   // trim, collapse whitespace/newlines/control, cap at maxLength, nil if empty
}
```
Used to sanitize user-entered text for lock/snooze request messages. Server-side cap is 100 Unicode code points (slightly looser, so client/server counting can't cause action failures). Message is cosmetic text only, never instructions, markdown, or logging.

### CoachActionDisplay / LockNoteCache (`Models/CoachActionDisplay.swift`)
```swift
struct CoachActionDisplay { enum Lock { case active, snoozed }; var lock: Lock?; var halo: Bool; var lockNote: String?; var snoozedByName: String? }
static func derive(from raw: [String: Any], uid:, cache:, now:) -> [String: CoachActionDisplay]   // keyed by coach UID
static func cacheUpdate(from raw: [String: Any], uid:, now:) -> CacheUpdate                       // .keep / .clear / .set
struct LockNoteCache: Codable   // {uid, lockId, by, byName, message, at}
```
Pure; turns the raw `userSettings/{me}` doc into the trainee's per-coach lock badge (red active, grey while snoozed), snooze halo, and RECEIVED lock note (server `lockCommand.lockNote` first, phone cache as fallback for an old server, today only). `LockNoteCache` lives in `UserDefaults.standard` keyed by UID: never Codable into `UserSettings`, never in the App Group (the shield could show a stale note).

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

**⚠️ Keep-out-of-Codable rule:** `lockCommand` and `snoozeRequestMessages` exist in Firestore but **must not** be added to `UserSettings`'s `CodingKeys` enum. A full-doc `setData(merge:)` from the client would otherwise write stale cached values back to the server. Read these fields from raw snapshot dictionaries instead (like `lockCommand` already is in `LockReconciler`).

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
