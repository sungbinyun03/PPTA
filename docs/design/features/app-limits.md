# App Limits

A trainee picks Monitored Apps and a daily time limit, and turns App Limits On or Off, saved together
on the App Limits screen. Internally the On/Off switch is still called "pressure level"
(`PressureLevel`, Firestore `selectedMode`); see the README's Terminology.

## Behaviour

- App Limits are **Off** (nothing tracked) or **On** (hitting the limit tells coaches, who can lock).
  Nothing locks automatically; coaches decide.
- On needs a viable setup: a time limit above zero and at least one app. Off can be saved with
  anything.
- Whole categories are dropped when the picker closes; the user picks individual apps so coaches can
  see exactly what is limited.
- Anyone can change App Limits at any time, even while locked or on extra time. Every save starts
  today over under the new limits: it lifts every lock and cancels extra time, then re-checks today's
  usage. Still over the new limit means attention needed again (coaches notified). A save made after
  going over the limit tells coaches they're cheating (see coach-notifications.md).
- The Commitment Streak resets on any change except lowering the time limit.
- Saving tells coaches what changed: see
  [coach-notifications.md](coach-notifications.md#app-limits-changed).
- Hardcore (auto-lock at the limit) was removed on 2026-11-22. A stored Hardcore reads as On; on the
  first launch of the new build it is written back as On without telling coaches, and a Hardcore lock
  that is up is lifted and usage re-checked (still over → attention needed, coaches get the usual
  "Hit their limit" push).

## Copy

| Where | Text |
|---|---|
| App Limits screen, section | `App Limits` with pills `Off` / `On` ★ |
| Info (?) | `Off:` `No monitoring. Take a break :)` / `On:` `Your coaches are told when you hit your limit and can lock your apps.` |
| Save confirm | `Are you sure?` / `Any change that isn't decreasing your time limit will reset your Commitment Streak.` |
| Not viable | `Set up App Limits first` / `Set a daily time limit and pick at least one app before turning App Limits on.` |
| Home card, App Limits off | `App Limits Off` / `Go to **Settings** and turn **App Limits** on so your coaches can hold you to your limit.` |
| Home, not set up | `App Limits aren't set up. Go to Settings → App Limits to pick your apps, set a daily time limit, and turn App Limits on.` |
| Settings, not set up | `Set a daily time limit, pick at least one app, and turn App Limits on.` |
| Friend profile tile | `App Limits` / `On` or `Off` |

## Decisions

- 2026-10-11: No whole categories in the selection.
- 2026-11-11: Coaches are told what changed (see coach-notifications.md).
- 2026-11-15: Any App Limits save lifts every lock and re-checks usage under the new limits; nothing
  is disabled while locked (replaces the 2026-11-11 Off-only rule).
- 2026-11-22: **Hardcore removed; App Limits are On or Off.** On is the old Standard. The word
  "Pressure" is gone from the UI ("App Limits On / Off"); internal names stay. Hardcore users move to
  On silently; no auto-lock replaces it. See roadmap/remove-hardcore.md.
- 2026-11-22: On keeps the stored value `Standard` so Firestore, the server and older builds need no
  migration.

## Where it lives

- `PPTAMinimal/Views/Settings/AppLimitsView.swift` (screen, save), `PPTAMinimal/Models/UserSettings.swift`
  (`PressureLevel`, `appLimitsAreViable`), `PPTAMinimal/Managers/UserSettingsManager.swift` (save,
  coach notice, `migrateFromHardcoreIfNeeded`), `PPTAMinimal/Views/Home/PressureOffHomeCardView.swift`.

## Open questions

- None.
