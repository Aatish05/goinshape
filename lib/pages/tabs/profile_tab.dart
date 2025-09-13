import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../services/session.dart';
import '../auth/login_page.dart';
import '../profile_setup_page.dart';

class ProfileTab extends StatefulWidget {
  final int userId;
  final Map<String, Object?>? profile;
  final Future<void> Function() onChanged;
  const ProfileTab({super.key, required this.userId, required this.profile, required this.onChanged});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, Object?>? _user;
  Map<String, Object?>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppDatabase.instance.getUser(widget.userId);
    final prof = await AppDatabase.instance.getProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _user = user;
      _profile = prof;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final name = (_user?['name'] as String?) ?? 'User';
    final email = (_user?['email'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(radius: 34, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U')),
              const SizedBox(height: 10),
              Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_profile != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _row('Sex', '${_profile!['sex'] ?? '-'}'),
                _row('Age', '${_profile!['age'] ?? '-'}'),
                _row('Height', '${_profile!['height_cm'] ?? '-'} cm'),
                _row('Weight', '${_profile!['weight_kg'] ?? '-'} kg'),
                _row('Goal', '${_profile!['goal'] ?? '-'}'),
                _row('Rate', '${_profile!['target_rate_kg_per_week'] ?? 0} kg/week'),
              ]),
            ),
          )
        else
          const Text('No profile yet.'),

        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
            await widget.onChanged();
            await _load();
          },
          child: const Text('Edit profile'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          onPressed: () async {
            await Session.setUserId(null);
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 120, child: Text(a, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(b, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
