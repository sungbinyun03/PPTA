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

functions.http('statusUpdate', async (req, res) => {
  try {
    if (req.method !== 'POST') return bad(res, 405, 'method not allowed');

    const data = readBodyAsObject(req);
    // ▲ NEW (per-coach): targetCoach — the single coach a mercy request is addressed to.
    // ▲ NEW: change — what a settingsChanged event altered (appLimits | pressureLevel | both).
    //   Sent in the body but NOT signed; kept for the data payload only (copy is centralized).
    const { uid, status, ts, sig, type, cause, by, targetCoach, change } = data;

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

    if (requestType === 'status') {
      const settingsUpdate = {
        traineeStatus: status,
        lastStatusAt: admin.firestore.FieldValue.serverTimestamp(),
        // ▲ NEW (per-coach): any non-cutOff status ends ALL outstanding snooze requests — a
        //   snooze, a new-day allClear, or a drop to attentionNeeded empties the list. This is
        //   the authoritative clear that the trainee's coaches (who watch this doc live) react to.
        ...(status !== 'cutOff' ? { snoozeRequestedCoachIds: [] } : {}),
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
    } else if (isMercyRequest) {
      // ▲ NEW (per-coach): a mercy request never changes enforcement state (asking ≠ deciding),
      //   it just adds the chosen coach to the trainee's outstanding-request list. arrayUnion is
      //   idempotent, so re-asking the same coach is a no-op. Cleared by any non-cutOff status.
      await settingsRef.set(
        { snoozeRequestedCoachIds: admin.firestore.FieldValue.arrayUnion(targetCoach) },
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
            },
            notification: {
              title: `${traineeName} is asking for more time`,
              body: 'Open PPTA to snooze their lock.',
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
      //   deterrent). Silent background push (like traineeStatus) so the APP composes the copy;
      //   the client turns this into a local notification. No status/state is written here.
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
              type: 'traineeReinstalled',
              uid: String(uid),
              traineeName,
            },
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
        } catch (_) {
          // best-effort
        }
      }
    } else if (isSettingsChanged) {
      // ▲ NEW: a trainee changed their App Limits — alert ALL their coaches. Messaging is
      //   centralized on "App Limits" regardless of what actually changed, and nudges the coach to
      //   ask for a screenshot. First name only in the title. Alert push (like mercyRequest) so it
      //   shows even if the coach's app is closed; the server composes the copy since there's no
      //   client handler. No status/state is written.
      const traineeFirstName = String(traineeName).trim().split(/\s+/)[0] || traineeName;

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
            notification: {
              title: `${traineeFirstName} changed their App Limits`,
              body: 'They updated their App Limits, reach out to them for a screenshot so you know their goals!',
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
        } catch (_) {
          // best-effort
        }
      }
    } else {
      // Status update: silent background fan-out to all coaches so their apps refresh.
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

      for (const coachId of coachIds) {
        try {
          const coachSnap = await db.collection('users').doc(coachId).get();
          const token = coachSnap.exists ? coachSnap.get('fcmToken') : null;
          if (!token) continue;

          await admin.messaging().send({
            token,
            data: {
              type: 'traineeStatus',
              uid: String(uid),
              status: String(status),
              traineeName,
              ...attribution,
            },
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