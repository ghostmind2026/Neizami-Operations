import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app/app_controller.dart';
import 'core/api/api_client.dart';
import 'core/models/bootstrap_data.dart';
import 'core/storage/session_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sessions = SessionStore();
  final api = ApiClient(sessions);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppController(api, sessions)..initialize(),
      child: const NeizamiApp(),
    ),
  );
}

class NeizamiApp extends StatelessWidget {
  const NeizamiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final branding = app.bootstrap?.branding ?? Branding.fromJson({});

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: branding.appName,
      theme: buildAppTheme(branding),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: branding.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: app.loading
              ? const SplashScreen(key: ValueKey('splash'))
              : app.authenticated
                  ? const AppShell(key: ValueKey('shell'))
                  : const LoginScreen(key: ValueKey('login')),
        ),
      ),
    );
  }
}
