# Design changelog

Newest first. Each entry: what was added, changed, removed or fixed, why, and the commit.



## 2026-11-22: Hardcore removed; App Limits are On or Off
- **Removed** Hardcore (auto-lock at the limit). Hitting the limit always tells coaches, who decide.
  Removed with it: the Hardcore pill, the "Hardcore mode locked <app>" shield title, the Hardcore
  Home banner line and trainee notification, the repeat-fire shield re-assert, the Standard ↔
  Hardcore coach notice, and the Standard → Hardcore streak exception. Deleted the unused
  `PressureLevelCard.swift`.
- **Changed** the word "Pressure" is gone from the UI: the setting is **App Limits On / Off** (App
  Limits screen, Home card `App Limits Off`, Settings, friend profile tile, lock-ended lines).
  Internal names stay (`PressureLevel.off` / `.on`; On is still stored as `Standard`).
- **Added** a one-time silent move for Hardcore users: written back as On without a coach notice; a
  Hardcore lock that is up is lifted and usage re-checked.
- **Kept** for trainees on older builds: the `hardcoreLimit` coach copy and the server's
  `levelChanged` copy (see worth-revisiting.md).
- Why: keep the app streamlined; peers decide (roadmap/remove-hardcore.md).

## 2026-11-21: Roadmap for the next big versions
- **Added** `roadmap/`: one file per planned feature (remove Hardcore, peers, stats, tabs and feed,
  personas, ads and in-app purchases, invite link), with the decisions made in chat, open questions
  and the agreed order. Nothing built yet.

## 2026-11-16: Permissions screen, quiet notifications, launch reminder

- **Added**: a permissions screen (Screen Time + notifications, with why), as an onboarding step
  after App Limits and as a reminder over the app on each launch while either is missing ("Not now"
  to skip). Settings → Alerts to choose Alerts or Quiet.
- **Changed**: launch requests quiet (provisional) notifications silently instead of showing iOS's
  prompt with no context, so locks apply while PPTA is closed even for people who never answer.
  Find Coach no longer asks for notifications.
- **Why**: the lock extension only runs when notifications are on, and the app can't require them.
- **Rollout**: next app build. See features/permissions.md.

## 2026-11-15: Coach/trainee request pushes were never delivered

- **Fixed**: "Coach Request" / "Trainee Request" pushes and their "accepted" pushes were rejected by
  Apple since server-composed alerts shipped (`876bc9a`): the push's `apns-collapse-id` was
  `roleReq-<requester>_<target>_<role>`, about 73 bytes, over APNs' 64-byte limit. Long ids are now
  hashed (`role-requests.js` `apnsCollapseId`). Friend request pushes were unaffected.

## 2026-11-15: Red count on the app icon

- **Added**: PPTA's app icon shows how many things are waiting on you: trainees needing attention,
  trainees asking you for more time, and incoming friend and coach/trainee requests. Every push
  carries the current total, so it updates while PPTA is closed. See features/app-badge.md.
- **Why**: Chee Seng: make it clearer when something needs doing.
- **Rollout**: pushes carry the count on deploy; the in-app count and silent-push handling with the
  next build.

## 2026-11-15: Changing App Limits lifts locks and starts over

- **Changed**: App Limits is never disabled, even for a cut-off Hardcore trainee. Any save lifts
  every lock (Hardcore's or a coach's) and cancels extra time, then re-checks today's usage under
  the new limits: still over means attention needed again (Standard) or locked again (Hardcore).
  Coaches get the "after going over their limit" notification; the coach sheet says
  `Sam changed their App Limits, so their lock ended.`
- **Fixed**: the coach sheet's stalled extra-time row said "snooze".
- **Fixed**: the "lock ended" row (Pressure Off / App Limits) showed only to a coach who had sent
  that lock from the sheet in the same session; it now shows to every coach for the rest of the day.
- **Removed**: the lock screen's "Ask a coach for more time" button (and the notification it posted).
- **Why**: the notification is the deterrent, not a disabled screen; the limits should always
  reflect what the trainee chose.

## 2026-11-15: "Snooze" leaves the UI

- **Changed**: every user-facing "snooze" now says what happens: coaches **Give 10 More Minutes**, trainees
  **Ask for 10 Min**, the state is **Extra time**. Notifications: `Alex gave them 10 minutes. ⏳`,
  `Their 10 minutes ran out, so they're locked again. 🔒`, `Gave you 10 minutes ⏳ Make them count!`,
  `Extra Time's Up! 🔒`, and "ask for a snooze" hints read "ask for 10 more minutes". Full list in
  locks-and-snoozes.md, coach-notifications.md and trainee-notifications.md.
- **Unchanged**: code and Firestore names (`snoozedLock`, `snoozeRequestedCoachIds`, `unlockapp`).
- **Why**: "snooze" confused users; "10 minutes" says exactly what they get.
- **Rollout**: push copy on deploy; in-app copy with the next TestFlight build.

## 2026-11-11: Pressure Off is an emergency exit; coaches hear about it

- **Changed**: turning Pressure Off lifts a coach lock too (it used to stay, with an in-app `Coach
  lock stays on`). The ended lock doesn't come back if Pressure goes back on the same day. Cut-off
  Hardcore trainees can now switch to Off (only to Off). The coach sheet says
  `Sam turned Pressure off, so their lock ended.`
- **Added**: any App Limits save after going over the limit (attentionNeeded, cutOff, snoozed) tells
  coaches `Changed their App Limits after going over their limit! They're cheating 👹`.
- **Removed**: the `Coach lock stays on` message.
- **Why**: let people reach their apps in an emergency; coaches are told instead.
- **Rollout**: server copy on deploy; the app behaviour with the next TestFlight build.

## 2026-11-11: Notifications titled with the person's name

- **Changed**: coach notifications about a trainee (limit, locks, snoozes, more-time asks, reinstall,
  App Limits) and the trainee's lock/snooze notifications are titled with the other person's full
  name; the body says what happened. Friend, coach and trainee requests are titled `Friend Request`,
  `Coach Request`, `Trainee Request`, with the person's full name in the body. More-time asks gain 🛐.
  The trainee's own screen time warnings are unchanged.
- **Why**: matches how other apps word notifications about a person.
- **Rollout**: server copy changes on deploy; the app's fallback copy with the next TestFlight build.

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
