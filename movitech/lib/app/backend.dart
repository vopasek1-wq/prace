import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/config.dart';
import '../demo/demo_backend.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/firebase_chat_repository.dart';
import '../features/drive/data/gateway_photo_store.dart';
import '../features/drive/data/photo_cache.dart';
import '../features/drive/data/photo_store.dart';
import '../features/notifications/push_service.dart';
import '../firebase_options.dart';

/// Všechny služby aplikace pohromadě. Ostrá verze = Firebase + brána k hlavnímu Google Disku,
/// demo verze = vše v paměti.
class Backend {
  const Backend({
    required this.auth,
    required this.chat,
    required this.users,
    required this.photos,
    this.push,
    this.isDemo = false,
  });

  final AuthRepository auth;
  final ChatRepository chat;
  final UserDirectory users;
  final PhotoStore photos;
  final PushService? push;
  final bool isDemo;
}

Future<Backend> createFirebaseBackend() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

  final firebaseAuth = FirebaseAuth.instance;
  final auth = FirebaseAuthRepository(firebaseAuth, db);
  await auth.init();
  final users = FirebaseUserDirectory(db);
  return Backend(
    auth: auth,
    chat: FirebaseChatRepository(db, firebaseAuth),
    users: users,
    photos: GatewayPhotoStore(
      gatewayUrl: AppConfig.photoGatewayUrl,
      idToken: () async => firebaseAuth.currentUser?.getIdToken(),
      cache: DiskPhotoCache(),
    ),
    push: AppConfig.enablePush ? PushService(db) : null,
  );
}

Future<Backend> createDemoBackend({bool simulateTeammates = true}) async {
  final demo = DemoBackend(simulateTeammates: simulateTeammates);
  await demo.seedPhotos();
  return Backend(
    auth: DemoAuthRepository(demo),
    chat: DemoChatRepository(demo),
    users: DemoUserDirectory(demo),
    photos: DemoPhotoStore(demo),
    isDemo: true,
  );
}
