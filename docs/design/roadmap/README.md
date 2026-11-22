# Roadmap: the next big versions

Status: planning, started 2026-11-21. Nothing here is built. Each file holds the idea, what's been
decided (with the date), and the questions still open. When a feature ships, its design moves to
`../features/` and the roadmap file is marked **Shipped**.

| Feature | File | Status |
|---|---|---|
| Remove Hardcore (Pressure is just On / Off) | [remove-hardcore.md](remove-hardcore.md) | Decided |
| Peers instead of coach/trainee | [relationships.md](relationships.md) | Decided |
| Stat tracking | [stats.md](stats.md) | Mostly decided |
| New tabs: social Home with activity feed, Screen Time tab | [tabs-and-feed.md](tabs-and-feed.md) | Mostly decided |
| Personas (Cop, Angel, Prisoner...) | [personas.md](personas.md) | Concept agreed |
| Ads and in-app purchases | [monetization.md](monetization.md) | Ads decided, IAP later |
| Sharing and invite incentives (like Beli) | [sharing.md](sharing.md) | Invite link decided |

## How they depend on each other

- **Stats** feed the activity feed, personas, the Screen Time tab and most invite incentives.
- **Relationships** decide who sees what: who can lock you, who gets pushes, who only sees stats.
- **Remove Hardcore** stands alone, and makes the relationship change simpler (fewer lock rules).
- **Monetization** depends on what extra time means once the relationship model changes.
- **Sharing** needs something worth gatekeeping (feed, personas, stats).

## Order

Agreed 2026-11-21:

1. **Remove Hardcore**: small; removes a lock path before the relationship rewrite.
2. **Peers**: the big migration; everything else depends on who is a peer vs a friend.
3. **Stats recording**: its own step, right after peers, so history builds up before anything shows
   it.
4. **Tabs and feed**: needs peers and stats.
5. **Invite link and peer-slot gate**: needs the peer cap; growth works better once the app is social.
6. **Personas**: needs weeks of stats and the feed to announce them.
7. **Ads**: needs the feed and personas to reveal secret ads after the fact. In-app purchases later.

## Parked for later
- Screen time totals (approximate, via usage events): `stats.md`.
- Leaderboard: `tabs-and-feed.md`.
- Feed reactions: `tabs-and-feed.md`.
- In-app purchases: `monetization.md`.
- More invite unlocks: `sharing.md`.
