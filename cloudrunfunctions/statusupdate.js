'use strict';

const functions = require('@google-cloud/functions-framework');
const admin = require('firebase-admin');
const crypto = require('crypto');

if (!admin.apps.length) {
  admin.initializeApp();
}

// ▲ NEW: single source of truth for lock-cause values (mirrors Swift `enum LockCause`).
const LOCK_CAUSE = {
  HARDCORE_LIMIT: 'hardcoreLimit',
  COACH: 'coach',
  SNOOZE_ENDED: 'snoozeEnded',
};
const VALID_CAUSES = Object.values(LOCK_CAUSE);

// Switch for server-composed alert pushes to coaches (traineeStatus, traineeReinstalled). false =
// the old silent background push (the app composes the banner locally), safe with any app build.
// Flip to true only once the build that skips its local banner when `aps.alert` is present is on
// every tester's phone; older builds would show two banners.
const ALERT_PUSH = true;

function bad(res, code, reason) {
  res.status(code).set('Content-Type', 'text/plain').send(reason);
}

function timingSafeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (!/^[a-f0-9]{64}$/i.test(a) || !/^[a-f0-9]{64}$/i.test(b)) return false;

  return crypto.timingSafeEqual(
    Buffer.from(a, 'hex'),
    Buffer.from(b, 'hex')
  );
}

function safeJsonParse(s) {
  try {
    return JSON.parse(s);
  } catch {
    return {};
  }
}

function readBodyAsObject(req) {
  const raw = req.rawBody ?? req.body;

  if (raw && typeof raw === 'object' && !Buffer.isBuffer(raw)) {
    return raw;
  }

  if (Buffer.isBuffer(raw)) {
    return safeJsonParse(raw.toString('utf8'));
  }

  if (typeof raw === 'string') {
    return safeJsonParse(raw);
  }

  return {};
}

const MAX_MESSAGE_CODE_POINTS = 100;

// Mirror of `_clean_message` in lockapp.py (and ActionMessage.clean on the client): whitespace and
// control characters (category Cc) collapse to single spaces, ends are trimmed, and the result is
// capped at 100 code points. Format characters (e.g. U+200D ZWJ) are kept so emoji sequences
// survive. Returns null when nothing is left.
function cleanMessage(raw) {
  if (typeof raw !== 'string') return null;
  const out = [];
  let lastWasSpace = true; // also drops leading whitespace
  for (const ch of raw) {
    if (/[\p{Z}\p{Cc}]/u.test(ch)) {
      if (!lastWasSpace) out.push(' ');
      lastWasSpace = true;
    } else {
      out.push(ch);
      lastWasSpace = false;
    }
  }
  // The cut can leave a trailing space.
  const capped = out.slice(0, MAX_MESSAGE_CODE_POINTS).join('').replace(/ +$/, '');
  return capped || null;
}

function firstName(name, fallback) {
  const first = String(name || '').trim().split(/\s+/)[0];
  return first || fallback;
}

// The trainee's daily limit in whole minutes, from userSettings' thresholdHour + thresholdMinutes.
// 0 when unset or unreadable.
function limitMinutes(hours, minutes) {
  return (Number.isFinite(hours) ? Math.floor(hours) : 0) * 60 +
    (Number.isFinite(minutes) ? Math.floor(minutes) : 0);
}

