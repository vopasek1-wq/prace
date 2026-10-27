# Jak Movitech vyzkoušet na telefonu

**Nic se nikam nepublikuje.** Žádný Google Play, žádný App Store, žádný TestFlight, žádný Firebase App Distribution.
Aplikace se do telefonu nainstaluje přímo z vašeho počítače kabelem (nebo u Androidu souborem `.apk`, který si pošlete
jen sami sobě).

Máte dvě možnosti. Začněte demem – za 15 minut uvidíte celou aplikaci.

| | **A) Demo režim** | **B) Ostrý režim** |
|---|---|---|
| Co potřebujete | jen počítač, telefon a Flutter | + Firebase projekt (zdarma) a skript na hlavním Google Disku |
| Přihlášení | tlačítko "Vstoupit do demo režimu" | opravdu přes Google (běžný Gmail stačí) |
| Data | jen v paměti telefonu, po vypnutí zmizí | Firestore, sdílená mezi lidmi, v reálném čase |
| Kolegové | 5 vymyšlených, odpovídají za 1,6 s | skuteční lidé z vašeho seznamu (max. 6) |
| Fotky | ukázkové, galerie, fotoaparát | ukládají se na **hlavní Google Disk** |
| Přepis textu z fotek | ukázkový text | skutečný (Google Disk OCR) |
| Push notifikace | ne | ne (volitelné, kapitola 6) |

**Místnosti:** Movitech, Velké nakládky a Nápady (název třetí místnosti si změníte v kapitole 5.5).

---

## 1. Co potřebujete

### Pro Android telefon (Windows, Mac i Linux)
1. **Flutter SDK** – <https://docs.flutter.dev/get-started/install> (zde ověřeno s Flutter 3.47.8, Dart 3.13).
2. **Android Studio** – <https://developer.android.com/studio> (kvůli Android SDK; spustit stačí jednou a nechat doinstalovat součásti).
3. **Git** – <https://git-scm.com/downloads>.
4. USB kabel (musí umět přenášet data, ne jen nabíjet).

### Pro iPhone (jen Mac)
iPhone aplikaci jde sestavit **jen na Macu**. Na Windows ani Linuxu to technicky nejde.
1. **Xcode** z Mac App Store (velký, stahuje se dlouho) + jednou ho spustit a odsouhlasit licenci.
2. Flutter SDK a Git jako výše. Navíc `sudo gem install cocoapods` (nebo `brew install cocoapods`).
3. **Apple ID** (zdarma stačí). Omezení bezplatného účtu: aplikace v telefonu **vydrží 7 dní**, pak ji
   stejným příkazem nainstalujete znovu. Push notifikace na iPhonu bez placeného účtu (99 USD/rok) nefungují.
4. Lightning/USB-C kabel.

Po instalaci spusťte `flutter doctor` – vypíše, co ještě chybí, a řekne jak to doplnit.

---

## 2. Stažení projektu

```bash
git clone https://github.com/vopasek1-wq/Jimmy.git
cd Jimmy
git checkout claude/beautiful-hopper-jvanka
flutter pub get
```
(Složka a repozitář se jmenují `Jimmy`, aplikace v telefonu se jmenuje **Movitech**.)

---

## 3. Příprava telefonu

### Android
1. *Nastavení → O telefonu →* 7× klepněte na **Číslo sestavení** (zapne se režim pro vývojáře).
2. *Nastavení → Systém → Možnosti pro vývojáře →* zapněte **Ladění přes USB** (název se mírně liší podle výrobce).
3. Připojte kabelem a v telefonu potvrďte **Povolit ladění USB**.
4. Na počítači: `flutter devices` – telefon se musí objevit v seznamu.

