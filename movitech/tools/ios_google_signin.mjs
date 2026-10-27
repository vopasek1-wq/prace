// Doplní do ios/Runner/Info.plist URL schéma potřebné pro přihlášení přes Google na iPhonu.
// Spusťte po `flutterfire configure` (ten vytvoří lib/firebase_options.dart):
//
//   node tools/ios_google_signin.mjs
//
// Schéma se odvodí z iosClientId v lib/firebase_options.dart. Skript lze spouštět opakovaně.
import {readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';

const root = process.env.JIMMY_ROOT ?? join(dirname(fileURLToPath(import.meta.url)), '..');
const optionsPath = join(root, 'lib/firebase_options.dart');
const plistPath = join(root, 'ios/Runner/Info.plist');

const options = readFileSync(optionsPath, 'utf8');
const match = options.match(/iosClientId:\s*'([^']+)\.apps\.googleusercontent\.com'/);
if (!match) {
  console.error('V lib/firebase_options.dart jsem nenašel iosClientId.');
  console.error('Spusťte nejdřív "flutterfire configure" a vyberte i platformu iOS.');
  process.exit(1);
}
const scheme = `com.googleusercontent.apps.${match[1]}`;

let plist = readFileSync(plistPath, 'utf8');
if (plist.includes('CFBundleURLTypes')) {
  plist = plist.replace(/com\.googleusercontent\.apps\.[A-Za-z0-9._-]+/g, scheme);
} else {
  const entry = `\t<key>CFBundleURLTypes</key>
\t<array>
\t\t<dict>
\t\t\t<key>CFBundleTypeRole</key>
\t\t\t<string>Editor</string>
\t\t\t<key>CFBundleURLSchemes</key>
\t\t\t<array>
\t\t\t\t<string>${scheme}</string>
\t\t\t</array>
\t\t</dict>
\t</array>
`;
  const end = plist.lastIndexOf('</dict>');
  plist = plist.slice(0, end) + entry + plist.slice(end);
}
writeFileSync(plistPath, plist);
console.log(`Info.plist: URL schéma nastaveno na ${scheme}`);
