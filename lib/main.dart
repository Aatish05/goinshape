import 'dart:async';
import 'package:flutter/material.dart';
import 'services/db.dart';
import 'services/session.dart';
import 'pages/home_page.dart';
import 'pages/auth/login_page.dart';

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
    );
  }
}

/// Robust bootstrap gate:
/// - Initializes DB
/// - Reads current session
/// - Times out (so we never spin forever)
/// - Shows friendly error + “Reset local data” if something fails
class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late Future<_BootstrapResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
  }

  Future<_BootstrapResult> _bootstrap() async {
    try {
      // Give every step a timeout so we never hang indefinitely.
      await AppDatabase.instance.ensureInitialized()
          .timeout(const Duration(seconds: 8));

      final userId = await Session.currentUserId()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      return _BootstrapResult.ok(userId);
    } catch (e, _) {
      return _BootstrapResult.err(e.toString());
    }
  }

  Future<void> _resetAndRetry() async {
    await AppDatabase.instance.deleteDatabaseFile();
    await Session.setUserId(null);
    if (!mounted) return;
    setState(() {
      _future = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError || (snap.data?.error != null)) {
          final msg = snap.error?.toString() ?? snap.data!.error!;
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('We couldn’t start the app.',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _resetAndRetry,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset local data and retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final uid = snap.data!.userId;
        return (uid == null) ? const LoginPage() : const HomePage(firstTime: true);
      },
    );
  }
}

class _BootstrapResult {
  final int? userId;
  final String? error;
  _BootstrapResult.ok(this.userId) : error = null;
  _BootstrapResult.err(this.error) : userId = null;
}
