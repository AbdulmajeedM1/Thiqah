import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/store.dart';
import 'src/theme.dart';
import 'src/app.dart';
import 'src/auth.dart';
import 'src/local_auth.dart';
import 'src/auth_screens.dart';
import 'src/admin_screen.dart';
import 'src/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TrustStore();
  final auth = AuthController(
    api: LocalAuthApi(),
    onAuthenticated: (user) => store.activateAccount(
      accountId: user.id,
      fullName: user.fullName,
      accountCity: user.city,
      isProvider: user.role == 'provider',
    ),
    onLogout: store.clearAccount,
  );
  runApp(TrustApp(store: store, auth: auth));
  await auth.restore();
}

class TrustApp extends StatefulWidget {
  const TrustApp({super.key, required this.store, this.auth});
  final TrustStore store;
  final AuthController? auth;

  @override
  State<TrustApp> createState() => _TrustAppState();
}

class _TrustAppState extends State<TrustApp> {
  bool launchFinished = false;
  TrustStore get store => widget.store;
  AuthController? get auth => widget.auth;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, ?auth]),
    builder: (context, _) => MaterialApp(
      key: ValueKey(auth?.user?.id ?? 'signed-out'),
      title: 'ثقة | TRUST',
      debugShowCheckedModeBanner: false,
      locale: Locale(store.english ? 'en' : 'ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: trustTheme(Brightness.light),
      darkTheme: trustTheme(Brightness.dark),
      themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => LaunchIntro(
        enabled: !launchFinished,
        onComplete: () => setState(() => launchFinished = true),
        child: child!,
      ),
      home: auth == null
          ? (store.memoryOnly
                ? TrustShell(store: store)
                : throw StateError('Authentication is required'))
          : auth!.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth!.user == null
          ? AuthScreen(store: store, auth: auth!)
          : auth!.user!.role == 'admin'
          ? AdminScreen(store: store, auth: auth!)
          : TrustShell(store: store, auth: auth),
    ),
  );
}
