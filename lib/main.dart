import 'dart:async';
import 'package:flutter/material.dart';
import 'services/db.dart';
import 'services/session.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/profile_setup_page.dart';
import 'pages/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoinShapeApp());
}

class GoinShapeApp extends StatelessWidget {
  const GoinShapeApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorSchemeSeed: const Color(0xFF5E86FF),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    return MaterialApp(
      title: 'GoinShape',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const _BootstrapGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();
  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late Future<_Boot> _future;
  @override
  void initState() {
    super.initState();
    _future = _boot();
  }

  Future<_Boot> _boot() async {
    try {
      await AppDatabase.instance.ensureInitialized().timeout(const Duration(seconds: 8));
      final uid = await Session.currentUserId().timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (uid == null) return _Boot.login();
      final profile = await AppDatabase.instance.getProfile(uid);
      if (profile == null) return _Boot.profileSetup(uid);
      return _Boot.home(uid);
    } catch (e) {
      return _Boot.error(e.toString());
    }
  }

  Future<void> _reset() async {
    await AppDatabase.instance.deleteDatabaseFile();
    await Session.setUserId(null);
    setState(() => _future = _boot());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Boot>(
      future: _future,
      builder: (context, s) {
        if (!s.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final b = s.data!;
        if (b.error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('We couldn’t start the app.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(b.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt), label: const Text('Reset local data and retry')),
                ]),
              ),
            ),
          );
        }
        if (b.mode == _BootMode.login) return const LoginPage();
        if (b.mode == _BootMode.profileSetup) return ProfileSetupPage(userId: b.userId!);
        return Shell(userId: b.userId!);
      },
    );
  }
}

enum _BootMode { login, profileSetup, home, err }

class _Boot {
  final _BootMode mode;
  final int? userId;
  final String? error;
  _Boot.login() : mode = _BootMode.login, userId = null, error = null;
  _Boot.profileSetup(this.userId) : mode = _BootMode.profileSetup, error = null;
  _Boot.home(this.userId) : mode = _BootMode.home, error = null;
  _Boot.error(this.error) : mode = _BootMode.err, userId = null;
}
