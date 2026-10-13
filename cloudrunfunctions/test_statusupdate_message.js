'use strict';

// Run: node --test cloudrunfunctions/test_statusupdate_message.js
// No node_modules in this repo, so the SDKs are stubbed at require time; nothing touches Firebase.

const test = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const Module = require('node:module');

const DELETE = Symbol('FieldValue.delete');
let handler;
let sets;
let sent;
let lockCommand; // the trainee's userSettings.lockCommand, as the ack transaction reads it
let acks;

const fakeAdmin = {
  apps: [1],
  initializeApp() {},
  firestore: Object.assign(
    () => ({
      runTransaction: async (fn) =>
        fn({
          get: async () => ({ exists: true, get: (f) => (f === 'lockCommand' ? lockCommand : undefined) }),
          update: (_ref, data) => acks.push(data),
        }),
      collection: (name) => ({
        doc: (id) => ({
          get: async () => ({
            exists: true,
            get: (f) => (name === 'users' ? { name: 'Sam Trainee', fcmToken: `tok-${id}` }[f] : []),
          }),
          set: async (data, opts) => sets.push({ name, id, data, opts }),
        }),
      }),
    }),
    {
      FieldValue: {
        delete: () => DELETE,
        serverTimestamp: () => 'ts',
        arrayUnion: (v) => ({ union: v }),
      },
    }
  ),
  messaging: () => ({ send: async (m) => sent.push(m) }),
};

const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === '@google-cloud/functions-framework') {
    return { http: (_name, fn) => (handler = fn) };
  }
  if (request === 'firebase-admin') return fakeAdmin;
  return origLoad.call(this, request, ...rest);
};
require('./statusupdate.js');
Module._load = origLoad;

process.env.UNLOCK_SECRET = 'secret';

function sign(msg) {
  return crypto.createHmac('sha256', Buffer.from('secret')).update(msg).digest('hex');
}

async function call(body) {
  const res = {
    code: null,
    status(c) { this.code = c; return this; },
    set() { return this; },
    send() { return this; },
  };
  await handler({ method: 'POST', body }, res);
  return res.code;
}

function mercy(extra = {}) {
  const ts = Math.floor(Date.now() / 1000);
  return {
    uid: 'u1', status: 'cutOff', ts, type: 'mercyRequest', targetCoach: 'c1',
    sig: sign(`u1|cutOff|${ts}|mercyRequest|c1`), ...extra,
  };
}

function statusBody(status) {
  const ts = Math.floor(Date.now() / 1000);
  return { uid: 'u1', status, ts, sig: sign(`u1|${status}|${ts}`) };
}

test.beforeEach(() => { sets = []; sent = []; acks = []; lockCommand = undefined; });

test('mercy request without a message is unchanged', async () => {
  assert.strictEqual(await call(mercy()), 200);
  assert.deepStrictEqual(sets[0].data, { snoozeRequestedCoachIds: { union: 'c1' } });
  assert.strictEqual(sent[0].notification.body, 'Open PPTA to snooze their lock.');
  assert.deepStrictEqual(Object.keys(sent[0].data).sort(), ['traineeName', 'type', 'uid']);
});

test('empty or whitespace message counts as absent', async () => {
  assert.strictEqual(await call(mercy({ message: ' \n\t ' })), 200);
  assert.ok(!('snoozeRequestMessages' in sets[0].data));
  assert.ok(!('message' in sent[0].data));
});

test('mercy request stores a cleaned message per coach and pushes it', async () => {
  assert.strictEqual(await call(mercy({ message: '  ten\n more\x00 minutes ' })), 200);
  assert.deepStrictEqual(sets[0].data.snoozeRequestMessages, { c1: 'ten more minutes' });
  assert.strictEqual(sets[0].opts.merge, true);
  assert.strictEqual(sent[0].data.message, 'ten more minutes');
  assert.strictEqual(sent[0].notification.body, '"ten more minutes"');
});

test('message is unsigned: signature does not cover it', async () => {
  assert.strictEqual(await call(mercy({ message: 'hi' })), 200);
});

