# Personas

Status: concept agreed (2026-11-21); details and graphics to flesh out.

## Idea
Each user becomes a character based on their biggest stat: **Cop** (locks people most), **Angel**
(gives extra time most), **Prisoner** (gets locked constantly). The persona changes their profile
sheet and adds a small badge on their picture on others' Home (a siren for a Cop).

## Decided
- 2026-11-21: **Persona = biggest stat, recomputed at random times.** Once a day the server rolls for
  each user; the chance of a recompute grows with days since the last one (an increasing hazard, not
  Poisson, which would be a constant rate). Starting table, to tune:

  | Days since last recompute | Chance that day |
  |---|---|
  | 0-3 | 2% |
  | 4 | 15% |
  | 5 | 40% |
  | 6 | 70% |
  | 7 | 100% |

  Expected gap about 5-6 days, never over 7, and users change at different times, so feed moments
  stay spread out and surprising.
- 2026-11-21: **Recompute looks at stats since the last recompute.** Below a minimum (e.g. 3 events),
  the current persona stays.
- 2026-11-21: **Personas are special and temporary.** Most people have none most of the time. You
  earn one by standing out (crossing a high bar, not just having a biggest stat), keep it for a
  while, then go back to none. Stronger achievements last longer, but nothing is permanent. Never
  everyone at once. To be fleshed out conceptually when work starts; the random recompute above
  may become "how long you keep it".

## Persona ideas (brainstorm, not decided)
| Persona | Earned by |
|---|---|
| Cop 🚨 | Locking peers a lot |
| Prisoner ⛓️ | Getting locked a lot |
| Angel 😇 | Giving extra time a lot |
| Beggar / Negotiator 🙏 | Asking for extra time a lot |
| Monk 🧘 | Long streak under limit, no locks |
| Fugitive 🏃 | Turning Pressure Off |
| Lone Wolf 🐺 | Pressure On with no peers for a week |
| Repeat Offender 🔁 | Locked 3+ times in one day |
| Speedrunner ⚡ | Hitting the limit before noon |
| Night Owl 🦉 | Hitting the limit late at night |
| Warden 🗝️ | Locking the same peer again and again |
| Sheriff ⭐ | Locking the most different peers |
| Ghost 👻 | Ignoring peers who need attention |
| Comeback Kid 🔥 | A long streak right after being a Prisoner |
| Smuggler 🕶️ | Watching lots of ads for secret extra time |
| Influencer 📣 | Inviting the most friends (ties to sharing) |

Civilian is dropped: no persona is the default.

## Open questions
- Final list, the bar for each, and how long each lasts.
- Can someone hide theirs?
- Can you hold two at once, or only one?
- Graphics: who draws them, style.
