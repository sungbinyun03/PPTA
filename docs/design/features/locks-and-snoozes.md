# Locks and snoozes

A coach can lock a trainee's monitored apps, and snooze a lock for 10 minutes. The lock has to be
applied on the trainee's phone (iOS only lets an app shield apps on its own device), so the server
records the command and pushes it, and the phone confirms ("acks") once applied.

## Behaviour

- **Lock** is offered only while the trainee is **Attention needed**. **Snooze** is offered only while
  they are **Cut off** (greyed out while snoozed).
- While a lock or snooze is unconfirmed, the coach sheet shows a delivery row and offers no other
  lock action. The row is shown after reopening the sheet too (it reads the command from Firestore).
  - Under 60 s: `Waiting for Sam's phone` (spinner).
  - After 60 s: `Sam's phone hasn't confirmed yet. The lock applies as soon as it's online or PPTA opens.`
    (`snooze` instead of `lock` for a snooze).
- **Resend** appears on a stalled **lock**, only for the coach who sent it, with a 60 s cooldown. It
  calls `lockapp` again (a new command); the phone applies only the newest command, so a lock never
  applies twice. **No resend for snoozes**: if the first snooze applied but its ack was lost, a resend
  would grant a second 10 minutes.
- On the trainee's phone a lock applies: from the push via the notification service extension (works
  with PPTA closed, needs notification permission), or when PPTA opens.
- A snooze belongs to the day it was granted. A snooze still running at midnight is cancelled by the
  new day, not turned into a lock.
- Turning Pressure **Off** lifts any lock, a coach lock included: it's the trainee's emergency exit,
  and their coaches are told (see coach-notifications.md, "after going over their limit"). A coach
  lock ended this way stays ended if Pressure goes back on the same day; a new lock works as usual.
  Hardcore trainees who are cut off can switch to Off too (only to Off).

## Copy (coach sheet)

| State | Text |
|---|---|
| Waiting | `Waiting for Sam's phone` |
| Stalled | `Sam's phone hasn't confirmed yet. The lock applies as soon as it's online or PPTA opens.` |
| Confirmed | `Sam's apps are locked` / `Sam's lock is snoozed` |
| Not applied | `Sam has pressure turned off, so nothing changed.` / `Sam has no apps selected, so nothing changed.` / `A newer lock or snooze replaced this one.` |
| Trainee turned Pressure off | `Sam turned Pressure off, so their lock ended.` |
| Resend button | `Resend` |

Notification copy for locks and snoozes: see [coach-notifications.md](coach-notifications.md).

## Decisions

- 2026-10-01: Off never lifts a coach lock (otherwise two taps escape any lock). Reversed 2026-11-11.
- 2026-11-11: Off lifts every lock, coach locks included, for emergencies. Coaches are told it's
  cheating instead of the trainee being kept locked.
- 2026-10-11: Snoozes are scoped to the day they were granted.
- 2026-10-27: Coach resend for stalled locks only, client-side (no server change).

## Where it lives

- Coach sheet: `PPTAMinimal/ViewModels/FriendProfileViewModel.swift` (`LockDelivery`, `track`,
  `canResendLock`, `resendLock`), `PPTAMinimal/Views/Friends/FriendProfileView.swift`,
  `FriendProfileSheetView.swift`.
- Trainee device: `PPTAMinimal/Managers/LockReconciler.swift`, `PPTANotificationService/`,
  `DeviceActivityManager.swift` (`UnlockGrace`, `liftUserClearableShield`); `LockReconciler.swift` (ended locks,
  `LocalSettingsStore.endedLockCommandId`), `AppMonitor/`.
- Server: `cloudrunfunctions/lockapp.py`, `unlockapp.py`, `statusupdate.js` (acks for the extension).

## Open questions

- Server-side automatic resend; snooze resend with the same command id (see README proposals).
