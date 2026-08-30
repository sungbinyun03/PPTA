# PPTA Onboarding Redesign — Analysis & Plan

Status: proposal, no code changed yet.
Written against commit `ae3c3b9`.

---

## 1. What the app is actually for

The insight PPTA is built on: **self-imposed screen time limits fail because you hold your own
key.** Apple's Screen Time has an "Ignore Limit" button. Every willpower app has an escape hatch.

PPTA's whole product is *removing your own escape hatch and handing it to a friend.*

That means the value is not tracking, not charts, not streaks. The value is:

> Someone else decides when you get your apps back.

Everything else in the codebase — the DeviceActivity monitor, the shield, the report extension,
streaks — exists to serve that one transaction.

### The golden flow (the configuration where the app actually works)

```
1.  Sign up                              ← LoginView
2.  Grant Screen Time authorization      ← required; nothing works without it
3.  Pick monitored apps                  ← FamilyActivitySelection
4.  Set a daily limit                    ← thresholdHour / thresholdMinutes
5.  Set Pressure Level to Standard or Hardcore
6.  Add a friend                         ← Friendship, must be ACCEPTED by them
7.  Make that friend your COACH          ← RoleRequest(.coach), must be ACCEPTED by them
─────────────────────────────────────────────────────────────────
    ↓ the loop can now run ↓
8.  Use monitored apps → approach limit  → eventWillReachThreshold → .attentionNeeded
9.  Hit limit → Hardcore auto-shields, Standard pings coaches → .cutOff
10. Shield appears; trainee taps "ask my coach" → MercyRequest
11. Coach taps Release → 10-min UnlockGracePeriod → .snoozedLock
12. Grace burns down (monitored-app usage, not wall clock) → re-shield → .cutOff
13. Midnight → intervalDidEnd → shield cleared, status reset, streak +1
```

**Steps 1–7 are all prerequisites.** Miss any one and the app is inert. Miss step 7 specifically
and the app is a worse version of Screen Time.

**The hardest constraint in the whole product:** step 7 requires a *second human* to tap Accept.
Onboarding cannot complete the golden flow on its own. Any onboarding design that pretends
otherwise will produce a user who finishes onboarding and sees nothing happen.

---

## 2. Assessment of the current onboarding

### What it actually is

`OnboardingCoordinator.swift` — five steps plus a terminal state:

```
welcome → createProfile → enableTracking → enableNotifications → findFriends → completed
```

> Note: `CLAUDE.md` §11 documents 7 steps including `signInOrSignUp`, and claims
> `EnableTrackingView` presents a `FamilyActivityPicker`. Neither is true in the code.
> Auth happens *before* onboarding (`PPTAMinimalApp.swift:200`), and `EnableTrackingView`
> only calls `AuthorizationCenter.requestAuthorization`. The doc is stale.

### Finding A — Onboarding never configures the product *(critical)*

Onboarding collects: a display name, Screen Time authorization, notification authorization,
and some friend requests. It never sets **apps**, **limit**, or **pressure level**, and never
establishes a **coach**.

So the reward for completing onboarding is `SetupCardView` (`SetupCardView.swift:14–26`) telling
you that you have five things left to do:

```
Setup incomplete
 • App Limits
 • Pressure Level
 • Friends
 • Trainees
 • Coaches
```

…and `HomeView`'s status card (`HomeView.swift:85–97`) simultaneously saying **"Not Tracking —
Pressure Level is off and App Limits aren't set up."**

The user finishes an onboarding flow and lands on a screen that says they haven't onboarded.
This is the single biggest problem and it makes every other issue secondary.

### Finding B — The mechanic is never explained

`WelcomeView` says *"Set goals together. Hold each other accountable and stay focused."*
That is a wellness-app platitude. It never says the actual thing:

- what a **coach** is versus a **trainee**
- that a coach can **remotely lock your phone**
- that in Hardcore **you cannot unlock yourself**
- that release is **10 minutes at a time**, and it burns down while you use the apps
- what the three **pressure levels** mean

Pressure level semantics are explained only inside `Settings → PressureLevelView`, a screen the
user has no reason to open. A user reaching `.cutOff` for the first time will not have consented
to it in any meaningful sense.

### Finding C — Heavy permissions are asked before any value is shown

