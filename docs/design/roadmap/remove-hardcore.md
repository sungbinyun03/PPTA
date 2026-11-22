# Remove Hardcore

Status: decided (2026-11-21).

## Idea
Keep the app streamlined: Pressure has two levels, **On** and **Off**. No Standard or Hardcore.

## Today
Pressure is Off / Standard / Hardcore (`PressureLevelCard.swift`, `UserSettings.swift`). Hardcore
locks the trainee automatically at their limit ("cut-off"), with no coach involved; Standard tells
coaches, who decide. About 20 files mention Hardcore, including the monitor and shield extensions,
`statusupdate.js` and the tests.

## Decided
- 2026-11-21: **Pressure is On or Off.** On is today's Standard: hitting your limit tells your peers,
  who decide whether to lock you.
- 2026-11-21: **Hardcore users move to On silently** on update. Any Hardcore cut-off lock in place is
  lifted. Why: tiny beta group, no notice needed.
- 2026-11-21: **No auto-lock replaces it.** If no peer locks you, you keep going (it shows in stats
  and the feed). Why: the point is peer pressure; one less rule to explain.

## Technical defaults (no decision needed)
- Old builds still store `hardcore`: the server and new app treat it as On until everyone has
  updated, then the value is migrated away.
- Remove Hardcore copy, the cut-off status and shield variant, and the tests that cover them
  (about 20 files: `AppLimitsView`, `DeviceActivityManager`, the monitor and shield extensions,
  `statusupdate.js`, `UserSettings`, `PressureLevelCard`, `LockReconciler`...).
- Update `../features/app-limits.md` and the Pressure copy in `coach-notifications.md` when shipped.
