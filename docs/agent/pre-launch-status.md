Covers §15 Pre-launch Status from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 15. Pre-launch Status

### Done
- Auth (email/password, Google, Apple) + account deletion
- Friend requests; role requests with live incoming **and** outgoing/cancellable rows
- UID-based coach-trainee relationships
- DeviceActivity monitoring with tiered limit warnings
- Pressure levels (Off/Standard/Hardcore), consolidated into App Limits
- Custom shield lock screen (`PPTAShieldConfiguration`) + "Ask my coach" handoff (`PPTAShieldAction`)
- Per-app block-attempt stats surfaced on the coach's profile view
- Remote lock + per-coach snooze (10 min of monitored usage), with `LockCause` attribution
- Trainee status tracking (all 5 states)
- Commitment Streak
- Reinstall detection + coach notification
- System notifications for all coach/trainee events
- ScreenTime report (3 scenes) + settings-change-anchored ring reset
- Onboarding (5 steps, resumable, per-user) + trimmed post-reinstall reconfigure flow
- Contacts import; profile image upload (Settings)
- App group bridges (main app ↔ AppMonitor, main app ↔ shield extensions)

### Partially Done
- Phone number flows (legacy phone sign-in; UID migration in progress)
- Streak model — Commitment Streak ships, **Clean Streak is stubbed in the UI copy only** ("Coming soon")
- Extension ↔ main app sync (working, but untested under edge cases)

### Not Started / Missing
- Forgot password flow
- Clean Streak (days since last cut off) — needs its own field
- Invite flow (banner exists, does nothing)
- International phone number support
- Unit tests (`PPTAMinimalTests` empty) and UI tests (`PPTAMinimalUITests` empty)
- Offline-first sync (fully Firestore-dependent)

### Overall status
**Pre-beta.** Core loop is functional end-to-end including the shield and snooze flows. Blockers
before first TestFlight: forgot password, the streak field split, and deleting the dead Status
Center folder. The UID-based relationship model is the future; avoid adding to the legacy
phone-based system.

---
