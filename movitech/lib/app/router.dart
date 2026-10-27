import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/chat/domain/message.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/drive/presentation/photo_viewer_screen.dart';
import '../features/rooms/presentation/room_list_screen.dart';
import '../features/search/presentation/search_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      final signedIn = auth.value != null;
      if (!signedIn) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/rooms';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/rooms',
        builder: (_, _) => const RoomListScreen(),
        routes: [
          GoRoute(
            path: ':roomId',
            builder: (_, state) => ChatScreen(roomId: state.pathParameters['roomId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (_, state) => SearchScreen(initialRoomId: state.uri.queryParameters['room']),
      ),
      GoRoute(
        path: '/photo',
        builder: (_, state) => PhotoViewerScreen(photo: state.extra! as PhotoRef),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
