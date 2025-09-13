import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../profile_setup_page.dart';

class ProfileTab extends StatefulWidget {
  final int userId;
  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, Object?>? _user;
  Map<String, Object?>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final u = await db.getUser(widget.userId);
    final p = await db.getProfile(widget.userId);
    setState(() { _user = u; _profile = p; });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(_user!['name'] as String),
              subtitle: Text(_user!['email'] as String),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _row('Sex', (_profile!['sex'] ?? '') as String),
                _row('Age', '${_profile!['age'] ?? ''}'),
                _row('Height', '${_profile!['height_cm'] ?? ''} cm'),
                _row('Weight', '${_profile!['weight_kg'] ?? ''} kg'),
                _row('Goal', (_profile!['goal'] ?? '') as String),
                _row('Rate/week', '${_profile!['target_rate_kg_per_week'] ?? ''} kg'),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileSetupPage(userId: widget.userId)));
                _load();
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => ListTile(
    dense: true,
    title: Text(k),
    trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
