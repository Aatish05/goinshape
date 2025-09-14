import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../services/session.dart';
import '../shell.dart';
import '../auth/register_page.dart';
import '../profile_setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GoInShape', style: TextStyle(fontSize: 38, color:Colors.blue, fontWeight: FontWeight.w800)),
                const SizedBox(height: 66),
                const Text('Log in', style: TextStyle(fontSize: 28,color:Colors.blueAccent, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Continue'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Create account')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() { _err = null; _loading = true; });
    final id = await AppDatabase.instance.loginUser(email: _email.text, password: _pass.text);
    if (id == null) {
      setState(() { _err = 'Invalid credentials'; _loading = false; });
      return;
    }
    await Session.setUserId(id);
    final profile = await AppDatabase.instance.getProfile(id);
    if (!mounted) return;
    if (profile == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileSetupPage(userId: id)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Shell(userId: id)));
    }
  }
}
