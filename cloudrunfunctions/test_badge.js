'use strict';

// Run: node --test cloudrunfunctions/test_badge.js
const test = require('node:test');
const assert = require('node:assert');
const { badgeCountFor, needsCoach, withBadgeData, withBadgeAps } = require('./badge');

// A tiny Firestore stand-in: `userSettings` answers the array-contains query, the request collections
// answer count() for the equality filters.
function fakeDb({ trainees = [], friendRequests = [], roleRequests = [] }) {
  const matches = (doc, filters) => filters.every(([f, op, v]) =>
    op === 'array-contains' ? (doc[f] || []).includes(v) : doc[f] === v);
  const query = (docs, filters) => ({
    where: (f, op, v) => query(docs, [...filters, [f, op, v]]),
    get: async () => {
      const hits = docs.filter((d) => matches(d, filters));
      return { forEach: (fn) => hits.forEach((d) => fn({ data: () => d })) };
    },
    count: () => ({ get: async () => ({ data: () => ({ count: docs.filter((d) => matches(d, filters)).length }) }) }),
  });
  const collections = { userSettings: trainees, friendships: friendRequests, roleRequests };
  return { collection: (name) => query(collections[name], []) };
}

test('counts trainees needing attention, asks for more time to this coach, and incoming requests', async () => {
  const db = fakeDb({
    trainees: [
      { coachIds: ['me'], traineeStatus: 'attentionNeeded' },
      { coachIds: ['me'], traineeStatus: 'cutOff', snoozeRequestedCoachIds: ['me'] },
      { coachIds: ['me'], traineeStatus: 'cutOff', snoozeRequestedCoachIds: ['other'] }, // asked someone else
      { coachIds: ['me'], traineeStatus: 'allClear' },
      { coachIds: ['other'], traineeStatus: 'attentionNeeded' }, // not my trainee
    ],
    friendRequests: [
      { requesteeId: 'me', status: 'pending' },
      { requesteeId: 'me', status: 'accepted' },
    ],
    roleRequests: [
      { targetId: 'me', status: 'pending' },
      { targetId: 'someoneElse', status: 'pending' },
    ],
  });
  assert.strictEqual(await badgeCountFor(db, 'me'), 4);
});

test('zero when nothing is waiting', async () => {
  assert.strictEqual(await badgeCountFor(fakeDb({}), 'me'), 0);
});

test('null (leave the icon alone) when counting fails or there is no uid', async () => {
  const broken = { collection: () => { throw new Error('boom'); } };
  assert.strictEqual(await badgeCountFor(broken, 'me'), null);
  assert.strictEqual(await badgeCountFor(fakeDb({}), ''), null);
});

test('a snoozed (extra time) trainee who asked earlier no longer counts', () => {
  assert.strictEqual(needsCoach({ traineeStatus: 'snoozedLock', snoozeRequestedCoachIds: ['me'] }, 'me'), false);
});

test('badge goes in data as a string and in aps as a number, and is omitted when null', () => {
  assert.deepStrictEqual(withBadgeData({ type: 'x' }, 3), { type: 'x', badge: '3' });
  assert.deepStrictEqual(withBadgeData({ type: 'x' }, null), { type: 'x' });
  assert.deepStrictEqual(withBadgeAps({ sound: 'default' }, 0), { sound: 'default', badge: 0 });
  assert.deepStrictEqual(withBadgeAps({ sound: 'default' }, null), { sound: 'default' });
});