`EnableTrackingView` is screen 3 of 5. It asks for Screen Time authorization — a system prompt
that reads as invasive — backed by one sentence of justification, on a flow where the user has so
far invested only a display name. There is deliberately no skip (`EnableTrackingView.swift:45–47`,
correct decision), so a denial is a hard wall with an "Open Settings" fallback.

This is the highest-risk drop-off point in the app, and it currently has the least persuasion
behind it.

### Finding D — Contacts permission fires with zero priming

`FindFriendsView.swift:125`:

```swift
.onAppear { requestContactsAccess() }
```

The system contacts dialog appears the instant the screen loads. No explanation, no priming
screen, no framing of *why* PPTA wants the address book. Denial → alert → a permanently empty
list whose only remaining affordance is a `ShareLink`.

### Finding E — "Find Friends" does not produce a coach

Even in the happy path, `addSelectedAsFriends()` sends **friendship** requests
(`FriendsViewModel.addFriends`). A friendship is not a coaching relationship. To get a coach the
user must later:

1. wait for the friend to accept the friendship,
2. open `FriendsView` → the friend → `FriendProfileView`,
3. tap "Request as Coach" (`FriendProfileViewModel.swift:305–310`),
4. wait for the friend to accept *that* too.

Onboarding never mentions that this second step exists. The step that makes the app work is
buried two navigations deep behind a screen the user has no reason to revisit.

### Finding F — Dead ends and weak empty states

- No contacts / no permission → `showNoContactsAlert`, then an empty rounded box.
- No way to search by phone number, username, or invite code.
- The primary button still reads **"Let's Begin"** whether or not anything was selected —
  the flow's most important outcome is silently optional.

### Finding G — Mechanical and structural issues

| Where | Issue |
|---|---|
| `OnboardingContainerView.swift:16` | Deprecated `NavigationView`; rest of app uses `NavigationStack` |
| `OnboardingContainerView.swift:20–33` | Bare `switch` in a `ZStack` — no `.transition`, no `withAnimation`. Steps snap. |
| `OnboardingContainerView.swift:62–69` | `PhoneVerificationView` sheet can appear over *any* step, `interactiveDismissDisabled(true)`. A modal wall that can interrupt Welcome. |
| `EnableTrackingView.swift:66–72`, `EnableNotificationsView.swift:62–68` | `asyncAfter(0.8)` auto-advance. Magic delay; tapping Back during the window still advances. |
| `PageIndicator` call sites | Page index hardcoded per file (`page: 0`…`page: 4`, `length: 5`). Adding a step means editing five files. |
| `PageIndicator.swift:16,26` | `ForEach(0..<page)` over a non-constant range without `id:` — SwiftUI treats this as a constant range and misbehaves when it changes. |
| `OnboardingCoordinator` | No persistence. Killing the app mid-flow restarts from `.welcome`. Deliberate (see the doc comment at :58) and correct today, but painful once the flow is longer. |

### Finding H — Asset quality

Four imagesets, all rough monochrome marker line art (a genuinely nice, distinctive style —
keep it). But:

- Source PNGs are **267×270 px at the 1x slot** with 2x and 3x **empty**. Displayed ~330pt wide
  they are being upscaled ~3×. They are visibly soft.
- Filenames are export junk: `Peer Pressure app Image 1440 (1).png`.
- Asset name `onboarding-illustration-one 1` contains a space.
- Dark mode is handled by `.invertedForDarkMode()` → `.colorInvert()`. This works *only* because
  the art is pure black on pure white. It is a hack that constrains every future asset, and it
  produces pure white line art on dark rather than the app's olive `primaryColor`.

### Finding I — Nothing is ever demonstrated

The user never sees what a shield looks like, what a coach notification looks like, or what the
status card will say. The most alarming thing the app does — locking you out — is first
encountered live, in anger, with no prior exposure.

---

## 3. Proposed onboarding

### Design principles

1. **Explain the mechanic before asking for the power.** Every system permission gets a priming
   screen that earns it.
2. **Onboarding ends with a working configuration, not a to-do list.** Apps, limit, and pressure
   level move *into* onboarding.
3. **Make the async part honest.** A coach must accept. Show that as a first-class "pending"
   state instead of hiding it.
4. **Show, don't tell.** Mock the shield and the coach notification.
5. **One layout, five screens.** A single scaffold so the flow feels like one object —
   and a step array short enough that adding or splitting a screen is a one-line change.

