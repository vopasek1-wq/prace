/**
 * Movitech – brána pro fotky na hlavním Google Disku.
 *
 * Skript běží pod HLAVNÍM Google účtem (tím, na jehož Disku se mají fotky ukládat).
 * Členové týmu mají jen přihlášení přes Google do aplikace; k Disku se nikdy nepřihlašují.
 * Aplikace posílá fotky sem a skript je ukládá do jedné složky "Movitech – fotky" na Disku hlavního účtu.
 *
 * Kdo smí volat: jen člen týmu. Skript to ověří tak, že přečte Firestore (kolekci rooms)
 * s ID tokenem volajícího – bezpečnostní pravidla Firestore pustí jen e-maily z `allowlist`.
 * Seznam povolených tedy existuje na jediném místě (Firestore).
 *
 * Nastavení a nasazení: docs/SPUSTENI.md, kapitola 5.3.
 *
 * Protokol (POST, tělo JSON jako text):
 *   {idToken, action: 'upload', mimeType, data: <base64>, ocr?}    -> {ok, fileId, text, ocrFailed}
 *   {idToken, action: 'ocr', fileId}                               -> {ok, text}     (přepis textu z fotky ve složce)
 *   {idToken, action: 'get', fileId, variant: 'preview'|'full'}    -> {ok, mimeType, data: <base64>}
 *   {idToken, action: 'list', pageToken?, limit?}                  -> {ok, items: [{id,name,mimeType,width,height,thumb}], next}
 * Chyba: {ok: false, error: 'unauthorized'|'forbidden'|'not-found'|'too-large'|'unsupported-type'|'bad-request'|'ocr-failed'|'not-configured'|'server-error'}
 */

const DRIVE_API = 'https://www.googleapis.com/drive/v3';
const MAX_UPLOAD_BASE64_CHARS = 11 * 1024 * 1024; // ≈ 8 MB fotky
const MAX_DIRECT_BYTES = 6 * 1024 * 1024; // větší originály se posílají jako zmenšený náhled
const ALLOWED_MIME = /^image\/(jpeg|png|webp|heic|heif|gif)$/;
const MEMBER_CACHE_SECONDS = 300;
const MAX_OCR_CHARS = 3500; // zpráva v chatu smí mít max. 4000 znaků

class GatewayError_ extends Error {
  constructor(code, detail) {
    super(detail || code);
    this.code = code;
  }
}

function props_() {
  return PropertiesService.getScriptProperties();
}

/** Spusťte JEDNOU ručně (tlačítko Spustit): založí složku na Disku hlavního účtu. */
function setup() {
  if (!props_().getProperty('FIREBASE_PROJECT_ID')) {
    throw new Error('Nejdřív přidejte Script property FIREBASE_PROJECT_ID (ID vašeho Firebase projektu).');
  }
  let folderId = props_().getProperty('FOLDER_ID');
  if (!folderId) {
    folderId = DriveApp.createFolder('Movitech – fotky').getId();
    props_().setProperty('FOLDER_ID', folderId);
  }
  Logger.log('Složka s fotkami: ' + DriveApp.getFolderById(folderId).getUrl());
}

function doGet() {
  return json_({ok: true, service: 'jimmy-photo-gateway'});
}

function doPost(e) {
  let result;
  try {
    const req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    const who = requireMember_(req.idToken);
    switch (req.action) {
      case 'upload':
        result = upload_(req, who);
        break;
      case 'get':
        result = get_(req);
        break;
      case 'ocr':
        result = ocr_(req);
        break;
      case 'list':
        result = list_(req);
        break;
      default:
        throw new GatewayError_('bad-request');
    }
  } catch (err) {
    const known = err instanceof GatewayError_;
    result = {ok: false, error: known ? err.code : 'server-error'};
    if (!known) console.error(err && err.stack ? err.stack : String(err));
  }
  return json_(result);
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

// ----------------------------------------------------------------- oprávnění

function requireMember_(idToken) {
  if (!idToken || typeof idToken !== 'string' || idToken.split('.').length !== 3) {
    throw new GatewayError_('unauthorized');
  }
  const cache = CacheService.getScriptCache();
  const key = 'member:' + Utilities.base64EncodeWebSafe(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, idToken));
  const cached = cache.get(key);
  if (cached) return JSON.parse(cached);

  const projectId = props_().getProperty('FIREBASE_PROJECT_ID');
  if (!projectId) throw new GatewayError_('not-configured', 'FIREBASE_PROJECT_ID');
  const url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(projectId) +
      '/databases/(default)/documents/rooms?pageSize=1';
  const res = UrlFetchApp.fetch(url, {headers: {Authorization: 'Bearer ' + idToken}, muteHttpExceptions: true});
  const code = res.getResponseCode();
  if (code === 401) throw new GatewayError_('unauthorized');
  if (code === 403) throw new GatewayError_('forbidden');
  if (code !== 200) throw new GatewayError_('server-error', 'firestore ' + code);

  const payload = decodeJwtPayload_(idToken);
  const who = {email: String(payload.email || ''), uid: String(payload.user_id || payload.sub || '')};
  cache.put(key, JSON.stringify(who), MEMBER_CACHE_SECONDS);
  return who;
}

