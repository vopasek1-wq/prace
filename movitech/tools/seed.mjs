// Založí 3 místnosti a seznam povolených e-mailů ve Firestore.
//
// Použití (z kořene projektu):
//   cp tools/seed.example.json tools/seed.json      # upravte názvy místností a e-maily
//   cd tools && npm install && cd ..
//   gcloud auth application-default login            # jednou, přihlášení k Google Cloud
//   FIREBASE_PROJECT=vase-id-projektu node tools/seed.mjs
//
// Pro emulátor: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_PROJECT=demo-jimmy node tools/seed.mjs
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const project = process.env.FIREBASE_PROJECT;
if (!project) {
  console.error('Nastavte FIREBASE_PROJECT (ID vašeho Firebase projektu).');
  process.exit(1);
}

const config = JSON.parse(readFileSync(process.env.SEED_FILE ?? join(here, 'seed.json'), 'utf8'));
if (config.rooms.length !== 3) {
  console.error(`Očekávám přesně 3 místnosti, v souboru je ${config.rooms.length}.`);
  process.exit(1);
}
if (config.allowlist.length > 6) {
  console.error(`Maximum je 6 uživatelů, v souboru je ${config.allowlist.length}.`);
  process.exit(1);
}

initializeApp({projectId: project});
const db = getFirestore();

const batch = db.batch();
config.rooms.forEach((room, order) => {
  batch.set(db.doc(`rooms/${room.id}`), {name: room.name, order, emoji: room.emoji ?? null});
});
for (const user of config.allowlist) {
  // ID dokumentu = e-mail malými písmeny (pravidla ho porovnávají s přihlášeným účtem)
  batch.set(db.doc(`allowlist/${user.email.trim().toLowerCase()}`), {displayName: user.displayName ?? ''});
}
await batch.commit();
console.log(`Hotovo: ${config.rooms.length} místnosti, ${config.allowlist.length} povolených e-mailů.`);
