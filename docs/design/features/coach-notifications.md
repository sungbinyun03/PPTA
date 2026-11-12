# Coach notifications

Push notifications a coach receives about a trainee. The server (`cloudrunfunctions/statusupdate.js`)
writes the copy, so a copy change ships on deploy without an app update. The app keeps matching
fallback copy for silent pushes from an older server.

## Behaviour

- Names are first names only.
- Durations are written as Screen Time does: `1 hr 4 min`, `45 min`, `2 hr`. Limits are stored in
  whole minutes, so there are no seconds.
- **Status changes** (`traineeStatus`) go to every coach of the trainee. The coach who acted sees "You…".
- **App Limits changes** (`traineeSettingsChanged`) go to every coach. The trainee's app works out
  what changed and sends it; the server picks the copy. Only one notification per save:
  - Pressure turned **Off** is reported alone, whatever else changed.
  - Pressure turned **on** (from Off) asks for a screenshot.
  - A **Standard ↔ Hardcore** switch is reported as the switch and asks for a screenshot (apps and
    time limit may have changed too).
  - Otherwise: apps only, time limit only, or both.
  - Edits made while Pressure stays Off are not reported.
  - First-time setup is not reported (no previous viable limits).
  - An older app build sends no detail, and coaches get the generic copy.

## Copy

### Trainee hit their limit

| When | Title | Body |
|---|---|---|
| Standard, limit hit | `Sam hit their time limit! 👀` | `Their limit is 1 hr 4 min. Go ahead and cut them off!` |
| Hardcore, apps locked automatically | `Sam hit their time limit! 👀` | `Their limit is 1 hr 4 min. They're on Hardcore, so their apps locked themselves. 🔒` |
| Limit unknown (safety net) | `Sam hit their time limit! 👀` | Body without the `Their limit is …` sentence |

### Locks and snoozes

| When | Title | Body |
|---|---|---|
| Coach locked them | `Sam has been locked! 🔒` | `You cut off their apps.` / `Alex cut off their apps.` |
| Snooze ran out | `Sam has been locked! 🔒` | `Their snooze ran out — they're locked again.` |
| Other lock | `Sam has been locked! 🔒` | `Their apps are now locked.` |
| Snoozed | `Sam's lock has been snoozed! ⏳` | `You gave them 10 more minutes.` / `Alex gave them 10 more minutes.` |
| New day (allClear) | none | none |

### Requests and alerts

| When | Title | Body |
|---|---|---|
| Trainee asks this coach for more time | `Sam is asking for more time` | Their note in quotes, or `Open PPTA to snooze their lock.` |
| Trainee deleted and reinstalled PPTA | `Sam reinstalled PPTA` | `They deleted the app and reinstalled it, might want to check if they're cheating 🤨` |
| Coach's lock/snooze not confirmed (old server only) | `Lock not confirmed for Sam yet` / `Snooze not confirmed for Sam yet` | `Sam's phone hasn't confirmed the lock.` / `…the snooze.` |

### App Limits changed

`ASK` = `Ask for a screenshot of their App Limits to know what they're tracking!`

| When | Title | Body |
|---|---|---|
| Pressure turned Off | `Sam stopped tracking their apps! 🥀` | `Their apps aren't being tracked anymore. Why did they stop locking in?` |
| Pressure turned on | `Sam started tracking their apps! 💪` | `ASK` |
| Switched to Hardcore | `Sam switched to Hardcore 🔥` | `ASK` |
| Switched to Standard | `Sam switched to Standard` | `ASK` |
| Monitored apps changed | `Sam changed their monitored apps` | `ASK` |
| Time limit changed | `Sam changed their time limit` | `From 1 hr 30 min to 2 hr. Monitored apps stayed the same.` |
| Apps and time limit changed | `Sam changed all their App Limits` | `ASK` |
| Older app build (no detail) | `Sam changed their App Limits` | `They updated their App Limits, reach out to them for a screenshot so you know their goals!` |

## Decisions

- 2026-08-25: Every notification is a regular iOS system notification, never an in-app banner.
- 2026-08-25: Going back to all clear at the new day is silent.

- 2026-11-11: The limit goes in the **body**, not the title ("1h 15m" in a title read awkwardly and
  could be cut off by long names). The title stays `hit their time limit!`.
- 2026-11-11: Hardcore auto-lock uses the same title as Standard; only the body differs.
- 2026-11-11: App Limits notifications name what changed. Anything that may involve the app selection
  asks the coach to get a screenshot from the trainee, because iOS hides a trainee's apps from coaches.
- 2026-11-11: Turning Pressure off is reported alone; turning it back on asks for the screenshot.
- 2026-11-11: A Standard ↔ Hardcore switch assumes apps/time limit may also have changed, so it asks
  for a screenshot.
- 2026-11-11: The screenshot ask is explicit: `Ask for a screenshot of their App Limits to know what
  they're tracking!`. A time-limit-only change says `Monitored apps stayed the same.`; when apps and
  the time limit both change, the body is only the screenshot ask (no from → to).

## Where it lives

- Server copy: `cloudrunfunctions/statusupdate.js`: `traineeStatusCopy`, `settingsChangedCopy`,
  `formatLimit`. Tests: `cloudrunfunctions/test_statusupdate_message.js`.
- App fallback copy (status pushes): `PPTAMinimal/PPTAMinimalApp.swift`, `traineeStatus` handler.
- What changed on save: `PPTAMinimal/Managers/UserSettingsManager.swift`:
  `notifyCoachesIfSetupChanged`, `settingsEvent`. Sent by
  `DeviceActivityManager.sendSettingsChanged` (`SettingsEvent`). Tests: `SettingsEventTests`.

## Open questions

- None.
