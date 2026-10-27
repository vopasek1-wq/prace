# Movitech – Mobile Team Chat: Specification & Implementation Plan

> **Stav implementace (říjen 2026):** aplikace podle tohoto návrhu je v repozitáři (`lib/`, `gateway/`, `firestore.rules`,
> `functions/`, `tools/`). Jak ji vyzkoušet na telefonu bez publikování: [SPUSTENI.md](SPUSTENI.md).
> Od původního návrhu se liší tyto body (v textu níže jsou označené *„Implementováno jinak"*):
> 1. **Fotky se ukládají na jeden HLAVNÍ Google Disk** (přes malý skript v Google Apps Script, „brána“), ne na osobní
>    Disky jednotlivých členů. Členové (běžné Gmaily) se přihlašují jen kvůli totožnosti, k Disku nepotřebují žádné
>    oprávnění. Kapitola 5 je podle toho přepsaná.
> 2. **Přepis textu z fotek (OCR)**: po nahrání se text z fotky přepíše (Disk převede obrázek na dokument) a přidá pod
>    fotku, takže je kopírovatelný a **vyhledatelný**. Přepínač v náhledu, výchozí zapnuto.
> 3. Náhled místnosti a tečka „nepřečteno" se počítají **v aplikaci** (`limit(1)` na zprávy), ne Cloud Functionem →
>    celé běží na bezplatných plánech; funkce slouží jen pro push notifikace (volitelné).
> 4. Hledání načítá historii **ze serveru jednou za běh aplikace** (posledních 1000 zpráv v každé místnosti, offline z cache);
>    klepnutí na výsledek otevře místnost (skok na konkrétní zprávu zatím není).
> 5. České texty jsou v `lib/core/strings.dart`, ne v `.arb` souborech. Aplikace se jmenuje **Movitech**; místnosti
>    Movitech, Velké nakládky, Nápady.

## 0. Assumptions and decisions you can veto

| # | Decision | Why |
|---|---|---|
| A1 | All 6 users are on **one Google Workspace domain**. If they use consumer Gmail, see §5.6. | This decides whether a Google verification review is needed (§5.1). |
| A2 | UI language is **Czech** (strings in `.arb` files; English is easy to add later). | The reaction names are Czech. |
| A3 | A user may put **several different reactions** on one message, such as 👍 and 🟩. This is one constant, `exclusiveReactions`. | It is simpler. The code in §9 supports both modes. |
| A4 | Messages are **immutable** (no edit or delete). Only `reactions` changes after creation. | Edit/delete was not requested, and it keeps search and sync trivial. |
| A5 | The max-6-users rule is enforced by an **email allowlist** in Firestore, managed in the Firebase console. | No admin panel was requested. |

---

## 1. Technology Stack Recommendation

**Framework: Flutter (Dart).**
- **Firebase and Google support.** FlutterFire (Auth, Firestore, FCM) is officially supported by the Firebase team. `google_sign_in` is a first-party package. `googleapis` is a generated, typed Dart client for Drive v3.
- **One codebase.** There is a single UI codebase with no JS bridge and no Expo dev-client constraints from native modules. That matters for a 1–3 person team.
- **Offline cache comes with Firestore.** Persistence is on by default on mobile.

React Native is a fully valid alternative (`@react-native-firebase/*`, `@react-native-google-signin/google-signin`). The Drive client would have to be hand-written REST, because the Node `googleapis` library isn't RN-friendly. Choose RN only if your team is JS/TS-only or you plan a shared web client. Native Swift and Kotlin would double the work for no benefit at this scale.

**Backend: Firebase.** You need Auth (Google provider), Firestore, FCM and one Cloud Function.
- **What Firebase gives you.** Firestore listeners give real-time delivery. The SDK queues writes offline and caches reads. FCM is the only free route to push on both iOS and Android.
- **Cost.** The Spark free tier covers everything except Cloud Functions. Functions need the **Blaze** plan, which is pay-as-you-go. At 6 users the bill is about $0, so set a $1 budget alert.
- **Why the function is needed.** Push must be sent from a trusted server. Sending FCM from the client would mean shipping credentials in the app.
- **Alternative: Supabase.** Postgres full-text search would be better than what Firestore offers. But you would have to build offline caching yourself, you'd still need FCM, and the Drive tokens are client-side either way. Reconsider it only if search becomes a core feature.

**Photos: one main Google Drive account**, behind a `PhotoStore` interface and a small Google Apps Script "gateway" that runs as that account (§5). If this ever proves too fiddly, Firebase Storage can replace it without touching the rest of the app.

**State and navigation:** Riverpod (providers, no code generation needed) and `go_router` (auth redirect).

**Unavoidable costs outside Firebase:** Apple Developer Program, $99/year (needed for iOS builds and the APNs key for push). Android can be sideloaded or distributed via Firebase App Distribution for free.

---

## 2. Application Architecture

```
┌──────────────────────────── Flutter app (iOS + Android) ────────────────────────────┐
│ PRESENTATION  LoginScreen · RoomListScreen · ChatScreen · PhotoPickerSheet ·         │
│               SearchScreen · PhotoViewer        (go_router, auth-guarded)            │
│ ──────────────────────────────────────────────────────────────────────────────────── │
│ APPLICATION   authProvider · roomsProvider · messagesProvider(roomId) ·              │
│ (Riverpod)    usersProvider (all 6, cached) · searchIndexProvider · sendController   │
│ ──────────────────────────────────────────────────────────────────────────────────── │
│ DATA          AuthRepository   RoomRepository   MessageRepository   DriveRepository  │
│               PushService      SearchRepository (client-side; swappable)             │
└──────┬──────────────┬───────────────────┬───────────────────────┬──────────────┬─────┘
       │Google ID     │Firestore SDK      │Firebase ID token      │FCM token     │
       │token         │(realtime + disk   │access token           │              │
       ▼              │ cache + write q)  ▼                       ▼              │
 Firebase Auth        ▼               Photo gateway (Apps Script) FCM ◄──────────┘
 (Google provider)  Cloud Firestore   runs as the MAIN account     ▲
       ▲            ├ allowlist/{email}  → Drive folder           │ sendEachForMulticast
       │            ├ users/{uid}                                  │
       │            ├ rooms/{roomId}                               │
       │            └ rooms/{roomId}/messages/{id} ──onCreate──► Cloud Function
       │                       ▲                                (jen push, volitelné)
       └─── security rules: isMember() = email ∈ allowlist ─────────┘
```

**Repo layout (feature-first):**

```
lib/
  main.dart  app.dart                 # Firebase init, router, theme
  core/        l10n/ constants.dart (kExclusiveReactions, kMaxMessageLength) utils/
  features/
    auth/      data/auth_repository.dart  presentation/login_screen.dart
    rooms/     data/ domain/room.dart  presentation/room_list_screen.dart
    chat/      data/message_repository.dart  domain/{message,reaction}.dart
               presentation/{chat_screen,message_bubble,reaction_bar,composer}.dart
    drive/     data/drive_repository.dart  presentation/{photo_picker_sheet,drive_image}.dart
    search/    data/search.dart  presentation/search_screen.dart
    notifications/ push_service.dart
functions/index.js   firestore.rules   firestore.indexes.json   tools/seed_rooms.js
```

**Offline.** Firestore's persistent cache is already on, so any room you've opened is readable offline. Raise `cacheSizeBytes` if you want a deeper history offline. Sent messages queue locally and flush on reconnect.

**Push (volitelné).** Each device stores its FCM token on `users/{uid}`. A Cloud Function fires on each new message and sends notifications to the other 5 users. Implementováno jinak: funkce nic jiného nedělá (náhled místnosti se počítá v aplikaci), takže bez push stačí plán Spark.

---

## 3. Database Schema (Firestore)

Region: `europe-west3`. Firestore's location can't be changed later.

```
allowlist/{email}                      # 6 docs, doc ID = lowercase Google email. Console-managed.
  displayName: string                  # informational only

users/{uid}                            # uid = Firebase Auth uid
  email, displayName, photoUrl
  fcmTokens: [string]                  # one per device
  driveFolderId: string?               # the user's "Movitech – fotky" folder (§5)
  driveSharedWith: [email]             # who that folder is already shared with
  lastReadAt: { <roomId>: timestamp }  # for unread dots

rooms/{roomId}                         # exactly 3 docs, created in the console or by tools/seed.mjs; ID = slug
  name: string, order: int, emoji?: string
  # Implementováno jinak: žádné lastMessage. Náhled a „nepřečteno" se počítají v aplikaci z posledního dokumentu.

rooms/{roomId}/messages/{messageId}    # messageId = client-generated (idempotent, offline-safe)
  senderId: string                     # name/photo resolved from users cache, not denormalised
  type: 'text' | 'photo'
  text: string                         # ≤ 4000; '' for a photo without caption. THE ONLY SEARCHED FIELD.
  photo: { driveFileId, mimeType, width?, height? } | null   # no filename stored, so it can't be searched
  reactions: { thumbs_up: [uid], green: [uid], red: [uid], orange: [uid] }
  createdAt: timestamp (server)
```

**Reactions are embedded, not a collection.**

| Option | Verdict |
|---|---|
| **Map of uid-arrays on the message doc** | **Chosen.** One listener delivers message and reactions together. `arrayUnion` / `arrayRemove` toggles are atomic and idempotent, and they work offline. With 6 users the arrays hold at most 6 entries. |
| Subcollection `messages/{id}/reactions/{uid_kind}` | Needs a listener per visible message, which means many more reads and a more complex UI. Not worth it for 6 users. |

The keys (`thumbs_up`, `green`, `red`, `orange`) are stable identifiers, not emoji. The glyphs live only in the UI layer.

**Indexes.** Only `createdAt` ordering is used, so the automatic single-field index is enough and there are no composite indexes.

**Security rules:** the real, tested file is [`firestore.rules`](../firestore.rules) (23 emulator tests in `backend-tests/`).
In short:
- `isMember()` = signed in + verified email + `allowlist/{email}` exists.
- `users/{uid}`: members read all; write only their own doc, and `email` must equal their token email.
- `rooms`: members read; nobody writes from the client.
- `messages`: members read. **Create** only as yourself, with a server timestamp, empty reactions, a text of 1–4000 characters
  (type `text`) or a `photo` map with a `driveFileId` (type `photo`), and no other fields.
  **Update** only the `reactions` field, and per reaction you may add or remove **only your own uid**. Never delete.

Notes on these rules:
- **Allowlist is the 6-user cap.** Anyone with a Google account can create a Firebase Auth user, but the rules deny them all data unless their email is on the allowlist. A "blocking function" could also reject sign-up. That needs Identity Platform and isn't needed here.
- **Email format.** Allowlist doc IDs must be lowercase emails.
- **Tests.** Test the rules with the Emulator Suite and `@firebase/rules-unit-testing`. Include cases for reacting as someone else, adding a 5th key, and editing `text`.

---

## 4. Screen-by-Screen UI Specification

**Global:** Material 3, light and dark themes, Czech strings. A `go_router` redirect sends signed-out users to `/login` and signed-in users away from it. A global offline banner reads "Offline – zprávy se odešlou po připojení".

### 4.1 Login (`/login`)
- Logo and app name.
- Button **"Přihlásit se přes Google"**. It shows a spinner while the sign-in is in progress.
- Error states:
  - Cancelled: no message.
  - Not on the allowlist: "Tento účet nemá přístup. Požádejte správce o přidání."
  - Network error: with a retry.
- No email or password fields and no registration.

### 4.2 Room list (`/rooms`)
- AppBar with title, a search icon (→ Search) and a menu (My account / Sign out).
- Exactly 3 `RoomTile`s ordered by `order`. Each tile has:
  - the room emoji or initial and the room name;
  - a preview of the newest message, shown as "Jméno: text" or "📷 Fotka" (computed in the app from the newest message);
  - a relative time;
  - an unread dot when the newest message is from someone else and newer than `users/{me}.lastReadAt[roomId]`.
- Loading shows a skeleton and an error shows retry. The empty state "Místnosti nejsou nastavené" appears only if seeding failed.
- Pull-to-refresh isn't needed because the stream is live.

### 4.3 Chat room (`/rooms/:roomId`)
- AppBar with back, room name, and a search icon scoped to this room.
- `ListView(reverse: true)` of messages, newest at the bottom. It uses an infinite-scroll limit (+50 when scrolled near the top).
- Day separators ("Dnes", "Včera", date).
- Each `MessageBubble` has:
  - the sender's avatar and name from the cached users map (own messages are right-aligned and tinted);
  - the text, selectable and with tappable links;
  - for a photo: `DriveImage` at the stored aspect ratio, with a blurred placeholder; tapping opens the PhotoViewer;
  - the time, plus a clock icon while `metadata.hasPendingWrites`;
  - the `ReactionBar` summary chips (§6). **Long-press** on a bubble opens a pop-over with all 4 reaction buttons.
- Composer: 📎 button (→ Photo picker), multiline text field (max 4000 characters), and a send button, disabled when empty.
- Sending is optimistic: the message appears immediately with the clock icon.
- Opening or leaving the room sets `lastReadAt[roomId]`.
- Tapping a push notification deep-links to this screen.

### 4.4 Photo picker / Google Drive browser (modal bottom sheet)
Three tabs:

| Tab | Behaviour |
|---|---|
| **Fotoaparát** | `ImagePicker.pickImage(source: camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80)`, then preview, then "Odeslat". |
| **Galerie** | Same, with `source: gallery`. |
| **Ze složky na Google Disku** | Grid (3 columns) of the images in the main account's folder "Movitech – fotky" (including files the owner dropped in by hand), newest first, 36 per page, infinite scroll. Single selection, then "Připojit". Nothing is copied. |

- **Preview step.** Before sending, a dialog shows the photo, an optional caption and the switch **"Přepsat text z fotky"** (default on).
- **Upload progress.** Show a progress overlay with a cancel option.
- **Errors.** Offline, forbidden, too large or a failed text recognition each show a message (a failed recognition still sends the photo).

### 4.5 Search (`/search?room=<optional>`)
- Autofocus search field with clear button, and a room filter chip row (Všechny / 3 rooms).
- Result list: sender, room name, date, and a snippet with the match highlighted.
- Tapping a result opens the Chat room. *Implementováno jinak:* skok přímo na nalezenou zprávu zatím není.
- Empty states: "Zadejte hledaný text" before typing, "Nic nenalezeno" after.
- Searching older history shows "Prohledávám starší zprávy…" with a progress bar.
- It matches message text only, with no filename or reaction matching.

### 4.6 Photo viewer (`/photo/:fileId`)
Full-screen pinch-to-zoom (`InteractiveViewer`). It loads the full-resolution file, with the preview as a placeholder. It offers "Otevřít v Disku" (the file's `webViewLink`) and close.

---

## 5. Photos on the main Google Drive (gateway)

*Implementováno jinak než v prvním návrhu (osobní složky členů sdílené mezi sebou): požadavek je, aby se fotky ukládaly
na jeden hlavní Google Disk a všichni členové jsou na běžných Gmailech.*

### 5.1 Why a gateway
Every member would otherwise need Drive permissions in their own account: reading others' files needs the restricted
`drive.readonly` scope, which for consumer Gmail means an "unverified app" screen, a 100-user cap and weekly re-consent while in
*Testing*. A gateway removes all of that: members only sign in (name + email, no review), and **one** trusted script acts as the
main account.

### 5.2 Architecture
```
Phone ──(Firebase ID token + photo bytes, HTTPS POST)──► Apps Script web app "Movitech fotky"
                                                           │ runs as the MAIN Google account
                                                           ├─ 1. is the caller a member?  GET Firestore /rooms with the caller's own
                                                           │     ID token → the security rules answer 200 (member) / 403
                                                           ├─ 2. upload → folder "Movitech – fotky" on the main Drive
                                                           ├─ 3. get / list → thumbnails, originals, folder listing
                                                           └─ 4. ocr → Drive converts the image to a Google Doc (OCR), the text is
                                                                 exported, the temporary Doc is deleted
```
- **Membership is checked by the existing Firestore rules**, so the allowlist exists in one place only.
- The script only touches files **inside its folder** (parents are checked), and accepts only image types up to ~8 MB.
- Members never see the Drive; the owner can still open the folder, delete photos, or drop new ones in.
- Protocol and error codes: header of [`gateway/Code.gs`](../gateway/Code.gs). Client: `lib/features/drive/data/gateway_photo_store.dart`.

### 5.3 Upload
1. Pick from camera/gallery. `image_picker` downscales to 1600 px and JPEG quality 80 (≈ 300–500 KB).
2. Preview dialog: caption + switch "Přepsat text z fotky".
3. POST `{action:'upload', mimeType, data:<base64>, ocr}` → `{fileId, text, ocrFailed}`.
4. The message `{type:'photo', photo:{driveFileId,…}, text: caption + "\n\n" + recognized text}` is written to Firestore.
5. The sender keeps the bytes in the local cache, so they are never downloaded again.

### 5.4 Attach a photo that is already in the folder
"Ze složky na Google Disku" lists the folder; selecting a photo creates a message that references the same file (no copy).
Optionally the text is recognised with `{action:'ocr', fileId}`.

### 5.5 Display
Preview (`variant:'preview'`, ≈ 1080 px thumbnail) is fetched once per device and cached on disk by file id; the full-screen viewer
fetches the original (or a 2048 px thumbnail when the original is larger than 6 MB).

### 5.6 Text recognition (OCR)
- Done by Google Drive when converting an image to a Google Doc (`files.copy` with `mimeType: application/vnd.google-apps.document`
  and `ocrLanguage`, default `cs`). The exported plain text is cleaned (BOM, blank lines), capped at 3500 characters and
  stored as the message text → **searchable** (§7) and copyable.
- It never blocks sending: a failure only means the photo is posted without text and the app says so.
- Works best on printed text photographed straight and close (delivery notes, labels, tables); handwriting and distant shots are
  usually not read. Quality for Czech must be judged on real documents.

### 5.7 Limits and trade-offs
- **Single owner.** Photos live in the main account's Drive (15 GB free); if that account is lost, so are the photos.
- **Apps Script quotas** (consumer account): tens of thousands of URL fetches and ~90 minutes of runtime per day – far above 6 people.
- **Latency:** a call takes ~1–3 s (more with OCR); thumbnails and downloads are cached on the device.
- **"Anyone" deployment:** the web app URL can be called without a Google login, but every call needs a valid member token.
- **Not verified against real Google services** (only against test doubles): the 302 redirect that Apps Script returns for POST,
  `thumbnailLink` behaviour and the quality of Drive OCR. See [SPUSTENI.md](SPUSTENI.md) chapter 9 for the first checks.

---

## 6. Reactions Implementation

**Model.** Stable keys, with the glyphs kept in the UI layer:

```dart
enum ReactionKind {
  thumbsUp('thumbs_up', '👍', 'Palec nahoru'),
  green('green', '🟩', 'Zelený čtvereček'),
  red('red', '🟥', 'Červený čtvereček'),
  orange('orange', '🟧', 'Oranžový čtvereček');

  const ReactionKind(this.key, this.emoji, this.label);
  final String key, emoji, label;
}
```

**Storage.** `reactions.<key>` is an array of uids (§3).

**Toggle (per message, per user).**
1. The UI already has the message from its live snapshot, so it knows whether the current uid is in `reactions[key]`.
2. In the Firestore update:
   - `arrayRemove([uid])` if present;
   - `arrayUnion([uid])` if not.
3. If `exclusiveReactions` is on, the same update removes the uid from the other three keys when adding.
4. The Firestore SDK applies the change locally first, so the UI updates instantly and offline. The rules (§3) ensure a user can only add or remove their own uid.
5. Both operations are idempotent, so two devices of the same user can't corrupt anything.

**Display.**
- Summary chips under the bubble appear only for kinds with count > 0, as glyph + count. The chip is highlighted when it's mine.
- A long-press on the bubble shows all four as large buttons (`showEmpty: true`).
- Tapping a chip toggles it. Long-pressing a chip lists who reacted, using names from the users cache.
- The order is fixed: 👍 🟩 🟥 🟧.
- **Glyph rendering.** 👍 is drawn as an emoji. The three squares are drawn as small rounded colored boxes, not emoji. 🟩🟥🟧 are Unicode 12 (2019) and show as missing-glyph boxes on Android 9 and older.
- **Accessibility.** Each button has a `Semantics` label such as "Zelený čtvereček, 2 reakce, vy jste reagovali". Red and green are hard to tell apart for some users, so the label and fixed order matter.

---

## 7. Search Implementation

| Approach | Pros | Cons | Verdict |
|---|---|---|---|
| **Client-side filter** over a local copy of message text | Zero infrastructure and free. Works offline. Easy to make case- and diacritic-insensitive (important for Czech). Substring match, not just prefix. | Must load the history it searches. Not typo-tolerant. | **Chosen** |
| Firestore queries (`>= term`, `<= term + ''`) | Server-side | Prefix-only on the whole text. Not case- or diacritic-insensitive. No multi-word matching. | Rejected |
| Algolia / Typesense (via function or Firebase extension) | Typo tolerance, ranking, huge scale | Extra service, cost, sync code, and data leaves Firebase. | Only if you outgrow client-side |

**How it works.**
1. **Normalise.** The query and the message text go through `removeDiacritics(...).toLowerCase()`, via the `diacritic` package. "příliš" then matches "prilis".
2. **Multi-word AND.** The query is split on whitespace, and a message matches if it contains every word.
3. **Text only.** Only `Message.text` is examined. Photo messages have no filename in the schema, and reactions are never touched. For a photo, `text` is the caption plus the text recognised from the picture (§5.6), so text on delivery notes is searchable too.
4. **Index.** A per-session in-memory list of `(roomId, message)`:
   - *Implementováno jinak:* při prvním otevření hledání se načte posledních 1000 zpráv každé místnosti ze serveru (offline z cache) a drží se po dobu běhu aplikace; je-li starší než 3 minuty, při otevření hledání se načte znovu.
   - Původní návrh: cache-first po 2000 zprávách s „načíst starší" a doplňováním z listeneru – zatím neimplementováno.
5. **Cost.** Even if all of it came from the server, 6,000 reads per search session is cents at worst. The Firestore free tier is 50k reads/day.
6. **Swap point.** Put the whole thing behind `SearchRepository.search(query, {roomId})`. Moving to Typesense or Algolia later only changes that implementation.

**Switch criteria.** Move to a hosted engine if a room passes about 50k messages or you want typo tolerance.

---

## 8. Development Roadmap

Estimates are for **1 developer**. With 2–3 people, parallelise as marked.

### Phase 0 – Setup and spikes (≈ 3 days)
- Create the Firebase project, Blaze plan with a $1 budget alert, Firestore in `europe-west3`.
- Enable the Google provider, register Android SHA-1/SHA-256, upload the APNs key.
- Note the Web client ID (Google sign-in is identity only – no Drive scopes).
- Fill the allowlist with 6 emails, run `seed_rooms.js` with the 3 room names, and deploy the rules.
- **Drive spike** (§5.5 a–c). Don't start Phase 2 without it.
- *Done when:* a "hello" Flutter build signs in on both OSes and the spike notes are written.

### Phase 1 – Auth + Rooms + Basic messaging (≈ 2 weeks)
- Login, allowlist rejection, users profile sync, sign-out.
- Room list with last-message preview.
- Chat screen: send/receive text, optimistic pending state, pagination, day separators.
- Offline cache and queued sends. Test in airplane mode.
- Push: FCM token registration, the Cloud Function (push, optional), deep link on tap, token pruning.
- Rules tests in the emulator.
- *Done when:* 6 people on real devices chat across 3 rooms in real time, and a backgrounded app gets a push.

### Phase 2 – Google Drive + Photos (≈ 2 weeks; parallelisable with Phase 3 reactions)
- Gateway script on the main account, upload, folder listing, text recognition.
- Photo picker sheet with three tabs, and the Drive grid with paging.
- `DriveImage` with disk cache and fallbacks. PhotoViewer.
- Error paths: forbidden, offline, too large, failed recognition.
- *Done when:* A uploads, and B, C, … see the preview within seconds, including after cold start and offline re-open.

### Phase 3 – Reactions + Search + Polish (≈ 1.5 weeks)
- Reactions: widget, toggle, rules, accessibility.
- Search: index, screen, highlight, jump-to-message.
- Unread dots, offline banner, app icon, splash, dark mode, Czech copy review.
- Beta via TestFlight and Firebase App Distribution. Fix findings.
- *Done when:* all acceptance criteria in this document pass on a real iPhone and a real Android phone.

**Total:** about 6 weeks for 1 developer, and 3–4 weeks for 2–3 developers.

---

## 9. Key Code Snippets (Flutter / Dart)

Versions verified for the Google packages: `google_sign_in: ^7.2.0` and `extension_google_sign_in_as_googleapis_auth: ^3.0.0`. Use latest for the rest.

### 9.1 Google Sign-In initialisation (v7 API)

```dart
// auth_repository.dart
class AuthRepository {
  AuthRepository(this._auth, this._db, [GoogleSignIn? google])
      : _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;

  // Web client ID from Google Cloud Console; required on Android to receive an ID token.
  static const _serverClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  GoogleSignInAccount? googleAccount; // needed later for Drive authorization

  /// Call once at startup, before runApp.
  Future<void> init() async {
    await _google.initialize(serverClientId: _serverClientId);
    // Silent re-login so Drive calls work after a cold start (Firebase session persists on its own).
    googleAccount = await _google.attemptLightweightAuthentication();
  }

  Future<void> signInWithGoogle() async {
    final account = await _google.authenticate(); // throws GoogleSignInException on cancel
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Google nevrátil ID token');
    googleAccount = account;

    final cred = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    final user = cred.user!;

    try {
      // Rules reject this write if the email isn't on the allowlist.
      await _db.doc('users/${user.uid}').set({
        'email': user.email,
        'displayName': user.displayName ?? user.email,
        'photoUrl': user.photoURL,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await signOut();
        throw const NotAllowlistedException();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
    googleAccount = null;
  }
}
```

### 9.2 Sending a message to Firestore

```dart
// message_repository.dart
Future<void> sendText({required String roomId, required String text}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return Future.value();

  final ref = _db.collection('rooms/$roomId/messages').doc(); // client-side ID: offline-safe, idempotent
  final write = ref.set({
    'senderId': _auth.currentUser!.uid,
    'type': 'text',
    'text': trimmed,
    'photo': null,
    'reactions': {for (final k in ReactionKind.values) k.key: <String>[]},
    'createdAt': FieldValue.serverTimestamp(),
  });
  // Do NOT await this in the UI: Firestore completes the Future only when the *server*
  // acknowledges, so offline it would hang. The UI shows the message from the local snapshot
  // with metadata.hasPendingWrites == true.
  return write;
}

Stream<List<Message>> watchMessages(String roomId, {int limit = 50}) => _db
    .collection('rooms/$roomId/messages')
    .orderBy('createdAt', descending: true)
    .limit(limit)
    .snapshots(includeMetadataChanges: true)
    .map((s) => s.docs.map(Message.fromDoc).toList());

// Message.fromDoc: a pending serverTimestamp reads back as null, so fall back to "now".
// createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
// pending: doc.metadata.hasPendingWrites,
```

For photos, `sendPhoto` is identical except for `type: 'photo'`, `text: caption ?? ''` and `photo: {driveFileId, mimeType, width, height}`.

### 9.3 Rendering and toggling the 4 reaction buttons

```dart
// reaction_bar.dart
const _squareColors = {
  ReactionKind.green: Color(0xFF77B255),
  ReactionKind.red: Color(0xFFDD2E44),
  ReactionKind.orange: Color(0xFFF4900C),
};

class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions, // key -> uids, from the message doc
    required this.myUid,
    required this.onToggle,
    this.showEmpty = false,  // true in the long-press picker, false for the chips under a bubble
  });

  final Map<ReactionKind, List<String>> reactions;
  final String myUid;
  final void Function(ReactionKind) onToggle;
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    final kinds = ReactionKind.values
        .where((k) => showEmpty || (reactions[k]?.isNotEmpty ?? false));
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final k in kinds)
        _ReactionButton(
          kind: k,
          count: reactions[k]?.length ?? 0,
          mine: reactions[k]?.contains(myUid) ?? false,
          onTap: () => onToggle(k),
        ),
    ]);
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.kind, required this.count, required this.mine, required this.onTap});
  final ReactionKind kind;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 👍 is a universally supported emoji; the squares (Unicode 12) are drawn, so old Androids don't show tofu.
    final glyph = kind == ReactionKind.thumbsUp
        ? const Text('👍', style: TextStyle(fontSize: 18))
        : Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: _squareColors[kind], borderRadius: BorderRadius.circular(3)),
          );
    return Semantics(
      button: true,
      selected: mine,
      label: '${kind.label}, $count, ${mine ? "vy jste reagovali" : "nereagovali jste"}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            border: Border.all(color: mine ? scheme.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            glyph,
            if (count > 0) ...[const SizedBox(width: 6), Text('$count')],
          ]),
        ),
      ),
    );
  }
}
```

The toggle goes in the repository:

```dart
// message_repository.dart
Future<void> toggleReaction({
  required String roomId,
  required String messageId,
  required ReactionKind kind,
  required bool alreadyReacted,        // read from the live snapshot
  bool exclusive = kExclusiveReactions,
}) {
  final uid = _auth.currentUser!.uid;
  return _db.doc('rooms/$roomId/messages/$messageId').update({
    'reactions.${kind.key}': alreadyReacted
        ? FieldValue.arrayRemove([uid])
        : FieldValue.arrayUnion([uid]),
    if (exclusive && !alreadyReacted)
      for (final other in ReactionKind.values.where((o) => o != kind))
        'reactions.${other.key}': FieldValue.arrayRemove([uid]),
  });
}
```

### 9.4 Message text search

```dart
// search.dart
import 'package:diacritic/diacritic.dart';

/// Case- and diacritic-insensitive: "Příliš" matches "prilis".
String normalizeForSearch(String s) => removeDiacritics(s).toLowerCase();

class SearchHit {
  SearchHit(this.message, this.ranges);
  final Message message;
  final List<TextRange> ranges; // for highlighting; empty if offsets can't be mapped safely
}

/// Searches message TEXT only (no filenames, no reactions). All words must appear (AND).
List<SearchHit> searchMessages(Iterable<Message> messages, String query, {int limit = 200}) {
  final words = normalizeForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];

  final hits = <SearchHit>[];
  for (final m in messages) {
    if (m.text.isEmpty) continue;                      // photo without caption
    final hay = normalizeForSearch(m.text);
    if (!words.every(hay.contains)) continue;

    // Offsets are only valid if normalisation kept the length (true for Czech).
    final ranges = <TextRange>[];
    if (hay.length == m.text.length) {
      for (final w in words) {
        for (var i = hay.indexOf(w); i != -1; i = hay.indexOf(w, i + w.length)) {
          ranges.add(TextRange(start: i, end: i + w.length));
        }
      }
    }
    hits.add(SearchHit(m, ranges));
  }
  hits.sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt)); // newest first
  return hits.length > limit ? hits.sublist(0, limit) : hits;
}
```

### 9.5 Bonus: photos through the gateway

The real files: [`gateway/Code.gs`](../gateway/Code.gs) (the script), [`lib/features/drive/data/gateway_photo_store.dart`](../lib/features/drive/data/gateway_photo_store.dart)
(client; note the manual handling of the 302 redirect – `dart:io` reports `isRedirect` for a POST only on 303), and
[`backend-tests/`](../backend-tests) (gateway tests with Google service doubles and a fake HTTP server used by the Dart end-to-end test).

### 9.6 Bonus: Cloud Function for push (optional)

The real file is [`functions/index.js`](../functions/index.js). It reads the new message, collects the FCM tokens of the other
members from `users/{uid}.fcmTokens`, sends them with `sendEachForMulticast`, and removes dead tokens.
Deploy needs the Blaze plan: `firebase deploy --only functions`.

---

## 10. Risk register

| Risk | Mitigation |
|---|---|
| Apps Script / Drive behave differently than the test doubles (redirect on POST, thumbnails, OCR quality) | First live checks in SPUSTENI.md chapter 9. Fallback is Firebase Storage behind `PhotoStore`. |
| Single point of failure: the main Google account | Back up the folder "Movitech – fotky"; the app only needs the web-app URL to be redeployed under another account. |
| Photos disappear if the uploader's account is removed | Document it. Optional move to a Shared Drive or Firebase Storage. |
| iOS push doesn't arrive | APNs key uploaded to Firebase, Push Notifications and Background Modes capabilities, and testing on a real device (the simulator can't). |
| `await ref.set()` hangs offline | Never await Firestore writes in the UI (§9.2). |
| Blaze surprise bill | $1 budget alert. Real usage is a few thousand reads and writes a day. |
| A user leaves the company | Remove the email from `allowlist`. They lose all access immediately. Photos they uploaded stay in their Drive. |

---

Sources:
- [google_sign_in 7.2.0 on pub.dev](https://pub.dev/packages/google_sign_in)
- [extension_google_sign_in_as_googleapis_auth 3.0.0](https://pub.dev/packages/extension_google_sign_in_as_googleapis_auth)
- [Drive API scope classification](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Drive `files` resource reference](https://developers.google.com/workspace/drive/api/reference/rest/v3/files)
- [OAuth 2.0 token expiration](https://developers.google.com/identity/protocols/oauth2#expiration)
- [Cloud Firestore triggers for Cloud Functions](https://firebase.google.com/docs/functions/firestore-events)