### iPhone
1. *Nastavení → Soukromí a zabezpečení → Režim vývojáře* – zapnout (telefon se restartuje).
2. Připojte kabelem, v telefonu klepněte **Důvěřovat tomuto počítači**.
3. Na Macu otevřete Xcode → *Settings → Accounts →* přidejte své Apple ID.
4. Otevřete `ios/Runner.xcworkspace` (dvojklikem), vlevo vyberte **Runner**, záložka **Signing & Capabilities**:
   - *Team*: vyberte "(Personal Team)",
   - *Bundle Identifier*: změňte na něco jedinečného, např. `cz.vasepriezvisko.movitech`
     (původní `io.github.vopasek1wq.jimmy` může být u bezplatného účtu obsazený).
   - Pokud pak použijete ostrý režim, **stejné ID** zadejte při `flutterfire configure` (kapitola 5.4).
5. Na Macu: `flutter devices` – iPhone se musí objevit.

---

## 4. Varianta A – demo režim (doporučuji začít tady)

Zjistěte ID telefonu příkazem `flutter devices` (např. `R58M123ABC` nebo dlouhé UDID u iPhonu) a spusťte:

```bash
flutter run --release --dart-define=DEMO=true -d <ID-telefonu>
```

- `--release` je záměrně: aplikace se normálně nainstaluje, **zůstane v telefonu i po odpojení kabelu**
  a spouští se ikonou. (Ladicí verze na iPhonu po odpojení kabelu spadne.)
- První sestavení trvá několik minut (Android: stahuje se Gradle, iPhone: CocoaPods).
- iPhone, první spuštění: *Nastavení → Obecné → VPN a správa zařízení →* klepněte na svůj Apple ID → **Důvěřovat**.

**Co si v demu zkusit**
- Klepněte na **Vstoupit do demo režimu**, otevřete místnost **Movitech**.
- Napište zprávu – za chvíli odpoví "kolega" (simulace příchozí zprávy).
- **Podržte prst na zprávě** → čtyři reakce 👍 🟩 🟥 🟧; klepnutím reakci přidáte, dalším klepnutím zrušíte.
- Lupa → napište `zlutoucky kun` (bez diakritiky) → najde "žluťoučký kůň" a zvýrazní ho.
- Ikona fotky vlevo od pole → **Ze složky na Google Disku** → mřížka ukázkových fotek → vyberte → u náhledu je
  přepínač **Přepsat text z fotky** → po odeslání je pod fotkou ukázkový přepis (v demu se text nerozpoznává doopravdy).
- Místnost **Velké nakládky** má ukázkovou fotku; tečka u místnosti znamená nepřečtené zprávy.

---

## 5. Varianta B – ostrý režim (Firebase + hlavní Google Disk)

Vše je v bezplatných plánech (bez platební karty). Push notifikace v nich nejsou – viz kapitola 6.

**Jak to funguje:** všichni (běžné Gmail účty) se do aplikace přihlásí přes Google – to slouží **jen k ověření, kdo jste**.
Žádný člen nedává aplikaci přístup ke svému Disku. Fotky se ukládají na **jeden hlavní Google účet** (ten, který určíte):
aplikace je posílá malému skriptu ("brána"), který běží pod tímto hlavním účtem, ověří, že volá člen týmu,
a uloží fotku do složky **"Movitech – fotky"** na jeho Disku.

### 5.1 Firebase projekt
1. <https://console.firebase.google.com> → **Add project** → pojmenujte (např. `movitech-chat`), Google Analytics vypněte.
2. **Build → Firestore Database → Create database** → *Production mode* → lokalita **europe-west3** (Frankfurt)
   nebo `eur3`. **Lokalitu už nelze změnit.**
3. **Build → Authentication → Get started → Sign-in method → Google → Enable** → vyberte support e-mail → Save.
   Poté Google poskytovatele znovu otevřete a z části *Web SDK configuration* opište **Web client ID**
   (vypadá `123456789-abc….apps.googleusercontent.com`). Budete ho potřebovat v 5.4.
4. **Project settings (ozubené kolo) →** opište **Project ID** (např. `movitech-chat-a1b2c`). Budete ho potřebovat v 5.3.

