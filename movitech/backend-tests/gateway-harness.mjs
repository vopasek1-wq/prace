// Spustí gateway/Code.gs v Node.js s náhradami (mocky) služeb Apps Script a Disku.
// Slouží k testům logiky brány bez nasazení do Googlu.
import vm from 'node:vm';
import crypto from 'node:crypto';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';

const CODE = new URL('../gateway/Code.gs', import.meta.url);
const SCRIPT_TOKEN = 'script-oauth-token';

const signed = (buf) => Array.from(buf, (b) => (b > 127 ? b - 256 : b));
const unsigned = (arr) => Buffer.from(Array.from(arr, (b) => b & 255));
const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');

/** Nepodepsaný JWT jako ID token (takové přijímá Firestore emulátor). */
export function makeJwt({uid, email, verified = true, projectId = 'demo-jimmy'}) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${projectId}`, aud: projectId, iat: now, exp: now + 3600,
    sub: uid, user_id: uid, email, email_verified: verified,
    firebase: {identities: {email: [email]}, sign_in_provider: 'google.com'},
  };
  return `${b64url({alg: 'none', typ: 'JWT'})}.${b64url(payload)}.`;
}

function response(code, body, headers = {}) {
  const buf = Buffer.isBuffer(body) ? body : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
  return {
    getResponseCode: () => code,
    getContentText: () => buf.toString('utf8'),
    getContent: () => signed(buf),
    getHeaders: () => headers,
  };
}

/**
 * @param {object} opts
 * @param {string} [opts.projectId]
 * @param {string} [opts.emulatorHost]  např. "127.0.0.1:8080" – členství pak rozhodují skutečná pravidla Firestore
 * @param {string[]} [opts.allowedEmails]  bez emulátoru: povolené e-maily (simulace pravidel)
 */
export function loadGateway({projectId = 'demo-jimmy', emulatorHost, allowedEmails = []} = {}) {
  const state = {files: new Map(), props: new Map(), cache: new Map(), firestoreCalls: 0, folders: new Map(), seq: 0, errors: [], ocrFail: false, ocrCopyUrls: [], ocrTempDocsCreated: 0};
  const newId = () => `F${(++state.seq).toString().padStart(3, '0')}${crypto.randomBytes(8).toString('hex')}`;

  const membership = (url, headers) => {
    state.firestoreCalls++;
    const auth = headers.Authorization || '';
    if (emulatorHost) {
      const target = url.replace('https://firestore.googleapis.com', `http://${emulatorHost}`);
      const code = execFileSync('curl', ['-s', '--globoff', '-o', '/dev/null', '-w', '%{http_code}', '-H', `Authorization: ${auth}`, target]).toString();
      return response(Number(code), '{}');
    }
    try {
      const payload = JSON.parse(Buffer.from(auth.replace('Bearer ', '').split('.')[1], 'base64url').toString());
      return allowedEmails.includes(payload.email) ? response(200, {}) : response(403, {});
    } catch {
      return response(401, {});
    }
  };

  const driveFetch = (url, headers, opts = {}) => {
    if (headers.Authorization !== `Bearer ${SCRIPT_TOKEN}`) return response(401, {error: 'bad token'});
    const u = new URL(url);
    if (u.hostname === 'thumb.local') {
      const m = u.pathname.match(/^\/(.+?)=s(\d+)/);
      return state.files.has(m[1]) ? response(200, Buffer.from(`THUMB-${m[1]}-${m[2]}`), {'Content-Type': 'image/jpeg'}) : response(404, {});
    }
    const path = u.pathname.replace('/drive/v3', '');
    if (path === '/files') {
      const q = u.searchParams.get('q');
      const folder = q.match(/'([^']+)' in parents/)[1];
      const sorted = [...state.files.values()].filter((f) => f.parents.includes(folder) && f.mime.startsWith('image/')).sort((a, b) => b.created - a.created);
      const start = Number(u.searchParams.get('pageToken') || 0);
      const size = Number(u.searchParams.get('pageSize'));
      const slice = sorted.slice(start, start + size);
      return response(200, {
        nextPageToken: start + size < sorted.length ? String(start + size) : undefined,
        files: slice.map((f) => ({id: f.id, name: f.name, mimeType: f.mime, thumbnailLink: `https://thumb.local/${f.id}=s220`, imageMediaMetadata: f.dims})),
      });
    }
    // --- OCR: kopie obrázku jako Google Dokument, export textu, smazání
    const copyMatch = path.match(/^\/files\/([^/]+)\/copy$/);
    if (copyMatch && (opts.method || '').toLowerCase() === 'post') {
      state.ocrCopyUrls.push(url);
      const source = state.files.get(copyMatch[1]);
      if (!source) return response(404, {});
      if (state.ocrFail) return response(500, {error: 'boom'});
      const request = JSON.parse(opts.payload);
      if (request.mimeType !== 'application/vnd.google-apps.document') return response(400, {});
      const docId = newId();
      const asText = source.bytes.toString('utf8');
      state.files.set(docId, {id: docId, name: request.name, mime: request.mimeType, bytes: Buffer.alloc(0), parents: source.parents, created: ++state.seq, text: asText.startsWith('TEXT:') ? asText.slice(5) : ''});
      state.ocrTempDocsCreated++;
      return response(200, {id: docId});
    }
    const exportMatch = path.match(/^\/files\/([^/]+)\/export$/);
    if (exportMatch) {
      const doc = state.files.get(exportMatch[1]);
      if (!doc || doc.mime !== 'application/vnd.google-apps.document' || u.searchParams.get('mimeType') !== 'text/plain') return response(404, {});
      // skutečný export bývá s BOM a nadbytečnými prázdnými řádky
      return response(200, Buffer.from(`\uFEFF${doc.text}\r\n\r\n\r\n\r\n`), {'Content-Type': 'text/plain'});
    }
    const m = path.match(/^\/files\/([^/]+)$/);
    if (m && (opts.method || '').toLowerCase() === 'delete') {
      return state.files.delete(m[1]) ? response(204, '') : response(404, {});
    }
    const file = m && state.files.get(m[1]);
    if (!file) return response(404, {});
    if (u.searchParams.get('alt') === 'media') return response(200, file.bytes, {'Content-Type': file.mime});
    return response(200, {id: file.id, mimeType: file.mime, size: String(file.size ?? file.bytes.length), parents: file.parents, thumbnailLink: `https://thumb.local/${file.id}=s220`});
  };

  const fetch = (url, opts = {}) => {
    const headers = opts.headers || {};
    if (url.startsWith('https://firestore.googleapis.com/')) return membership(url, headers);
    return driveFetch(url, headers, opts);
  };

  const makeBlob = (bytes, mime, name) => ({
    getBytes: () => bytes, getContentType: () => mime, getName: () => name,
    getDataAsString: () => unsigned(bytes).toString('utf8'),
  });

  const sandbox = {
    console: {error: (...args) => state.errors.push(args.join(' ')), log: () => {}},
    Logger: {log: () => {}},
    ScriptApp: {getOAuthToken: () => SCRIPT_TOKEN},
    PropertiesService: {getScriptProperties: () => ({getProperty: (k) => state.props.get(k) ?? null, setProperty: (k, v) => state.props.set(k, v)})},
    CacheService: {getScriptCache: () => ({get: (k) => state.cache.get(k) ?? null, put: (k, v) => state.cache.set(k, v)})},
    ContentService: {MimeType: {JSON: 'JSON'}, createTextOutput: (s) => ({getContent: () => s, setMimeType() { return this; }})},
    UrlFetchApp: {fetch, fetchAll: (reqs) => reqs.map((r) => fetch(r.url, r))},
    Utilities: {
      DigestAlgorithm: {SHA_256: 'sha256'},
      computeDigest: (alg, s) => signed(crypto.createHash(alg).update(s).digest()),
      base64Encode: (bytes) => unsigned(bytes).toString('base64'),
      base64EncodeWebSafe: (bytes) => unsigned(bytes).toString('base64url'),
      base64Decode: (s) => signed(Buffer.from(s, 'base64')),
      base64DecodeWebSafe: (s) => signed(Buffer.from(s, 'base64url')),
      newBlob: makeBlob,
    },
    DriveApp: {
      createFolder: (name) => {
        const id = newId();
        state.folders.set(id, {id, name});
        return {getId: () => id, getUrl: () => `https://drive.google.com/drive/folders/${id}`};
      },
      getFolderById: (id) => {
        if (!state.folders.has(id)) throw new Error('Folder not found');
        return {
          getUrl: () => `https://drive.google.com/drive/folders/${id}`,
          createFile: (blob) => {
            const fid = newId();
            const file = {id: fid, name: blob.getName(), mime: blob.getContentType(), bytes: unsigned(blob.getBytes()), parents: [id], created: ++state.seq, description: ''};
            state.files.set(fid, file);
            return {getId: () => fid, setDescription: (d) => { file.description = d; }};
          },
        };
      },
    },
  };

  const ctx = vm.createContext(sandbox);
  vm.runInContext(readFileSync(CODE, 'utf8'), ctx, {filename: 'Code.gs'});

  return {
    state,
    configure({withFolder = true} = {}) {
      state.props.set('FIREBASE_PROJECT_ID', projectId);
      if (withFolder) ctx.setup();
      return state.props.get('FOLDER_ID');
    },
    run: (fn) => ctx[fn](),
    doGet: () => JSON.parse(ctx.doGet().getContent()),
    /** Zavolá doPost se zadaným tělem a vrátí rozparsovanou odpověď. */
    call(body) {
      const raw = typeof body === 'string' ? body : JSON.stringify(body);
      return JSON.parse(ctx.doPost({postData: {contents: raw}}).getContent());
    },
    /** Přidá soubor přímo na "Disk" (jako by ho tam vložil majitel ručně). */
    addFile({name, mime = 'image/jpeg', bytes, parents, dims = {width: 800, height: 600}, size}) {
      const id = newId();
      state.files.set(id, {id, name, mime, bytes: Buffer.from(bytes), parents: parents ?? [state.props.get('FOLDER_ID')], created: ++state.seq, dims, size});
      return id;
    },
  };
}
