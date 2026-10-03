Covers §11 Navigation from PPTAMinimal's agent guide. Back to [`../../CLAUDE.md`](../../CLAUDE.md).

## 11. Navigation

### Root switches
Auth → `AuthViewModel.userSession`; onboarding → `AuthViewModel.isOnboardingComplete`;
reconfigure → `AuthViewModel.needsScreenTimeReconfigure`.

### Onboarding (`OnboardingCoordinator`)
Order lives in `coordinator.steps`, **not** in a hand-written `advance()` switch — `PageIndicator`
derives its position from the same array, so dots can't drift out of sync.

```
.fresh flow:        intro → profile → appLimits → findCoach → completed
                    (profile dropped entirely when the user already has a display name)
.reconfigure flow:  appLimits only
```

- `advance()` / `goBack()` walk `steps`; `isGoingBack` drives the slide direction
- The step is persisted per-uid so an abandoned run resumes; **completion is not** — the `onboardingComplete_<uid>` flag is written only at the end of `findCoach`
- **There is no global Skip.** It used to mark onboarding complete without Screen Time permission, app selection, or a limit — an account that looks set up but can't monitor anything. Only the final step is skippable, and it says so.
- `PhoneVerificationView` appears only at the `findCoach` step, where the phone number actually matters (contact matching). It used to pop over any step the moment `currentUser` loaded, with `interactiveDismissDisabled(true)` making it an unskippable wall.

**Reconfigure flow:** Screen Time authorization doesn't survive an uninstall, but the Firestore
account does. Rather than replaying onboarding, a returning user re-grants Screen Time and
re-confirms apps + limit/pressure. Coaches and trainees are untouched.

### Main app (TabNavigator)
Tab 0 Home, tab 1 Friends. Both badged. `AppLimitsView` is shared verbatim between Settings and
the onboarding `appLimits` step.

---