### Proposed sequence — five screens, ~45 seconds

Four for most users: screen 2 auto-skips when a name already exists.

| # | Screen | What happens | Asset |
|---|---|---|---|
| 1 | **The key** | The whole product in one line: "You set the limit. A friend holds the key." | `onb-the-key` |
| 2 | **Profile** | Name + optional photo. **Skipped entirely** when `currentUser.name` is already set (Apple/Google sign-in, or email registration). | — |
| 3 | **Pick your apps** | Priming copy → tap → Screen Time auth → `FamilyActivityPicker` presents immediately on success. One screen, chained. | `onb-pick-apps` |
| 4 | **Your rules** | Daily limit picker + "when I go over:" → *Coach decides* / *Lock me instantly*. | `onb-the-loop` (small) |
| 5 | **Your coach** | Contacts priming → "Ask to coach me" → sending also requests notifications ("we'll tell you when they accept"). | `onb-find-coach` |

Then straight into the app.

### What was cut, and why the cuts are improvements

The first draft had eleven screens. Nine of those were doing work that something else does better:

- **Three concept screens → one.** Explaining coach/trainee/pressure/lock-out as abstract slides
  before the user has done anything is the least persuasive possible placement. One screen states
  the metaphor; the rest of the explanation moves to point-of-use.
- **Screen Time priming + app picker → one screen.** The priming copy *is* the picker screen's
  copy. Splitting them added a tap and taught nothing.
- **Limit + pressure level → one screen.** "1h 30m a day" and "what happens when I blow past it"
  are one decision, and they read better adjacent. This is also where the lock-out consequence
  gets explained — at the moment it's actually being chosen, not three screens earlier.
- **Notifications priming → folded into the coach ask.** The single most concrete reason to allow
  notifications is "so you know when Alex accepts." Asking there converts far better than a
  standalone screen, and costs zero screens.
- **"You're all set" summary → deleted.** It duplicated what `HomeView` already renders. Home has
  `SetupCardView` and `statusCard` and will show the pending-coach state anyway. Showing a summary
  and then immediately showing the same summary again is padding.

Net: same information, roughly half the taps, and every explanation now sits on the screen where
it changes a decision.

### Why this ordering

- Apps → limit → pressure is forced by an existing guard: `PressureLevelView` refuses to save
  unless `hasViableAppLimits` is true (`UserSettings.swift:123`). Configuring in this order
  satisfies it naturally.
- Screen Time authorization must precede the app picker — `FamilyActivityPicker` needs it.
- The coach ask goes last because it is the only step with an external dependency, so it must
  never block the rest.

### The honest ending

There is no ending screen. The user lands on Home, and **Home's first-run state does the work**:

> **Your limit is live.** 1h 30m across 6 apps, Standard pressure.
> **Waiting on Alex and Sam** to accept your coach request. Until someone accepts, nobody can
> lock you — and nobody can let you back in.

This means `SetupCardView` needs to grow a first-run variant (see Phase 3) rather than the app
growing a twelfth onboarding screen.

## 4. Implementation plan

### Phase 0 — Foundations *(no new screens; makes the rest cheap)*

1. **`OnboardingStep` becomes ordered data.** Replace the hand-written `advance()`/`goBack()`
   switches with an ordered `[OnboardingStep]` and index math. `CaseIterable` + a computed
   `progressIndex` / `progressTotal`.
2. **`PageIndicator` derives its page from the coordinator.** Delete all five hardcoded
   `page:`/`length:` call sites. Fix the `ForEach` range bug (`ForEach(0..<length, id: \.self)`
   with a filled/unfilled ternary).
3. **`OnboardingScaffold`** — one reusable view: illustration slot, title (`BambiBold`), body
   (`Satoshi-Variable`), primary button, optional secondary link, page dots, back chevron.
   Every screen becomes ~25 lines of content instead of a copy-pasted `VStack`.
