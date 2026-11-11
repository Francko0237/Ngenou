import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Activer des URLs sans le préfixe '#' pour que /admin et /nouveautes fonctionnent proprement
  usePathUrlStrategy();

  // Initialisation de Supabase via --dart-define
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: NgenouWebApp(),
    ),
  );
}

class NgenouWebApp extends ConsumerWidget {
  const NgenouWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Ngenou — Votre Tuteur IA d\'Apprentissage Intelligent',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
