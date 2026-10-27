// Testy bezpečnostních pravidel Firestore proti lokálnímu emulátoru.
// Spuštění: cd backend-tests && npm install && npm test
import {readFileSync} from 'node:fs';
import {after, before, beforeEach, describe, it} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {arrayRemove, arrayUnion, deleteDoc, doc, getDoc, getDocs, collection, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';

const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
let env;

const A = {uid: 'uidA', email: 'a@firma.cz'};
const B = {uid: 'uidB', email: 'b@firma.cz'};
const OUTSIDER = {uid: 'uidX', email: 'x@jinde.cz'};

const as = (u, verified = true) => env.authenticatedContext(u.uid, {email: u.email, email_verified: verified}).firestore();

const emptyReactions = () => ({thumbs_up: [], green: [], red: [], orange: []});
const textMessage = (senderId, extra = {}) => ({
  senderId, type: 'text', text: 'Ahoj', photo: null, reactions: emptyReactions(), createdAt: serverTimestamp(), ...extra,
});
const msgRef = (db, id = 'new1') => doc(db, 'rooms/obecne/messages', id);

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-jimmy', firestore: {rules}});
});
after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'allowlist/a@firma.cz'), {displayName: 'A'});
    await setDoc(doc(db, 'allowlist/b@firma.cz'), {displayName: 'B'});
    await setDoc(doc(db, 'rooms/obecne'), {name: 'Obecné', order: 0});
    await setDoc(doc(db, 'users/uidB'), {email: B.email, displayName: 'B'});
    await setDoc(doc(db, 'rooms/obecne/messages/m1'), {
      senderId: 'uidB', type: 'text', text: 'původní text', photo: null,
      reactions: {thumbs_up: ['uidB'], green: [], red: [], orange: []}, createdAt: new Date(),
    });
  });
});

describe('přístup', () => {
  it('nepřihlášený nic nečte', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'rooms/obecne')));
    await assertFails(getDocs(collection(db, 'rooms/obecne/messages')));
  });

  it('přihlášený mimo allowlist nic nečte ani nezapisuje', async () => {
    const db = as(OUTSIDER);
    await assertFails(getDoc(doc(db, 'rooms/obecne')));
    await assertFails(getDocs(collection(db, 'rooms/obecne/messages')));
    await assertFails(setDoc(doc(db, 'users/uidX'), {email: OUTSIDER.email, displayName: 'X'}));
    await assertFails(setDoc(msgRef(db), textMessage('uidX')));
  });

  it('neověřený e-mail neprojde ani s allowlistem', async () => {
    await assertFails(getDoc(doc(as(A, false), 'rooms/obecne')));
  });

  it('člen čte místnosti, zprávy i uživatele', async () => {
    const db = as(A);
    await assertSucceeds(getDoc(doc(db, 'rooms/obecne')));
    await assertSucceeds(getDocs(collection(db, 'rooms/obecne/messages')));
    await assertSucceeds(getDoc(doc(db, 'users/uidB')));
  });

  it('allowlist klient nepřečte ani nezmění', async () => {
    const db = as(A);
    await assertFails(getDoc(doc(db, 'allowlist/a@firma.cz')));
    await assertFails(setDoc(doc(db, 'allowlist/x@jinde.cz'), {displayName: 'X'}));
  });

  it('člen nemůže měnit místnosti', async () => {
    const db = as(A);
    await assertFails(setDoc(doc(db, 'rooms/nova'), {name: 'Nová', order: 9}));
    await assertFails(updateDoc(doc(db, 'rooms/obecne'), {name: 'Přejmenováno'}));
    await assertFails(deleteDoc(doc(db, 'rooms/obecne')));
  });
});

describe('uživatelé', () => {
  it('člen zapíše svůj profil se svým e-mailem', async () => {
    await assertSucceeds(setDoc(doc(as(A), 'users/uidA'), {email: A.email, displayName: 'A'}));
  });

  it('nelze zapsat cizí e-mail ani cizí uid', async () => {
    const db = as(A);
    await assertFails(setDoc(doc(db, 'users/uidA'), {email: B.email, displayName: 'A'}));
    await assertFails(setDoc(doc(db, 'users/uidB'), {email: B.email, displayName: 'podvrh'}));
  });

  it('člen si může uložit lastReadAt a fcmTokens', async () => {
    const db = as(A);
    await assertSucceeds(setDoc(doc(db, 'users/uidA'), {email: A.email, displayName: 'A'}));
    await assertSucceeds(setDoc(doc(db, 'users/uidA'), {lastReadAt: {obecne: serverTimestamp()}}, {merge: true}));
    await assertSucceeds(setDoc(doc(db, 'users/uidA'), {fcmTokens: arrayUnion('token')}, {merge: true}));
  });
});

