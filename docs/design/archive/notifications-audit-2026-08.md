> **Archived 2026-11-11.** Historical audit from 2026-08. Some copy here is out of date; the live copy is in `docs/design/features/`.

# PPTA Notifications Audit

A complete catalog of every notification in the app — trainee-facing, coach-facing, and
user-to-user (friends/roles). Reviewed against the **current** code after the shield-extension,
share-limits, mercy-request, and coach-setup-alert commits (`9f86675`, `ae3c3b9`).

**How to use this doc:** each entry has a **Status** and its copy. Items marked 🚀 SHIPPED are live
(client + server deployed as of 2026-08-25). Remaining ⚪ OPEN rows are the follow-up backlog.

**Status legend:**
- 🚀 **SHIPPED** — implemented and deployed (client + server where relevant)
- ✅ **KEEP** — correct, no change
- 🟠 **STALE** — copy no longer matches behavior
- 🔵 **INCONSISTENT** — works, but mechanism/tone differs from siblings
- 🔴 **MISSING** — should exist but doesn't
- ⚪ **OPEN** — still needs a call from you
- 🟣 **BACKEND** — copy/behavior lives in the Cloud Run/FCM `statusUpdate` function

---

## 0. Global decision — kill all in-app banners 🚀 SHIPPED

> **Your call:** *"None of the notifications should ever be in-app banners — they should be regular
> iOS system notifications."*

The app had three delivery paths. **M2 (in-app banner) has been retired everywhere.**

| # | Mechanism | File | Outcome |
|---|---|---|---|
| M1 | `NotificationManager.sendNotification` | `NotificationManager.swift` | **Kept** (the standard path). 🚀 2s delay dropped → fires immediately (`trigger: nil`) + `.default` sound. |
| M2 | `NotificationManager.showInAppMessage` | `NotificationManager.swift` | 🚀 **All call sites converted to M1.** The method + `InAppBannerView` overlay are now unused dead code (optional cleanup). |
| M3 | `scheduleLocalNotification` (extension) | `DeviceActivityMonitorExtension.swift` | **Kept** (immediate; force-quit-proof). |

**All M2 call sites converted:** friend-request-received (4.1), role-request-received banner
(4.3), mercy "Request sent"/"Couldn't send" (1.11), and the Share Limits screenshot toast.

---

## 1. Trainee-facing — screen time, lock state, shield

Source: `AppMonitor/DeviceActivityMonitorExtension.swift` (M3) and `DeviceActivityManager.swift` (M1).

_(Copy below reflects the tone pass — see §7. Trainee-facing lock/limit copy now points to the mercy flow.)_

### 1.1 Halfway warning — 🚀 SHIPPED
- **"Halfway there! ⏳"** — "You've used half your daily screen time — pace yourself!" (limits ≥ 5 min)

### 1.2 Five-minute warning — 🚀 SHIPPED
- **"5 minutes left! ⏳"** — "Just 5 minutes of screen time left today." (limits > 10 min)

### 1.3 Two-minute warning — 🚀 SHIPPED
- **"2 minutes left! ⏳"** — "Only 2 minutes of screen time left today — wrap it up!" (limits ≥ 2 min)

### 1.4 Limit reached — Standard mode — 🚀 SHIPPED
- **"Time's up! ⏰"** — "You've hit your daily limit — your coaches have been notified."

### 1.5 Limit reached — Hardcore mode — 🚀 SHIPPED
- **"Time's up, you're cut off! 🔒"** — "Head to a coach's profile to ask them to snooze the lock."
  _(Was "Your apps are locked for the rest of the day." — now points to the mercy/snooze flow. Any coach can be asked.)_

### 1.6 Snooze / grace expired — 🚀 SHIPPED
- **Trigger:** trainee burns the 10 post-unlock grace minutes → apps re-lock (`DeviceActivityMonitorExtension.swift`)
- **Live:** **"Snoozed Lock Ended! 🔒"** — "Your 10 minutes are up — your apps are locked again."
  _(Also sends `cause: snoozeEnded` to coaches → 2.2.)_

### 1.7 Coach locked you — 🚀 SHIPPED
- **"Locked by {coach} 🔒"** — "Head to a coach's profile to ask them to snooze the lock." (`DeviceActivityManager.handleRemoteLock`)
  _(Was "Your coach locked your monitored apps." — body now points to the mercy flow, and says "a coach" since the trainee can ask any of theirs.)_

