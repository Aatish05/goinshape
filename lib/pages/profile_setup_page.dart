import 'package:flutter/material.dart';
import '../services/db.dart';
import '../services/session.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _form = GlobalKey<FormState>();

  String _sex = 'male';
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController(); // cm
  final _weightCtrl = TextEditingController(); // kg

  String _goal = 'maintain'; // lose/gain/maintain
  double _rate = 0.0; // - for lose, + for gain, 0 maintain

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('About you', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _sex,
                onChanged: (v) => setState(() => _sex = v ?? 'male'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                decoration: const InputDecoration(labelText: 'Sex', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'e.g., 25',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 10 || n > 100) return 'Enter a valid age (10–100)';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  hintText: 'height in cm (e.g., 170)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 120 || n > 230) return 'Enter height in cm (120–230)';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  hintText: 'weight in kg (e.g., 70)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 30 || n > 300) return 'Enter weight in kg (30–300)';
                  return null;
                },
              ),

              const SizedBox(height: 16),
              Text('Your goal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),

              // Goal radio
              Column(children: [
                RadioListTile<String>(
                  title: const Text('Maintain weight'),
                  value: 'maintain',
                  groupValue: _goal,
                  onChanged: (v) => setState(() { _goal = v!; _rate = 0; }),
                ),
                RadioListTile<String>(
                  title: const Text('Lose weight'),
                  value: 'lose',
                  groupValue: _goal,
                  onChanged: (v) => setState(() { _goal = v!; _rate = -0.5; }),
                ),
                if (_goal == 'lose')
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Wrap(spacing: 8, children: [
                      ChoiceChip(label: const Text('0.5 kg/week'), selected: _rate == -0.5, onSelected: (_) => setState(() => _rate = -0.5)),
                      ChoiceChip(label: const Text('1.0 kg/week'), selected: _rate == -1.0, onSelected: (_) => setState(() => _rate = -1.0)),
                      ChoiceChip(label: const Text('2.0 kg/week'), selected: _rate == -2.0, onSelected: (_) => setState(() => _rate = -2.0)),
                    ]),
                  ),
                RadioListTile<String>(
                  title: const Text('Gain weight'),
                  value: 'gain',
                  groupValue: _goal,
                  onChanged: (v) => setState(() { _goal = v!; _rate = 0.5; }),
                ),
                if (_goal == 'gain')
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Wrap(spacing: 8, children: [
                      ChoiceChip(label: const Text('0.5 kg/week'), selected: _rate == 0.5, onSelected: (_) => setState(() => _rate = 0.5)),
                      ChoiceChip(label: const Text('1.0 kg/week'), selected: _rate == 1.0, onSelected: (_) => setState(() => _rate = 1.0)),
                      ChoiceChip(label: const Text('2.0 kg/week'), selected: _rate == 2.0, onSelected: (_) => setState(() => _rate = 2.0)),
                    ]),
                  ),
              ]),

              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final uid = await Session.currentUserId();
                  if (uid == null) return;

                  await AppDatabase.instance.upsertProfile(
                    userId: uid,
                    sex: _sex,
                    age: int.parse(_ageCtrl.text.trim()),
                    heightCm: int.parse(_heightCtrl.text.trim()),
                    weightKg: double.parse(_weightCtrl.text.trim()),
                    goal: _goal,
                    ratePerWeek: _rate,
                  );

                  if (!mounted) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