function decodeJwtPayload_(jwt) {
  let part = jwt.split('.')[1];
  part += '='.repeat((4 - (part.length % 4)) % 4);
  return JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(part)).getDataAsString('UTF-8'));
}

// ----------------------------------------------------------------- akce

function folderId_() {
  const id = props_().getProperty('FOLDER_ID');
  if (!id) throw new GatewayError_('not-configured', 'FOLDER_ID – spusťte funkci setup');
  return id;
}

function upload_(req, who) {
  const mime = String(req.mimeType || '');
  if (!ALLOWED_MIME.test(mime)) throw new GatewayError_('unsupported-type');
  if (typeof req.data !== 'string' || req.data.length === 0) throw new GatewayError_('bad-request');
  if (req.data.length > MAX_UPLOAD_BASE64_CHARS) throw new GatewayError_('too-large');

  const extension = {'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'image/heif': 'heif', 'image/gif': 'gif'}[mime] || 'jpg';
  const blob = Utilities.newBlob(Utilities.base64Decode(req.data), mime, 'jimmy_' + Date.now() + '.' + extension);
  const file = DriveApp.getFolderById(folderId_()).createFile(blob);
  file.setDescription('Nahrál: ' + who.email);

  // Přepis textu z fotky nesmí zablokovat nahrání: když selže, fotka je uložená a jen se to oznámí.
  let text = '';
  let ocrFailed = false;
  if (req.ocr === true) {
    try {
      text = recognizeText_(file.getId());
    } catch (err) {
      ocrFailed = true;
      console.error('OCR selhalo: ' + (err && err.message ? err.message : err));
    }
  }
  return {ok: true, fileId: file.getId(), text: text, ocrFailed: ocrFailed};
}

/** Ověří ID a že soubor leží ve složce s fotkami, aby přes bránu nešlo vyžádat cokoli jiného z Disku. */
function fileInFolder_(req) {
  const id = String(req.fileId || '');
  if (!/^[A-Za-z0-9_-]{10,}$/.test(id)) throw new GatewayError_('bad-request');
  const meta = driveJson_('/files/' + id + '?fields=' + encodeURIComponent('id,mimeType,size,parents,thumbnailLink'));
  if (!meta.parents || meta.parents.indexOf(folderId_()) === -1) throw new GatewayError_('not-found');
  return meta;
}

function ocr_(req) {
  const meta = fileInFolder_(req);
  try {
    return {ok: true, text: recognizeText_(meta.id)};
  } catch (err) {
    console.error('OCR selhalo: ' + (err && err.message ? err.message : err));
    throw new GatewayError_('ocr-failed');
  }
}

/**
 * Přepis textu z fotky: Disk umí obrázek převést na Google Dokument a přitom provede OCR.
 * Dočasný dokument se hned smaže, výsledný text se vrátí.
 */
function recognizeText_(fileId) {
  const language = props_().getProperty('OCR_LANGUAGE') || 'cs';
  const headers = {Authorization: 'Bearer ' + ScriptApp.getOAuthToken()};
  const copy = UrlFetchApp.fetch(DRIVE_API + '/files/' + fileId + '/copy?fields=id&ocrLanguage=' + encodeURIComponent(language), {
    method: 'post',
    contentType: 'application/json',
    headers: headers,
    payload: JSON.stringify({name: 'ocr-' + Date.now(), mimeType: 'application/vnd.google-apps.document'}),
    muteHttpExceptions: true,
  });
  if (copy.getResponseCode() !== 200) throw new Error('OCR kopie: HTTP ' + copy.getResponseCode());
  const docId = JSON.parse(copy.getContentText()).id;
  try {
    const exported = UrlFetchApp.fetch(DRIVE_API + '/files/' + docId + '/export?mimeType=' + encodeURIComponent('text/plain'), {
      headers: headers,
      muteHttpExceptions: true,
    });
    if (exported.getResponseCode() !== 200) throw new Error('OCR export: HTTP ' + exported.getResponseCode());
    return cleanOcrText_(exported.getContentText());
  } finally {
    UrlFetchApp.fetch(DRIVE_API + '/files/' + docId, {method: 'delete', headers: headers, muteHttpExceptions: true});
  }
}

function cleanOcrText_(raw) {
  let text = String(raw || '')
      .replace(/^\uFEFF/, '')
      .replace(/\r\n?/g, '\n')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  if (text.length > MAX_OCR_CHARS) text = text.slice(0, MAX_OCR_CHARS).trimEnd() + '…';
  return text;
}

function get_(req) {
  const meta = fileInFolder_(req);
  const id = meta.id;

  const wantFull = req.variant === 'full';
  const tooBigForDirect = Number(meta.size || 0) > MAX_DIRECT_BYTES;
  let response = null;

  if (!wantFull || tooBigForDirect) {
    if (meta.thumbnailLink) {
      response = fetchAuthorized_(meta.thumbnailLink.replace(/=s\d+(-c)?$/, '=s' + (wantFull ? 2048 : 1080)));
    }
  }
  if (!response && !tooBigForDirect) {
    response = fetchAuthorized_(DRIVE_API + '/files/' + id + '?alt=media');
  }
  if (!response) throw new GatewayError_('too-large');

  const headers = response.getHeaders();
  const contentType = String(headers['Content-Type'] || headers['content-type'] || meta.mimeType || 'image/jpeg').split(';')[0];
  return {ok: true, mimeType: contentType, data: Utilities.base64Encode(response.getContent())};
}

function list_(req) {
  const limit = Math.max(1, Math.min(60, Number(req.limit) || 36));
  const query = "'" + folderId_() + "' in parents and mimeType contains 'image/' and trashed = false";
  let url = '/files?q=' + encodeURIComponent(query) + '&orderBy=' + encodeURIComponent('createdTime desc') +
      '&pageSize=' + limit + '&fields=' +
      encodeURIComponent('nextPageToken,files(id,name,mimeType,thumbnailLink,imageMediaMetadata(width,height))');
  if (req.pageToken) url += '&pageToken=' + encodeURIComponent(String(req.pageToken));
  const page = driveJson_(url);
  const files = page.files || [];

  // Náhledy se stahují najednou (paralelně) a posílají přímo v odpovědi.
  const token = ScriptApp.getOAuthToken();
  const requests = files.filter((f) => f.thumbnailLink).map((f) => ({
    url: f.thumbnailLink.replace(/=s\d+(-c)?$/, '=s256'),
    headers: {Authorization: 'Bearer ' + token},
    muteHttpExceptions: true,
  }));
  const responses = requests.length ? UrlFetchApp.fetchAll(requests) : [];
  let next = 0;
  const items = files.map((f) => {
    let thumb = null;
    if (f.thumbnailLink) {
      const r = responses[next++];
      if (r && r.getResponseCode() === 200) thumb = Utilities.base64Encode(r.getContent());
    }
    const dims = f.imageMediaMetadata || {};
    return {id: f.id, name: f.name || '', mimeType: f.mimeType || 'image/jpeg', width: dims.width || null, height: dims.height || null, thumb: thumb};
  });
  return {ok: true, items: items, next: page.nextPageToken || null};
}

// ----------------------------------------------------------------- Drive REST

function fetchAuthorized_(url) {
  const res = UrlFetchApp.fetch(url, {headers: {Authorization: 'Bearer ' + ScriptApp.getOAuthToken()}, muteHttpExceptions: true});
  return res.getResponseCode() === 200 ? res : null;
}

function driveJson_(path) {
  const res = UrlFetchApp.fetch(DRIVE_API + path, {
    headers: {Authorization: 'Bearer ' + ScriptApp.getOAuthToken()},
    muteHttpExceptions: true,
  });
  const code = res.getResponseCode();
  if (code === 404) throw new GatewayError_('not-found');
  if (code !== 200) throw new GatewayError_('server-error', 'drive ' + code);
  return JSON.parse(res.getContentText());
}
