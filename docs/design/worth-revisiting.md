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