### 5.2 Přihlášení běžným Gmailem
Žádné zvláštní nastavení Google Cloudu není potřeba: aplikace chce jen jméno a e-mail, takže se nic neověřuje
a nic nevyprší. Kdyby Google při přihlášení hlásil "přístup zablokován / aplikace není ověřená", otevřete
<https://console.cloud.google.com> → stejný projekt → **Google Auth Platform → Audience** a buď **Publish app**
(pro základní přihlášení není ověření potřeba), nebo do **Test users** přidejte všech 6 e-mailů.

### 5.3 Brána pro fotky na hlavním Disku (10 minut, jednou)
Dělejte to **pod hlavním Google účtem**, na jehož Disku se mají fotky ukládat.

1. Otevřete <https://script.google.com> → **Nový projekt** → pojmenujte "Movitech fotky".
2. *Nastavení projektu* (ozubené kolo vlevo) → zaškrtněte **Zobrazit soubor manifestu "appsscript.json" v editoru**.
3. V editoru (Soubory vlevo):
   - **Code.gs** – smažte obsah a vložte celý obsah souboru `gateway/Code.gs` z tohoto projektu,
   - **appsscript.json** – nahraďte obsahem souboru `gateway/appsscript.json`.
   Uložte (Ctrl+S).
4. *Nastavení projektu →* **Vlastnosti skriptu → Přidat vlastnost skriptu:**
   - `FIREBASE_PROJECT_ID` = Project ID z 5.1 (bod 4),
   - (volitelně) `OCR_LANGUAGE` = `cs` (jazyk přepisu textu z fotek; `cs` je výchozí).
5. Nahoře vyberte funkci **setup** a klepněte **Spustit**. Google se zeptá na oprávnění: **Zkontrolovat oprávnění →**
   vyberte hlavní účet → *"Google tuto aplikaci neověřila"* → **Rozšířené → Přejít na Movitech fotky (nezabezpečené) → Povolit**.
   (Je to váš vlastní skript, proto ta výstraha.) Po doběhnutí je na Disku složka **Movitech – fotky** (odkaz je v protokolu spuštění).
6. **Nasadit → Nové nasazení →** ozubené kolo → typ **Webová aplikace** →
   *Spustit jako:* **Já** · *Kdo má přístup:* **Kdokoli** → **Nasadit**. Zkopírujte **URL webové aplikace** (končí `/exec`).
   "Kdokoli" znamená jen to, že se skript dá zavolat bez Google přihlášení; každé volání musí obsahovat platný token
   člena týmu, jinak ho skript odmítne (ověřuje se přes Firestore pravidla, takže seznam povolených je jen na jednom místě).
7. Zkouška: otevřete zkopírovanou URL v prohlížeči – má se zobrazit `{"ok":true,"service":"jimmy-photo-gateway"}`.
8. Adresu vložíte do `config.json` v 5.4 jako `PHOTO_GATEWAY_URL`.

> Když skript později změníte: **Nasadit → Spravovat nasazení → Upravit (tužka) → Verze: Nová verze → Nasadit**.
> Adresa zůstane stejná.

**Limity zdarma:** u běžného Gmailu skript zvládne desítky tisíc volání denně a 90 minut běhu denně – pro 6 lidí je to
nesrovnatelně víc, než potřebujete. Fotky zabírají místo na Disku hlavního účtu (15 GB zdarma).

### 5.4 Nástroje a propojení aplikace s Firebase
Nástroje (jednou):
```bash
npm install -g firebase-tools          # vyžaduje Node.js: https://nodejs.org
dart pub global activate flutterfire_cli
firebase login
```
V kořeni projektu (`Jimmy/`):
```bash
flutterfire configure --project=VASE-PROJECT-ID --platforms=android,ios \
  --android-package-name=io.github.vopasek1wq.jimmy \
  --ios-bundle-id=TO-ID-CO-JSTE-ZVOLILI-V-XCODE
git update-index --skip-worktree lib/firebase_options.dart   # ať se vaše konfigurace omylem nedostane do gitu
cp config.example.json config.json
```
Otevřete `config.json` a doplňte:
- `GOOGLE_WEB_CLIENT_ID` = Web client ID z 5.1 (bod 3),
- `PHOTO_GATEWAY_URL` = adresa z 5.3 (bod 6).

