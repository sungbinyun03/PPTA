# Ads and in-app purchases

Status: ads direction decided (2026-11-21); IAP later.

## Idea
Watch an ad to get extra time without your friends being notified. Later, other ways to earn:
in-app purchases.

## Constraints known
- The shield can't show an ad or open PPTA directly; an ad plays inside PPTA.
- Extra time with nobody told cuts against the accountability idea, so limits matter.

## Decided
- 2026-11-21: **Ad extra time sends no push.** It is revealed after the fact in the feed, in
  aggregate: a stat update ("watched 4 ads this week") or a persona (e.g. Smuggler).
- 2026-11-21: **The ad offer is occasional**, not every time someone hits their limit or their extra
  time runs out. Keeps it special and protects the core loop.
- 2026-11-21: **The offer comes at the limit, before peers act** (hitting the limit, or extra time
  running out). Peers are only told if the ad isn't finished: ignoring the offer, closing it or
  skipping the ad all notify peers as usual. An ad never lifts a peer's lock.
- 2026-11-21: **In-app purchases decided later**, once the rest is fleshed out and tested. All
  directions liked: Plus subscription (ad-free, perks like more peers or persona graphics),
  cosmetics (ring styles, badge skins, app icons), extra time packs.

## How it might work (to settle at implementation)
- The monitor extension hits the limit with PPTA usually closed, so the offer is a local
  notification ("Watch an ad for 10 more min, nobody's told") that opens PPTA to the ad.
- The peer push is held on the server for a short window (e.g. 2 min) and cancelled only when the
  app reports a finished ad. Anything else, including no answer, sends it. This keeps the default
  path working with the app closed.
- Server decides when the offer appears (random, capped per day), so it can't be gamed on-device.

## Open questions
- How much time per ad (10 min?), max ads per day, how often the offer appears.
- Ad network (AdMob, AppLovin...).