describe('vytvoření zprávy', () => {
  it('platná textová zpráva projde', async () => {
    await assertSucceeds(setDoc(msgRef(as(A)), textMessage('uidA')));
  });

  it('platná fotka (s popiskem i bez) projde', async () => {
    const photo = {driveFileId: 'abc123', mimeType: 'image/jpeg', width: 800, height: 600};
    await assertSucceeds(setDoc(msgRef(as(A), 'p1'), textMessage('uidA', {type: 'photo', text: '', photo})));
    await assertSucceeds(setDoc(msgRef(as(A), 'p2'), textMessage('uidA', {type: 'photo', text: 'Střecha', photo})));
  });

  it('nelze psát jako někdo jiný', async () => {
    await assertFails(setDoc(msgRef(as(A)), textMessage('uidB')));
  });

  it('čas musí dát server', async () => {
    await assertFails(setDoc(msgRef(as(A)), textMessage('uidA', {createdAt: new Date('2020-01-01')})));
  });

  it('zakázané pole, předvyplněné reakce, špatný typ', async () => {
    const db = as(A);
    await assertFails(setDoc(msgRef(db, 'e1'), textMessage('uidA', {isAdmin: true})));
    await assertFails(setDoc(msgRef(db, 'e2'), textMessage('uidA', {reactions: {...emptyReactions(), green: ['uidA']}})));
    await assertFails(setDoc(msgRef(db, 'e3'), textMessage('uidA', {type: 'video'})));
    await assertFails(setDoc(msgRef(db, 'e4'), textMessage('uidA', {reactions: {thumbs_up: []}})));
  });

  it('text: prázdný ne, přes 4000 znaků ne, přesně 4000 ano', async () => {
    const db = as(A);
    await assertFails(setDoc(msgRef(db, 't0'), textMessage('uidA', {text: ''})));
    await assertFails(setDoc(msgRef(db, 't1'), textMessage('uidA', {text: 'x'.repeat(4001)})));
    await assertSucceeds(setDoc(msgRef(db, 't2'), textMessage('uidA', {text: 'x'.repeat(4000)})));
  });

  it('fotka bez photo nebo text s photo neprojde', async () => {
    const db = as(A);
    await assertFails(setDoc(msgRef(db, 'f1'), textMessage('uidA', {type: 'photo', text: '', photo: null})));
    await assertFails(setDoc(msgRef(db, 'f2'), textMessage('uidA', {type: 'text', photo: {driveFileId: 'x'}})));
    await assertFails(setDoc(msgRef(db, 'f3'), textMessage('uidA', {type: 'photo', text: '', photo: {mimeType: 'image/png'}})));
  });
});

describe('reakce', () => {
  const m1 = (db) => doc(db, 'rooms/obecne/messages/m1');

  it('přidat sebe do kterékoli ze čtyř reakcí', async () => {
    const db = as(A);
    for (const key of ['thumbs_up', 'green', 'red', 'orange']) {
      await assertSucceeds(updateDoc(m1(db), {[`reactions.${key}`]: arrayUnion('uidA')}));
    }
  });

  it('odebrat sebe', async () => {
    const db = as(B); // B už má thumbs_up
    await assertSucceeds(updateDoc(m1(db), {'reactions.thumbs_up': arrayRemove('uidB')}));
  });

  it('nelze přidat někoho jiného ani odebrat cizí reakci', async () => {
    const db = as(A);
    await assertFails(updateDoc(m1(db), {'reactions.green': arrayUnion('uidB')}));
    await assertFails(updateDoc(m1(db), {'reactions.thumbs_up': arrayRemove('uidB')}));
  });

  it('nelze přidat pátou reakci ani změnit tvar pole', async () => {
    const db = as(A);
    await assertFails(updateDoc(m1(db), {'reactions.heart': arrayUnion('uidA')}));
    await assertFails(updateDoc(m1(db), {reactions: {thumbs_up: ['uidA']}}));
  });

  it('s reakcí nelze zároveň měnit jiné pole', async () => {
    const db = as(A);
    await assertFails(updateDoc(m1(db), {'reactions.green': arrayUnion('uidA'), text: 'přepsáno'}));
    await assertFails(updateDoc(m1(db), {text: 'přepsáno'}));
    await assertFails(updateDoc(m1(db), {senderId: 'uidA'}));
  });

  it('exkluzivní varianta: přidat jednu a odebrat své ostatní v jednom zápisu', async () => {
    const db = as(B);
    await assertSucceeds(updateDoc(m1(db), {
      'reactions.red': arrayUnion('uidB'),
      'reactions.thumbs_up': arrayRemove('uidB'),
    }));
  });

  it('člen mimo allowlist nereaguje a zprávy nikdo nemaže', async () => {
    await assertFails(updateDoc(m1(as(OUTSIDER)), {'reactions.green': arrayUnion('uidX')}));
    await assertFails(deleteDoc(m1(as(B))));
  });
});
