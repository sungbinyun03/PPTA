# Permissions (Screen Time and notifications)

PPTA needs Screen Time to track and lock apps, and notifications so a coach's lock or extra time
applies while PPTA is closed (the notification service extension only runs for a delivered push).
Neither is ever required: App Review 4.5.4 forbids requiring push, so every ask has a way on.

## Behaviour

- **Notifications are one iOS permission with four states:**

  | State | How you get there | Locks apply while PPTA is closed? |
  |---|---|---|
  | Not asked | Fresh install | No |
  | Quiet (provisional) | PPTA requests it silently at launch; no prompt | Yes (pushes land in Notification Centre only) |
  | Alerts | iOS's prompt → Allow, or Keep on a quiet notification | Yes |
  | Off | iOS's prompt → Don't Allow, or Turn Off on a quiet notification | No; only iOS Settings can undo it |
  | Quiet (in Settings) | Allowed, with Banners and Sounds turned off for PPTA in iOS Settings | Yes. Counts as Quiet in PPTA |

- **Launch:** quiet mode for anyone never asked. iOS's real prompt is never shown cold; only from the
  permissions screen, after it says why (iOS shows it once per install).
- **Permissions screen** (onboarding look): a card each for Screen Time and Notifications with status
  and why. Buttons: Turn On (Screen Time prompt / iOS's notification prompt), Open Settings when
  notifications are off.
- **Onboarding:** step after App Limits, so every new user sees the option of full alerts. Skipped
  going forward only when there is nothing to offer (full alerts, or quiet chosen in Settings, plus
  Screen Time).
- **Launch reminder:** once per app launch, after the launch screen, if Screen Time is off or
  notifications are off (quiet counts as on), the permissions screen opens over the app. "Not now"
  closes it until next launch; coming back from Settings re-checks and closes it once everything is
  on. Not shown right after onboarding's permissions step.
- **Settings → Alerts:** choose Alerts or Quiet; the row shows On / Quiet / Off (orange mark when off).
  Alerts asks iOS (from quiet or not asked). Quiet from Alerts can only be done in iOS Settings
  (turn off Banners and Sounds), so it explains and opens Settings. Off shows Open Settings.
- Find Coach no longer asks for notifications itself.

## Copy

Keep copy short: say what to do and what the user gets, never how it works (iOS prompting once,
pushes letting a lock apply while PPTA is closed).

Wording standard:
- Verbs: **turn on / turn off** (never enable/disable). States: **On**, **Off**, **Quiet**.
- **Notifications** is the permission; **Alerts** (banners and sounds) and **Quiet** (neither) are its
  two styles. Not "push notifications".
- iOS Settings labels are quoted exactly: Allow Notifications, Banners, Sounds.

| Where | Text |
|---|---|
| Screen title / message | `Keep the pressure on` / `Two permissions are needed for the full Peer Pressure experience.` |
| Screen Time, off / on | `Lets PPTA track the apps you picked and lock them when you hit your limit.` / `On.` |
| Notifications, not asked | `Hear from your coaches and trainees as it happens.` |
| Notifications, quiet (iOS default) | `On, but quiet by default. Turn on Alerts to get banners and sounds.` |
| Notifications, quiet (Settings) | `On, but quiet: banners and sounds are off in Settings.` |
| Notifications, alerts | `On.` |
| Notifications, off | `Off. Highly recommended to turn on (even in quiet mode) so Peer Pressure works as intended.` |
| Buttons | `Turn On`, `Next` (onboarding), `Not now` / `Done` (reminder) |
| Settings → Alerts | `Highly recommended to keep notifications on (even in quiet mode) so Peer Pressure works as intended.` (when off: `...to turn on notifications...`); `Alerts`: `Banners and sounds when your coaches or trainees need you.`; `Quiet`: `No banners or sounds; notifications wait in Notification Centre.`; off: `Notifications are off` / `Turn them on, then pick Alerts or Quiet here.` |
| Settings help alerts (then `Open Settings`) | `Turn on notifications`: `Turn on Allow Notifications for PPTA in Settings.` / `Switch to Quiet`: `Turn off Banners and Sounds for PPTA in Settings.` / `Turn on Alerts`: `Turn on Banners and Sounds for PPTA in Settings.` |

## Decisions

- 2026-11-16: The permissions screen only appears when Screen Time or notifications are off; quiet is
  enough (pushes still arrive and the lock extension runs).
- 2026-11-16: Quiet (provisional) notifications by default; iOS's prompt only behind PPTA's own
  screen; a skippable reminder on every launch instead of a gate (4.5.4). Our buttons say `Turn On`,
  not `Allow`, so the screen doesn't mimic iOS's prompt.

## Where it lives

- `PPTAMinimal/Managers/Permissions.swift` (states, rules, requests), `Views/Onboarding/PermissionsView.swift`,
  `Views/Settings/AlertsSettingsView.swift`; launch request in `PPTAMinimalApp.swift` (AppDelegate);
  reminder in `Views/TabNavigator.swift`; onboarding step in `OnboardingCoordinator`.

## Open questions

- Confirm on a device that the notification service extension runs for quiet (provisional) pushes.
