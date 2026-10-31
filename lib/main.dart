import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/store.dart';
import 'src/app.dart';
import 'src/auth.dart';
import 'src/local_auth.dart';
import 'src/auth_screens.dart';
import 'src/admin_screen.dart';

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

class TrustApp extends StatelessWidget {
  const TrustApp({super.key, required this.store, this.auth});
  final TrustStore store;
  final AuthController? auth;

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
      theme: ThemeData(
        fontFamily: 'Tajawal',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F7),
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E7E6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E7E6)),
          ),
          contentPadding: const EdgeInsets.all(18),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B6E4F),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF063D2C),
          ),
          titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 14, height: 1.65),
        ),
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
