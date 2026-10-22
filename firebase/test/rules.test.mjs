import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, query, where, orderBy,
  limit, getDocs, runTransaction, serverTimestamp, deleteField, Timestamp,
} from 'firebase/firestore';

let env;
const ALICE = '5551230001', BOB = '5551230002', CAROL = '5551230003';
const now = Timestamp.now();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ppta',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

// Real shapes: User.swift, UserSettings.encode, Friendship.swift:16, role-requests service.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (id, name, phone) => setDoc(doc(db, 'users', id), {
      id, name, email: `${id}@example.com`, phoneNumber: phone, fcmToken: `tok-${id}`,
    });
    await user('alice', 'Alice', ALICE);
    await user('bob', 'Bob', BOB);
    await user('carol', 'Carol', CAROL);
    await setDoc(doc(db, 'userSettings', 'alice'), {
      applications: [], thresholdHour: 2, thresholdMinutes: 0, selectedMode: 'strict',
      onboardingCompleted: true, peerCoaches: [], coaches: [], trainees: [],
      coachIds: ['bob'], traineeIds: [], isTracking: true, traineeStatus: 'cutOff',
      lockedByUID: 'bob', lockedByName: 'Bob', snoozeRequestedCoachIds: [],
      monitoredAppNames: [], monitoredAppStats: [],
      lockCommand: { id: 'c1', action: 'lock', by: 'bob', byName: 'Bob', at: now, message: 'phone down' },
      lockAck: { id: 'c1', action: 'lock', result: 'applied', at: now },
      snoozeRequestMessages: { bob: '5 more' },
    });
    await setDoc(doc(db, 'userSettings', 'bob'), { traineeIds: ['alice'], coachIds: [] });
    const fr = (id, a, b, status) => setDoc(doc(db, 'friendships', id), {
      id, requesterId: a, requesteeId: b, status, createdAt: now,
    });
    await fr('f1', 'alice', 'bob', 'accepted');
    await fr('f2', 'carol', 'alice', 'pending');
    await fr('f3', 'bob', 'carol', 'accepted');
    await setDoc(doc(db, 'roleRequests', 'r1'), {
      requesterId: 'alice', targetId: 'bob', role: 'trainee', status: 'accepted', createdAt: now,
    });
    await setDoc(doc(db, 'roleRequests', 'r2'), {
      requesterId: 'carol', targetId: 'alice', role: 'trainee', status: 'pending', createdAt: now,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('users: phone lookups only, no dump, self-only writes (U1-U8)', async () => {
  const users = (db) => collection(db, 'users');
  // U1 AuthViewModel.swift:72-90 via UserRespository.swift:36-45 (signed out)
  await assertSucceeds(getDocs(query(users(anon()), where('phoneNumber', '==', ALICE), limit(1))));
  // U2 FirestoreService.swift:112,174 (batch of 10 mixing formats and short numbers)
  const batch = [ALICE, '1' + BOB, '+1' + CAROL, '5551234', '15551234', '+15551234',
    '5559990001', '15559990002', '+15559990003', '555999'];
  await assertSucceeds(getDocs(query(users(as('eve')), where('phoneNumber', 'in', batch))));
  // U3 the leak: nothing that doesn't name the numbers (unauth and signed in)
  for (const db of [anon(), as('eve')]) {
    await assertFails(getDocs(users(db)));
    await assertFails(getDocs(query(users(db), where('phoneNumber', '>=', ''))));
    await assertFails(getDocs(query(users(db), orderBy('phoneNumber'), limit(50))));
    await assertFails(getDocs(query(users(db), where('name', '==', 'Alice'))));
  }
  // U4 FriendsViewModel.swift:51, FriendProfileViewModel.swift:142
  await assertSucceeds(getDoc(doc(as('eve'), 'users', 'alice')));
  // U5
  await assertFails(getDoc(doc(anon(), 'users', 'alice')));
  // U6 AuthViewModel.swift:151,159 (new user checks own missing doc, then creates it)
  const dan = as('dan');
  await assertSucceeds(getDoc(doc(dan, 'users', 'dan')));
  await assertSucceeds(setDoc(doc(dan, 'users', 'dan'), {
    id: 'dan', name: 'Dan', email: 'dan@example.com', phoneNumber: '5551230004', fcmToken: 'tok-dan',
  }));
  // U7 AuthViewModel.swift:364,374,390,416,550
  const a = as('alice');
  await assertSucceeds(updateDoc(doc(a, 'users', 'alice'), { fcmToken: 'new' }));
  await assertSucceeds(updateDoc(doc(a, 'users', 'alice'), { name: 'Alice B' }));
  await assertSucceeds(updateDoc(doc(a, 'users', 'alice'), { phoneNumber: '5551239999' }));
  await assertSucceeds(setDoc(doc(a, 'users', 'alice'), { fcmToken: 'merged' }, { merge: true }));
  await assertSucceeds(updateDoc(doc(a, 'users', 'alice'), { fcmToken: deleteField() }));
  // U8 other people's docs
  const eve = as('eve');
  await assertFails(updateDoc(doc(eve, 'users', 'alice'), { phoneNumber: '5550000000' }));
  await assertFails(setDoc(doc(eve, 'users', 'alice'), { fcmToken: 'x' }, { merge: true }));
  await assertFails(deleteDoc(doc(eve, 'users', 'alice')));
});

test('userSettings: lockCommand is server-only, everything else is the owner (S1-S9)', async () => {
  const a = as('alice');
  const ref = doc(a, 'userSettings', 'alice');
  // S1 FirestoreService.swift:17,65 (full Codable map, merge, existing lockCommand + lockAck)
  await assertSucceeds(setDoc(ref, {
    applications: [], thresholdHour: 3, thresholdMinutes: 30, selectedMode: 'strict',
    onboardingCompleted: true, peerCoaches: [], coaches: [], trainees: [],
    coachIds: ['bob'], traineeIds: [], isTracking: true, traineeStatus: 'cutOff',
    lockedByUID: 'bob', lockedByName: 'Bob', snoozeRequestedCoachIds: [],
    monitoredAppNames: [], monitoredAppStats: [],
  }, { merge: true }));
  const after = (await getDoc(ref)).data();
  assert(after.thresholdHour === 3 && after.lockCommand.id === 'c1' && after.lockCommand.action === 'lock');
  // S2 LockReconciler.swift:415-436
  await assertSucceeds(runTransaction(a, async (tx) => {
    await tx.get(ref);
    tx.update(ref, { lockAck: { id: 'c1', action: 'lock', result: 'applied', at: serverTimestamp() } });
  }));
  // S3 self-unlock forgery
  const forged = { id: 'c2', action: 'unlock', by: 'alice', byName: 'Alice', at: now };
  await assertFails(updateDoc(ref, { lockCommand: forged }));
  await assertFails(setDoc(ref, { lockCommand: forged }, { merge: true }));
  // S4 AuthViewModel.swift:125 via UserSettingsManager.swift:61
  const dan = as('dan');
  await assertSucceeds(getDoc(doc(dan, 'userSettings', 'dan')));
  await assertSucceeds(setDoc(doc(dan, 'userSettings', 'dan'),
    { thresholdHour: 2, selectedMode: 'strict', coachIds: [], traineeIds: [] }, { merge: true }));
  // S5 StatusCenterViewModel.swift:174, FriendProfileViewModel.swift:268
  for (const who of ['bob', 'carol']) {
    await assertSucceeds(getDoc(doc(as(who), 'userSettings', 'alice')));
    await assertSucceeds(getDoc(doc(as(who), 'userSettings', 'alice')));
  }
  // S6
  await assertFails(getDoc(doc(anon(), 'userSettings', 'alice')));
  // S7 cross-user forgery
  for (const who of ['eve', 'bob']) {
    const r = doc(as(who), 'userSettings', 'alice');
    await assertFails(setDoc(r, { lockCommand: forged }, { merge: true }));
    await assertFails(updateDoc(r, { traineeStatus: 'allClear' }));
    await assertFails(deleteDoc(r));
  }
  // S8
  const eve = as('eve');
  await assertFails(getDocs(collection(eve, 'userSettings')));
  await assertFails(getDocs(query(collection(eve, 'userSettings'), where('coachIds', 'array-contains', 'bob'))));
  // S9 287a1fd AuthViewModel.swift:453
  await assertSucceeds(deleteDoc(ref));
});

test('friendships: parties only, old-build shapes only (F1-F6)', async () => {
  const a = as('alice');
  const fs = (db) => collection(db, 'friendships');
  // F1 FriendshipRepository.swift:48-75, FriendsViewModel.swift:108,140
  await assertSucceeds(getDocs(query(fs(a), where('requesteeId', '==', 'alice'), where('status', '==', 'pending'))));
  await assertSucceeds(getDocs(query(fs(a), where('requesterId', '==', 'alice'), where('status', '==', 'accepted'))));
  // F2 FriendshipRepository.swift:106-121 (both directions)
  for (const [x, y] of [['alice', 'bob'], ['bob', 'alice']]) {
    await assertSucceeds(getDocs(query(fs(a), where('requesterId', '==', x),
      where('requesteeId', '==', y), where('status', '==', 'accepted'), limit(1))));
  }
  // F3
  const eve = as('eve');
  await assertFails(getDocs(query(fs(eve), where('requesteeId', '==', 'alice'))));
  await assertFails(getDocs(fs(eve)));
  await assertFails(getDoc(doc(eve, 'friendships', 'f3')));
  // F4 ab5476b FriendshipRepository.swift:22-38
  await assertSucceeds(setDoc(doc(a, 'friendships', 'f4'), {
    id: 'f4', requesterId: 'alice', requesteeId: 'eve', status: 'pending', createdAt: now,
  }));
  await assertSucceeds(updateDoc(doc(a, 'friendships', 'f2'), { status: 'accepted' }));
  // F5 (f2 is accepted now, so reset the pending shape for the requester-accepts case)
  await env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), 'friendships', 'f2'), { status: 'pending' }));
  const c = as('carol');
  await assertFails(setDoc(doc(a, 'friendships', 'f5'), {
    id: 'f5', requesterId: 'carol', requesteeId: 'alice', status: 'pending', createdAt: now,
  }));
  await assertFails(setDoc(doc(a, 'friendships', 'f6'), {
    id: 'f6', requesterId: 'alice', requesteeId: 'eve', status: 'accepted', createdAt: now,
  }));
  await assertFails(updateDoc(doc(c, 'friendships', 'f2'), { status: 'accepted' }));
  // F6 ab5476b FriendshipRepository.swift:40-42
  await assertSucceeds(deleteDoc(doc(c, 'friendships', 'f2')));
  await assertFails(deleteDoc(doc(eve, 'friendships', 'f1')));
});

