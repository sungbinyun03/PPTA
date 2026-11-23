# PPTA design docs

How PPTA behaves and why, feature by feature, with every change logged in the
[CHANGELOG](CHANGELOG.md). For how the code is structured, see `docs/agent/`.

## Features

| Feature | Status | File |
|---|---|---|
| Coach notifications (what coaches are told, exact copy) | Live | [features/coach-notifications.md](features/coach-notifications.md) |
| Trainee notifications (screen time warnings, locks) | Live | [features/trainee-notifications.md](features/trainee-notifications.md) |
| Friends and roles (requests, notifications) | Live | [features/friends-and-roles.md](features/friends-and-roles.md) |
| Locks and snoozes (coach actions, delivery, resend, midnight) | Live | [features/locks-and-snoozes.md](features/locks-and-snoozes.md) |
| App icon badge (red count of things waiting on you) | Live | [features/app-badge.md](features/app-badge.md) |
| Permissions (Screen Time, notifications, quiet mode, launch reminder) | Live | [features/permissions.md](features/permissions.md) |
| App Limits (On / Off) | Live | [features/app-limits.md](features/app-limits.md) |
| Backend deploy pipeline (Cloud Run via Cloud Build) | Live | [features/backend-deploy.md](features/backend-deploy.md) |

## Terminology

| Internal name (code, Firestore, docs) | What users see |
|---|---|
| snooze (`unlockapp`, `requestSnooze`, `snoozeRequestedCoachIds`) | **give 10 min** (`Give 10 More Minutes`, `Alex gave you 10 minutes`, `Ask for 10 Min`) |
| `TraineeStatus.snoozedLock` | **Extra time** (status pill, Home banner) |
| pressure level (`PressureLevel`, `pressureLevel`, Firestore `selectedMode`, events `pressureOn` / `pressureOff`) | **App Limits On / Off** (On is stored as `Standard`) |

Never put the word snooze, or Pressure for the On/Off setting, in user-facing copy ("Peer Pressure",
the brand, is fine). Identifiers stay as they are: renaming them would need
a Firestore migration and break older app builds.

## Roadmap

The next big versions (peers, feed, stats, personas, ads, sharing, removing Hardcore), with
decisions and open questions: [roadmap/](roadmap/README.md).

## Worth revisiting

Parked ideas, more expensive alternatives and further research, each with why it was deferred and
when to pick it up: [worth-revisiting.md](worth-revisiting.md).

## Open proposals (not decided)

- **Server-side automatic resend** of an unconfirmed lock (Cloud Tasks), and a snooze resend that
  reuses the same command id. Today only the coach can resend, and only locks.
- **Separate test services** for the backend so testing never touches live testers.
