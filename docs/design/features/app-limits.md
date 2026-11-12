# App Limits and Pressure

A trainee picks Monitored Apps, a daily time limit and a Pressure level, saved together on the App
Limits screen.

## Behaviour

- Pressure levels: **Off** (nothing tracked), **Standard** (hitting the limit tells coaches, who can
  lock), **Hardcore** (hitting the limit locks the apps automatically).
- Standard and Hardcore need a viable setup: a time limit above zero and at least one app. Off can be
  saved with anything.
- Whole categories are dropped when the picker closes; the user picks individual apps so coaches can
  see exactly what is limited.
- A Hardcore trainee who is cut off cannot edit App Limits.
- The Commitment Streak resets on any change except lowering the time limit or Standard → Hardcore.
- Saving tells coaches what changed: see
  [coach-notifications.md](coach-notifications.md#app-limits-changed).

## Decisions

- 2026-10-11: No whole categories in the selection.
- 2026-11-11: Coaches are told what changed (see coach-notifications.md).

## Where it lives

- `PPTAMinimal/Views/Settings/AppLimitsView.swift` (screen, save), `PPTAMinimal/Models/UserSettings.swift`
  (`PressureLevel`, `appLimitsAreViable`), `PPTAMinimal/Managers/UserSettingsManager.swift` (save and
  coach notice).

## Open questions

- None.
