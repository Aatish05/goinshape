import 'package:flutter/material.dart';
import '../../services/db.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Create account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign up'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    setState(() { _err = null; _loading = true; });
    try {
      await AppDatabase.instance.registerUser(name: _name.text, email: _email.text, password: _pass.text);
      if (!mounted) return;
      Navigator.pop(context); // back to login
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Please log in.')));
    } catch (e) {
      setState(() { _err = e.toString(); _loading = false; });
    }
  }
}
