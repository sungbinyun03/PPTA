# Trainee notifications

Notifications a trainee receives about their own screen time and locks. Most are local
notifications from the monitoring extension; coach lock/snooze ones come from the server push.

## Behaviour

- Regular iOS notifications, never in-app banners.
- Coach names are first names only. A coach's note replaces the default body of a lock or snooze.

## Copy

| When | Title | Body |
|---|---|---|
| Half the limit used | `Halfway there! ⏳` | `You've used half your daily screen time — pace yourself!` |
| 5 min left | `5 minutes left! ⏳` | `Just 5 minutes of screen time left today.` |
| 2 min left | `2 minutes left! ⏳` | `Only 2 minutes of screen time left today — wrap it up!` |
| Limit hit (Standard) | `Time's up! ⏰` | `You've hit your daily limit — your coaches have been notified.` |
| Limit hit (Hardcore) | `Time's up, you're cut off! 🔒` | `Head to a coach's profile to ask for 10 more minutes.` |
| Extra time ran out | `Extra Time's Up! 🔒` | `Your 10 minutes are up — your apps are locked again.` |
| A coach locked them | `Alex Coach` (coach's full name) | `Locked your apps 🔒 "note"` or `Locked your apps 🔒 Head to a coach's profile to ask for 10 more minutes.` |
| A coach gave them 10 minutes | `Alex Coach` (coach's full name) | `Gave you 10 minutes ⏳ "note"` or `Gave you 10 minutes ⏳ Make them count!` |

## Decisions

- 2026-08-25: No in-app banners; all notifications are system notifications.

## Where it lives

- `AppMonitor/DeviceActivityMonitorExtension.swift` (limit warnings, limit hit, snooze ended).
- `cloudrunfunctions/lockapp.py`, `unlockapp.py` (lock/snooze pushes); `PPTAMinimal/Models/ActionMessage.swift`
  (local fallback bodies).

## Open questions

- None.
