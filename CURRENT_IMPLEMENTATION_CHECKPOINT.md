# Current Implementation Checkpoint (Post-Cleanup)

This document enumerates the **core consumer-app spine** that remains after stripping the “coach-visible app list / app-name resolution” experiments.

## What we intentionally removed as junk
- **Coach-visible monitored app list** (previous `userSettings.appList` + report→app group→Firestore sync + UI rendering).
  - Reason: deemed unreliable/impossible after investigation; large amount of code existed purely to chase this.

## Essential features (where + how they work)

### 1) Track app screen time (local)
- **UI entry**: `PPTAMinimal/Views/HomeView.swift`
  - Embeds `ReportView()`.
- **Report UI**: `PPTAMinimal/Views/ReportView.swift`
  - Requests FamilyControls authorization.
  - Loads the user’s `FamilyActivitySelection` from Firestore and (when non-empty) filters the report to selected apps/categories.
- **Report extension**: `PPTAReport/TotalActivityReport.swift`
  - Renders “Total Activity” report content (no cross-device syncing).
- **Report list behavior**: `PPTAReport/TotalActivityView.swift`
  - Shows **only the currently selected monitored apps** (application tokens).
  - Includes **0:00 rows** for selected apps with no usage.
  - Note: categories are not expanded into 0-usage rows (apps-only).

### 2) Lock apps when time limit is exceeded
- **Monitoring start**: `PPTAMinimal/Views/HomeView.swift`
  - After settings load, calls `DeviceActivityManager.startDeviceActivityMonitoring(...)`.
  - If `isTracking == false`, monitoring is stopped/disabled.
- **Monitoring config**: `PPTAMinimal/Managers/DeviceActivityManager.swift`
  - Monitors daily interval 00:00–23:59.
  - Uses a single event: `DeviceActivityEvent.Name("timeLimitReached")`.
- **Lock enforcement**: `AppMonitor/DeviceActivityMonitorExtension.swift`
  - On threshold reached:
    - **Coach/Hard**: `store.shield.applications = selectedTokens`
    - **Chill**: no shielding (status updates only)

### 3) Remote unlock via signed URL + Cloud Run → FCM → device unlock
- **Signed URL generator**: `PPTAMinimal/Managers/UnlockService.swift`
  - Signs `"{childUID}|{coachUID}|{ts}"` using shared secret (HMAC-SHA256).
- **Backend (existing)**: your Cloud Run function `unlockApp`
  - Verifies HMAC + expiry, reads `users/{uid}.fcmToken`, sends FCM data push `{type:"unlock", by:coach}`.
- **Client receive**: `PPTAMinimal/PPTAMinimalApp.swift` (`AppDelegate.didReceiveRemoteNotification`)
  - On `type == "unlock"`: calls `DeviceActivityManager.handleRemoteUnlock(from:)`.
- **Unlock action**: `PPTAMinimal/Managers/DeviceActivityManager.swift`
  - Clears shields unless `selectedMode == "Hard"`.

### 4) Peer coach can unlock my app
- **Coach UI**: `PPTAMinimal/Views/StatusCenter/StatusCenterView.swift`
  - Trainee rows include a **Release** button when trainee is `cutOff`.
  - Release opens the signed unlock URL in Safari (`UIApplication.shared.open(...)`), triggering the backend unlock flow.
- **Relationship model** (for showing trainees/coaches):
  - UID-based roles in `UserSettings.coachIds` / `UserSettings.traineeIds`.
  - Loaded via `PPTAMinimal/ViewModels/StatusCenterViewModel.swift`.

### 5) DeviceActivityReport shows monitoring status properly
- **Report correctness**: `PPTAMinimal/Views/ReportView.swift`
  - Always attempts to filter to selected apps/categories (when present).
  - Shows a clear permission error message if authorization is missing.
- **Monitoring correctness**:
  - Monitoring is tied to `isTracking` and the persisted selection/limit.

## Near-real-time coach-visible status (attentionNeeded/cutOff)
To meet “coach knows almost immediately”, the monitor extension posts status transitions to a backend endpoint.

- **Monitor extension calls**: `AppMonitor/DeviceActivityMonitorExtension.swift`
  - `attentionNeeded` on threshold warning
  - `cutOff` on threshold reached
  - `allClear` on interval start/end
- **Main app call**: `PPTAMinimal/Managers/DeviceActivityManager.swift`
  - `allClear` after remote unlock (best-effort)
- **Backend required**: deploy `statusUpdate` endpoint and set iOS URL constants.
  - Spec + reference code: `STATUS_UPDATE_BACKEND.md`
  - Current app is configured to call: `https://statusupdate-538124351649.us-central1.run.app`

Coach notification handling:
- `PPTAMinimal/PPTAMinimalApp.swift` handles `type == "traineeStatus"` and shows a local notification.

## Smoke test checklist (10 minutes)
1. **Permissions**
   - Fresh install: onboarding → enable Screen Time permission.
2. **Select apps**
   - Settings → Monitored Apps → pick 1–2 apps → Save.
3. **Set limit + mode**
   - Settings → Limit Settings:
     - set a short limit (e.g. 1–2 minutes)
     - test each mode: Chill, Coach, Hard.
4. **Exceed limit**
   - Open monitored app, exceed threshold.
   - Expect:
     - Chill: no shield applied; status updates should still fire.
     - Coach/Hard: shield applies (app becomes blocked).
5. **Coach sees status quickly**
   - Ensure backend `statusUpdate` is deployed.
   - Coach device receives push `type:"traineeStatus"` quickly.
6. **Unlock**
   - Coach opens Status Center → trainee row shows `cutOff` → tap Release.
   - Expect:
     - Coach mode: trainee device unlocks via FCM (`type:"unlock"`).
     - Hard mode: trainee device shows “Unlock denied”.
7. **Report**
   - Home → Daily Screen Time report shows data for selected apps/categories.

