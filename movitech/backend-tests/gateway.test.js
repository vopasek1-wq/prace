// Testy brány pro fotky (gateway/Code.gs). Členství rozhodují SKUTEČNÁ pravidla Firestore v emulátoru.
// Spuštění: cd backend-tests && npm test
import {readFileSync} from 'node:fs';
import {after, before, beforeEach, describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc} from 'firebase/firestore';
import {loadGateway, makeJwt} from './gateway-harness.mjs';

const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
let env;

const A = {uid: 'uidA', email: 'a@gmail.com'};
const OUTSIDER = {uid: 'uidX', email: 'x@gmail.com'};
const tokenOf = (u, opts = {}) => makeJwt({...u, ...opts});
const png = Buffer.from('89504e470d0a1a0a0000', 'hex');
const b64 = (buf) => Buffer.from(buf).toString('base64');

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-jimmy', firestore: {rules}});
});
after(async () => { await env.cleanup(); });

let gw;
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'allowlist/a@gmail.com'), {displayName: 'A'});
    await setDoc(doc(db, 'rooms/movitech'), {name: 'Movitech', order: 0});
  });
  gw = loadGateway({emulatorHost: EMULATOR});
  gw.configure();
});

describe('nastavení', () => {
  it('doGet odpoví, že brána žije', () => {
    assert.deepEqual(gw.doGet(), {ok: true, service: 'jimmy-photo-gateway'});
  });

  it('setup založí složku "Movitech – fotky" a je opakovatelný', () => {
    const id = gw.state.props.get('FOLDER_ID');
    assert.equal(gw.state.folders.get(id).name, 'Movitech – fotky');
    gw.run('setup');
    assert.equal(gw.state.folders.size, 1);
  });

  it('bez FIREBASE_PROJECT_ID setup selže s návodem', () => {
    const fresh = loadGateway({emulatorHost: EMULATOR});
    assert.throws(() => fresh.run('setup'), /FIREBASE_PROJECT_ID/);
  });

  it('bez složky vrací not-configured', () => {
    const fresh = loadGateway({emulatorHost: EMULATOR});
    fresh.configure({withFolder: false});
    const res = fresh.call({idToken: tokenOf(A), action: 'list'});
    assert.deepEqual(res, {ok: false, error: 'not-configured'});
  });
});

describe('oprávnění (pravidla Firestore)', () => {
  it('bez tokenu nebo s rozbitým tokenem: unauthorized', () => {
    assert.equal(gw.call({action: 'list'}).error, 'unauthorized');
    assert.equal(gw.call({action: 'list', idToken: 'neco'}).error, 'unauthorized');
    assert.equal(gw.call('to není json').error, 'server-error');
    assert.match(gw.state.errors[0], /SyntaxError/); // chyba se zapíše do logu skriptu, klientovi se nic neprozradí
  });

  it('člen z allowlistu projde', () => {
    assert.equal(gw.call({idToken: tokenOf(A), action: 'list'}).ok, true);
  });

  it('přihlášený mimo allowlist: forbidden', () => {
    assert.deepEqual(gw.call({idToken: tokenOf(OUTSIDER), action: 'list'}), {ok: false, error: 'forbidden'});
  });

  it('člen s neověřeným e-mailem: forbidden', () => {
    assert.equal(gw.call({idToken: tokenOf(A, {verified: false}), action: 'list'}).error, 'forbidden');
  });

  it('ověření členství se na 5 minut cachuje (jen jedno čtení Firestore)', () => {
    const token = tokenOf(A);
    gw.call({idToken: token, action: 'list'});
    gw.call({idToken: token, action: 'list'});
    gw.call({idToken: token, action: 'list'});
    assert.equal(gw.state.firestoreCalls, 1);
  });

  it('neznámá akce: bad-request', () => {
    assert.equal(gw.call({idToken: tokenOf(A), action: 'smazat-vse'}).error, 'bad-request');
  });
});