// Spelled out as Screen Time writes durations: "1 hr 15 min", "45 min", "2 hr". The limit is stored
// in whole minutes, so there are no seconds to round. null for no limit.
function formatLimit(total) {
  if (!(total > 0)) return null;
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h} hr` : `${h} hr ${m} min`;
}

// What a settingsChanged event changed, as the trainee's app reports it (unsigned; copy only).
const SETTINGS_EVENTS = ['pressureOff', 'pressureOn', 'levelChanged', 'appsChanged', 'limitChanged', 'appsAndLimitChanged'];
const SCREENSHOT_ASK = "Ask for a screenshot of their App Limits to know what they're tracking!";

// Banner copy for a settingsChanged push. Anything that may have touched the app selection asks the
// coach to get a screenshot, since coaches can't see a trainee's apps. Turning Pressure off is reported
// alone: nothing is tracked, and turning it back on asks for the screenshot. `null` for an event this
// server doesn't know (an older app build sends none), and the caller falls back to the generic copy.
function settingsChangedCopy({ event, traineeFirst, level, fromMinutes, toMinutes }) {
  const from = formatLimit(fromMinutes);
  const to = formatLimit(toMinutes);
  switch (event) {
    case 'pressureOff':
      return { title: `${traineeFirst} stopped tracking their apps! 🥀`, body: "Their apps aren't being tracked anymore. Why did they stop locking in?" };
    case 'pressureOn':
      return { title: `${traineeFirst} started tracking their apps! 💪`, body: SCREENSHOT_ASK };
    case 'levelChanged':
      if (level !== 'Hardcore' && level !== 'Standard') return null;
      return {
        title: level === 'Hardcore' ? `${traineeFirst} switched to Hardcore 🔥` : `${traineeFirst} switched to Standard`,
        body: SCREENSHOT_ASK,
      };
    case 'appsChanged':
      return { title: `${traineeFirst} changed their monitored apps`, body: SCREENSHOT_ASK };
    case 'limitChanged':
      if (!from || !to) return null;
      return { title: `${traineeFirst} changed their time limit`, body: `From ${from} to ${to}. Monitored apps stayed the same.` };
    case 'appsAndLimitChanged':
      return { title: `${traineeFirst} changed all their App Limits`, body: SCREENSHOT_ASK };
    default:
      return null;
  }
}

// Banner copy for a traineeStatus push, rendered per recipient: the coach who acted sees "You…".
// `null` = no banner (allClear is the silent daily reset). Mirrors the app's fallback copy.
// `limit` (formatLimit) names the limit hit, in the body so the title stays short; without it the
// body is the old one.
function traineeStatusCopy({ status, cause, traineeFirst, byFirst, actedBySelf, limit }) {
  const limitTitle = `${traineeFirst} hit their time limit! 👀`;
  const limitIs = limit ? `Their limit is ${limit}. ` : '';
  switch (status) {
    case 'attentionNeeded':
      return { title: limitTitle, body: `${limitIs}Go ahead and cut them off!` };
    case 'cutOff': {
      const title = `${traineeFirst} has been locked! 🔒`;
      switch (cause) {
        case LOCK_CAUSE.HARDCORE_LIMIT:
          // Same title as Standard's: the event is the limit; Hardcore is why there's nothing to do.
          return { title: limitTitle, body: `${limitIs}They're on Hardcore, so their apps locked themselves. 🔒` };
        case LOCK_CAUSE.COACH:
          return { title, body: actedBySelf ? 'You cut off their apps.' : `${byFirst} cut off their apps.` };
        case LOCK_CAUSE.SNOOZE_ENDED:
          return { title, body: "Their snooze ran out — they're locked again." };
        default:
          return { title, body: 'Their apps are now locked.' };
      }
    }
    case 'snoozedLock':
      return {
        title: `${traineeFirst}'s lock has been snoozed! ⏳`,
        body: actedBySelf ? 'You gave them 10 more minutes.' : `${byFirst} gave them 10 more minutes.`,
      };
    case 'allClear':
      return null;
    default:
      return { title: 'Accountability update', body: `${traineeFirst} has a status update.` };
  }
}

// One send path for the coach fan-out. With ALERT_PUSH on and copy present: an alert push (shows
// while the app is force-quit) that still carries `data` and content-available so the app's handler
// runs its side effects. Otherwise the old silent background push.
async function sendCoachPush(token, data, copy, collapseId) {
  if (!ALERT_PUSH || !copy) {
    return admin.messaging().send({
      token,
      data,
      apns: {
        headers: {
          'apns-priority': '5',
          'apns-push-type': 'background',
        },
        payload: {
          aps: { 'content-available': 1 },
        },
      },
    });
  }

  return admin.messaging().send({
    token,
    data,
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
        'apns-collapse-id': collapseId,
        'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600),
      },
      payload: {
        aps: {
          alert: { title: copy.title, body: copy.body },
          sound: 'default',
          'content-available': 1,
        },
      },
    },
  });
}

