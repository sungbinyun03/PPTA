# Relationships: peers instead of coach and trainee

Status: decided (2026-11-21).

## Idea
Drop the one-way coach/trainee roles. Two options on the table:
- **Peers**: a tier above friends, two-way. Peers lock and give extra time to each other, and get
  each other's pushes. Friends only see stat updates in the feed.
- **Friends only**: every friend holds every other friend accountable, no extra tier.

## Today
`coachIds` / `traineeIds` on each user, role requests (`roleRequests`), coach and trainee pushes,
coach sheet, trainee status. See `../features/friends-and-roles.md`.

## Decided
- 2026-11-21: **Peers tier.** Peers are two-way: each can lock the other and give extra time, and
  each gets the other's pushes. Plain friends only see stats in the feed. Why: consent stays explicit,
  pushes stay relevant, and friends become the social layer.

- 2026-11-21: **Request + accept.** One sends "Add as peer", the other accepts (today's role request,
  one type). Either can remove the peer link anytime.
- 2026-11-21: **Migration: all coach/trainee links become peer links**, both ways, with a one-time note
  in the app. Why: simple, and the beta group is small and friendly.
- 2026-11-21: **Pressure Off means nobody can lock you**, as today. Peers still get the "turned Off"
  push, and you can still lock peers whose Pressure is On.
- 2026-11-21: **Called "peer"** in the app ("Add as peer", "Your peers"), matching Peer Pressure.
- 2026-11-21: **Cap of 10 peers.** Keeps the circle tight and pushes manageable. Anyone over 10 after
  migration keeps their links but can't add more until under 10. Inviting enough people raises
  the cap to 20 (see `sharing.md`).

## Open questions
