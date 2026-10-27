// Volitelné: push notifikace o nových zprávách.
// Nasazení vyžaduje plán Blaze:  firebase deploy --only functions
// Aplikace musí být spuštěná s ENABLE_PUSH=true (viz docs/SPUSTENI.md).
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

initializeApp();

const DEAD_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

exports.onMessageCreated = onDocumentCreated(
  {document: 'rooms/{roomId}/messages/{messageId}', region: 'europe-west3'},
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const db = getFirestore();
    const [room, users] = await Promise.all([
      db.doc(`rooms/${event.params.roomId}`).get(),
      db.collection('users').get(),
    ]);

    const sender = users.docs.find((d) => d.id === msg.senderId)?.data();
    const preview = msg.type === 'photo'
      ? (msg.text ? `📷 ${msg.text}` : '📷 Fotka')
      : String(msg.text).slice(0, 140);

    // token -> dokument uživatele, aby šly neplatné tokeny odstranit
    const owners = new Map();
    for (const user of users.docs) {
      if (user.id === msg.senderId) continue;
      for (const token of user.get('fcmTokens') ?? []) owners.set(token, user.ref);
    }
    if (owners.size === 0) return;

    const tokens = [...owners.keys()];
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: room.get('name') ?? 'Movitech',
        body: `${sender?.displayName ?? 'Někdo'}: ${preview}`,
      },
      data: {roomId: event.params.roomId},
      apns: {payload: {aps: {sound: 'default'}}},
    });

    await Promise.all(result.responses.map((r, i) =>
      !r.success && DEAD_TOKEN_CODES.includes(r.error?.code)
        ? owners.get(tokens[i]).update({fcmTokens: FieldValue.arrayRemove(tokens[i])})
        : null));
  });
