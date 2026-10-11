'use strict';

// Run: node --test cloudrunfunctions/test_role_requests_friends.js
// Covers the friend-request actions in role-requests.js against an in-memory Firestore. No
// node_modules in this repo, so the SDKs are stubbed at require time; nothing touches Firebase.

const test = require('node:test');
const assert = require('node:assert');
const Module = require('node:module');

let store; // { [collection]: Map<id, data> }
let sent;  // FCM messages
let nextId;

function coll(name) {
  if (!store[name]) store[name] = new Map();
  return store[name];
}

function snapOf(name, id) {
  const data = coll(name).get(id);
  return {
    id,
    exists: data !== undefined,
    ref: docRef(name, id),
    get: (f) => (data ? data[f] : undefined),
    data: () => data,
  };
}

function docRef(name, id) {
  return {
    _kind: 'doc',
    id,
    _name: name,
    get: async () => snapOf(name, id),
    set: async (data) => coll(name).set(id, { ...data }),
    update: async (data) => coll(name).set(id, { ...coll(name).get(id), ...data }),
    delete: async () => coll(name).delete(id),
  };
}

function query(name, filters) {
  return {
    _kind: 'query',
    where: (f, _op, v) => query(name, [...filters, [f, v]]),
    limit: () => query(name, filters),
    get: async () => runQuery(name, filters),
  };
}

function runQuery(name, filters) {
  const docs = [...coll(name).entries()]
    .filter(([, d]) => filters.every(([f, v]) => d[f] === v))
    .map(([id]) => snapOf(name, id));
  return { docs, empty: docs.length === 0, size: docs.length };
}

const fakeDb = {
  collection: (name) => ({
    doc: (id) => docRef(name, id ?? `auto${nextId++}`),
    where: (f, op, v) => query(name, [[f, v]]),
  }),
  runTransaction: async (fn) => {
    const writes = [];
    const tx = {
      get: async (refOrQuery) => refOrQuery.get(),
      set: (ref, data) => writes.push(() => ref.set(data)),
      update: (ref, data) => writes.push(() => ref.update(data)),
      delete: (ref) => writes.push(() => ref.delete()),
    };
    const out = await fn(tx);
    for (const w of writes) await w();
    return out;
  },
  batch: () => ({ set() {}, delete() {}, commit: async () => {} }),
};

const fakeAdmin = {
  apps: [1],
  initializeApp() {},
  firestore: Object.assign(() => fakeDb, {
    FieldValue: { serverTimestamp: () => 'ts', arrayUnion: (v) => v, arrayRemove: (v) => v },
  }),
  auth: () => ({ verifyIdToken: async (t) => ({ uid: t }) }), // token == uid in tests
  messaging: () => ({ send: async (m) => sent.push(m) }),
};

let handler;
const origLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === '@google-cloud/functions-framework') return { http: (_n, fn) => (handler = fn) };
  if (request === 'firebase-admin') return fakeAdmin;
  return origLoad.call(this, request, ...rest);
};
require('./role-requests.js');
Module._load = origLoad;

async function call(asUid, body) {
  const res = {
    statusCode: 0,
    body: null,
    status(c) { this.statusCode = c; return this; },
    set() { return this; },
    send(b) { this.body = b ? JSON.parse(b) : b; return this; },
  };
  await handler({ method: 'POST', body, get: () => `Bearer ${asUid}` }, res);
  return res;
}

function reset() {
  store = {};
  sent = [];
  nextId = 1;
  coll('users').set('alice', { name: 'Alice Smith', fcmToken: 'tok-alice' });
  coll('users').set('bob', { name: 'Bob Jones', fcmToken: 'tok-bob' });
}

const friendships = () => [...coll('friendships').values()];

test('send creates a pending doc with an id field and pushes the requestee', async () => {
  reset();
  const res = await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.status, 'pending');
  const [doc] = friendships();
  assert.deepEqual(
    { id: doc.id, requesterId: doc.requesterId, requesteeId: doc.requesteeId, status: doc.status },
    { id: res.body.id, requesterId: 'alice', requesteeId: 'bob', status: 'pending' }
  );
  assert.equal(sent.length, 1);
  assert.equal(sent[0].token, 'tok-bob');
  assert.equal(sent[0].data.type, 'friendRequestReceived');
  assert.equal(sent[0].apns.payload.aps.alert.body, 'Alice sent you a friend request.');
});

test('sending twice is idempotent: one doc, one push', async () => {
  reset();
  await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  const again = await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  assert.equal(again.statusCode, 200);
  assert.equal(friendships().length, 1);
  assert.equal(sent.length, 1);
});

test('sending back to someone who already asked accepts their request', async () => {
  reset();
  await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  const res = await call('bob', { action: 'sendFriendRequest', targetId: 'alice' });
  assert.equal(res.body.status, 'accepted');
  assert.equal(friendships().length, 1);
  assert.equal(friendships()[0].status, 'accepted');
  assert.equal(sent.at(-1).token, 'tok-alice');
  assert.equal(sent.at(-1).data.type, 'friendRequestAccepted');
});

test('send rejects self, unknown users and existing friends', async () => {
  reset();
  assert.equal((await call('alice', { action: 'sendFriendRequest', targetId: 'alice' })).statusCode, 400);
  assert.equal((await call('alice', { action: 'sendFriendRequest', targetId: 'ghost' })).statusCode, 404);
  coll('friendships').set('f1', { requesterId: 'bob', requesteeId: 'alice', status: 'accepted' });
  assert.equal((await call('alice', { action: 'sendFriendRequest', targetId: 'bob' })).statusCode, 409);
});

test('only the requestee can accept; accept pushes the requester once', async () => {
  reset();
  const { body } = await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  assert.equal((await call('alice', { action: 'acceptFriendRequest', id: body.id })).statusCode, 403);
  assert.equal((await call('bob', { action: 'acceptFriendRequest', id: body.id })).statusCode, 200);
  assert.equal(friendships()[0].status, 'accepted');
  assert.equal(sent.at(-1).data.type, 'friendRequestAccepted');
  const pushes = sent.length;
  assert.equal((await call('bob', { action: 'acceptFriendRequest', id: body.id })).statusCode, 200);
  assert.equal(sent.length, pushes, 'double accept sends no second push');
});

test('decline is requestee-only, cancel is requester-only; both delete and tolerate repeats', async () => {
  reset();
  let { body } = await call('alice', { action: 'sendFriendRequest', targetId: 'bob' });
  assert.equal((await call('alice', { action: 'declineFriendRequest', id: body.id })).statusCode, 403);
  assert.equal((await call('bob', { action: 'declineFriendRequest', id: body.id })).statusCode, 200);
  assert.equal(friendships().length, 0);
  assert.equal((await call('bob', { action: 'declineFriendRequest', id: body.id })).statusCode, 200);

  ({ body } = await call('alice', { action: 'sendFriendRequest', targetId: 'bob' }));
  assert.equal((await call('bob', { action: 'cancelFriendRequest', id: body.id })).statusCode, 403);
  assert.equal((await call('alice', { action: 'cancelFriendRequest', id: body.id })).statusCode, 200);
  assert.equal(friendships().length, 0);
});
