import 'package:flutter/material.dart';
import '../../services/db.dart';

class WeeklyTab extends StatefulWidget {
  final int userId;
  const WeeklyTab({super.key, required this.userId});

  @override
  State<WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<WeeklyTab> {
  Map<DateTime, int> _data = {};
  int _dailyTarget = 2000;
  bool _loading = true;

  int _computeDailyTarget(Map<String, Object?>? p) {
    final age = (p?['age'] as num?)?.toInt() ?? 25;
    final h = (p?['height_cm'] as num?)?.toInt() ?? 170;
    final w = (p?['weight_kg'] as num?)?.toDouble() ?? 70.0;
    final sex = (p?['sex'] as String? ?? 'male');
    final goal = (p?['goal'] as String? ?? 'maintain');
    final rate = (p?['target_rate_kg_per_week'] as num?)?.toDouble() ?? 0.0;

    final bmr = sex == 'male'
        ? 10 * w + 6.25 * h - 5 * age + 5
        : 10 * w + 6.25 * h - 5 * age - 161;
    double tdee = bmr * 1.3;

    if (rate != 0) {
      tdee += 7700.0 * rate / 7.0;
    } else {
      if (goal == 'lose') tdee -= 450;
      if (goal == 'gain') tdee += 300;
    }
    final t = tdee.round();
    if (t < 900) return 900;
    if (t > 5000) return 5000;
    return t;
  }

  Future<void> _load() async {
    final totals = await AppDatabase.instance.last7Totals(widget.userId, DateTime.now());
    final profile = await AppDatabase.instance.getProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _data = totals;
      _dailyTarget = _computeDailyTarget(profile);
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final weeklyTarget = _dailyTarget * 7;
    final consumed = _data.values.fold<int>(0, (s, v) => s + v);
    final remaining = weeklyTarget - consumed;
    final overWeek = remaining < 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('This week', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, cons) {
            final narrow = cons.maxWidth < 560;
            final cards = [
              _statCard(context, 'Weekly target', '$weeklyTarget kcal', Icons.flag_outlined),
              _statCard(context, 'Consumed', '$consumed kcal', Icons.local_fire_department_outlined),
              _statCard(
                context,
                overWeek ? 'Over this week' : 'Remaining this week',
                '${remaining.abs()} kcal',
                overWeek ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: overWeek ? Colors.red.withOpacity(.10) : Colors.green.withOpacity(.10),
                iconColor: overWeek ? Colors.red : Colors.green,
              ),
            ];
            if (narrow) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 8),
                  cards[1],
                  const SizedBox(height: 8),
                  cards[2],
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[2]),
                ],
              );
            }
          },
        ),

        const SizedBox(height: 16),
        Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 420),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Consumed')),
                DataColumn(label: Text('Daily target')),
                DataColumn(label: Text('Status')),
              ],
              rows: _data.entries.map((e) {
                final c = e.value;
                final over = c > _dailyTarget;
                final status = over ? 'Over by ${c - _dailyTarget}' : 'Remaining ${_dailyTarget - c}';
                return DataRow(cells: [
                  DataCell(Text(_fmt(e.key))),
                  DataCell(Text('$c kcal')),
                  DataCell(Text('$_dailyTarget kcal')),
                  DataCell(Text(status, style: TextStyle(color: over ? Colors.red : Colors.green))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon,
      {Color? color, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}