3b. **`WobblyStroke` shape helper** — the illustrations only read as hand-drawn if the chrome
   around them does too. Stock `Circle()` page dots and hairline `Divider()`s sitting next to
   rough marker art look like the art was pasted in. One seeded-jitter `Shape` (1–2 pt deviation,
   deterministic by index so it doesn't re-jitter every render) covers page dots, dividers, the
   primary button's edge, and — highest value — the *selection* affordance on the app picker and
   pressure cards, so the interaction itself feels drawn. See
   `docs/onboarding-asset-prompts.md` §1b.
4. **`NavigationView` → `NavigationStack`**; wrap step changes in `withAnimation` with an
   asymmetric slide transition (forward slides left, back slides right).
5. **Persist progress.** `onboardingStep_<uid>` in UserDefaults, restored in `OnboardingCoordinator.init`.
   Keep the existing rule that `onboardingComplete_<uid>` is only set at the very end.
6. **Fix the auto-advance.** Replace `asyncAfter(0.8)` with an explicit "Continue" that becomes
   enabled, or `Task { try? await Task.sleep(...) }` tied to the view's lifetime so back
   navigation cancels it.
7. **Contain the phone sheet.** Only present `PhoneVerificationView` at a defined step rather
   than on any `currentUser` change.

### Phase 1 — The concept screen

New: `IntroKeyView` on `OnboardingScaffold`. Pure content, one illustration, one button.
Replaces `WelcomeView`.

### Phase 2 — Configuration (2 screens)

- **`ChooseAppsView`** — one screen doing three things in sequence on a single tap:
  request `AuthorizationCenter` authorization → on `.approved`, present
  `.familyActivityPicker(isPresented:selection:)` → store into a **draft** on the coordinator,
  not `UserSettingsManager`, so Back stays clean. Keep the existing hard-wall-on-denial behaviour
  from `EnableTrackingView` (`:45–47`) — it is correct.
  Validation: `applicationTokens` or `categoryTokens` non-empty.
- **`YourRulesView`** — daily limit (preset chips 30m / 1h / 1h30 / 2h + custom wheel reusing
  `TimeLimitSheetView`'s picker) above a two-option pressure choice reusing `PressureLevelView`'s
  card design. Standard preselected; **Off is not offered here**.
  This screen is the densest in the flow — if it feels cramped on a small device, splitting it
  back into two is a one-line change to the step array, not a rewrite.
- **Single commit point.** After `YourRulesView`, one
  `UserSettingsManager.shared.update { ... }` writes applications + threshold + pressureLevel
  together. `HomeView`'s `onReceive(userSettingsManager.$userSettings)` then starts monitoring on
  first appearance. Avoids three partial saves and three monitor restarts.

### Phase 3 — The coach ask + Home's first-run state

- **`FindCoachView`** — rework of `FindFriendsView`:
  - contacts priming *card* with an explicit "Find my friends" button, replacing the bare
    `.onAppear { requestContactsAccess() }` (`FindFriendsView.swift:125`);
  - row action reads **"Ask to coach me"**, not "+";
  - sending the requests is also what triggers `UNUserNotificationCenter.requestAuthorization`,
    framed as "we'll tell you when they accept";
  - `ShareLink` promoted from a footnote to the real empty-state action;
  - sent rows show a "Requested" pill.
  - Skippable, but the skip states the consequence rather than hiding it.
  - **Notifications fallback:** if the user skips this screen entirely, notifications are never
    requested. Ask on first arrival at Home instead, or on the first status change.
- **`SetupCardView` first-run variant** — currently it lists five missing items and will scold a
  user who just finished onboarding. It needs to (a) treat a *pending* coach request as
  satisfied-pending, and (b) render the "your limit is live / waiting on N" state described above
  instead of a to-do list.

### Phase 3a — RESOLVED: how the coach request actually works

Both open questions are closed by reading the code. **Do not re-derive these at implementation
time — they are counter-intuitive and getting either wrong builds the feature backwards.**

**1. `RoleRequestRole` is the REQUESTER's role, not the target's.**

```swift
// To make THEM my coach (I am the trainee) — this is what onboarding needs:
try await roleRequests.createRoleRequest(targetId: them, role: .trainee)

// To make THEM my trainee (I am the coach):
try await roleRequests.createRoleRequest(targetId: them, role: .coach)
```

Confirmed in three independent places:
`FriendProfileViewModel.performCoachPrimary()` (`:276`) sends `.trainee` to make the other person
a coach; `removeRelationship`'s doc comment (`RoleRequestRepository.swift:74–79`) defines role as
"the current user's role relative to otherId"; and inbox copy
(`RoleRequestsInboxViewModel:142`) renders `.coach` as "X wants to be your coach" — requester is
the coach. **`FindCoachView` sends `role: .trainee`.**

**2. Friendship is a precondition, enforced by the app today.**
`buildCoachAction` (`FriendProfileViewModel:351`) and `buildTraineeAction` (`:373`) both return
`enabled: false` when `!friends`. Role requests are unreachable in the UI until a friendship is
accepted. Onboarding must not be the one place that violates that convention.

**So "Ask to coach me" cannot be one call for a new contact. Use a queue:**

- **New `PendingCoachRequestStore`** in `Services/`, backed by UserDefaults key
  `pendingCoachRequests_<uid>` holding `[String]` of target uids.
- On tap: send the friend request, append the uid to the queue.
- If the person is **already an accepted friend**, skip the queue and call
  `createRoleRequest(targetId:role: .trainee)` immediately.
- **Drain** from `FriendsViewModel.refresh()` once `friends` is populated, and again on
  `scenePhase == .active` in `PPTAMinimalApp`: for each queued uid now in `friends`, fire the role
  request and remove it from the queue.

**3. `sendFriendRequest` has no duplicate guard.** `FriendshipRepository.sendFriendRequest`
(`:22–33`) blindly `setData`s a new document on every call — two taps create two pending
friendships. `FindCoachView` must exclude anyone already in `friends`, `incomingRequests`, or
`outgoingRequests`, and disable each row once sent.

### Phase 4 — Assets & polish

- Import new illustrations at proper resolution. **Recommended: vector PDF, "Preserve Vector
  Data" + "Render As: Template Image"**, then tint with `Color("primaryColor")`. This gets
  resolution independence *and* correct dark mode for free, and lets `.invertedForDarkMode()` be
  deleted rather than perpetuated.
  If the generator can only produce raster, ship 1024px PNGs in the **3x** slot.
- Rename assets to semantic names (`onb-hook`, `onb-the-key`, …); no spaces.
- Optionally import the five hand-drawn chrome marks (`ui-check`, `ui-circle-mark`,
  `ui-underline`, `ui-divider`, `ui-arrow`) if the `WobblyStroke` route from Phase 0 doesn't
  cover a case — see asset prompts §1b, Path B.
- Keep `onboarding-illustration-verify` — still used by `PhoneView.swift:73`.
- **Update `SetupCardView`** to treat a *pending* coach request as satisfied-pending rather than
  missing, so a user who just finished onboarding is not scolded for something they already did.

### Phase 5 — Verification (manual, on device)

Matrix to walk before calling it done:

- deny Screen Time → confirm hard wall + Open Settings works, no advance
- deny notifications → confirm "Continue without notifications" path
- deny contacts → confirm invite-link empty state, flow still completes
- zero contacts on device → same
- kill app at each step → confirm resume at the right step, `onboardingComplete` still unset
- second account on same device → confirm onboarding replays
- complete flow with no coach → confirm `AllSetView` copy is honest and `SetupCardView` is sane
- complete flow with a coach → confirm limit is live, monitoring starts, status card is All Clear

---

## 5. Asset manifest

See `docs/onboarding-asset-prompts.md` for the generation prompts.

**Core set — five illustrations.**

| Asset | Used on | Status |
|---|---|---|
| `onb-the-key` | 1 — The key | new |
| `onb-pick-apps` | 3 — Pick your apps | new |
| `onb-the-loop` | 4 — Your rules (small, above the pressure choice) | new |
| `onb-find-coach` | 5 — Your coach | new |
| `onb-waiting` | Home first-run "waiting on your coach" | new, small spot |

Optional sixth: `onb-all-set` for Home's first-run card once a coach accepts.

**Retire:** `onboarding-illustration-one 1`, `onboarding-illustration-tracking`,
`onboarding-illustration-notifs`.
**Keep:** `onboarding-illustration-verify` — still used by `PhoneView.swift:73`.

---

## 6. Execution brief — read this at go-time

Everything below is verified against the code as of `ae3c3b9`. Signatures are real. Build in this
order; each step compiles on its own.

### 6.1 Verified APIs (do not re-check)

```swift
// Components
PrimaryButton(title:isDisabled:enabledBackground:disabledBackground:cornerRadius:action:)
InputView(text:title:placeholder:isSecureField:)          // uses Color("backgroundGray") — no dark variant
PageIndicator(page:length:)                                // has a dynamic-ForEach bug, see 6.3
TimeLimitSheetView(draftHours: Binding<Int>, draftMinutes: Binding<Int>)   // reusable as-is

// Auth
AuthViewModel.shared
  .currentUser: User?                       .userSession: FirebaseAuth.User?
  .isOnboardingComplete: Bool               .markOnboardingComplete()
  .updateUserDisplayName(displayName:) async

// Settings
UserSettingsManager.shared
  .userSettings: UserSettings               // @Published
  .saveSettings(_ settings: UserSettings)   // sets isTracking + traineeStatus itself
  .update { inout UserSettings in ... }     // ⚠️ see 6.2
UserSettings.appLimitsAreViable(thresholdHour:thresholdMinutes:applications:) -> Bool
PressureLevel.off / .standard / .hardcore   // rawValue "Off"/"Standard"/"Hardcore"

// Relationships
FriendsViewModel: .friends .incomingRequests .outgoingRequests
  .refresh() async  .addFriend(userId:) async  .addFriend(byPhone:) async
FriendshipRepository.areFriends(_:_:) async throws -> Bool
RoleRequestRepository.createRoleRequest(targetId:role:) async throws -> String
```

### 6.2 Traps found while verifying — each one is a real bug if ignored

| Trap | Consequence | Handling |
|---|---|---|
| `RoleRequestRole` is the **requester's** role | Coach/trainee inverted app-wide | Send `.trainee` to gain a coach (6.1, Phase 3a) |
| Friendship required before a role request | Coach request silently unreachable | Queue via `PendingCoachRequestStore` |
| `sendFriendRequest` has no dedupe | Duplicate pending friendships | Filter against existing lists, disable sent rows |
| `UserSettingsManager.update()` falls back to `loadSettingsSyncFromDefaults()` when `draft.id == UserSettings().id` — a "crude isDefault check" (`:192–204`) | A brand-new user's in-memory draft can be silently replaced by defaults mid-onboarding | **Do not use `update {}` for the Act II commit.** Mutate `userSettingsManager.userSettings` and call `saveSettings(_:)` explicitly, exactly as `PressureLevelView.saveToFirebase()` does |
| `PressureLevelView.saveToFirebase()` calls `stopMonitoring()` + clears `isMonitoringActive` **before** saving | Monitoring won't restart cleanly if skipped | Mirror both lines in the Act II commit |
| `saveSettings` → `notifyCoachesIfSetupChanged` | Would spam coaches on first setup | **Already safe** — guarded by `previous.hasViableAppLimits`, false for a new user. No action needed. |
| `pressureCard(...)` is `private` in `PressureLevelView` | Can't reuse directly | Extract to `Views/Components/PressureLevelCard.swift`, update both call sites |
| `PhoneVerificationView` sheet fires on any `currentUser` change with `interactiveDismissDisabled(true)` (`OnboardingContainerView:62–69`) | Modal wall over any step | Present only at a defined step |

### 6.3 File-by-file change list

**New — `Views/Onboarding/`**
| File | Contents |
|---|---|
| `OnboardingScaffold.swift` | illustration slot · title (`BambiBold`) · body (`Satoshi-Variable`) · primary button · optional secondary link · page dots · back chevron |
| `IntroKeyView.swift` | screen 1 · `onb-the-key` |
| `ChooseAppsView.swift` | screen 3 · auth → `.familyActivityPicker` → draft · `onb-pick-apps` |
| `YourRulesView.swift` | screen 4 · limit chips + `TimeLimitSheetView` + pressure cards · `onb-the-loop` |
| `FindCoachView.swift` | screen 5 · contacts priming, "Ask to coach me", ShareLink empty state · `onb-find-coach` |

**New — elsewhere**
| File | Contents |
|---|---|
| `Services/PendingCoachRequestStore.swift` | queue + drain (Phase 3a) |
| `Views/Components/PressureLevelCard.swift` | extracted from `PressureLevelView` |
| `Views/Components/WobblyStroke.swift` | seeded-jitter `Shape`, 1–2 pt deviation |

**Modified**
| File | Change |
|---|---|
| `OnboardingCoordinator.swift` | ordered `[OnboardingStep]` + index math; drop the two switches; add `progressIndex`/`progressTotal`; hold the Act II draft; persist `onboardingStep_<uid>` |
| `OnboardingContainerView.swift` | `NavigationView` → `NavigationStack`; `withAnimation` + asymmetric slide; gate the phone sheet to one step |
| `PageIndicator.swift` | fix `ForEach(0..<page)` → `ForEach(0..<length, id: \.self)` with a filled/unfilled ternary; wobbly dots |
| `CreateProfileView.swift` | onto scaffold; auto-skip when `currentUser.name` is non-empty and != "Unknown" |
| `PressureLevelView.swift` | use extracted `PressureLevelCard` |
| `FriendsViewModel.swift` | drain the pending-coach queue at the end of `refresh()` |
| `PPTAMinimalApp.swift` | drain on `scenePhase == .active` alongside the existing `applyPendingStatusIfNeeded()` |
| `Dashboard/SetupCardView.swift` | first-run variant; pending coach request counts as satisfied-pending |
| `Extensions/ViewModifiers/DarkModeColorInvert.swift` | **delete** once assets are templates |

**Deleted:** `WelcomeView.swift`, `EnableTrackingView.swift`, `EnableNotificationsView.swift`,
`FindFriendsView.swift` (its `AppUserContact` / `AppUserCardView` / `ContactCardView` move into
`FindCoachView.swift`).

**Also delete while in here:** `AppMonitor/SettingsLoader.swift` — dead code, already flagged in
`CLAUDE.md` §Cleanup.

### 6.4 Assets — import steps

Source: `~/Downloads/separated_transparent_pngs` (4 approved) + one redo for `onb-the-loop`.

| File | → asset name |
|---|---|
| `01_key_access.png` | `onb-the-key` |
| `02_select_option.png` | `onb-pick-apps` |
| `04_helping_hand.png` | `onb-find-coach` |
| `05_pending_message.png` | `onb-waiting` |
| *(pending redo)* | `onb-the-loop` |

1. Pad each to square with ≥11% margin (they arrive trimmed to bbox, 382–534 px, non-square).
2. Trace to PDF (`potrace` on a thresholded bitmap, or Illustrator image-trace).
3. Add to `PPTAMinimal/Assets.xcassets`; set **Resizing: Preserve Vector Data** and
   **Render As: Template Image**.
4. Tint at the call site with `Color("primaryColor")`.
5. Delete `DarkModeColorInvert.swift` and its 4 call sites (`WelcomeView`, `EnableTrackingView`,
   `EnableNotificationsView` are being deleted anyway; **`PhoneView.swift:73` is not** — convert
   that one).
6. Retire `onboarding-illustration-one 1`, `-tracking`, `-notifs`. **Keep
   `onboarding-illustration-verify`** — still used by `PhoneView.swift:73`.

Raster fallback if tracing is skipped: 1024 px into the **3x** slot, never 1x.

### 6.5 Build order

1. Phase 0 foundations — coordinator, scaffold, `PageIndicator` fix, `WobblyStroke`, `NavigationStack`, step persistence. *Independent of assets; can start before the redo lands.*
2. `PressureLevelCard` extraction.
3. Screens 1, 2 (scaffold + existing profile logic).
4. Screen 3 `ChooseAppsView`.
5. Screen 4 `YourRulesView` + the single Act II commit.
6. `PendingCoachRequestStore` + drain sites.
7. Screen 5 `FindCoachView`.
8. `SetupCardView` first-run variant.
9. Asset import + `DarkModeColorInvert` removal.
10. Delete the four old onboarding views + `SettingsLoader.swift`.

### 6.6 Device verification matrix

Per the standing rule I don't run builds — this is your list once it compiles.

- Deny Screen Time → hard wall holds, Open Settings works, no advance
- Deny contacts → invite-link empty state, flow still completes
- Zero contacts on device → same
- Deny notifications → flow completes, no "Enabled ✓" lie
- Kill app at each step → resumes at that step, `onboardingComplete_<uid>` still unset
- Second account on same device → onboarding replays
- Finish with **no** coach → Home shows the honest pending state, `SetupCardView` doesn't scold
- Finish **with** an existing friend as coach → role request sent immediately, no queue
- Finish with a **new** contact → friend request sent; on their accept, coach request auto-fires
- Tap a contact twice → exactly one friendship document
- After completion → `hasViableAppLimits` true, monitoring starts, status card reads All Clear
