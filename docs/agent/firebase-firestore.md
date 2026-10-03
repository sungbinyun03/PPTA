Covers §9 Firebase/Firestore from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 9. Firebase / Firestore

### Collections

| Collection | Doc ID | Key Fields |
|---|---|---|
| `users` | Firebase UID | id, name, email, phoneNumber, fcmToken |
| `userSettings` | Firebase UID | applications, thresholdHour, thresholdMinutes, **selectedMode** (= pressureLevel), coachIds, traineeIds, isTracking, traineeStatus, startDailyStreakDate, lockedByUID, lockedByName, snoozeRequestedCoachIds, snoozeRequestMessages, lockCommand, monitoredAppNames, monitoredAppStats |
| `friendships` | Auto | requesterId, requesteeId, status, createdAt |
| `roleRequests` | Auto | requesterId, targetId, role, status, createdAt, resolvedAt |
| `mercyRequests` | — | **dead**, no longer written |

**Important:** `pressureLevel` is stored under the key `"selectedMode"` (CodingKeys migration artifact).

**New fields (action messages):**
- `lockCommand` = `{id, action, by, byName, at, message?}` — coach lock command. `message` is an optional cosmetic string (≤100 code points server-side, set by lock endpoint, cleared by unlock). **Read from raw dict only; never add to `UserSettings` Codable.**
- `snoozeRequestMessages` = `{coachUid: text, ...}` — trainee's snooze request message to each coach (max 100 code points each), written with `{merge:true}`, cleared alongside `snoozeRequestedCoachIds` on any non-cutOff status. **Read from raw dict only; never add to `UserSettings` Codable.**

### Auth providers
Email/password, Google OAuth, Apple OAuth. (Phone is verification-only, not a sign-in provider.)

### FCM notification types (all handled in `AppDelegate.didReceiveRemoteNotification`)

| `type` | Effect |
|---|---|
| `unlock` | `handleRemoteUnlock(from:coachUID:)` — clears shield, arms grace |
| `lock` | `handleRemoteLock(from:coachUID:pushShowsBanner:message:)`. Data key `message` (optional, cosmetic) is used for the client-built notification body when present; the source of truth is `userSettings.lockCommand.message` (durable read). |
| `mercyRequest` | Data keys: `type`, `uid`, `traineeName`, and `message` (only when present). `message` is the sanitized request body sent to `statusUpdate` (not read from `snoozeRequestMessages[myUid]`); the notification body quotes it when present, else the default "Open PPTA to snooze their lock." text. |
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
is present. `LockCause` raw values are mirrored server-side as `LOCK_CAUSE`. `statusUpdate` takes the optional unsigned `message` parameter only on `mercyRequest` (cosmetic text only, ≤60 chars client-side, ≤100 code points server-side, sanitized server-side). Lock uses a separate unsigned `msg` query param on the `lockapp` URL for the same purpose. Both are backward-compatible and, being unsigned, must be treated as untrusted display text.

---