(`config.json` je v `.gitignore` – necommitujte ho.)

**Android – otisk certifikátu (bez něj přihlášení na Androidu nefunguje):**
```bash
cd android && ./gradlew signingReport        # Windows: gradlew.bat signingReport
```
V části `Variant: debug` opište **SHA-1** a **SHA-256** a vložte je v Firebase Console:
*Project settings → Your apps → (Android aplikace) → Add fingerprint*.
(Aplikace sestavená jako release se podepisuje stejným ladicím klíčem, takže stejné otisky platí.)
Každý počítač má vlastní ladicí klíč – sestavujete-li na dvou počítačích, přidejte otisky z obou.

**iPhone – URL schéma pro přihlášení přes Google:**
```bash
node tools/ios_google_signin.mjs
```
(Doplní do `ios/Runner/Info.plist` hodnotu odvozenou z `iosClientId`.)

### 5.5 Pravidla a data
```bash
firebase deploy --only firestore:rules --project VASE-PROJECT-ID
```
Pak v **Firebase Console → Firestore Database → Start collection** založte ručně (5 minut):

**Kolekce `rooms`** – přesně 3 dokumenty, pole:

| Document ID | `name` (string) | `order` (number) | `emoji` (string, nepovinné) |
|---|---|---|---|
| `movitech` | `Movitech` | `0` | `🏢` |
| `velke-nakladky` | `Velké nakládky` | `1` | `🚛` |
| `napady` | `Nápady` *(přejmenujte podle potřeby)* | `2` | `💡` |

**Kolekce `allowlist`** – jeden dokument na člověka (max. 6). *Document ID* = **Gmail adresa malými písmeny**
(např. `jana@gmail.com`), jediné pole `displayName` (string, libovolné jméno).
Jen lidé z tohoto seznamu se do aplikace dostanou a jen oni smějí s fotkami cokoli dělat.

> Pohodlnější je skript `tools/seed.mjs` (viz hlavička souboru), ale vyžaduje nainstalovaný Google Cloud CLI.
> Pro 5 minut práce je ruční zadání jednodušší.

### 5.6 Spuštění v telefonu
```bash
flutter run --release --dart-define-from-file=config.json -d <ID-telefonu>
```
- Přihlaste se Googlem. E-mail musí být v `allowlist`, jinak: "Tento účet nemá přístup".
- Aby si lidé mohli psát, musí mít aplikaci nainstalovanou **každý** – viz kapitola 7.

### 5.7 Fotky a přepis textu z fotek
- **Poslat fotku:** ikona fotky vlevo od pole → *Vyfotit* / *Z galerie* / *Ze složky na Google Disku*.
  Fotka se zmenší (max. 1600 px) a uloží do složky **Movitech – fotky** na hlavním Disku.
- **Ze složky na Google Disku:** ukáže fotky, které ve složce jsou – i ty, které tam hlavní účet **vložil ručně**
  (třeba z počítače nebo z aplikace Disk). Vyberete a odešlete; nic se nekopíruje.