describe('upload', () => {
  const upload = (extra = {}) => gw.call({idToken: tokenOf(A), action: 'upload', mimeType: 'image/png', data: b64(png), ...extra});

  it('uloží soubor do složky a poznamená, kdo ho nahrál', () => {
    const res = upload();
    assert.equal(res.ok, true);
    const file = gw.state.files.get(res.fileId);
    assert.deepEqual(file.bytes, png);
    assert.deepEqual(file.parents, [gw.state.props.get('FOLDER_ID')]);
    assert.equal(file.mime, 'image/png');
    assert.match(file.name, /^jimmy_\d+\.png$/);
    assert.equal(file.description, 'Nahrál: a@gmail.com');
  });

  it('jpeg dostane příponu jpg', () => {
    const res = upload({mimeType: 'image/jpeg'});
    assert.match(gw.state.files.get(res.fileId).name, /\.jpg$/);
  });

  it('odmítne jiný typ než obrázek, prázdná data a příliš velký soubor', () => {
    assert.equal(upload({mimeType: 'application/pdf'}).error, 'unsupported-type');
    assert.equal(upload({mimeType: 'text/html'}).error, 'unsupported-type');
    assert.equal(upload({data: ''}).error, 'bad-request');
    assert.equal(upload({data: 'A'.repeat(11 * 1024 * 1024 + 1)}).error, 'too-large');
    assert.equal(gw.state.files.size, 0);
  });

  it('člen mimo allowlist nic nenahraje', () => {
    const res = gw.call({idToken: tokenOf(OUTSIDER), action: 'upload', mimeType: 'image/png', data: b64(png)});
    assert.equal(res.error, 'forbidden');
    assert.equal(gw.state.files.size, 0);
  });
});

describe('get', () => {
  const get = (fileId, variant) => gw.call({idToken: tokenOf(A), action: 'get', fileId, variant});

  it('náhled je zmenšený (s1080), originál je původní soubor', () => {
    const {fileId} = gw.call({idToken: tokenOf(A), action: 'upload', mimeType: 'image/png', data: b64(png)});
    const preview = get(fileId, 'preview');
    assert.equal(preview.ok, true);
    assert.equal(Buffer.from(preview.data, 'base64').toString(), `THUMB-${fileId}-1080`);
    assert.equal(preview.mimeType, 'image/jpeg');
    const full = get(fileId, 'full');
    assert.deepEqual(Buffer.from(full.data, 'base64'), png);
    assert.equal(full.mimeType, 'image/png');
  });

  it('velký originál (nad 6 MB) se pošle jako náhled s2048', () => {
    const id = gw.addFile({name: 'velka.jpg', bytes: Buffer.from('x'), size: 12 * 1024 * 1024});
    assert.equal(Buffer.from(get(id, 'full').data, 'base64').toString(), `THUMB-${id}-2048`);
  });

  it('soubor mimo složku s fotkami se nevydá', () => {
    const outside = gw.addFile({name: 'soukrome.jpg', bytes: Buffer.from('tajne'), parents: ['jina-slozka-123']});
    assert.deepEqual(get(outside, 'full'), {ok: false, error: 'not-found'});
  });

  it('špatné nebo neexistující ID', () => {
    assert.equal(get('../../etc/passwd', 'full').error, 'bad-request');
    assert.equal(get('x', 'full').error, 'bad-request');
    assert.equal(get('NeexistujiciId1234567', 'full').error, 'not-found');
  });
});

describe('list (soubory vložené do složky na Disku ručně i z aplikace)', () => {
  it('řadí od nejnovější, vrací náhledy a stránkuje', () => {
    const ids = [];
    for (let i = 1; i <= 5; i++) ids.push(gw.addFile({name: `foto${i}.jpg`, bytes: Buffer.from(`f${i}`), dims: {width: 400 + i, height: 300}}));
    gw.addFile({name: 'dokument.pdf', mime: 'application/pdf', bytes: Buffer.from('pdf')});

    const first = gw.call({idToken: tokenOf(A), action: 'list', limit: 2});
    assert.equal(first.ok, true);
    assert.deepEqual(first.items.map((i) => i.name), ['foto5.jpg', 'foto4.jpg']);
    assert.equal(first.items[0].width, 405);
    assert.equal(Buffer.from(first.items[0].thumb, 'base64').toString(), `THUMB-${ids[4]}-256`);
    assert.equal(first.next, '2');

    const second = gw.call({idToken: tokenOf(A), action: 'list', limit: 2, pageToken: first.next});
    assert.deepEqual(second.items.map((i) => i.name), ['foto3.jpg', 'foto2.jpg']);
    const third = gw.call({idToken: tokenOf(A), action: 'list', limit: 2, pageToken: second.next});
    assert.deepEqual(third.items.map((i) => i.name), ['foto1.jpg']);
    assert.equal(third.next, null);
  });

  it('prázdná složka vrátí prázdný seznam', () => {
    assert.deepEqual(gw.call({idToken: tokenOf(A), action: 'list'}), {ok: true, items: [], next: null});
  });
});

