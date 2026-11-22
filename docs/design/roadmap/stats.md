# Stat tracking

Status: mostly decided (2026-11-21).

## Idea
Record what happens so the feed, personas and Screen Time tab have something to show. Examples:
100 locks in a year, locked x times in one day.

## Today
No history is kept. Status lives on `userSettings` (current state only); screen time comes from
Screen Time reports on the device (`PPTAReport`), which can't leave the device as raw data.

## Decided
- 2026-11-21: **First version records:** locks given and received; extra time given, asked for and
  received; days under limit, with current and best streak.
- 2026-11-21: **Screen time totals are a later extension**, not in the first version (see below).
- 2026-11-21: **Stat updates are public, raw stats are private.** Peers and friends see stat updates
  in the feed (milestones, streaks). Only you see your own raw numbers (on the Screen Time tab); nobody can
  open someone else's stats from their sheet. Why: avoids overloading people with numbers, and keeps
  feed updates fun and surprising.
- 2026-11-21: **Windows: today, this week, this year, all time.** Cost and complexity to be checked when
  implementation planning starts. First thought: one counter document per user per period (e.g.
  `stats/{uid}/periods/2026-W47`), incremented by the server when a lock or extra time happens, so
  reads stay one document per window.

## Later: screen time totals
Exact minutes can't leave the phone (the report extension has no network). Approximate totals can:
the monitor extension would arm extra usage events (e.g. every 15 min of Monitored Apps) and report
"at least 45 min today". Accurate to one step, works with PPTA closed. Limits: iOS caps events per
schedule, so steps get coarser later in the day; App Review may question sharing Screen Time data
(never use it for ads). Would enable a screen-time leaderboard.

## Open questions
- Week starts Monday or Sunday? Day boundary is the user's local midnight (as limits today)?
