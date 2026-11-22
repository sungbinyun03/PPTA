# Worth revisiting

Ideas we looked at and chose not to build yet: nice-to-haves, more expensive alternatives to what
shipped, and things that need more research. Each entry says what it is, why it was deferred, and
what would make it worth picking up. Unlike the README's *Open proposals*, nothing here is waiting on
a decision; it's parked on purpose.

When an entry is built, move it into the feature file and the CHANGELOG and delete it here.

## Entry format

- **What:** the idea in a sentence or two.
- **Deferred because:** why we didn't do it (cost, complexity, not needed yet).
- **Revisit when:** the signal that would make it worth it.
- **Sketch:** enough detail to start from.

---

## `badge-sync`: keep the app icon badge exact while PPTA is closed

*Logged 2026-11-15. Related: [features/app-badge.md](features/app-badge.md).*

- **What:** a new Cloud Run function that recomputes a user's app icon count whenever something
  that affects it changes in Firestore, and sends them a silent badge-only push. The icon would
  always be right, down as well as up, without anyone opening PPTA.
- **Deferred because:** what shipped (every existing push carries the recipient's current total)
  covers almost every case with no new service. The only gap is something resolved with no push to
  that user, e.g. someone cancels a request they sent you: the count stays one too high until your
  next push or app open. `badge-sync` would add a sixth service, Eventarc triggers, IAM setup and a
  new deploy step, and run on every `userSettings` write.
- **Revisit when:** testers notice stale badge counts, or we add more badge items that resolve
  without a push.
- **Sketch:**
  - `cloudrunfunctions/badge-sync.js` (Node): a CloudEvent handler on Firestore `document.written`
    for `userSettings`, `friendships` and `roleRequests`.
  - Work out who is affected: for `userSettings/{trainee}`, every uid in `coachIds` (only when
    `traineeStatus`, `snoozeRequestedCoachIds` or `coachIds` changed; return early otherwise, since
    most writes are ring/settings updates); for requests, the `requesteeId` / `targetId`.
  - Recount with the existing `badgeCountFor` (`badge.js`), and push only when the total changed:
    store the last sent value as `users/{uid}.badgeCount`.
  - Push: `apns-push-type: background`, `content-available: 1`, `data.badge`. The app already sets
    the icon from `data.badge` (`AppBadge.count(fromPush:)`). Note iOS doesn't wake a force-quit app
    for silent pushes, so an alert-free badge update can still be missed then.
  - Deploy: add to `deploy/cloudbuild.yaml` and `deploy.sh` (event-trigger flags), plus a one-time
    Eventarc setup: Firestore triggers and a service account with the Eventarc event receiver role.
  - Tests: Node tests for the "who is affected" filter and the only-on-change dedupe.

---

## Cleanup and optimisation review (2026-11-21)

*A full pass over code and docs at `3557104` (22 commits after `v1.0-beta.3`). Nothing here is broken;
each item is a candidate, with a rough cost (S < 1h, M < 1 day, L > 1 day). Decide per item.*

### Remove what no longer runs

- **Old-server fallbacks (M).** The server now always sends composed alert pushes and command ids,
  so these only serve app builds older than the server: `ALERT_PUSH` switches and the silent-push
  branches in `statusupdate.js`, `role-requests.js`, `lockapp.py`, `unlockapp.py`; the app's
  fallback copy for silent pushes (`PPTAMinimalApp.swift`, around the `traineeStatus` handler);
  `FriendProfileViewModel.scheduleVerification` ("Delete once the new server is deployed");
  the old-server note path in `CoachActionDisplay`. Safe once every tester runs a build newer than
  beta.3. Removes two copies of every notification string.
- **Status Center leftovers (S).** `Views/StatusCenter/` (5 files) and `Services/MercyRequestService.swift`
  are dead per their own headers. `StatusCenterViewModel` is *not* dead (Home uses it): rename it
  with the folder delete so the name stops pointing at a removed tab.
- **Shield "Ask a coach" handoff (S).** Button removed 2026-11-15; `ShieldHandoff`, the tap handler in
  `PPTAMinimalApp.userNotificationCenter(_:didReceive:)` and `NotificationManager.requestCoachesPopover`
  / `coachesPopoverRequestedAt` (and its listeners in `TabNavigator`, `TraineeCoachView`) remain.
- **Unused calls (S).** `NotificationManager.requestAuthorization()` has no callers since permissions
  moved to `Permissions.swift`.
- **Repo clutter (S).** `PPTAMinimal.zip` (265 KB) and `PPTAMinimal/.DS_Store` are committed. Root
  notes `CURRENT_IMPLEMENTATION_CHECKPOINT.md`, `STATUS_UPDATE_BACKEND.md`, `LAUNCH_TASKS.md` predate
  `docs/design` and partly contradict it: archive into `docs/design/archive/` or delete.
- **Legacy phone-based relationships (L).** `coaches`/`trainees`/`peerCoaches` and the phone→uid
  fallback (`resolvePhonesToUids`, `FirestoreService`) still coexist with `coachIds`/`traineeIds`.
  Needs a one-off Firestore migration, then the fallback code and `FirestoreService` go.

### Docs drift

- **CLAUDE.md is stale (S).** "Last verified against `876dfa3`"; says notification copy always uses
  `firstNameOnly` (notifications now title with the full name, 2026-11-11); lists `FirestoreService`
  as dead (it isn't: `UserSettingsManager`, `StatusCenterViewModel`, `FriendsContactsImportView` use it).
- **docs/agent (M).** Written before the notification service extension, Cloud Build deploys,
  Firestore rules, badge, permissions, and "extra time" wording. `firebase-firestore.md` and
  `file-folder-structure.md` repeat the first-name rule. Refresh, or point each file at docs/design
  for behaviour and keep docs/agent to structure only.
- **Firestore rules deploy is manual (S).** `firebase/README.md`: paste into the console. Nothing
  records which version is live. Add a deploy step (`firebase deploy --only firestore:rules`) to
  Cloud Build, or at least a "last published" line in the README.

### Code health

- **Debug `print` (M).** 124 `print(` calls across the app and extensions, including the FCM token
  (`PPTAMinimalApp.swift`). Move to `os.Logger` with categories; drop token logging.
- **Large files (M each).** `DeviceActivityManager.swift` (820 lines: shield policy, grace, lock
  application, settings events), `FriendProfileView.swift` (703), `AppLimitsView.swift` (672),
  `FriendProfileViewModel.swift` (660). Natural splits: lock delivery tracking out of the profile
  view model; grace/shield policy out of `DeviceActivityManager`.
- **App group id (S, check).** Every target uses `group.com.sungbinyun.com.PPTADev`. Fine if that is
  also the production group; decide before App Store release, since changing it later loses
  on-device state.
- **Shared server helpers (S).** `badge.js` showed the pattern: `fullName`, `firstName`,
  token lookup and the alert-push builder are duplicated between `statusupdate.js` and
  `role-requests.js`. Move them next to `badge.js`.

### Performance and cost

- **Sequential coach fan-out (S).** `statusupdate.js` loops coaches one at a time (user read, badge
  count of 3 queries, send). A trainee with 5 coaches is ~25 awaited round trips. `Promise.all`
  per coach cuts latency to one round trip deep.
- **Badge queries (S).** `badgeCountFor` runs 3 queries per recipient per push. Fine now; if pushes
  grow, cache the total on `users/{uid}` (see `badge-sync` above).
- **Firestore listeners (M, measure first).** Home, Friends, the profile sheet and the reconciler each
  hold listeners; some overlap (`userSettings` of the same trainees). Worth a read-count check in the
  Firebase console before changing anything.

### Testing

- **Device-only behaviour has no automated check (M).** Lock push → extension → shield, quiet
  (provisional) delivery, midnight boundary, permissions reminder. A written manual test script in
  docs/design (steps + expected result) would make each beta's smoke test repeatable.
- **Simulator test runs (S).** Parallel test clones hung twice; the reliable command is
  `xcodebuild test ... -parallel-testing-enabled NO -only-testing:PPTAMinimalTests` on an iOS 26+
  simulator. Record it in docs/agent.