describe('přepis textu z fotky (OCR přes Disk)', () => {
  const textPhoto = (text) => Buffer.from(`TEXT:${text}`);
  const upload = (bytes, extra = {}) => gw.call({idToken: tokenOf(A), action: 'upload', mimeType: 'image/png', data: b64(bytes), ...extra});
  const docs = () => [...gw.state.files.values()].filter((f) => f.mime === 'application/vnd.google-apps.document');

  it('upload s ocr:true vrátí vyčištěný text a smaže dočasný dokument', () => {
    const res = upload(textPhoto('Nakládací list č. 118\nTrasa: Praha – Brno'), {ocr: true});
    assert.equal(res.ok, true);
    assert.equal(res.text, 'Nakládací list č. 118\nTrasa: Praha – Brno'); // bez BOM a prázdných řádků navíc
    assert.equal(res.ocrFailed, false);
    assert.equal(gw.state.ocrTempDocsCreated, 1);
    assert.equal(docs().length, 0);
    assert.ok(gw.state.files.has(res.fileId)); // fotka zůstává
  });

  it('jazyk OCR je výchozí čeština a jde změnit ve vlastnostech skriptu', () => {
    upload(textPhoto('a'), {ocr: true});
    assert.match(gw.state.ocrCopyUrls[0], /ocrLanguage=cs/);
    gw.state.props.set('OCR_LANGUAGE', 'en');
    upload(textPhoto('b'), {ocr: true});
    assert.match(gw.state.ocrCopyUrls[1], /ocrLanguage=en/);
  });

  it('fotka bez textu dá prázdný text; bez ocr se OCR vůbec nespustí', () => {
    assert.equal(upload(Buffer.from('jen obrazek'), {ocr: true}).text, '');
    const before = gw.state.ocrCopyUrls.length;
    const plain = upload(textPhoto('Text, který se nemá číst'));
    assert.equal(plain.text, '');
    assert.equal(plain.ocrFailed, false);
    assert.equal(gw.state.ocrCopyUrls.length, before);
  });

  it('když OCR selže, fotka se přesto uloží a jen se to oznámí', () => {
    gw.state.ocrFail = true;
    const res = upload(textPhoto('x'), {ocr: true});
    assert.equal(res.ok, true);
    assert.equal(res.ocrFailed, true);
    assert.equal(res.text, '');
    assert.ok(gw.state.files.has(res.fileId));
    assert.match(gw.state.errors.at(-1), /OCR selhalo/);
  });

  it('dlouhý text se ořízne, aby se vešel do zprávy', () => {
    const res = upload(textPhoto('slovo '.repeat(2000)), {ocr: true});
    assert.ok(res.text.length <= 3501);
    assert.ok(res.text.endsWith('…'));
  });

  it('akce ocr přepíše fotku, která už ve složce je (např. vložená ručně)', () => {
    const id = gw.addFile({name: 'rucne.jpg', bytes: textPhoto('Dodací list 77')});
    assert.deepEqual(gw.call({idToken: tokenOf(A), action: 'ocr', fileId: id}), {ok: true, text: 'Dodací list 77'});
    assert.equal(docs().length, 0);
  });

  it('akce ocr: cizí soubor, špatné ID a selhání', () => {
    const outside = gw.addFile({name: 'soukrome.jpg', bytes: textPhoto('tajne'), parents: ['jina-slozka-123']});
    assert.equal(gw.call({idToken: tokenOf(A), action: 'ocr', fileId: outside}).error, 'not-found');
    assert.equal(gw.call({idToken: tokenOf(A), action: 'ocr', fileId: '../x'}).error, 'bad-request');
    const id = gw.addFile({name: 'foto.jpg', bytes: textPhoto('x')});
    gw.state.ocrFail = true;
    assert.deepEqual(gw.call({idToken: tokenOf(A), action: 'ocr', fileId: id}), {ok: false, error: 'ocr-failed'});
  });

  it('člen mimo allowlist OCR nespustí', () => {
    const id = gw.addFile({name: 'foto.jpg', bytes: textPhoto('x')});
    assert.equal(gw.call({idToken: tokenOf(OUTSIDER), action: 'ocr', fileId: id}).error, 'forbidden');
    assert.equal(gw.state.ocrCopyUrls.length, 0);
  });
});
