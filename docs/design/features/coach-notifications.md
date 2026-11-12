# Coach notifications

Push notifications a coach receives about a trainee. The server (`cloudrunfunctions/statusupdate.js`)
writes the copy, so a copy change ships on deploy without an app update. The app keeps matching
fallback copy for silent pushes from an older server.

## Behaviour

- Titles are the trainee's full name (first and last); the body says what happened. Another coach
  named in a body uses their first name.
- Durations are written as Screen Time does: `1 hr 4 min`, `45 min`, `2 hr`. Limits are stored in
  whole minutes, so there are no seconds.
- **Status changes** (`traineeStatus`) go to every coach of the trainee. The coach who acted sees "You…".
- **App Limits changes** (`traineeSettingsChanged`) go to every coach. The trainee's app works out
  what changed and sends it; the server picks the copy. Only one notification per save:
  - Any save made after going over their limit today (attentionNeeded, cutOff or snoozed) gets the
    "cheating" copy instead, whatever changed.
  - Pressure turned **Off** is reported alone, whatever else changed.
  - Pressure turned **on** (from Off) asks for a screenshot.
  - A **Standard ↔ Hardcore** switch is reported as the switch and asks for a screenshot (apps and
    time limit may have changed too).
  - Otherwise: apps only, time limit only, or both.
  - Edits made while Pressure stays Off are not reported.
  - First-time setup is not reported (no previous viable limits).
  - An older app build sends no detail, and coaches get the generic copy.

## Copy

Every title is the trainee's full name (first and last), e.g. `Sam Trainee`; shown below as `Sam Trainee`.
The body says what happened. Another coach is named by first name in the body (`Alex`).

### Trainee hit their limit

| When | Title | Body |
|---|---|---|
| Standard, limit hit | `Sam Trainee` | `Hit their 1 hr 4 min limit. Go ahead and cut them off! 👀` |
| Hardcore, apps locked automatically | `Sam Trainee` | `Hit their 1 hr 4 min limit. They're on Hardcore, so their apps locked themselves. 🔒` |
| Limit unknown (safety net) | `Sam Trainee` | `Hit their time limit. Go ahead and cut them off! 👀` |

### Locks and snoozes

| When | Title | Body |
|---|---|---|
| Coach locked them | `Sam Trainee` | `You cut off their apps. 🔒` / `Alex cut off their apps. 🔒` |
| Snooze ran out | `Sam Trainee` | `Their snooze ran out, so they're locked again. 🔒` |
| Other lock | `Sam Trainee` | `Their apps are now locked. 🔒` |
| Snoozed | `Sam Trainee` | `You snoozed their lock for 10 minutes. ⏳` / `Alex snoozed their lock for 10 minutes. ⏳` |
| New day (allClear) | none | none |

### Requests and alerts

| When | Title | Body |
|---|---|---|
| Trainee asks this coach for more time | `Sam Trainee` | `Asking for more time 🛐 "note"` or `Asking for more time 🛐 Open PPTA to snooze their lock.` |
| Trainee deleted and reinstalled PPTA | `Sam Trainee` | `Deleted and reinstalled PPTA. Might want to check if they're cheating 🤨` |
| Coach's lock/snooze not confirmed (old server only) | `Lock not confirmed for Sam yet` / `Snooze not confirmed for Sam yet` | `Sam's phone hasn't confirmed the lock.` / `…the snooze.` |

### App Limits changed

`ASK` = `Ask for a screenshot to see what they're tracking!`

| When | Title | Body |
|---|---|---|
| Any change after going over their limit | `Sam Trainee` | `Changed their App Limits after going over their limit! They're cheating 👹` |
| Pressure turned Off | `Sam Trainee` | `Stopped tracking their apps 🥀 Why did they stop locking in?` |
| Pressure turned on | `Sam Trainee` | `Started tracking their apps 💪 ` + ASK |
| Switched to Hardcore | `Sam Trainee` | `Switched to Hardcore 🔥 ` + ASK |
| Switched to Standard | `Sam Trainee` | `Switched to Standard. ` + ASK |
| Monitored apps changed | `Sam Trainee` | `Changed their monitored apps. ` + ASK |
| Time limit changed | `Sam Trainee` | `Changed their time limit from 1 hr 30 min to 2 hr. Monitored apps stayed the same.` |
| Apps and time limit changed | `Sam Trainee` | `Changed all their App Limits. ` + ASK |
| Older app build (no detail) | `Sam Trainee` | `Changed their App Limits. ` + ASK |

## Decisions

- 2026-08-25: Every notification is a regular iOS system notification, never an in-app banner.
- 2026-08-25: Going back to all clear at the new day is silent.

- 2026-11-11: The limit goes in the **body**, not the title ("1h 15m" in a title read awkwardly and
  could be cut off by long names).
- 2026-11-11: Every coach notification about a trainee is titled with the trainee's **full name**;
  the body merges what used to be the title and body (like other apps' person notifications).
- 2026-11-11: App Limits notifications name what changed. Anything that may involve the app selection
  asks the coach to get a screenshot from the trainee, because iOS hides a trainee's apps from coaches.
- 2026-11-11: Turning Pressure off is reported alone; turning it back on asks for the screenshot.
- 2026-11-11: A Standard ↔ Hardcore switch assumes apps/time limit may also have changed, so it asks
  for a screenshot.
- 2026-11-11: The screenshot ask: `Ask for a screenshot to see what they're tracking!`. A
  time-limit-only change says `Monitored apps stayed the same.`; when apps and the time limit both
  change, there is no from → to.
- 2026-11-11: A save made after going over the limit is reported as cheating, one body for every
  change (Pressure Off now lifts coach locks, so this is how coaches find out).
- 2026-11-11: A more-time ask carries 🛐 (not used by any other notification).

## Where it lives

- Server copy: `cloudrunfunctions/statusupdate.js`: `traineeStatusCopy`, `settingsChangedCopy`,
  `formatLimit`. Tests: `cloudrunfunctions/test_statusupdate_message.js`.
- App fallback copy (status pushes): `PPTAMinimal/PPTAMinimalApp.swift`, `traineeStatus` handler.
- What changed on save: `PPTAMinimal/Managers/UserSettingsManager.swift`:
  `notifyCoachesIfSetupChanged`, `settingsEvent`. Sent by
  `DeviceActivityManager.sendSettingsChanged` (`SettingsEvent`). Tests: `SettingsEventTests`.

## Open questions

- None.