test('caps at 100 code points, strips trailing space, keeps ZWJ sequences', async () => {
  const family = '\u{1F468}‍\u{1F469}‍\u{1F467}'; // 5 code points
  await call(mercy({ message: `${'a'.repeat(99)} ${family}` }));
  assert.strictEqual(sets[0].data.snoozeRequestMessages.c1, 'a'.repeat(99));
  sets = [];
  await call(mercy({ message: `${family} x` }));
  assert.strictEqual(sets[0].data.snoozeRequestMessages.c1, `${family} x`);
  sets = [];
  await call(mercy({ message: 'é'.repeat(150) }));
  assert.strictEqual(Array.from(sets[0].data.snoozeRequestMessages.c1).length, 100);
});

test('non-string message is ignored', async () => {
  assert.strictEqual(await call(mercy({ message: 42 })), 200);
  assert.ok(!('snoozeRequestMessages' in sets[0].data));
});

test('non-cutOff status deletes the messages with the request list; cutOff leaves both', async () => {
  for (const status of ['allClear', 'attentionNeeded', 'snoozedLock']) {
    sets = [];
    assert.strictEqual(await call(statusBody(status)), 200);
    assert.deepStrictEqual(sets[0].data.snoozeRequestedCoachIds, []);
    assert.strictEqual(sets[0].data.snoozeRequestMessages, DELETE);
  }
  sets = [];
  assert.strictEqual(await call(statusBody('cutOff')), 200);
  assert.ok(!('snoozeRequestedCoachIds' in sets[0].data));
  assert.ok(!('snoozeRequestMessages' in sets[0].data));
});

test('message on a non-mercy type is ignored', async () => {
  assert.strictEqual(await call({ ...statusBody('allClear'), message: 'hi' }), 200);
  assert.ok(!JSON.stringify(sets).includes('hi'));
});

function coachStatus(status, cmd, { signCmd = true } = {}) {
  const ts = Math.floor(Date.now() / 1000);
  const signed = `u1|${status}|${ts}|coach|c1${signCmd ? `|${cmd}` : ''}`;
  return { uid: 'u1', status, ts, cause: 'coach', by: 'c1', cmd, sig: sign(signed) };
}

test('extension report acks the current command', async () => {
  lockCommand = { id: 'abc123', action: 'lock' };
  assert.strictEqual(await call(coachStatus('cutOff', 'abc123')), 200);
  assert.deepStrictEqual(acks, [{ lockAck: { id: 'abc123', action: 'lock', result: 'applied', at: 'ts' } }]);

  acks = [];
  lockCommand = { id: 'def456', action: 'unlock' };
  assert.strictEqual(await call(coachStatus('snoozedLock', 'def456')), 200);
  assert.strictEqual(acks[0].lockAck.action, 'unlock');
});

test('no ack for a superseded command or a mismatched action', async () => {
  lockCommand = { id: 'newer', action: 'unlock' };
  assert.strictEqual(await call(coachStatus('cutOff', 'older')), 200);
  lockCommand = { id: 'same', action: 'unlock' };
  assert.strictEqual(await call(coachStatus('cutOff', 'same')), 200);
  assert.deepStrictEqual(acks, []);
});

test('cmd is signed and validated', async () => {
  lockCommand = { id: 'abc123', action: 'lock' };
  assert.strictEqual(await call(coachStatus('cutOff', 'abc123', { signCmd: false })), 403);
  assert.strictEqual(await call(coachStatus('cutOff', 'bad cmd!')), 400);
  assert.deepStrictEqual(acks, []);
});

test('no cmd: no ack, status update unchanged', async () => {
  lockCommand = { id: 'abc123', action: 'lock' };
  const ts = Math.floor(Date.now() / 1000);
  const body = { uid: 'u1', status: 'cutOff', ts, cause: 'coach', by: 'c1', sig: sign(`u1|cutOff|${ts}|coach|c1`) };
  assert.strictEqual(await call(body), 200);
  assert.deepStrictEqual(acks, []);
  assert.strictEqual(sets[0].data.traineeStatus, 'cutOff');
});
