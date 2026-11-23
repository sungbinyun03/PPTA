# Locks and snoozes

A coach can lock a trainee's monitored apps, and snooze a lock for 10 minutes. The lock has to be
applied on the trainee's phone (iOS only lets an app shield apps on its own device), so the server
records the command and pushes it, and the phone confirms ("acks") once applied.

"Snooze" is the internal name (code, Firestore, these docs). Users never see it: the app says
**give 10 min** for the action and **Extra time** for the state. See [README](../README.md#terminology).

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
- Any App Limits save (turning them Off included) lifts any lock, a coach lock included, and cancels
  extra time; usage is then re-checked under the new limits, so a trainee still over the limit is
  back to attention needed. Their coaches are told (see
  coach-notifications.md, "after going over their limit"). A coach lock ended this way stays ended
  for the rest of the day; a new lock works as usual.

## Copy (coach sheet)

| State | Text |
|---|---|
| Waiting | `Waiting for Sam's phone` |
| Stalled | `Sam's phone hasn't confirmed yet. The lock applies as soon as it's online or PPTA opens.` (extra time: `The extra time applies…`) |
| Confirmed | `Sam's apps are locked` / `Sam has 10 extra minutes` |
| Not applied | `Sam has App Limits turned off, so nothing changed.` / `Sam has no apps selected, so nothing changed.` / `A newer lock or extra time replaced this one.` |
| Trainee turned App Limits off | `Sam turned App Limits off, so their lock ended.` |
| Trainee changed App Limits | `Sam changed their App Limits, so their lock ended.` |

The two "lock ended" rows show to every coach on the trainee's sheet for the rest of the day, until a
newer lock or extra time replaces them.
| Resend button | `Resend` |

## Copy (buttons, banners, tips)

| Where | Text |
|---|---|
| Coach sheet button | `Give 10 More Minutes` |
| Note sheet before giving time | `Give Sam 10 minutes?` / `They'll see your note with the extra time.` / button `Give` |
| Status pill | `Extra time` |
| Trainee's request button on a coach's profile | `Ask for 10 Min` / `Asked for 10 min` |
| Home banner while it runs | `Extra Time` / `Your coach gave you 10 minutes. Apps re-lock when time's up.` |
| Home banner, cut off | `Alex locked your apps. Tap their avatar to ask for 10 more minutes.` / `A coach locked your apps. If you need more time, ask a coach for 10 minutes.` |
| Coach avatar tooltips (trainee) | `Alex gave you 10 minutes. Enjoy the break!` / `Alex locked your apps. Open their profile to ask for 10 more minutes.` / `Alex locked your apps, then gave you 10 minutes.` |
| Trainee halo tooltip (coach) | `Sam is asking for more time — open their profile to give them 10 minutes.` |
| Coach row tip (trainee) | `Open a coach's profile and tap Ask for 10 Min.` |
| Lock screen (shield) | `You've reached your limit on <app>` / `Open Peer Pressure the App and request more time from your coaches.` / one button `Got it` |
| Onboarding step | `Locked out? Ask a coach for 10 more minutes. Better make it a good excuse.` |

Notification copy for locks and snoozes: see [coach-notifications.md](coach-notifications.md).

## Decisions

- 2026-10-01: Off never lifts a coach lock (otherwise two taps escape any lock). Reversed 2026-11-11.
- 2026-11-11: Off lifts every lock, coach locks included, for emergencies. Coaches are told it's
  cheating instead of the trainee being kept locked.
- 2026-11-15: The lock screen drops its "Ask a coach for more time" button; its text already says
  where to go.
- 2026-11-15: Any App Limits save lifts every lock and cancels extra time, then re-checks usage under
  the new limits.
- 2026-11-15: "Snooze" leaves the UI; users see "give 10 min" / "Extra time". Code keeps snooze.
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
