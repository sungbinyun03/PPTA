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
- Anyone can change App Limits at any time, even while locked or on extra time. Every save starts
  today over under the new limits: it lifts every lock (Hardcore's or a coach's) and cancels extra
  time, then re-checks today's usage. Still over the new limit means Standard goes back to
  attention needed (coaches notified) and Hardcore locks again at once. A save made after going
  over the limit tells coaches they're cheating (see coach-notifications.md).
- The Commitment Streak resets on any change except lowering the time limit or Standard → Hardcore.
- Saving tells coaches what changed: see
  [coach-notifications.md](coach-notifications.md#app-limits-changed).

## Decisions

- 2026-10-11: No whole categories in the selection.
- 2026-11-11: Coaches are told what changed (see coach-notifications.md).
- 2026-11-11: Cut-off Hardcore trainees may switch to Off.
- 2026-11-15: Any App Limits save lifts every lock and re-checks usage under the new limits; nothing
  is disabled while locked (replaces the 2026-11-11 Off-only rule).

## Where it lives

- `PPTAMinimal/Views/Settings/AppLimitsView.swift` (screen, save), `PPTAMinimal/Models/UserSettings.swift`
  (`PressureLevel`, `appLimitsAreViable`), `PPTAMinimal/Managers/UserSettingsManager.swift` (save and
  coach notice).

## Open questions

- None.
