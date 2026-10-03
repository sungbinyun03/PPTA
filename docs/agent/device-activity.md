Covers §10 DeviceActivity & ScreenTime from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 10. DeviceActivity & ScreenTime

### Monitoring setup (DeviceActivityManager)
- Daily activity name: `AppUsageMonitoring`; schedule 00:00–23:59:59, repeating (no `warningTime`)
- Events include **both** `applicationTokens` AND `categoryTokens`
- `isMonitoringActive` is cross-checked against `DeviceActivityCenter().activities` on every start, so a device restart or OS suspension can't permanently block restarts
- Shielding: `ManagedSettingsStore().shield.applications`

### Full-day enforcement (`includesPastActivity`)
The daily limit and warning events are built with `includesPastActivity: true` (iOS 17.4+), so they
count **total** usage since midnight — the same number the report shows. A mid-day save or monitoring
restart no longer resets the count, and saving a limit below today's usage trips it right away
(Hardcore: shield; Standard: `.attentionNeeded`). The unlock-grace event deliberately does **not**
set it: it measures usage from the Release.

Consequence: any restart of monitoring while over (launch re-arm, re-save, reinstall) fires the events
immediately. `LimitFireGate` (in `DeviceActivityManager.swift`, pure) makes the extension's
`eventDidReachThreshold` idempotent per day, using App Group markers:
- `limitReachedFiredMarker` = `day|limitMinutes|pressure`: `LimitEvent.reached` acts once per day per limit+pressure. A repeat sends no `statusUpdate`, no notification and never calls `ShieldPolicy.apply` — so it can't re-lock after a coach Release / snooze, and can't stamp `lastRaisedAt` (which would make a late Release read as superseded in `LockReconciler`). Changing the limit or pressure level is a deliberate change and re-arms the gate.
- `limitWarningFiredMarker` = `day|limitMinutes|highestMinutes`: a warning fires only if above every warning already fired that day for that limit; all warnings share one notification identifier (`limit-warning`), so a burst of already-passed tiers leaves at most the highest one.

### Tiered limit warnings (`enum LimitEvent`)
Events armed by `warningThresholds(forLimitMinutes:)`, in minutes of cumulative usage (since midnight):

| Daily limit | Events armed |
|---|---|
| `< 2` | none |
| `2...4` | 2-minute |
| `5...10` | halfway + 2-minute |
| `> 10` | halfway + 5-minute + 2-minute |

A tier is emitted only when its threshold lands in `1 ..< limit`. These are **trainee-only nudges**:
local notification, no status change, no shield, no backend call.

`eventWillReachThresholdWarning` is now an explicit **no-op**. It depended on the schedule's
`warningTime` (never set), fired unreliably, and used to flip trainees to `.attentionNeeded` before
they'd actually hit the limit — telling coaches they were in trouble early.

### Snooze / unlock grace period (`enum UnlockGrace`)
When a coach releases a trainee, `handleRemoteUnlock` clears the shield and arms a **second**
DeviceActivity activity (`UnlockGracePeriod`) with a `graceExpired` event at 10 minutes. The
threshold measures **monitored-app usage, not wall clock** — the grace only burns down while the
trainee is actually in the shielded apps. On expiry the extension re-shields in every mode and sets
`.cutOff` with `cause: .snoozeEnded`, so the trainee reappears to their coaches with Release enabled
again — coaches can release repeatedly, 10 minutes at a time. During the window the status is
`.snoozedLock`.

Three non-obvious constraints, all easy to reintroduce as bugs:
- **`stopMonitoring()` must never stop the grace activity.** A trainee mid-grace reads as unlocked, so `AppLimitsView`'s `guard !isLocked` lets their save through; if that save stopped every activity, tapping Save would cancel their own re-lock and leave them unlocked all day. Use `stopAllMonitoring()` only for teardown and for Off.
- The grace schedule **must start at `now`**, not midnight. Thresholds count usage from the interval's start, so a midnight-anchored interval is already past 10 minutes and fires instantly. The interval ends one minute *before* it starts, wrapping around midnight to a ~24h window that clears the system's undocumented ~15-minute minimum.
- Every `intervalDidStart` / `intervalDidEnd` / `eventWillReachThresholdWarning` override must ignore `UnlockGrace.activityName`, or the grace activity's own interval boundaries clear the shield or fire spurious status updates.

### Extension event handlers (`AppMonitor/DeviceActivityMonitorExtension.swift`)

