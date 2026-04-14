import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'biometric_gate.dart';
import 'package:portones_mym/core/auth/auth_providers.dart'; // ajustá la ruta

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final _gate = BiometricGate();

  bool _unlocked = false;
  bool _busy = false;

  DateTime? _pausedAt; // para no molestar si salís 2 segundos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _shouldLock => ref.read(isLoggedInProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final t = _pausedAt;
      final wasAwayLong = t != null &&
          DateTime.now().difference(t) > const Duration(seconds: 30);

      if (_shouldLock && wasAwayLong) {
        _unlocked = false;
        _maybeUnlock();
      }
    }
  }

  Future<void> _maybeUnlock() async {
    if (!_shouldLock) return;
    if (_unlocked || _busy) return;

    setState(() => _busy = true);
    final ok = await _gate.unlock(reason: 'Desbloqueá la app para continuar');
    setState(() {
      _busy = false;
      _unlocked = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    // Si no hay sesión Google, no bloquea
    if (!isLoggedIn) return widget.child;

    // Si ya desbloqueó, pasa
    if (_unlocked) return widget.child;

    // Pantalla bloqueada
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 12),
              const Text(
                'App bloqueada',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('Usá tu huella o PIN para continuar.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _maybeUnlock,
                child: Text(_busy ? 'Verificando...' : 'Desbloquear'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}