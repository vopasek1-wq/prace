import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/backend.dart';
import 'app/providers.dart';
import 'core/config.dart';
import 'core/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('cs');

  final Backend backend;
  try {
    backend = AppConfig.demo ? await createDemoBackend() : await createFirebaseBackend();
  } catch (e) {
    runApp(SetupErrorApp(error: e));
    return;
  }

  runApp(ProviderScope(overrides: [backendProvider.overrideWithValue(backend)], child: const MovitechApp()));
}

/// Ukáže srozumitelnou chybu, když Firebase není nastavený (místo bílé obrazovky).
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.setupErrorTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('$error'),
                const SizedBox(height: 16),
                const Text(
                  'Postup nastavení najdete v docs/SPUSTENI.md.\nChcete aplikaci jen vyzkoušet? Spusťte ji s --dart-define=DEMO=true.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
