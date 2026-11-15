'use strict';

// The red count on PPTA's app icon: how many things are waiting on this user. The same items the
// app counts while it's open (`AppBadge.count` in the app):
//   - trainees in attentionNeeded (the coach can lock them),
//   - trainees cut off and asking this coach for more time (`snoozeRequestedCoachIds`),
//   - incoming friend requests and incoming coach/trainee requests.
//
// Every push the server sends a user carries their current total (`aps.badge` on alert pushes,
// `data.badge` on every push so a silent one can set it too), so any push corrects the icon, down
// as well as up. Something resolved with no push to this user (a request cancelled) leaves the icon
// as it was until their next push or app open; see docs/design/features/app-badge.md.
//
// Shared by statusupdate.js and role-requests.js; deploy.sh stages it next to each.

/** True when this trainee's settings are waiting on `coachId`. */
function needsCoach(settings, coachId) {
  if (!settings) return false;
  if (settings.traineeStatus === 'attentionNeeded') return true;
  return settings.traineeStatus === 'cutOff' &&
    Array.isArray(settings.snoozeRequestedCoachIds) &&
    settings.snoozeRequestedCoachIds.includes(coachId);
}

/**
 * The user's badge total, or null when it can't be counted (callers then leave the badge out, so
 * the icon keeps whatever it showed). Three queries, run together.
 */
async function badgeCountFor(db, uid) {
  if (typeof uid !== 'string' || !uid) return null;
  try {
    const [trainees, friendRequests, roleRequests] = await Promise.all([
      db.collection('userSettings').where('coachIds', 'array-contains', uid).get(),
      db.collection('friendships').where('requesteeId', '==', uid).where('status', '==', 'pending').count().get(),
      db.collection('roleRequests').where('targetId', '==', uid).where('status', '==', 'pending').count().get(),
    ]);
    let total = 0;
    trainees.forEach((doc) => {
      if (needsCoach(doc.data(), uid)) total += 1;
    });
    return total + friendRequests.data().count + roleRequests.data().count;
  } catch (e) {
    console.error('badge count failed:', e && e.message);
    return null;
  }
}

/** `data` with the badge added as a string (FCM data values must be strings); unchanged if null. */
function withBadgeData(data, badge) {
  return badge == null ? data : { ...data, badge: String(badge) };
}

/** An `aps` dictionary with the badge added; unchanged if null. Alert pushes only: Apple doesn't
 *  allow a badge on a background push. */
function withBadgeAps(aps, badge) {
  return badge == null ? aps : { ...aps, badge };
}

module.exports = { badgeCountFor, needsCoach, withBadgeData, withBadgeAps };