- **Přepis textu z fotky:** v náhledu před odesláním je přepínač **Přepsat text z fotky** (výchozí je zapnuto).
  Google Disk fotku převede na dokument, rozpozná tištěný text (čeština) a text se objeví **pod fotkou**:
  dá se zkopírovat (podržet zprávu → *Kopírovat text*) a **dá se v něm hledat** (lupa). Dlouhý text je zkrácený
  a rozbalíte ho "Zobrazit celý text". Přepis trvá pár sekund navíc. U fotek bez textu (rampa, zboží) přepínač vypněte.
  - Funguje nejlépe na tištěný text vyfocený zblízka a rovně (dodací listy, štítky, tabulky). Ručně psané písmo
    ani záběry z dálky Disk většinou nepřečte. Max. cca 3500 znaků na fotku.
  - Přepis je jen doplněk: když selže, fotka se odešle bez textu a aplikace to ohlásí.

---

## 6. Volitelně: push notifikace

Chodí jen s plánem **Blaze** (platební karta, při 6 lidech reálně 0 Kč; nastavte si upozornění na 1 USD).
1. Firebase Console → *Upgrade* na Blaze.
2. `cd functions && npm install && cd .. && firebase deploy --only functions --project VASE-PROJECT-ID`
3. `"ENABLE_PUSH": "true"` v `config.json` a aplikaci znovu nainstalovat.
4. **iPhone:** potřebuje placený Apple Developer účet a nahraný APNs klíč ve Firebase (*Project settings → Cloud Messaging*)
   a v Xcode přidanou schopnost *Push Notifications*. S bezplatným Apple ID push nefunguje – aplikace se jen nespustí s push a jinak funguje.
5. **Android:** funguje po nasazení funkce.

---

## 7. Jak aplikaci dostat k ostatním pěti – bez publikování

- **Android:** vytvořte soubor a pošlete ho (soukromě) ostatním:
  ```bash
  flutter build apk --release --split-per-abi --dart-define-from-file=config.json
  # soubor: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (pro dnešní telefony)
  ```
  V telefonu příjemce soubor otevřete a povolte instalaci z neznámých zdrojů pro aplikaci, ze které ho otevíráte.
  `.apk` je podepsaný ladicím klíčem počítače, na kterém vznikl; **jeho SHA-1/SHA-256 (viz 5.4) musí být ve Firebase** –
  pak funguje přihlášení na všech telefonech, kam ho nainstalujete. Soubor obsahuje vaše Firebase klíče a adresu brány
  → nedávejte ho na veřejné místo.
- **iPhone:** bez publikace (TestFlight/App Store) to jde jen tak, že si každý iPhone připojí k Macu a nainstaluje
  příkazem z kapitoly 5.6 (každých 7 dní znovu). Pro 6 lidí s iPhony je praktičtější placený účet + TestFlight – to už je publikace, tak jsem to nepřipravoval.

---

## 8. Časté problémy

