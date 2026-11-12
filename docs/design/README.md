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
| App Limits and Pressure | Live | [features/app-limits.md](features/app-limits.md) |
| Backend deploy pipeline (Cloud Run via Cloud Build) | Live | [features/backend-deploy.md](features/backend-deploy.md) |

## Open proposals (not decided)

- **Permissions gate.** A screen that every install sees until Screen Time and notifications are
  granted, rechecked on launch and foreground. Points raised: iOS shows the notification prompt only
  once (a denial can only be undone in Settings); Apple guideline 4.5.4 forbids requiring push
  notifications; a *provisional* notification grant needs no prompt and still runs the notification
  service extension. Also: the app currently asks for notifications at first launch
  (`PPTAMinimalApp.swift`), which uses up the one prompt before onboarding explains why.
- **Server-side automatic resend** of an unconfirmed lock (Cloud Tasks), and a snooze resend that
  reuses the same command id. Today only the coach can resend, and only locks.
- **Separate test services** for the backend so testing never touches live testers.