functions.http('statusUpdate', async (req, res) => {
  try {
    if (req.method !== 'POST') return bad(res, 405, 'method not allowed');

    const data = readBodyAsObject(req);
    // ▲ NEW (per-coach): targetCoach — the single coach a mercy request is addressed to.
    // ▲ NEW: change — what a settingsChanged event altered (appLimits | pressureLevel | both).
    //   Sent in the body but NOT signed; kept for the data payload only.
    // ▲ NEW: event / level / fromMinutes / toMinutes — the specific settingsChanged case and its
    //   details (see settingsChangedCopy). NOT signed: they only pick the coach's banner copy.
    // ▲ NEW: message — optional note on a mercyRequest. Sent in the body but NOT signed; sanitized
    //   below and omitted when empty, so a request without one behaves exactly as before.
    // ▲ NEW: cmd — the coach command (`lockCommand.id`) this status reports applying. Sent only by
    //   the app's notification service extension, which applies a lock/snooze while PPTA is closed
    //   and can't write Firestore itself; the server acks the command for it (see below). Signed.
    const { uid, status, ts, sig, type, cause, by, targetCoach, change, message, cmd, event, level, fromMinutes, toMinutes } = data;

    if (!uid || !status || ts === undefined || ts === null || !sig) {
      return bad(res, 400, 'missing params');
    }

    // 'snoozedLock' added — it was previously rejected, so snooze pushes never fanned out.
    if (!['allClear', 'attentionNeeded', 'cutOff', 'snoozedLock'].includes(status)) {
      return bad(res, 400, 'invalid status');
    }

    // `type` is optional. Absent (or 'status') keeps the original behaviour so existing
    // clients are unaffected; 'mercyRequest' is a trainee asking ONE coach for more time;
    // 'reinstalled' is a trainee reporting they deleted & reinstalled the app;
    // 'settingsChanged' is a trainee telling coaches they changed their App Limits.
    const requestType = type === undefined || type === null ? 'status' : type;
    if (!['status', 'mercyRequest', 'reinstalled', 'settingsChanged'].includes(requestType)) {
      return bad(res, 400, 'invalid type');
    }
    const isMercyRequest = requestType === 'mercyRequest';
    // ▲ NEW: a reinstall notice — no enforcement/state change, just a coach heads-up.
    const isReinstall = requestType === 'reinstalled';
    // ▲ NEW: a settings-change notice — no enforcement/state change, just a coach heads-up.
    const isSettingsChanged = requestType === 'settingsChanged';

    // ▲ NEW (per-coach): a mercy request must name exactly one target coach.
    const hasTargetCoach = typeof targetCoach === 'string' && targetCoach.length > 0;
    if (isMercyRequest && !hasTargetCoach) {
      return bad(res, 400, 'missing targetCoach');
    }

    // Optional attribution. `cause` explains a cutOff/snoozedLock; `by` is the acting coach's
    // UID (present only for cause === 'coach'). Validated but tolerant of absence for old clients.
    const hasCause = cause !== undefined && cause !== null && cause !== '';
    if (hasCause && !VALID_CAUSES.includes(cause)) {
      return bad(res, 400, 'invalid cause');
    }
    const hasBy = typeof by === 'string' && by.length > 0;
    const hasCmd = cmd !== undefined && cmd !== null && cmd !== '';
    if (hasCmd && !(typeof cmd === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(cmd))) {
      return bad(res, 400, 'invalid cmd');
    }

    const secret = process.env.UNLOCK_SECRET;
    if (!secret) return bad(res, 500, 'server misconfiguration');

    const tsStr = String(ts);
    if (!/^\d+$/.test(tsStr)) {
      return bad(res, 400, 'invalid timestamp format');
    }

    const tsInt = Number(tsStr);
    if (!Number.isFinite(tsInt)) {
      return bad(res, 400, 'invalid timestamp format');
    }

    const nowSec = Math.floor(Date.now() / 1000);
    if (Math.abs(nowSec - tsInt) > 5 * 60) {
      return bad(res, 410, 'link expired');
    }

    // The type is part of the signed message for mercy/reinstall/settingsChanged, so a captured
    // status-update signature can't be replayed with `type` flipped. Plain status updates keep the
    // original 3-part message, so old clients still verify.
    // ▲ NEW (per-coach): targetCoach is appended for mercy so it can't be tampered to redirect
    //   the request at a different coach. cause/by are appended for status updates as before.
    // ▲ NEW: 'reinstalled' / 'settingsChanged' append their type only (client signs
    //   `uid|status|ts|reinstalled` and `uid|status|ts|settingsChanged`). `change` is NOT signed.
    let msg = `${uid}|${status}|${tsInt}`;
    if (isMercyRequest) {
      msg += '|mercyRequest';
      if (hasTargetCoach) msg += `|${targetCoach}`;
    } else if (isReinstall) {
      msg += '|reinstalled';
    } else if (isSettingsChanged) {
      msg += '|settingsChanged';
    } else {
      if (hasCause) msg += `|${cause}`;
      if (hasBy) msg += `|${by}`;
      if (hasCmd) msg += `|${cmd}`;
    }

    const expected = crypto
      .createHmac('sha256', Buffer.from(secret, 'utf8'))
      .update(Buffer.from(msg, 'utf8'))
      .digest('hex');

    if (!timingSafeEqualHex(expected, sig)) {
      return bad(res, 403, 'bad sig');
    }

    const db = admin.firestore();

    // Resolve the acting coach's display name from `by` (same lookup shape as traineeName).
    // Best-effort: a failed lookup just omits byName, and the client falls back to neutral copy.
    let byName = null;
    if (hasBy) {
      try {
        const bySnap = await db.collection('users').doc(by).get();
        const n = bySnap.exists ? bySnap.get('name') : null;
        if (typeof n === 'string' && n.trim()) byName = n.trim();
      } catch (_) {
        // best-effort
      }
    }

    const settingsRef = db.collection('userSettings').doc(uid);
    const requestMessage = isMercyRequest ? cleanMessage(message) : null;

    if (requestType === 'status') {
      const settingsUpdate = {
        traineeStatus: status,
        lastStatusAt: admin.firestore.FieldValue.serverTimestamp(),
        // ▲ NEW (per-coach): any non-cutOff status ends ALL outstanding snooze requests — a
        //   snooze, a new-day allClear, or a drop to attentionNeeded empties the list. This is
        //   the authoritative clear that the trainee's coaches (who watch this doc live) react to.
        ...(status !== 'cutOff'
          ? {
              snoozeRequestedCoachIds: [],
              snoozeRequestMessages: admin.firestore.FieldValue.delete(),
            }
          : {}),
        ...(status === 'allClear'
          ? {
              lockedByUID: admin.firestore.FieldValue.delete(),
              lockedByName: admin.firestore.FieldValue.delete(),
            }
          : {}),
        // Persist who cut them off so the coach's profile view (which reads Firestore) is
        // consistent with the push. Only for a coach-caused cutOff.
        ...(status === 'cutOff' && cause === LOCK_CAUSE.COACH && hasBy
          ? { lockedByUID: by, ...(byName ? { lockedByName: byName } : {}) }
          : {}),
      };

      await settingsRef.set(settingsUpdate, { merge: true });

      // ▲ NEW: ack the coach command the extension applied, for the coach's sheet (which waits on
      //   `lockAck`). Same rules as the app's own ack: only when it is still the current command,
      //   so a late report can't overwrite the ack of a newer one. Best-effort.
      const ackAction = status === 'cutOff' ? 'lock' : status === 'snoozedLock' ? 'unlock' : null;
      if (hasCmd && ackAction && cause === LOCK_CAUSE.COACH) {
        try {
          await db.runTransaction(async (tx) => {
            const snap = await tx.get(settingsRef);
            const current = snap.exists ? snap.get('lockCommand') : null;
            if (!current || current.id !== cmd || current.action !== ackAction) return;
            tx.update(settingsRef, {
              lockAck: {
                id: cmd,
                action: ackAction,
                result: 'applied',
                at: admin.firestore.FieldValue.serverTimestamp(),
              },
            });
          });
        } catch (e) {
          console.error('statusUpdate: lockAck write failed', e);
        }
      }
    } else if (isMercyRequest) {
      // ▲ NEW (per-coach): a mercy request never changes enforcement state (asking ≠ deciding),
      //   it just adds the chosen coach to the trainee's outstanding-request list. arrayUnion is
      //   idempotent, so re-asking the same coach is a no-op. Cleared by any non-cutOff status.
      //   ▲ NEW: the optional note is stored per coach beside the list (a nested merge, so other
      //   coaches' notes survive). Re-asking without a note leaves an earlier one in place.
      await settingsRef.set(
        {
          snoozeRequestedCoachIds: admin.firestore.FieldValue.arrayUnion(targetCoach),
          ...(requestMessage ? { snoozeRequestMessages: { [targetCoach]: requestMessage } } : {}),
        },
        { merge: true }
      );
    }
    // ▲ NEW: 'reinstalled' and 'settingsChanged' write nothing — notification-only events. In
    //   particular settingsChanged must NOT write traineeStatus (its status is a placeholder
    //   'allClear'), or it would clobber the trainee's real status.

    // Trainee display name — needed by all push paths.
    let traineeName = 'Your trainee';
    try {
      const traineeSnap = await db.collection('users').doc(uid).get();
      const name = traineeSnap.exists ? traineeSnap.get('name') : null;
      if (typeof name === 'string' && name.trim()) {
        traineeName = name.trim();
      }
    } catch (_) {
      // best-effort
    }

    if (isMercyRequest) {
      // ▲ NEW (per-coach): notify ONLY the targeted coach — no broadcast.
      try {
        const coachSnap = await db.collection('users').doc(targetCoach).get();
        const token = coachSnap.exists ? coachSnap.get('fcmToken') : null;
        if (token) {
          await admin.messaging().send({
            token,
            data: {
              type: 'mercyRequest',
              uid: String(uid),
              traineeName,
              ...(requestMessage ? { message: requestMessage } : {}),
            },
            notification: {
              title: `${traineeName} is asking for more time`,
              body: requestMessage ? `"${requestMessage}"` : 'Open PPTA to snooze their lock.',
            },
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: { sound: 'default' },
              },
            },
          });
        }
      } catch (_) {
        // best-effort
      }
    } else if (isReinstall) {
      // ▲ NEW: a trainee deleted & reinstalled PPTA — notify ALL their coaches (accountability
      //   deterrent). Alert push once ALERT_PUSH is on (server composes the copy); until then a
      //   silent background push that the client turns into a local notification. No
      //   status/state is written here.
      const settingsSnap = await settingsRef.get();
      const rawCoachIds = settingsSnap.exists ? settingsSnap.get('coachIds') : [];
      const coachIds = Array.isArray(rawCoachIds)
        ? rawCoachIds.filter((coachId) => typeof coachId === 'string' && coachId.length > 0)
        : [];

      for (const coachId of coachIds) {
        try {
          const coachSnap = await db.collection('users').doc(coachId).get();
          const token = coachSnap.exists ? coachSnap.get('fcmToken') : null;
          if (!token) continue;

          await sendCoachPush(
            token,
            {
              type: 'traineeReinstalled',
              uid: String(uid),
              traineeName,
            },
            {
              title: `${firstName(traineeName, 'Your trainee')} reinstalled PPTA`,
              body: "They deleted the app and reinstalled it, might want to check if they're cheating 🤨",
            },
            `reinstall-${uid}`
          );
        } catch (_) {
          // best-effort
        }
      }
    } else if (isSettingsChanged) {
      // ▲ NEW: a trainee changed their App Limits — alert ALL their coaches with what changed
      //   (settingsChangedCopy), or the generic "App Limits" copy when the app didn't say (older
      //   builds). First name only in the title. Alert push (like mercyRequest) so it shows even if
      //   the coach's app is closed; the server composes the copy since there's no client handler.
      //   No status/state is written.
      const traineeFirstName = String(traineeName).trim().split(/\s+/)[0] || traineeName;
      const copy = (SETTINGS_EVENTS.includes(event) &&
        settingsChangedCopy({
          event,
          traineeFirst: traineeFirstName,
          level: typeof level === 'string' ? level : undefined,
          fromMinutes: Number(fromMinutes),
          toMinutes: Number(toMinutes),
        })) || {
        title: `${traineeFirstName} changed their App Limits`,
        body: 'They updated their App Limits, reach out to them for a screenshot so you know their goals!',
      };

      const settingsSnap = await settingsRef.get();
      const rawCoachIds = settingsSnap.exists ? settingsSnap.get('coachIds') : [];
      const coachIds = Array.isArray(rawCoachIds)
        ? rawCoachIds.filter((coachId) => typeof coachId === 'string' && coachId.length > 0)
        : [];

      for (const coachId of coachIds) {
        try {
          const coachSnap = await db.collection('users').doc(coachId).get();
          const token = coachSnap.exists ? coachSnap.get('fcmToken') : null;
          if (!token) continue;

          await admin.messaging().send({
            token,
            data: {
              type: 'traineeSettingsChanged',
              uid: String(uid),
              traineeName,
              change: String(change ?? ''),
            },
            notification: copy,
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: { sound: 'default' },
              },
            },
          });
        } catch (_) {
          // best-effort
        }
      }
    } else {
      // Status update: fan-out to all coaches. Alert push (ALERT_PUSH) with per-recipient copy, or
      // the silent background push (allClear always) that makes their apps refresh.
      const settingsSnap = await settingsRef.get();
      const rawCoachIds = settingsSnap.exists ? settingsSnap.get('coachIds') : [];
      const coachIds = Array.isArray(rawCoachIds)
        ? rawCoachIds.filter((coachId) => typeof coachId === 'string' && coachId.length > 0)
        : [];

      // Attribution fields for the traineeStatus push. FCM data values must be strings, so only
      // add keys that are actually present.
      const attribution = {};
      if (hasCause) attribution.cause = String(cause);
      if (hasBy) {
        attribution.by = String(by);
        if (byName) attribution.byName = byName;
      }
      // Read from the same snapshot as coachIds, so naming the limit costs no extra read. In the data
      // too (total minutes), for the app's fallback copy.
      const totalLimit = settingsSnap.exists
        ? limitMinutes(settingsSnap.get('thresholdHour'), settingsSnap.get('thresholdMinutes'))
        : 0;
      const limit = formatLimit(totalLimit);
      if (limit) attribution.limitMinutes = String(totalLimit);

      for (const coachId of coachIds) {
        try {
          const coachSnap = await db.collection('users').doc(coachId).get();
          const token = coachSnap.exists ? coachSnap.get('fcmToken') : null;
          if (!token) continue;

          await sendCoachPush(
            token,
            {
              type: 'traineeStatus',
              uid: String(uid),
              status: String(status),
              traineeName,
              ...attribution,
            },
            traineeStatusCopy({
              status: String(status),
              cause: hasCause ? String(cause) : undefined,
              traineeFirst: firstName(traineeName, 'Your trainee'),
              byFirst: firstName(byName, 'A coach'),
              actedBySelf: hasBy && String(by) === coachId,
              limit,
            }),
            `status-${uid}`
          );
        } catch (_) {
          // best-effort
        }
      }
    }

    res.status(200).set('Content-Type', 'text/plain').send('OK');
  } catch (e) {
    return bad(res, 500, 'internal error');
  }
});