# Design changelog

Newest first. Each entry: what was added, changed, removed or fixed, why, and the commit.

## 2026-11-11: App Limits notifications say what changed

- **Changed**: coaches now get a specific notification for Pressure off, Pressure on, a Standard ↔
  Hardcore switch, monitored apps changed, time limit changed (from → to), or both. Anything that may
  involve the app selection asks the coach to get a screenshot. Turning Pressure off is reported alone.
  Edits while Pressure stays off are no longer reported.
- **Why**: "changed their App Limits" didn't tell coaches what to look at.
- **Rollout**: server first (older app builds still get the generic copy); the detail appears once
  testers have the new app build.
- Also added these design docs. Folded in the live parts of the old
  `NOTIFICATIONS_AUDIT.md` (trainee and friend notification copy, checked against the code); the rest
  is archived in `archive/notifications-audit-2026-08.md`.

## 2026-11-11: Limit notification puts the limit in the body

- **Changed**: title back to `Sam hit their time limit! 👀`; body starts `Their limit is 1 hr 4 min.`
  Hardcore auto-lock uses the same title. Commit `937958b`.
- **Why**: `1h 15m` in the title read awkwardly.

## 2026-11-11: Deploy pipeline fixes

- **Fixed**: key check uses `grep` (`67169f2`); deploys run in three batches (`776a835`, `b6d5369`).
- **Why**: Google's image dropped `python3`; five parallel deploys hit a Cloud Build quota.

## 2026-11-10: Limit named in the coach's limit notification

- **Changed**: the limit appeared in the title (`Sam hit their 1h 15m limit! 👀`). Commit `dbc7c66`.
  Superseded on 2026-11-11.

## 2026-10-27: Coach can resend a stalled lock

- **Added**: the delivery row survives reopening the sheet; `Resend` on stalled locks only, for the
  coach who sent it, 60 s cooldown. Commit `20ecc3f`.
- **Why**: after reopening, the Lock button vanished with no explanation, and a lost push left the
  coach stuck.

## 2026-10-27: Backend deploys from `main`

- **Added**: Cloud Build trigger `ppta-functions`. Commits `c081909`, `10e5bae`.

## 2026-10-12: Locks apply while PPTA is closed

- **Added**: notification service extension applies coach lock and snooze pushes. Commit `540db63`.

## 2026-10-11: Snoozes end at midnight

- **Fixed**: a snooze granted near midnight no longer re-locks the trainee on the new day.
  Commit `325dae3`.
