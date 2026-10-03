Covers §12 Key Enums & Constants from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 12. Key Enums & Constants

```swift
// PressureLevel (Firestore key "selectedMode")
.off        // No monitoring, status = noStatus
.standard   // Coaches see status, can lock remotely
.hardcore   // Auto-lock at threshold. Coaches CAN still snooze — autolock is the only
            // difference from Standard (plus the app-limit edit lock while cut off).

// TraineeStatus: allClear | attentionNeeded | cutOff | snoozedLock | noStatus

// LockCause (mirrored server-side as LOCK_CAUSE)
.hardcoreLimit   // Hardcore auto-lock at the limit, no coach involved
.coach           // a coach locked or snoozed them — `by` names them
.snoozeEnded     // the grace timer ran out and re-locked them

// DeviceActivityName
"AppUsageMonitoring"   // DeviceActivityManager.dailyActivityName
"UnlockGracePeriod"    // UnlockGrace.activityName

// DeviceActivityEvent.Name
"timeLimitReached" | "limitHalfwayWarning" | "limitFiveMinuteWarning"
"limitTwoMinuteWarning" | "graceExpired"

UnlockGrace.durationMinutes = 10
AppNameStore.retentionDays  = 30

// App group
"group.com.sungbinyun.com.PPTADev"

// HMAC secret (DeviceActivityManager, UnlockService, AppMonitor extension)
"a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"

// UserDefaults keys
"onboardingComplete_<uid>" | "onboardingStep_<uid>" | "pendingCoachRequests_<uid>"
"ringResetAt" (standard only) | "ppta.installMirrorPresent" | "lastAllClearSentDate" (app group)
"shield.context" | "shield.appName.<key>" | "shield.blockAttempts.<key>" (app group)
```

---