test('roleRequests: read by parties, never written by clients (R1-R2)', async () => {
  const a = as('alice');
  const rr = (db) => collection(db, 'roleRequests');
  // R1 RoleRequestRepository.swift:18-34, RoleRequestsInboxViewModel.swift:69,94
  await assertSucceeds(getDocs(query(rr(a), where('targetId', '==', 'alice'),
    where('status', '==', 'pending'), orderBy('createdAt', 'desc'))));
  await assertSucceeds(getDocs(query(rr(a), where('requesterId', '==', 'alice'),
    where('status', '==', 'pending'), orderBy('createdAt', 'desc'))));
  // R2
  await assertFails(getDocs(query(rr(as('eve')), where('targetId', '==', 'alice'),
    where('status', '==', 'pending'), orderBy('createdAt', 'desc'))));
  await assertFails(addDoc(rr(a), { requesterId: 'alice', targetId: 'bob', role: 'coach', status: 'pending', createdAt: now }));
  await assertFails(updateDoc(doc(a, 'roleRequests', 'r2'), { status: 'accepted' }));
  await assertFails(deleteDoc(doc(a, 'roleRequests', 'r1')));
});

test('everything else is server-only (X1)', async () => {
  const a = as('alice');
  // X1 MercyRequestService.swift:21-57 (dead code) plus collections that never had a rule
  for (const [c, id] of [['lockRequests', 'alice'], ['unlockRequests', 'alice']]) {
    await assertFails(getDoc(doc(a, c, id)));
    await assertFails(setDoc(doc(a, c, id), { by: 'alice' }));
  }
  await assertFails(getDocs(query(collection(a, 'mercyRequests'), where('traineeId', '==', 'alice'),
    where('coachIds', 'array-contains', 'bob'), where('status', '==', 'pending'))));
  await assertFails(addDoc(collection(a, 'mercyRequests'), { traineeId: 'alice', status: 'pending' }));
  await assertFails(setDoc(doc(a, 'foo', 'x'), { a: 1 }));
  await assertFails(getDoc(doc(a, 'foo', 'x')));
});

function assert(cond) { if (!cond) throw new Error('assertion failed'); }