| Příznak | Příčina / řešení |
|---|---|
| Po startu "Aplikace není nastavená / Firebase není nastavený" | Chybí `flutterfire configure` (5.4), nebo spouštíte bez `--dart-define-from-file=config.json`. |
| Android: přihlášení spadne (`clientConfigurationError`, "Developer error", kód 10) | Chybí SHA-1/SHA-256 (5.4) nebo je špatné `GOOGLE_WEB_CLIENT_ID`. |
| iPhone: přihlášení otevře Google a pak nic | Nespuštěno `node tools/ios_google_signin.mjs`, nebo se `--ios-bundle-id` liší od ID v Xcode. |
| "Tento účet nemá přístup" | E-mail není v `allowlist` (malá písmena!), nebo nejsou nasazená pravidla (5.5). |
| `permission-denied` při čtení | Pravidla vyžadují ověřený e-mail a záznam v `allowlist`; po přidání se odhlaste a přihlaste. |
| "Místnosti nejsou nastavené" | Chybí kolekce `rooms` se 3 dokumenty (5.5). |
| Fotky: "Fotky nejsou nastavené … PHOTO_GATEWAY_URL" | V `config.json` chybí adresa brány (5.3, bod 6) nebo spouštíte bez `--dart-define-from-file`. |
| Fotky: "Brána pro fotky neodpověděla správně (HTTP …)" | Špatně nasazená brána: *Kdo má přístup* musí být **Kdokoli**, *Spustit jako* **Já**; po úpravě skriptu vytvořte **Novou verzi** nasazení (5.3). |
| Fotky: "Brána pro fotky není dokončená" | Ve skriptu jste nespustili funkci `setup` (5.3, bod 5). |
| Fotky: "Tento účet nemá přístup" (přihlášení jinak funguje) | Ve skriptu je jiné `FIREBASE_PROJECT_ID` než váš projekt, nebo e-mail není v `allowlist`. |
| Fotky: "Přihlášení vypršelo" | Odhlaste se a přihlaste znovu. |
| Fotka kolegy: ikona rozbitého obrázku | Klepnutím zkuste znovu; fotku mohl hlavní účet smazat z Disku. |
| Přepis textu: "nepodařilo přepsat" | Fotka je moc velká/rozmazaná, nebo Disk právě nereaguje; fotka je odeslaná, text zkuste znovu u další fotky. |
| iPhone: "Untrusted Developer" | *Nastavení → Obecné → VPN a správa zařízení → Důvěřovat* (kapitola 4). |
| iPhone: po týdnu aplikace nejde otevřít | Vyprchal bezplatný podpis; znovu `flutter run --release …`. |
| `Gradle`/`pod install` chyba při prvním sestavení | `flutter clean && flutter pub get` a znovu; u iPhonu `cd ios && pod repo update && cd ..`. |

---

## 9. Co je ověřené a co ne

**Ověřeno (v cloudovém kontejneru, bez telefonu a bez vašich účtů):**
- `flutter analyze` bez nálezů; 53 automatických testů aplikace (hledání, reakce, celý průchod demem, klient brány,
  přepis textu, dialog fotky).
- **Brána (`gateway/Code.gs`)**: 28 testů logiky ve Node.js s napodobeninami služeb Google, včetně toho, že **členství
  rozhodují skutečná pravidla Firestore** v emulátoru. Dále klient aplikace proti této bráně přes HTTP s přesměrováním
  jako u Apps Scriptu (tento test odhalil a pomohl opravit chybu při čtení odpovědi).
- Pravidla Firestore – 23 testů proti emulátoru (včetně "na reakci smí každý sáhnout jen sám na sebe").
- Seed skript proti emulátoru; skript pro iOS URL schéma na vzorových souborech.
- Demo režim jako webová verze v prohlížeči v rozměru telefonu.
- **Android se sestaví:** ladicí i release APK (Gradle, Android SDK 36). Na zařízení ani v emulátoru jsem je nespouštěl.

**Neověřeno – musíte vyzkoušet vy:**
- **Reálné nasazení skriptu v Google Apps Script** a jeho chování (především to, že POST vrací přesměrování, které klient
  čte – vychází z dokumentovaného chování Apps Scriptu, ale na skutečném nasazení jsem ho neviděl).
- **Skutečný Google Disk:** ukládání do složky, miniatury (`thumbnailLink`), a hlavně **přepis textu** (převod obrázku na
  Dokument s OCR přes Drive API). Kvalitu čtení češtiny zjistíte až na vašich dodacích listech.
- Přihlášení přes Google a Firebase s vašimi účty.
- Push notifikace (Cloud Function se načte, ale proti reálnému FCM neběžela).
- **iPhone build** – nemám Mac, takže iOS část je připravená podle dokumentace a nezkompilovaná.
- Běh na fyzickém zařízení (rychlost, klávesnice, oprávnění fotoaparátu).

**První, co vyzkoušet v ostré verzi:** (1) otevřít adresu brány v prohlížeči, (2) poslat fotku s dodacím listem
s přepínačem přepisu zapnutým a podívat se, co z ní vyšlo, (3) otevřít ji na telefonu druhého člena.
Jakmile narazíte na chybu, pošlete mi výpis z terminálu (`flutter run` ho vypíše) nebo text hlášky z aplikace.
