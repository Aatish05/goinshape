import 'package:flutter/material.dart';
import '../services/db.dart';
import '../services/targets.dart';
import 'shell.dart';

class ProfileSetupPage extends StatefulWidget {
  final int userId;
  const ProfileSetupPage({super.key, required this.userId});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  String _sex = 'male';
  String _goal = 'maintain';
  double _rate = 0.0;          // negative for lose, positive for gain, 0 for maintain
  bool _sedentary = true;

  double _preview = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefill();
  }

  Future<void> _loadPrefill() async {
    final u = await AppDatabase.instance.getUser(widget.userId);
    if (u != null) _name.text = (u['name'] as String?) ?? '';
    _recalc();
  }

  void _recalc() {
    final age = int.tryParse(_age.text) ?? 0;
    final h = int.tryParse(_height.text) ?? 0;
    final w = double.tryParse(_weight.text) ?? 0;
    if (age > 0 && h > 0 && w > 0) {
      _preview = computeDailyTarget(
        sex: _sex,
        age: age,
        heightCm: h,
        weightKg: w,
        goal: _goal,
        ratePerWeek: _rate,
        sedentary: _sedentary,
      );
    } else {
      _preview = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Name',
                ),
                onChanged: (_) => _recalc(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.cake),
                      hintText: 'Age',
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sex,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (v) { _sex = v ?? 'male'; _recalc(); },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.wc),
                      hintText: 'Sex',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.height),
                      hintText: 'Height (cm)',
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.monitor_weight),
                      hintText: 'Weight (kg)',
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _goal,
                items: const [
                  DropdownMenuItem(value: 'lose', child: Text('Lose weight')),
                  DropdownMenuItem(value: 'maintain', child: Text('Maintain')),
                  DropdownMenuItem(value: 'gain', child: Text('Gain weight')),
                ],
                onChanged: (v) {
                  _goal = v ?? 'maintain';
                  if (_goal == 'maintain') _rate = 0;
                  _recalc();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.flag),
                  hintText: 'Goal',
                ),
              ),
              const SizedBox(height: 12),
              if (_goal != 'maintain')
                DropdownButtonFormField<double>(
                  value: _rate == 0 ? null : _rate,
                  items: (_goal == 'lose'
                      ? const [-0.5, -1.0, -2.0]
                      : const [0.5, 1.0, 2.0])
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text('${e.abs()} kg per week'),
                  ))
                      .toList(),
                  onChanged: (v) { _rate = v ?? 0.0; _recalc(); },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.speed),
                    hintText: 'Weekly rate',
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _sedentary,
                onChanged: (v) { _sedentary = v; _recalc(); },
                title: const Text('Sedentary activity (lower calories)'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.local_fire_department),
                title: const Text('Daily target (preview)'),
                trailing: Text(
                  _preview == 0 ? '--' : _preview.round().toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _preview == 0 ? null : _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save & continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    // 1) Update the user's name (this was missing)


    // 2) Save profile details
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final height = int.tryParse(_height.text.trim()) ?? 0;
    final weight = double.tryParse(_weight.text.trim()) ?? 0.0;

    await AppDatabase.instance.upsertProfile(
      userId: widget.userId,
      sex: _sex,
      age: age,
      heightCm: height,
      weightKg: weight,
      goal: _goal,
      ratePerWeek: _rate, // negative for lose, positive for gain, 0 for maintain
    );

    // 3) Store sedentary toggle
    await AppDatabase.instance.setSedentaryNotify(widget.userId, _sedentary);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => Shell(userId: widget.userId)),
          (_) => false,
    );
  }
}
