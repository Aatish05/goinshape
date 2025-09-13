// lib/pages/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../services/targets.dart';
import '../profile_setup_page.dart';
import '../auth/login_page.dart';

class ProfileTab extends StatefulWidget {
  final int userId;
  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, Object?>? _user;
  Map<String, Object?>? _profile;
  int _dailyTarget = 0;

  // Visual-only switch state (does not persist)
  bool _mockSedentary = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _editNameDialog() async {
    final ctrl = TextEditingController(text: (_user?['name'] as String?) ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Enter your name'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            onFieldSubmitted: (_) => Navigator.pop(ctx), // optional
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileSetupPage(userId: widget.userId)),
              );
              if (changed == true && mounted) {
                await _load(); // pull fresh user+profile back into the tab
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final u = await db.getUser(widget.userId);
    final p = await db.getProfile(widget.userId);

    int daily = 0;
    if (p != null) {
      daily = computeDailyTarget(
        sex: (p['sex'] as String?) ?? 'male',
        age: (p['age'] as int?) ?? 25,
        heightCm: (p['height_cm'] as int?) ?? 170,
        weightKg: ((p['weight_kg'] as num?) ?? 70).toDouble(),
        goal: (p['goal'] as String?) ?? 'maintain',
        ratePerWeek: ((p['target_rate_kg_per_week'] as num?) ?? 0).toDouble(),
        sedentary: ((p['sedentary_notify'] as int?) ?? 0) == 1,
      ).round();
    }

    setState(() {
      _user = u;
      _profile = p;
      _dailyTarget = daily;
      _mockSedentary = ((p?['sedentary_notify'] as int?) ?? 0) == 1; // visual only
    });
  }

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : (first.length > 1 ? first[1] : '');
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user?['name'] as String?) ?? 'User';
    final email = (_user?['email'] as String?) ?? '';
    final p = _profile;

    // NEW: computed weekly target for the extra stat card
    final int weeklyTarget = _dailyTarget > 0 ? _dailyTarget * 7 : 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card with avatar (adaptive layout)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(.10),
                    Theme.of(context).colorScheme.primary.withOpacity(.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.35)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: LayoutBuilder(
                builder: (ctx, cons) {
                  final narrow = cons.maxWidth < 400; // phone width -> use icon only
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                        child: Text(
                          _initials(name),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Let text take as much room as needed and wrap
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              softWrap: true,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              email,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Adaptive action: icon on narrow, full button on wide
                      if (narrow)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileSetupPage(userId: widget.userId),
                              ),
                            );
                            if (changed == true && mounted) _load();
                          },
                        )
                      else
                        FilledButton.icon(
                          onPressed: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileSetupPage(userId: widget.userId),
                              ),
                            );
                            if (changed == true && mounted) _load();
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Quick stats (added Weekly target)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(context, Icons.local_fire_department, 'Daily target',
                    _dailyTarget > 0 ? '$_dailyTarget kcal' : '—'),
                _statCard(context, Icons.flag, 'Goal',
                    (p?['goal'] as String?) ?? '—'),
                _statCard(
                  context,
                  Icons.speed,
                  'Rate / wk',
                  (p?['target_rate_kg_per_week'] == null)
                      ? '—'
                      : '${(p!['target_rate_kg_per_week'] as num).toString()} kg',
                ),
                // NEW: weekly target card
                _statCard(
                  context,
                  Icons.calendar_month,
                  'Weekly target',
                  weeklyTarget > 0 ? '$weeklyTarget kcal' : '—',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _row('Sex', (p?['sex'] as String?) ?? '—'),
                  _row('Age', (p?['age']?.toString()) ?? '—'),
                  _row('Height',
                      (p?['height_cm'] == null) ? '—' : '${p!['height_cm']} cm'),
                  _row('Weight',
                      (p?['weight_kg'] == null) ? '—' : '${(p!['weight_kg'] as num).toString()} kg'),
                  SwitchListTile(
                    title: const Text('Sedentary activity notification'),
                    subtitle: const Text('Sedentary Activity Alert Notification.'),
                    value: _mockSedentary,
                    onChanged: (v) => setState(() => _mockSedentary = v), // local UI only
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sign out
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext ctx, IconData icon, String t, String v) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(ctx).dividerColor.withOpacity(.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(ctx).colorScheme.primary.withOpacity(.12),
            child: Icon(icon, size: 18, color: Theme.of(ctx).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t,
                    style: Theme.of(ctx)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.black54)),
                Text(v,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => ListTile(
    dense: true,
    title: Text(k),
    trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