### 1.8 Coach snoozed your lock (while tracking) — 🚀 SHIPPED
- **Trigger:** coach remote unlock, trainee tracking (`DeviceActivityManager.handleRemoteUnlock`)
- **Live:** **"Lock snoozed by {coach}! ⏳"** — "You've got 10 minutes before your apps lock again — make them count!"
  _(Also sends `snoozedLock` + `cause: coach` + coach UID to coaches → 2.4.)_

### 1.9 Coach unlocked you (pressure level Off) — 🚀 SHIPPED (removed)
- **Was:** "Unlocked by {coach}" — "Be Mindful of Your Screentime!"
- **Why removed:** you can only be unlocked if locked → only locked if you hit the limit → only hit
  the limit while tracking. The not-tracking branch is effectively unreachable, and the copy was misleading.
- **Live:** `handleRemoteUnlock` now `guard settings.isTracking` after clearing the shield — the shield
  clear stays as a harmless safety no-op, but **no notification fires when not tracking**.

### 1.10 Shield "ask your coach" handoff — ✅ KEEP
- **Trigger:** trainee taps the shield's secondary button (`PPTAShieldAction/ShieldActionExtension.swift:70`)
- **"Tap to ask your coach"** — "Open PPTA to send your request for more time."
- _Doing real work (the request isn't filed until the app opens), not just a confirmation. Keep._

### 1.11 Mercy request filed — confirmation to trainee — 🚀 SHIPPED (M2→M1)
- **Source:** `MercyRequestService.swift` — both now system notifications (were in-app banners).
- **Success:** "Request sent" — "Your coach(es) have been asked for more time."
- **Failure:** "Couldn't send request" — "Try again from your lock screen."

---

## 2. Coach-facing — about their trainee

FCM `type: "traineeStatus"`, **copy built client-side** in `PPTAMinimalApp.swift` (the push arrives as
silent data; the client re-raises the visible notification). Title stays "Accountability update" (2.5 open).

### 2.1 Trainee `attentionNeeded` — 🚀 SHIPPED
- **Was:** "{trainee} is **approaching** their screen time limit." (stale — `attentionNeeded` fires only
  when the limit is **actually hit in Standard mode**; the approaching path is a no-op; Hardcore → `cutOff`).
- **Live:** Title **"{trainee} hit their time limit! 👀"** · Body "Go ahead and cut them off!" _(Standard-only.)_

### 2.2 Trainee `cutOff` — 🚀 SHIPPED (attribution via `cause` + `by`; server deployed)
- **Was:** "{trainee} has hit their screen time limit." — wrong, because `cutOff` has **three** causes:

All three share the title **"{trainee} has been locked!"**; the body differs by cause:

| Cause | `cause` const | `by` (coach UID) | Body (live) |
|---|---|---|---|
| Hardcore auto-lock at limit | `hardcoreLimit` | — | "They hit their limit — their apps locked automatically." |
| Standard, a coach locked them | `coach` | coach UID | "{byName} cut off their apps." (actor: "You cut off their apps.") |
| Snooze/grace timer ended | `snoozeEnded` | — | "Their snooze ran out — they're locked again." |

- **Why `cause` (not a `mode` field):** `snoozeEnded` happens in **both** Standard and Hardcore, so a
  mode-based scheme can't distinguish it. `cause` names the trigger directly and is extensible.
- **Client sends only `by` (coach UID) — server resolves the name** (same `users/{uid}.name` lookup it
  already does for `traineeName`), and adds both to the push `data`. `by` (UID) → self-comparison;
  server-resolved `byName` → the copy (always fresh from Firestore).
- **Actor self-wording:** the acting coach also receives the fan-out; `by == currentUser.uid` → "You…".

> **Attribution schema (shared by 2.2 + 2.4) — 🚀 SHIPPED**
> - **`cause`** — const string on **both** sides. Swift `enum LockCause: String { case hardcoreLimit,
>   coach, snoozeEnded }` (in `DeviceActivityManager.swift`, compiled into app **and** extension).
>   Server `const LOCK_CAUSE = { HARDCORE_LIMIT: 'hardcoreLimit', COACH: 'coach', SNOOZE_ENDED: 'snoozeEnded' };`
> - **`by`** = coach UID (client sends only this). **`byName`** = server-resolved name, added to `data`.
>   Both present only when `cause == coach`.
> - **Client threading (done):** the coach UID from the lock/unlock FCM is now passed through the
>   AppDelegate → `handleRemoteLock`/`handleRemoteUnlock` → `postToStatusUpdate(cause:by:)`. `cause` set
>   at each call site — `hardcoreLimit` (extension Hardcore branch), `coach` (`handleRemoteLock`/`Unlock`),
>   `snoozeEnded` (extension grace block).
> - **Server (done):** `statusUpdate` now allow-lists `'snoozedLock'`, validates `cause`, resolves
>   `byName`, persists `lockedByUID/Name` on a coach cutOff, and forwards `cause`/`by`/`byName` in the push.
> - **Signature (done):** both sides build `uid|status|ts` then append, in order, `|mercyRequest`
>   (mercy only), `|<cause>`, `|<by>` — omitting absent fields. Legacy 3-part messages still verify.

### 2.3 Trainee `allClear` — 🚀 SHIPPED (midnight banner removed)
- **Was:** coaches got "{trainee} is back on track" every midnight (the daily `intervalDidStart` reset).
- **Live:** the coach-side `traineeStatus` handler returns `nil` for `allClear`, so **no banner fires**.
  The silent background push still refreshes the coach's Status Center from Firestore — status resets,
  just no notification.
- **Where:** `PPTAMinimalApp.swift` `traineeStatus` handler.

### 2.4 Trainee `snoozedLock` — 🚀 SHIPPED (attributed to the snoozing coach; server deployed)
- **Was:** fell through to default — "{trainee} has a status update." **Also** the server rejected
  `snoozedLock` with `400 invalid status`, so snooze pushes never fanned out at all — now allow-listed.
- Uses the **same attribution schema as 2.2**: `cause = coach` (only a coach can snooze) + coach UID.
- **Coach sees (live):** Title **"{trainee}'s lock has been snoozed!"** · Body "{byName} gave them 10 more minutes." (actor: "You gave them 10 more minutes.")
- **Set at:** `handleRemoteUnlock` → `postToStatusUpdate(status: .snoozedLock, cause: .coach, by: coachUID)`.

### 2.5 Contextual notification titles — 🚀 SHIPPED
- **Was:** every coach push shared one umbrella title, "Accountability update".
- **Live:** titles are contextual — format **"{trainee} <short event>"** — with the body elaborating
  who/why:
  - `attentionNeeded` → **"{trainee} hit their time limit!"**
  - `cutOff` → **"{trainee} has been locked!"** (body says coach vs. auto — see 2.2)
  - `snoozedLock` → **"{trainee}'s lock has been snoozed!"**
  - `allClear` → _no notification_ (see 2.3)
- **Where:** `PPTAMinimalApp.swift` `traineeStatus` handler now returns a `(title, body)?` per case.
- **First names only (app-wide):** a shared `String.firstNameOnly` helper trims display names to their
  first word across **all** notifications — coach-facing status pushes, trainee-side "Locked by / Lock
  snoozed by {coach}", friend/role-request alerts, and lock/unlock verification alerts. e.g.
  "Damien's lock has been snoozed!" not "Damien Koh's…". (`PPTAMinimal/Extensions/String+FirstName.swift`)

### 2.6 Coach setup-change alert (`settingsChanged`) — 🔴 / 🟣 BACKEND
- **Trigger:** trainee changes app limits or pressure level → coaches told (`UserSettingsManager.swift:88`,
  `DeviceActivityManager.sendSettingsChanged:284`). Sends `type:"settingsChanged"`, `change: appLimits|pressureLevel|both`.
- ⚠️ **Gap:** `PPTAMinimalApp.swift` `didReceiveRemoteNotification` has **no handler for `settingsChanged`**
  (handled types: unlock, lock, traineeStatus, roleRequestReceived, relationshipsChanged, roleRequestAccepted).
  So the coach only sees this if the **server sends a visible notification payload** — copy is server-side.
- ⚪ **Decision:** (a) confirm the server sends visible copy, or (b) add a client handler so we control
  the wording. Proposed client copy if we handle it:
  - `appLimits`: "{trainee} changed their app limits."
  - `pressureLevel`: "{trainee} changed their pressure level."
  - `both`: "{trainee} updated their limits and pressure level."

### 2.7 Mercy request received (`mercyRequest`) — 🔴 / 🟣 BACKEND
- **Trigger:** trainee asks coaches for more time (`DeviceActivityManager.sendMercyRequest:271`,
  `type:"mercyRequest"`).
- ⚠️ **Gap:** same as 2.6 — **no client handler for `mercyRequest`** in the AppDelegate switch, so the
  visible push is whatever the server sends. Firestore `mercyRequests` is the durable copy the coach
  UI reads; the *push* copy is server-side.
- ⚪ **Decision:** confirm server copy, or add a client handler. Proposed: "{trainee} is asking for more
  time." → deep-link to their profile.

---

## 3. Coach-facing — lock/unlock action verification — ✅ KEEP

`FriendProfileViewModel.swift:234` (M1). Fires only if the action didn't land within 15s.

- **3.1** "Lock may not have reached {name}" — "{name} may still have access to their apps. Try locking them again."
- **3.2** "Snooze may not have reached {name}" — "The snooze unlock didn't seem to go through. Try again."

---

## 4. User-to-user — friends & roles

### 4.1 Friend request received — 🚀 SHIPPED (banner→system) · ⚪ backend push still open
- **Source:** `FriendsViewModel.swift` — 🚀 now a system notification (was an in-app banner).
- **"New friend request"** — "{name} sent you a friend request."
- ⚪ **Still open (backend):** this only fires while the app is running (in-app Firestore listener). To
  fire when the app is closed, the server needs a `friendRequestReceived` FCM push (doesn't exist yet).

### 4.2 Friend request accepted — 🚀 SHIPPED (banner→system) · ⚪ backend push still open
- **Source:** `FriendsViewModel.swift` — a second Firestore listener watches this user's **outgoing**
  friendships flipping to `accepted` (the acceptor is the `requesteeId`), primed on first snapshot so
  the existing backlog stays silent.
- **"Friend request accepted! 🎉"** — "{name} accepted your friend request."
- ⚪ **Still open (backend):** like 4.1, this only fires while the app is running. An app-closed push
  needs a server `friendRequestAccepted` FCM (doesn't exist yet).

### 4.3 Role request received — 🚀 SHIPPED (banner dropped)
- **Source:** `RoleRequestsInboxViewModel.swift` — banner call removed; system notification kept.
- **"New role request"** — "{name} wants to be your coach." / "...your trainee."

### 4.4 Role request accepted — ✅ KEEP
- `PPTAMinimalApp.swift:141` — "Request accepted" — "{name} accepted your coach/trainee request."

### 4.5 Relationship ended / unfriended (`relationshipsChanged`) — ✅ KEEP (silent by design)
- `PPTAMinimalApp.swift:127` — no alert; just reloads settings so stale entries disappear.

### 4.6 Request declined (friend or role) — 🔴 MISSING — ⚪ OPEN
- Nothing fires on decline for either. ⚪ **Decision:** stay silent (recommended) or notify?

---

## 5. Change summary

| # | Item | Status | Where |
|---|---|---|---|
| §0 | Retire in-app banners; unify on M1; drop 2s delay | 🚀 | Client |
| 1.6 | Grace expired → "Snoozed Lock Ended" | 🚀 | Client (extension) |
| 1.8 | Unlock → "Lock snoozed by {coach}" + reworded body | 🚀 | Client |
| 1.9 | Remove not-tracking unlock notification | 🚀 | Client |
| 1.11 | Mercy confirm toasts → system notif | 🚀 | Client |
| 1.12 | Screenshot-saved notification **removed from code** | 🚀 | Client (removed) |
| 2.1 | `attentionNeeded` → "hit their time limit!" | 🚀 | Client |
| 2.2 | `cutOff` → 3 causes via `cause` const (`hardcoreLimit`/`coach`/`snoozeEnded`) + `by` | 🚀 | Client + server (deployed) |
| 2.3 | `allClear` → midnight "back on track" banner **removed** (silent status sync kept) | 🚀 | Client |
| 2.4 | `snoozedLock` → notify all coaches, attributed (`cause: coach` + `by`) | 🚀 | Client + server (deployed) |
| 2.5 | Contextual per-status titles ("{trainee} <short event>") | 🚀 | Client |
| 2.6 | `settingsChanged` — add client handler / confirm server copy | ⚪🟣 | Backend + maybe client |
| 2.7 | `mercyRequest` — add client handler / confirm server copy | ⚪🟣 | Backend + maybe client |
| 4.1 | Friend req received → system notif ✅; backend push ⚪ | 🚀 + ⚪ | Client done; backend open |
| 4.2 | Friend req accepted → system notif ✅; backend push ⚪ | 🚀 + ⚪ | Client done; backend open |
| 4.3 | Role req received → drop banner | 🚀 | Client |
| 4.6 | Decline notifications | ⚪ | Decision (likely skip) |

**🚀 SHIPPED (client + server deployed 2026-08-25):** §0, 1.6, 1.8, 1.9, 1.11, 1.12 (removed), 2.1, 2.2, 2.3, 2.4, 2.5, 4.1 (client), 4.2 (client), 4.3.
**⚪ Still open:** 2.6, 2.7, 4.1 & 4.2 (backend app-closed push), 4.6.

---

## 6. Remaining open decisions (follow-up backlog)

1. **2.6 / 2.7:** add client handlers for `settingsChanged` / `mercyRequest` so we own the copy, or leave to server?
   - ⚠️ `settingsChanged` (2.6) is currently rejected by the server's `type` allow-list — same class of
     bug as the `snoozedLock` fix we just shipped. If you want it, it needs the server too.
2. **4.1 / 4.2 backend push:** both fire client-side while the app is running; add
   `friendRequestReceived` / `friendRequestAccepted` FCM pushes so they also fire when the app is closed?
3. **4.6 decline:** silent (recommended) or notify?

---

## 7. Implementation log — 🚀 SHIPPED (2026-08-25)

**Client edits (live):**

| Item | File(s) changed |
|---|---|
| §0 immediate delivery | `NotificationManager.swift` — `sendNotification` now `trigger: nil` + `.default` sound |
| §0 banners → system | `FriendsViewModel.swift`, `RoleRequestsInboxViewModel.swift` (banner line removed), `MercyRequestService.swift` (×2), `ShareLimitsView.swift` |
| 1.6 snooze-ended title | `DeviceActivityMonitorExtension.swift` — "Snoozed Lock Ended" |
| 1.8 / 1.9 unlock copy + remove Off-mode notif | `DeviceActivityManager.swift` — `handleRemoteUnlock` |
| 2.1 attentionNeeded copy | `PPTAMinimalApp.swift` |
| 2.2 / 2.4 attribution | `LockCause` enum + `postToStatusUpdate` signing (`DeviceActivityManager.swift`); extension `sendStatusUpdate(cause:)` + call sites; coach UID threaded through `handleRemoteLock`/`handleRemoteUnlock` + AppDelegate; coach-side handler in `PPTAMinimalApp.swift` |
| 2.5 contextual titles | `PPTAMinimalApp.swift` — `traineeStatus` handler returns a `(title, body)?` per status |
| 4.3 role-req drop banner | `RoleRequestsInboxViewModel.swift` |

**Removed from code (2026-08-25 follow-up):**
- **1.12 screenshot-saved** — deleted the `userDidTakeScreenshotNotification` handler in `ShareLimitsView.swift`. No notification fires on screenshot (the on-screen tip still tells people to screenshot).
- **2.3 allClear midnight banner** — the coach-side `traineeStatus` handler now returns `nil` for `allClear`, so no "back on track" push fires at midnight. The silent background push still refreshes the coach's Status Center from Firestore (status sync preserved).

**Server — ✅ DEPLOYED (2026-08-25):** `statusUpdate/index.js` now defines `LOCK_CAUSE`, accepts
`cause`/`by`, allow-lists `'snoozedLock'`, folds `cause`/`by` into the signed message, resolves
`byName`, persists `lockedByUID/Name` on a coach cutOff, and forwards `cause`/`by`/`byName` in the
`traineeStatus` push. Backward-compatible (legacy 3-part signatures still verify).

**Tone pass (2026-08-26):** livened all coach- and trainee-facing copy with `!` and emojis
(⏳/⏰/🔒/👀/🙏/🤝/🎉/👋/⚠️) — **emojis in titles only; bodies are plain text**. Hardcore limit title →
"Time's up, you're cut off! 🔒"; coach-lock & hardcore bodies now point to the mercy/snooze flow
("Head to a coach's profile…").

**Friend request accepted (2026-08-26):** added a second Firestore listener in `FriendsViewModel`
(outgoing friendships → `accepted`) that fires **"Friend request accepted! 🎉"** — "{name} accepted your
friend request." Mirrors the friend-request-received listener; client-side only (backend push still open).

**Notes:**
- `showInAppMessage` + `InAppBannerView` are now unused (all callers converted) — optional dead-code cleanup.
- Open follow-ups tracked in §6: 2.6, 2.7, 4.1 (backend push), 4.2, 4.6.

_See §6 for the remaining backlog._

---

## 8. Full notification reference (live copy)

Every notification touching friends, requests, coaches, and trainees. All names are **first-name only**
(server sends full names; client trims via `String.firstNameOnly`).

### A. Trainee-facing — own screen time & lock state

| # | Trigger | Title | Body |
|---|---|---|---|
| 1 | Halfway through limit | **Halfway there! ⏳** | You've used half your daily screen time — pace yourself! |
| 2 | 5 min left | **5 minutes left! ⏳** | Just 5 minutes of screen time left today. |
| 3 | 2 min left | **2 minutes left! ⏳** | Only 2 minutes of screen time left today — wrap it up! |
| 4 | Limit hit (Standard) | **Time's up! ⏰** | You've hit your daily limit — your coaches have been notified. |
| 5 | Limit hit (Hardcore auto-lock) | **Time's up, you're cut off! 🔒** | Head to a coach's profile to ask them to snooze the lock. |
| 6 | Snooze/grace timer runs out | **Snoozed Lock Ended! 🔒** | Your 10 minutes are up — your apps are locked again. |
| 7 | A coach locks you | **Locked by {coach} 🔒** | Head to a coach's profile to ask them to snooze the lock. |
| 8 | A coach snoozes your lock | **Lock snoozed by {coach}! ⏳** | You've got 10 minutes before your apps lock again — make them count! |
| 9 | Tap shield "ask coach" button | **Tap to ask your coach 🙏** | Open PPTA to send your request for more time. |
| 10 | Mercy request filed (success) | **Request sent! 🙏** | Your coach(es) have been asked for more time. |
| 11 | Mercy request failed | **Couldn't send request 😕** | Try again from your lock screen. |

### B. Coach-facing — about their trainee (`traineeStatus` push)

Titles use `{trainee}` first name; body carries the detail.

| # | Situation | Title | Body |
|---|---|---|---|
| 12 | Trainee hit limit (Standard) | **{trainee} hit their time limit! 👀** | Go ahead and cut them off! |
| 13 | Locked — Hardcore auto | **{trainee} has been locked! 🔒** | They hit their limit — their apps locked automatically. |
| 14 | Locked — a coach did it | **{trainee} has been locked! 🔒** | {coach} cut off their apps. / actor: You cut off their apps. |
| 15 | Locked — snooze ran out | **{trainee} has been locked! 🔒** | Their snooze ran out — they're locked again. |
| 16 | Snoozed by a coach | **{trainee}'s lock has been snoozed! ⏳** | {coach} gave them 10 more minutes. / actor: You gave them 10 more minutes. |
| 17 | Back to all-clear | _(none — silent)_ | daily reset; Status Center refreshes, no banner |

### C. Coach-facing — lock/unlock action didn't land (15s verify)

| # | Situation | Title | Body |
|---|---|---|---|
| 18 | Lock may not have reached | **Lock may not have reached {name} ⚠️** | {name} may still have access to their apps. Try locking them again. |
| 19 | Snooze may not have reached | **Snooze may not have reached {name} ⚠️** | The snooze unlock didn't seem to go through. Try again. |

### D. Friends & role requests (user-to-user)

| # | Situation | Title | Body |
|---|---|---|---|
| 20 | Friend request received | **New friend request! 👋** | {name} sent you a friend request. |
| 21 | Friend request accepted | **Friend request accepted! 🎉** | {name} accepted your friend request. |
| 22 | Role request received | **New role request! 🤝** | {name} wants to be your coach. / …your trainee. |
| 23 | Role request accepted | **Request accepted! 🎉** | {name} accepted your coach/trainee request. |
| 24 | Relationship ended / unfriended | _(none — silent)_ | reloads lists silently, by design |

**Not built yet (see §6):** app-closed backend pushes for #20/#21 (they fire only while the app is
running), client-owned `settingsChanged`/`mercyRequest` copy, and decline notifications.
