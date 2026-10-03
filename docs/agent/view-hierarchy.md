Covers §5 View Hierarchy from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 5. View Hierarchy

```
PPTAMinimalApp
├── LoginView
├── OnboardingContainerView  (OnboardingCoordinator state machine)
│   ├── IntroKeyView
│   ├── CreateProfileView          (skipped when Apple/Google supplied a display name)
│   ├── AppLimitsView              (shared with Settings — apps + limit + pressure)
│   ├── FindCoachView              (ContactsPicker; the only skippable step)
│   └── .completed
└── TabNavigator                    (TabView, 2 tabs)
    ├── HomeView                            tag 0, badged with attentionNeeded trainee count
    │   ├── ProfileView                     (header)
    │   ├── SetupCardView                   → NoAppLimits / NoCoaches / NoTrainees / PressureOff cards
    │   ├── statusCard                      (status banner)
    │   ├── reportSection                   (Commitment Streak + inline DeviceActivityReport ring)
    │   │   └── ReportView                  (sheet)
    │   └── TraineeCoachView                (coach/trainee grid of TraineeCircleView)
    │       └── FriendProfileSheetView      (sheet)
    └── FriendsView                         tag 1, badged with incoming friend + role requests
        ├── FriendsContactsImportView / FriendsContactsPickerView
        ├── Role request cards (Accept/Decline)
        ├── Incoming friend request cards
        ├── Pending outgoing cards (friend + coach/trainee, cancellable)
        └── FriendProfileView / FriendProfileSheetView

Global overlay: InAppBannerView (from NotificationManager, on TabNavigator)

Sheets:
- ReportView (HomeView)
- SettingsView → AppLimitsView → TimeLimitSheetView
- FriendProfileSheetView (Home, Friends)
- PhoneVerificationView (Onboarding, at the findCoach step only)
```

**There is no Status Center tab.** It was removed; `Views/StatusCenter/` is dead code (`../../CLAUDE.md` §14).
`StatusCenterViewModel` survives and is very much alive — it backs `TraineeCoachView` on Home
via `@EnvironmentObject`, injected by `TabNavigator`.

---
