import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'providers.dart';
import 'router.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MovitechApp extends ConsumerWidget {
  const MovitechApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final push = ref.watch(backendProvider).push;

    if (push != null) {
      push.onOpenRoom = (roomId) => router.go('/rooms/$roomId');
      push.onForeground = (title, body) => scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$title\n$body')));
      // Push se zapíná po přihlášení a vypíná po odhlášení.
      ref.listen(currentUserProvider, (prev, next) {
        if (next != null) {
          push.start(next.uid);
        } else {
          push.stop();
        }
      });
    }

    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('cs'),
      supportedLocales: const [Locale('cs'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
