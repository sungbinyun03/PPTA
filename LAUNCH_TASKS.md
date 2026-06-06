# PPTA Launch Task List

Full context, analysis, and executable steps for every pre-launch fix. Each task is self-contained and can be handed to an agent or executed directly.

---

## Task 1 — Add Remaining Push Notifications

### Context
`AppDelegate` currently handles three FCM types: `"unlock"`, `"lock"`, `"traineeStatus"`. There are zero notifications for any social event: friend requests, role requests, or settings changes. The three existing Cloud Run functions (`lockApp`, `unlockApp`, `statusUpdate`) handle their own FCM sends. The social actions (`createRoleRequest`, `acceptRoleRequest`, etc.) go through `CloudRunHTTPClient` but those Cloud Run functions send no FCM at all.

Both sides need work: the backend must send FCM after each social write, and the iOS `AppDelegate` must handle the new types.

### Step 1 — Backend: add FCM sends to social action endpoints

For each action, after the Firestore write succeeds, look up the recipient's `fcmToken` from `users/{recipientUID}` and send a background data push. Use the same APNs background push config as the existing functions (`apns-push-type: background`, `content-available: 1`).

| Action | Recipient | `type` value | Required data fields |
|---|---|---|---|
| Friend request sent | target user | `"friendRequest"` | `fromName` (requester's name) |
| Friend request accepted | original requester | `"friendRequestAccepted"` | `fromName` (accepter's name) |
| Role request sent | target user | `"roleRequest"` | `fromName`, `role` (`"coach"` or `"trainee"`) |
| Role request accepted | original requester | `"roleRequestAccepted"` | `fromName`, `role` |
| Role request declined | original requester | `"roleRequestDeclined"` | `fromName` |

Sender names are resolved by fetching `users/{senderUID}.name` in the same function before building the FCM message.

### Step 2 — iOS: handle new types in `AppDelegate`

In `PPTAMinimalApp.swift`, add cases after the existing `traineeStatus` block inside `didReceiveRemoteNotification`:

```swift
// Friend request received
if let type = notification["type"] as? String, type == "friendRequest",
   let senderName = notification["fromName"] as? String {
    NotificationManager.shared.sendNotification(
        title: "New friend request",
        body: "\(senderName) wants to be friends."
    )
    completionHandler(.newData); return
}

// Friend request accepted
if let type = notification["type"] as? String, type == "friendRequestAccepted",
   let name = notification["fromName"] as? String {
    NotificationManager.shared.sendNotification(
        title: "Friend request accepted",
        body: "\(name) accepted your friend request."
    )
    completionHandler(.newData); return
}

// Role request received
if let type = notification["type"] as? String, type == "roleRequest",
   let senderName = notification["fromName"] as? String,
   let role = notification["role"] as? String {
    let roleLabel = role == "coach" ? "coach you" : "be your trainee"
    NotificationManager.shared.sendNotification(
        title: "New role request",
        body: "\(senderName) wants to \(roleLabel)."
    )
    completionHandler(.newData); return
}

// Role request accepted
if let type = notification["type"] as? String, type == "roleRequestAccepted",
   let name = notification["fromName"] as? String,
   let role = notification["role"] as? String {
    let roleLabel = role == "coach" ? "your coach" : "your trainee"
    NotificationManager.shared.sendNotification(
        title: "Role request accepted",
        body: "\(name) is now \(roleLabel)."
    )
    completionHandler(.newData); return
}

// Role request declined
if let type = notification["type"] as? String, type == "roleRequestDeclined",
   let name = notification["fromName"] as? String {
    NotificationManager.shared.sendNotification(
        title: "Role request declined",
        body: "\(name) declined your role request."
    )
    completionHandler(.newData); return
}
```

### Step 3 — Test
Send each action from device A, confirm the correct notification text appears on device B within a few seconds.

---

## Task 2 — Fix Friend Card Showing Blank When First Opened

### Context
`FriendProfileSheetView` (`Views/Friends/FriendProfileSheetView.swift`) holds a `@StateObject var vm: FriendProfileViewModel` which initialises with `isLoading = false` and `name = ""`. The body condition is:

```swift
if vm.isLoading && vm.name.isEmpty {
    ProgressView()
} else {
    FriendProfileView(name: vm.name, ...)
}
```

On first render: `isLoading = false`, `name = ""` → `false && true = false` → the else branch fires and renders a blank `FriendProfileView` before `.task { await vm.refresh() }` has had a chance to run.

### Fix

In `Views/Friends/FriendProfileSheetView.swift`, change the condition from:

```swift
if vm.isLoading && vm.name.isEmpty {
```

to:

```swift
if vm.name.isEmpty {
```

This ensures the `ProgressView` shows any time data hasn't loaded yet, regardless of whether the async task has set `isLoading = true`.

---

## Task 3 — Hardcore Mode: End-to-End Audit & Fixes

### Context
The confirmed-working parts of the Hardcore flow:
- Extension `eventDidReachThreshold` → shields apps via `ManagedSettingsStore` ✅
- Extension calls `sendStatusUpdate(.cutOff)` → `statusUpdate` Cloud Run → updates `userSettings/{uid}.traineeStatus` in Firestore ✅
- `statusUpdate` Cloud Run fetches `coachIds` and sends FCM `type: "traineeStatus"` to each coach ✅
- Coach's `StatusCenterViewModel` real-time listener picks up the Firestore change ✅
- `TraineeCellView.canRelease` is `false` when `pressureLevel == .hardcore` ✅

Two bugs remain.

### Bug A — FriendProfile shows Release button for Hardcore trainees

`makeUnlockURLIfNeeded()` in `Views/Friends/FriendProfileSheetView.swift` (line 66) does not check pressure level:

```swift
private func makeUnlockURLIfNeeded() -> URL? {
    guard vm.friendshipStatus == .isFriend else { return nil }
    guard vm.isTrainee else { return nil }
    // missing pressure level guard
    guard vm.traineeStatus == .cutOff || vm.traineeStatus == .attentionNeeded else { return nil }
    guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
    return UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID)
}
```

`TraineeCellView` correctly blocks this (`canRelease = pressureLevel != .hardcore`), but the FriendProfile sheet does not, so a coach who opens a Hardcore trainee's profile while they're cut off sees a Release button.

**Fix** — add the pressure level guard:

```swift
private func makeUnlockURLIfNeeded() -> URL? {
    guard vm.friendshipStatus == .isFriend else { return nil }
    guard vm.isTrainee else { return nil }
    guard vm.pressureLevel != .hardcore else { return nil }   // ADD
    guard vm.traineeStatus == .cutOff || vm.traineeStatus == .attentionNeeded else { return nil }
    guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
    return UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID)
}
```

### Bug B — No in-app indicator for the trainee when they're Hardcore-locked

When a Hardcore trainee hits their limit, their apps are shielded silently. The PPTA app itself shows no acknowledgment. When they open the app, the HomeView looks normal.

**Fix** — in `Views/HomeView.swift`, add a locked banner above `DashboardView()`:

```swift
if userSettingsManager.userSettings.traineeStatus == .cutOff
   && userSettingsManager.userSettings.pressureLevel == .hardcore {
    HStack(spacing: 12) {
        Image(systemName: "lock.fill")
            .foregroundColor(.white)
        VStack(alignment: .leading, spacing: 2) {
            Text("Apps Locked")
                .font(.custom("BambiBold", size: 15))
                .foregroundColor(.white)
            Text("You've hit your Hardcore limit for today.")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.white.opacity(0.85))
        }
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Color.red.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding(.horizontal, 24)
}
```

### Smoke-test checklist
- [ ] Set a very short Hardcore limit, confirm apps are shielded on threshold
- [ ] Confirm `userSettings/{traineeUID}.traineeStatus` becomes `"cutOff"` in Firestore within ~5s
- [ ] Confirm coach receives push notification with the trainee's actual name (not "Your trainee" — see Task 6 Fix A)
- [ ] Confirm coach's StatusCenter shows red dot and Release button is disabled
- [ ] Confirm FriendProfile Release button does NOT appear for Hardcore trainees
- [ ] Confirm HomeView locked banner appears when trainee opens app
- [ ] At midnight, confirm shield clears and status resets to `allClear` in Firestore

---

## Task 4 — Adjust Role Request Button Spacing/Margins

### Context
In `Views/Friends/FriendsView.swift`, the `requestCard` function is used for both friend requests (no subtitle) and role requests (has a subtitle like "Wants to be your coach"). When a subtitle is present, the content column expands but the button HStack on the trailing edge can feel cramped on smaller screens. The `Spacer()` between the name column and buttons also doesn't constrain the name text, so long names push the buttons off screen.

### Fix

In the `requestCard` function, replace the outer `HStack` and name/button layout:

```swift
HStack(alignment: .center, spacing: 12) {
    initialsCircle(name: name, size: 40)

    VStack(alignment: .leading, spacing: 3) {
        Text(name)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
        if let subtitle {
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)

    HStack(spacing: 8) {
        Button(action: onDecline) {
            Text("Decline")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        Button(action: onAccept) {
            Text("Accept")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(primaryColor)
                .clipShape(Capsule())
        }
    }
    .fixedSize()
}
.padding(.horizontal, 14)
.padding(.vertical, 13)
.background(primaryColor.opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
.contentShape(Rectangle())
.onTapGesture(perform: onTap)
```

Key changes: `.frame(maxWidth: .infinity, alignment: .leading)` on the name column so it absorbs width instead of the button HStack; `.fixedSize()` on the button HStack so buttons never compress; vertical padding bumped from 12 → 13.

---

## Task 5 — SKIPPED

---

## Task 6 — Fix Notification Bugs for Time Limit Events

### Context
The full notification chain for time limit events, now verified against the backend source:

| Event | Extension | Firestore | Coach push | Trainee push |
|---|---|---|---|---|
| Approaching threshold (`eventWillReachThresholdWarning`) | `savePendingStatus(.attentionNeeded)` + `sendStatusUpdate` | `traineeStatus = attentionNeeded` ✅ | Sends FCM but **no traineeName** ⚠️ | ❌ none |
| Threshold reached — Standard | `savePendingStatus(.attentionNeeded)` + `sendStatusUpdate` | `traineeStatus = attentionNeeded` ✅ | Sends FCM but **no traineeName** ⚠️ | ❌ none |
| Threshold reached — Hardcore | Shield + `savePendingStatus(.cutOff)` + `sendStatusUpdate` | `traineeStatus = cutOff` ✅ | Sends FCM but **no traineeName** ⚠️ | ❌ none |
| Remote unlock by coach | — | Updated by `unlockApp` indirectly via FCM→device | — | Sends FCM but **no byName** ⚠️ |
| Day reset | Clear shield + `sendStatusUpdate(.allClear)` | `traineeStatus = allClear` ✅ | FCM sent (allClear) ✅ | ❌ none |

Two bugs found in the backend source code. Both are simple fixes.

### Fix A — `statusUpdate` never sends the trainee's name to coaches

The function sends `{ type: 'traineeStatus', uid, status }` to coaches. `AppDelegate` reads `notification["traineeName"]` and falls back to `"Your trainee"`, so every coach notification reads *"Your trainee has hit their screen time limit"*.

**Backend fix** in the `statusUpdate` Cloud Run function — after fetching `settingsSnap`, fetch the trainee's name and include it:

```javascript
// After: const coachIds = settingsSnap.exists ? (settingsSnap.get('coachIds') || []) : [];
// Add:
let traineeName = 'Your trainee';
try {
  const traineeUserSnap = await db.collection('users').doc(uid).get();
  if (traineeUserSnap.exists) {
    traineeName = traineeUserSnap.get('name') || traineeName;
  }
} catch (_) {}

// Then in the message object, add traineeName to data:
const message = {
  token,
  data: { type: 'traineeStatus', uid, status, traineeName },  // ADD traineeName
  apns: { ... }
};
```

### Fix B — `unlockApp` never sends the coach's name to the trainee

`lockApp` correctly includes `byName: coach_name`. `unlockApp` only sends `{ type: "unlock", by: coach }`, so the trainee always sees *"Unlocked by Your coach"*.

**Backend fix** in the `unlockApp` Cloud Run function — add coach name resolution before building the message (same pattern as `lockApp`):

```python
coach_name = "Your coach"
try:
    coach_snap = db.collection("users").document(coach).get()
    if coach_snap.exists:
        coach_name = coach_snap.get("name") or coach_name
except Exception as e:
    print(f"Could not resolve coach name: {e}")

message = messaging.Message(
    token=token,
    data={
        "type": "unlock",
        "by": coach,
        "byName": coach_name,   # ADD
    },
    ...
)
```

### Fix C — Trainee receives no notification when their own limit is hit

When apps are shielded by the extension, the trainee gets no PPTA notification — only the iOS system shield UI. Add a local notification inside `eventDidReachThreshold` in `AppMonitor/DeviceActivityMonitorExtension.swift`:

```swift
// Add after the shield/status logic, before the function returns:
let content = UNMutableNotificationContent()
content.title = "Time's up"
content.body = settings.pressureLevel == .hardcore
    ? "Your apps are locked for the rest of the day."
    : "You've reached your daily limit. Your coaches have been notified."
let request = UNNotificationRequest(
    identifier: "threshold-\(UUID().uuidString)",
    content: content,
    trigger: nil
)
UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
```

Add `import UserNotifications` at the top of `DeviceActivityMonitorExtension.swift` if not already present.

---

## Task 7 — Fix In-App Lock/Release Bug (Stop Opening Browser)

### Context
In `Views/Friends/FriendProfileView.swift`, the Lock and Release buttons use `@Environment(\.openURL)`:

```swift
Button { openURL(lockURL) } label: { ... }   // line 135
Button { openURL(unlockURL) } label: { ... } // line 152
```

`openURL` routes to Safari. This takes the user out of the app and shows a raw "OK" response. `StatusCenterViewModel.performAction` already does this correctly via in-process `URLSession`. `FriendProfileView` needs the same treatment.

### Step 1 — Add lock/unlock action methods to `FriendProfileViewModel`

In `ViewModels/FriendProfileViewModel.swift`:

```swift
@Published var isPerformingLockUnlock = false
@Published var lockUnlockError: String?

func performLock(url: URL) async {
    await performLockUnlockAction(url: url)
}

func performUnlock(url: URL) async {
    await performLockUnlockAction(url: url)
}

private func performLockUnlockAction(url: URL) async {
    isPerformingLockUnlock = true
    lockUnlockError = nil
    defer { isPerformingLockUnlock = false }
    do {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            lockUnlockError = "Action failed — please try again."
            return
        }
        await refresh()
    } catch {
        lockUnlockError = error.localizedDescription
    }
}
```

### Step 2 — Replace URL params with action callbacks in `FriendProfileView`

In `Views/Friends/FriendProfileView.swift`:

Replace the two URL properties:
```swift
// Remove:
let lockURL: URL?
let unlockURL: URL?
@Environment(\.openURL) private var openURL
```

Add action closure properties:
```swift
let onLock: (() -> Void)?
let onUnlock: (() -> Void)?
```

Replace the button bodies:
```swift
// Lock button — was: Button { openURL(lockURL) }
if let onLock {
    Button { onLock() } label: {
        HStack {
            Text("Lock")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Image(systemName: "lock")
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .padding(.horizontal, 20)
}

// Release button — was: Button { openURL(unlockURL) }
if let onUnlock {
    Button { onUnlock() } label: {
        HStack {
            Text(traineeStatus == .attentionNeeded ? "Preemptively Release" : "Release")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Image(systemName: "lock.open")
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(primaryColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .padding(.horizontal, 20)
}
```

### Step 3 — Update `FriendProfileSheetView` to pass closures

In `Views/Friends/FriendProfileSheetView.swift`:

```swift
FriendProfileView(
    name: vm.name,
    friendshipStatus: vm.friendshipStatus,
    isTrainee: vm.isTrainee,
    isCoach: vm.isCoach,
    profilePicUrl: vm.profilePicUrl,
    traineeStatus: vm.traineeStatus,
    streakDays: vm.streakDays,
    timeLimitMinutes: vm.timeLimitMinutes,
    pressureLevel: vm.pressureLevel,
    onLock: makeLockURLIfNeeded().map { url in { Task { await vm.performLock(url: url) } } },
    onUnlock: makeUnlockURLIfNeeded().map { url in { Task { await vm.performUnlock(url: url) } } },
    coachAction: vm.coachAction,
    traineeAction: vm.traineeAction,
    onCoachPrimary: { Task { await vm.performCoachPrimary() } },
    onCoachSecondary: { Task { await vm.performCoachSecondary() } },
    onTraineePrimary: { Task { await vm.performTraineePrimary() } },
    onTraineeSecondary: { Task { await vm.performTraineeSecondary() } }
)
```

Add a loading overlay inside `FriendProfileSheetView.body`:
```swift
.overlay {
    if vm.isPerformingLockUnlock {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            ProgressView()
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

### Step 4 — Update the `#Preview` in `FriendProfileView.swift`

```swift
FriendProfileView(
    ...
    onLock: nil,
    onUnlock: nil,
    ...
)
```

---

## Task 8 — Make Peer Bubbles in HomeView Tappable

### Context
`Views/Dashboard/TraineeCoachView.swift` renders horizontal `TraineeCircleView` bubbles for trainees and coaches. They are purely presentational — no `Button` wrapper, no sheet state, no tap handler. `FriendProfileSheetView` already exists and is used in both StatusCenter and FriendsView.

### Fix

In `Views/Dashboard/TraineeCoachView.swift`:

1. Add state variables at the top of the struct:
```swift
@State private var selectedUserId: String? = nil
@State private var showFriendProfile = false
```

2. Wrap each `TraineeCircleView` in a `Button`:
```swift
// Trainees
ForEach(viewModel.trainees) { trainee in
    Button {
        selectedUserId = trainee.id
        showFriendProfile = true
    } label: {
        TraineeCircleView(
            status: trainee.traineeStatus ?? .noStatus,
            name: trainee.name,
            profilePicUrl: trainee.profileImageURL?.absoluteString
        )
    }
    .buttonStyle(.plain)
}

// Coaches
ForEach(viewModel.coaches) { coach in
    Button {
        selectedUserId = coach.id
        showFriendProfile = true
    } label: {
        TraineeCircleView(
            status: .noStatus,
            name: coach.name,
            profilePicUrl: coach.profileImageURL?.absoluteString
        )
    }
    .buttonStyle(.plain)
}
```

3. Add the sheet to the outer `VStack`:
```swift
.sheet(isPresented: $showFriendProfile) {
    if let id = selectedUserId {
        FriendProfileSheetView(otherUserId: id)
    }
}
```

---

## Task 9 — Fix Edit Profile UI

### Context
`Views/Profile/EditProfileView.swift` has a large `Spacer()` at the top pushing content to vertical center, a stock `.largeTitle` font, a single bare input field, and is presented via `NavigationLink` push from `SettingsView` (inconsistent with every other modal in the app which uses `.sheet`).

### Fix

**Replace the entire body of `EditProfileView`:**

```swift
var body: some View {
    VStack(spacing: 0) {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color("primaryColor").opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Edit Profile")
                    .font(.custom("BambiBold", size: 26))
                    .foregroundColor(Color("primaryColor"))
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("DISPLAY NAME")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color("primaryColor").opacity(0.6))
                        .padding(.horizontal, 24)

                    InputView(
                        text: $displayName,
                        title: "",
                        placeholder: "Your name"
                    )
                    .borderedContainer()
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 12)
        }

        PrimaryButton(
            title: isSaving ? "Saving..." : "Save",
            isDisabled: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
        ) {
            Task {
                isSaving = true
                let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                await viewModel.updateUserDisplayName(displayName: trimmed)
                isSaving = false
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    .onAppear { displayName = viewModel.currentUser?.name ?? "" }
}
```

**Change the presentation in `SettingsView`** from `NavigationLink` push to `.sheet`:

In `Views/Settings/SettingsView.swift`:
1. Add `@State private var showEditProfile = false`
2. Replace:
```swift
NavigationLink(destination: EditProfileView()) {
    HStack(spacing: 4) { ... }
}
```
With:
```swift
Button { showEditProfile = true } label: {
    HStack(spacing: 4) { ... }
}
```
3. Add to the outer `NavigationView`:
```swift
.sheet(isPresented: $showEditProfile) {
    EditProfileView()
        .environmentObject(viewModel)
}
```

---

## Task 10 — Add Back Button on Failure in Phone Verification View

### Context
`Views/Auth/PhoneView.swift` (`PhoneVerificationView`) is presented as a sheet with `interactiveDismissDisabled(true)` from `OnboardingContainerView`. Two user-trapping scenarios:

1. On the **code entry screen** (`isCodeSent = true`): no way to go back to the phone number screen to correct the number or request a resend to a different number.
2. On the **phone entry screen**: if an unrecoverable error appears (e.g., "This number is already registered"), the user cannot dismiss or proceed — they are stuck.

### Fix A — Back link on code entry screen

At the top of `codeEntryView`, before the heading, add:

```swift
HStack {
    Button {
        isCodeSent = false
        verificationCode = ""
        errorMessage = nil
    } label: {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
            Text("Change number")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(primaryColor)
    }
    Spacer()
}
.padding(.horizontal, 24)
.padding(.top, 16)
```

### Fix B — Escape hatch on phone entry error

In `phoneEntryView`, below the error message:

```swift
if let msg = errorMessage {
    Text(msg)
        .font(.caption)
        .foregroundColor(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)

    Button("Skip for now") { dismiss() }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 24)
}
```

This preserves `interactiveDismissDisabled(true)` for the normal flow while giving users an escape when they're genuinely blocked (e.g., already-registered number).

---

## Task 11 — Clarify That Screen Time Is Tracked by Sum

### Context
Apple's DeviceActivity API fires `eventDidReachThreshold` when the **combined total** of all monitored apps/categories reaches the threshold — not when any individual app reaches it. The current code is correct:

```swift
// One event, all apps share one threshold = sum tracking
let event = DeviceActivityEvent(
    applications: appTokens.applicationTokens,
    categories: appTokens.categoryTokens,
    webDomains: [],
    threshold: thresholdComponents
)
```

There is no UI copy anywhere explaining this to users. They may expect per-app limits (like the native iOS Screen Time app), not a combined limit.

### Fix

In `Views/Settings/AppLimitsView.swift` or `TimeLimitSheetView.swift`, add a helper text beneath the time picker:

```swift
Text("This limit applies to total combined usage across all your selected apps.")
    .font(.custom("Satoshi-Variable", size: 12))
    .fontWeight(.regular)
    .foregroundColor(.secondary)
    .multilineTextAlignment(.center)
    .padding(.horizontal, 24)
    .padding(.top, 4)
```

---

## Task 12 — Remove Security Row, Wire Support to Google Form

### Context
`Views/Settings/SettingsView.swift:238-239` has two dead rows with no action:

```swift
settingsRow(icon: Image(systemName: "lock.shield"), text: "Security", iconScale: 1.2)
settingsRow(icon: Image(systemName: "questionmark.circle"), text: "Support", iconScale: 1.2)
```

### Fix

1. **Delete the Security row** (line 238).

2. **Add `@Environment(\.openURL) private var openURL`** to `SettingsView`.

3. **Replace the Support row** with a tappable button:

```swift
Button {
    if let url = URL(string: "https://forms.gle/YOUR_FORM_ID") {
        openURL(url)
    }
} label: {
    settingsRow(
        icon: Image(systemName: "questionmark.circle"),
        text: "Support",
        iconScale: 1.2
    )
}
.buttonStyle(.plain)
```

Replace `YOUR_FORM_ID` with the actual Google Form ID.

---

## Task 13 — Show Who Locked a Trainee (Coach Attribution Badge)

### Context
When a coach locks a trainee via `lockApp`, the function writes `requestedBy: coachUID` to a separate `lockRequests/{traineeUID}` audit collection — the iOS app never reads this. `userSettings/{traineeUID}` has no `lockedByUID` or `lockedByName` fields. The trainee gets an FCM notification naming the coach, but this is transient. Coaches have no in-app way to see who locked a trainee, and trainees have no persistent in-app indication of who locked them.

The feature: a small initials badge on the trainee's avatar in `TraineeCellView` (Status Center) and a "Locked by" stat row in `FriendProfileView`.

### Step 1 — Backend: write lockedBy fields on lock, clear on unlock/allClear

**In `lockApp`**, after the audit log write, add a merge write to `userSettings/{uid}`:

```python
try:
    db.collection("userSettings").document(uid).set(
        {
            "lockedByUID": coach,
            "lockedByName": coach_name,
        },
        merge=True
    )
except Exception as e:
    print(f"Error writing lockedBy to userSettings: {e}")
```

**In `unlockApp`**, after the audit log write, clear those fields:

```python
try:
    db.collection("userSettings").document(uid).set(
        {
            "lockedByUID": None,
            "lockedByName": None,
        },
        merge=True
    )
except Exception as e:
    print(f"Error clearing lockedBy from userSettings: {e}")
```

**In `statusUpdate`** (Node.js), when `status === 'allClear'`, clear the fields in the same `settingsRef.set()` call:

```javascript
await settingsRef.set(
  {
    traineeStatus: status,
    lastStatusAt: admin.firestore.FieldValue.serverTimestamp(),
    // Clear lock attribution when status resets
    ...(status === 'allClear' ? { lockedByUID: null, lockedByName: null } : {}),
  },
  { merge: true }
);
```

### Step 2 — Add fields to `UserSettings` model

In `Models/UserSettings.swift`:

```swift
var lockedByUID: String? = nil
var lockedByName: String? = nil
```

Add to `CodingKeys`:
```swift
case lockedByUID, lockedByName
```

Add to `init(from decoder:)`:
```swift
lockedByUID = try? container.decode(String.self, forKey: .lockedByUID)
lockedByName = try? container.decode(String.self, forKey: .lockedByName)
```

Add to `encode(to:)`:
```swift
try container.encodeIfPresent(lockedByUID, forKey: .lockedByUID)
try container.encodeIfPresent(lockedByName, forKey: .lockedByName)
```

### Step 3 — Add `lockedByName` to `StatusCenterPerson`

In `Models/StatusCenterPerson.swift`:
```swift
struct StatusCenterPerson: Identifiable, Equatable {
    let id: String
    let name: String
    let profileImageURL: URL?
    let isCoach: Bool
    let isTrainee: Bool
    let traineeStatus: TraineeStatus?
    let streakDays: Int
    let timeLimitMinutes: Int
    let pressureLevel: PressureLevel
    let lockedByName: String?   // ADD
}
```

### Step 4 — Thread `lockedByName` through `StatusCenterViewModel`

In `fetchPeople()` in `ViewModels/StatusCenterViewModel.swift`, add to the returned `StatusCenterPerson`:

```swift
return StatusCenterPerson(
    id: id,
    name: name,
    profileImageURL: profileURL,
    isCoach: mySettings.coachIds.contains(id),
    isTrainee: mySettings.traineeIds.contains(id),
    traineeStatus: effectiveStatus,
    streakDays: streakDays,
    timeLimitMinutes: timeLimitMinutes,
    pressureLevel: settings?.pressureLevel ?? .off,
    lockedByName: settings?.lockedByName   // ADD
)
```

In the real-time listener in `attachTraineeListeners`, also read the field from snapshot:

```swift
let lockedByName = data["lockedByName"] as? String

if existing.traineeStatus != effectiveStatus {
    self.trainees[idx] = StatusCenterPerson(
        id: existing.id,
        name: existing.name,
        profileImageURL: existing.profileImageURL,
        isCoach: existing.isCoach,
        isTrainee: existing.isTrainee,
        traineeStatus: effectiveStatus,
        streakDays: existing.streakDays,
        timeLimitMinutes: existing.timeLimitMinutes,
        pressureLevel: existing.pressureLevel,
        lockedByName: lockedByName ?? existing.lockedByName   // ADD
    )
}
```

### Step 5 — Add initials badge to `TraineeCellView`

In `Views/StatusCenter/TraineeCellView.swift`, add `lockedByName: String?` to the init and add a badge overlay on the avatar:

```swift
// Add to init parameters:
var lockedByName: String? = nil

// Add overlay to the avatar Group:
.overlay(alignment: .bottomTrailing) {
    if status == .cutOff, let locker = lockedByName {
        let parts = locker.split(separator: " ")
        let initials = parts.prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        Text(initials)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Color.orange)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .offset(x: 2, y: 2)
    }
}
```

Update the `TraineeCellView` call site in `Views/StatusCenter/StatusCenterView.swift`:

```swift
TraineeCellView(
    name: user.name,
    status: user.traineeStatus ?? .noStatus,
    profilePicUrl: user.profileImageURL?.absoluteString,
    pressureLevel: user.pressureLevel,
    lockedByName: user.lockedByName,   // ADD
    onRelease: { ... },
    onLock: { ... }
)
```

### Step 6 — Add `lockedByName` to `FriendProfileViewModel` and `FriendProfileView`

In `ViewModels/FriendProfileViewModel.swift`:
```swift
@Published var lockedByName: String? = nil
```

In `refresh()`, after reading `otherSettings`:
```swift
lockedByName = otherSettings?.lockedByName
```

In `Views/Friends/FriendProfileView.swift`, add parameter:
```swift
let lockedByName: String?
```

In the stats card, add a row after the streak row:
```swift
if let locker = lockedByName, traineeStatus == .cutOff {
    Divider().opacity(0.3)
    statRow(label: "Locked by", value: locker)
}
```

In `Views/Friends/FriendProfileSheetView.swift`, pass the value:
```swift
FriendProfileView(
    ...
    lockedByName: vm.lockedByName,
    ...
)
```

Update the `#Preview` in `FriendProfileView.swift` to include `lockedByName: nil`.