| Event | Off | Standard | Hardcore |
|---|---|---|---|
| `intervalDidStart` | (guarded by `isTracking`) | status → allClear, **at most once per calendar day** | same |
| `intervalDidEnd` | — | clear shield | same |
| `LimitEvent` warnings | — | local notification only, gated by `LimitFireGate` | same |
| `LimitEvent.reached` (once/day via `LimitFireGate`) | — | status → attentionNeeded + local notif | shield apps, status → cutOff (`cause: .hardcoreLimit`) |
| `graceExpired` (UnlockGrace) | n/a | re-shield, status → cutOff (`cause: .snoozeEnded`) | same |

The once-per-day allClear guard (`lastAllClearSentDate` in the App Group) exists because
`intervalDidStart` fires at genuine midnight **and** on every monitoring restart; without it each
restart spammed the coaches.

Hitting the limit passes `resetStartDate: nil` — `startDailyStreakDate` is the Commitment Streak now,
so a cutoff must not reset it.

### The screen-time ring reset marker
`DeviceActivityManager.ringResetKey` = `"ringResetAt"`, written to `UserDefaults.standard` only.
It drives `@AppStorage` + `.id()` so HomeView/ReportView re-query the report after an App Limits /
Pressure save (`markRingReset()`). It no longer feeds any usage math.

The ring and full report always show **full-day** usage from the DeviceActivity API (`316b8fa`).
The old `RingSession` baseline subtraction ("usage since today's settings change") was removed:
recording the baseline was unreliable and produced "0m of 3m" after a limit was hit. Enforcement now counts the same full-day usage (`includesPastActivity`, above), so the ring and the limit agree.

### Shield extensions
- **`PPTAShieldConfiguration`** draws the lock screen and is the *only* process that can read `localizedDisplayName` off a token. It harvests names into the App Group as it draws (`AppNameStore.record`) and counts bounce-offs (`noteBlockAttempt`, bucketed per day, 30-day retention). The main app can never resolve these itself.
- **`PPTAShieldAction`** handles taps. Primary → `.close`. Secondary ("Ask my coach for more time") → posts a local notification (`ShieldHandoff.askCoachIdentifier`) and returns `.defer`, keeping the shield up. A shield extension can't open the app or reach Firestore, so the notification's *tap* is the bridge in; the actual snooze request is made per-coach from that coach's profile.
- `ShieldContext` (in `ShieldSharedStore`) carries the slice of state the shield needs for specific copy: `lockedByName`, `isHardcore`, `streakStart`, `hasCoaches`. All primitives — see the target isolation rule in `architecture.md`.

`AppNameStore.storageKey(for:)` derives its key from the token's `Codable` encoding, **never
`hashValue`** — Swift seeds hashing randomly per process, so an extension-written key would never
match one computed in the app.

### App group bridge (LocalSettingsStore)
- App group ID: `group.com.sungbinyun.com.PPTADev`
- `save(_:)` / `load()`, `saveCurrentUserId(_:)` / `loadCurrentUserId()`
- `savePendingStatus(_:resetStartDate:)` / `consumePendingStatus()`
- Main app calls `applyPendingStatusIfNeeded()` on app launch (HomeView.onAppear), on every foreground (scenePhase), and when a local notification presents in foreground

### ScreenTime report (PPTAReport extension)

| Context | Raw value | Filter | View | Purpose |
|---|---|---|---|---|
| `.totalActivity` | `"Total Activity"` | `.hourly()` today | `TotalActivityView` | Progress ring + hourly chart + per-app list |
| `.weeklyTrend` | `"Weekly Trend"` | `.daily()` last 7 days | `WeeklyTrendView` | 7-day bar chart |
| `.summaryRing` | `"Summary Ring"` | `.daily()` today | `SummaryRingView` | Ring only — inline on HomeView |

`HomeView.reportSection` shows the inline `"Summary Ring"`; tapping opens `ReportView`, which stacks
`.weeklyTrend` above `.totalActivity`.

**Fonts in PPTAReport**: `X_BAMBI.TTF` and `Satoshi-Variable.ttf` are in the target (via
`membershipExceptions` in project.pbxproj) and registered in `PPTAReport/Info.plist` under
`UIAppFonts`. Named colors from the main asset catalog are **not** available in extensions —
`primaryColor` is hardcoded via `Color.appPrimary(_:)` in `TotalActivityView.swift`:
`rgb(68, 86, 46)` light / `rgb(141, 147, 136)` dark.

---
