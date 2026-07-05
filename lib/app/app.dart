// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/security/app_lock_gate.dart';

import 'package:portones_mym/features/registro/presentation/registro_tab.dart';
import 'package:portones_mym/features/garantias/presentation/garantias_tab.dart';
import 'package:portones_mym/features/calendar/presentation/screens/calendar_home.dart';
import 'package:portones_mym/features/clients/presentation/clients_tab.dart';
import 'package:portones_mym/core/navigation/nav_key.dart';
import 'package:portones_mym/features/whatsapp/presentation/whatsapp_tab.dart';

// ✅ realtime
import 'package:portones_mym/core/sync/realtime_providers.dart';
import 'package:portones_mym/core/services/visita_watchdog.dart';

// ✅ Servicio Google
import 'package:portones_mym/core/auth/google_signin_service.dart';

class PortonesApp extends StatelessWidget {
  const PortonesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      title: 'Portones M y M',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppLockGate(child: AuthGate()),
    );
  }
}

/// ✅ Si no hay user => SignInScreen.
/// Si hay user => HomeTabs (con realtime).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashLoading();
        }

        final user = snap.data;

        if (user == null || user.isAnonymous) {
          return const SignInScreen();
        }

        // ✅ envolvemos HomeTabs con un host que inicia realtime 1 vez
        return const _HomeWithRealtime();
      },
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// ✅ Pantalla login Google (obligatoria)
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await GoogleSigninService.signIn();
      // authStateChanges() reconstruye y entra a HomeTabs
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar sesión. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portones M y M')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 54),
                const SizedBox(height: 12),
                const Text(
                  'Iniciá sesión con Google para sincronizar tus trabajos entre celulares.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.login),
                    label: Text(_loading ? 'Ingresando...' : 'Continuar con Google'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tip: Usá la MISMA cuenta Google en los 2 celulares.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha:0.7)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ Host estable: inicia realtime una sola vez al entrar a Home.
class _HomeWithRealtime extends ConsumerStatefulWidget {
  const _HomeWithRealtime();

  @override
  ConsumerState<_HomeWithRealtime> createState() => _HomeWithRealtimeState();
}

class _HomeWithRealtimeState extends ConsumerState<_HomeWithRealtime> {
  @override
  void initState() {
    super.initState();
    // ✅ inicia listener una vez (no en cada build)
    Future.microtask(() {
      if (mounted) {
        ref.read(jobsRealtimeStarterProvider);
        VisitaWatchdog.start(ref);
      }
    });
  }

  @override
  void dispose() {
    VisitaWatchdog.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeTabs();
  }
}

class HomeTabs extends ConsumerWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabIndexProvider);

    const pages = [
      CalendarHome(),
      ClientsTab(),
      RegistroTab(),
      GarantiasTab(),
      WhatsappTab(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          ref.read(homeTabIndexProvider.notifier).state = i;
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.people_alt), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Registro'),
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'Garantías'),
          NavigationDestination(
            icon: Icon(Icons.chat, color: Color(0xFF25D366)),
            label: 'WhatsApp',
          ),
          ],
      ),
    );
  }
}