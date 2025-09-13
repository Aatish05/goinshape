import 'package:flutter/material.dart';
import '../../services/db.dart';

class DashboardTab extends StatefulWidget {
  final int userId;
  final Map<String, Object?>? profile;
  const DashboardTab({super.key, required this.userId, required this.profile});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  int _dailyTarget = 2000;
  int _today = 0;
  bool _sedentary = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
    final p = widget.profile ?? await AppDatabase.instance.getProfile(widget.userId);
    final target = _computeDailyTarget(p);
    final today = await AppDatabase.instance.totalForDay(widget.userId, DateTime.now());
    final sed = await AppDatabase.instance.getSedentaryNotify(widget.userId);
    if (!mounted) return;
    setState(() {
      _dailyTarget = target;
      _today = today;
      _sedentary = sed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final percent = _dailyTarget == 0 ? 0.0 : _today / _dailyTarget;
    final percentText = (_dailyTarget == 0 ? 0 : (_today * 100 / _dailyTarget)).toStringAsFixed(0);
    final over = percent > 1.0;
    final remainAbs = (_dailyTarget - _today).abs();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(context),
          child: LayoutBuilder(
            builder: (context, cons) {
              final narrow = cons.maxWidth < 520;

              final ring = LayoutBuilder(
                builder: (context, cons2) {
                  final ringSize = (cons2.maxWidth * 0.64).clamp(140.0, 240.0);
                  final outerSize = (ringSize * 1.09).clamp(ringSize + 8, ringSize + 26);
                  final stroke = (ringSize / 12).clamp(12.0, 20.0);
                  final outerStroke = (stroke * 0.45).clamp(6.0, 10.0);

                  return SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: CircularProgressIndicator(
                            value: 1,
                            strokeWidth: stroke,
                            color: Colors.grey.shade300,
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: CircularProgressIndicator(
                            value: percent.clamp(0.0, 1.0),
                            strokeWidth: stroke,
                            color: over ? Colors.red : Theme.of(context).colorScheme.primary,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        if (over)
                          SizedBox(
                            width: outerSize,
                            height: outerSize,
                            child: CircularProgressIndicator(
                              value: (percent - 1.0).clamp(0.0, 1.0),
                              strokeWidth: outerStroke,
                              color: Colors.redAccent,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentText%',
                              style: TextStyle(
                                fontSize: (ringSize / 6.7).clamp(18.0, 34.0),
                                fontWeight: FontWeight.w900,
                                color: over ? Colors.red : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text('of daily', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );

              final right = Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: narrow ? 0 : 16, top: narrow ? 12 : 0),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    child: Column(
                      crossAxisAlignment: narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today: $_today / $_dailyTarget kcal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: narrow ? TextAlign.center : TextAlign.start,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          over ? 'Over by $remainAbs kcal' : 'Remaining $remainAbs kcal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: narrow ? TextAlign.center : TextAlign.start,
                          style: TextStyle(color: over ? Colors.red : Colors.green),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
                          children: [
                            _pill(context, Icons.local_fire_department_outlined, 'Daily target $_dailyTarget'),
                            _pill(context, Icons.calendar_view_week, 'Weekly ${_dailyTarget * 7} kcal'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return narrow ? Column(children: [ring, right]) : Row(children: [ring, right]);
            },
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(context),
          child: Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sedentary activity notification',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Switch(
                value: _sedentary,
                onChanged: (v) async {
                  setState(() => _sedentary = v);
                  await AppDatabase.instance.setSedentaryNotify(widget.userId, v);
                  // SnackBars disabled on desktop via safe mode (we keep UI quiet).
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text('Tips for today',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ..._buildTips(context,
            over: percent > 1.0,
            remainingAbs: (_dailyTarget - _today).abs(),
            goal: widget.profile?['goal'] as String?),
      ],
    );
  }

  List<Widget> _buildTips(BuildContext context,
      {required bool over, required int remainingAbs, String? goal}) {
    final items = <_TipData>[];
    if (over) {
      items.addAll([
        _TipData(icon: Icons.no_food_outlined, title: 'You’re over today',
            body: 'Consider a lighter dinner or a short walk to offset a bit.', color: Colors.red.withOpacity(.08)),
        _TipData(icon: Icons.water_drop_outlined, title: 'Hydration helps',
            body: 'Drink water before snacks to reduce extra intake.'),
      ]);
    } else {
      items.addAll([
        _TipData(icon: Icons.check_circle_outline, title: 'On track',
            body: 'You have $remainingAbs kcal remaining — plan a balanced meal.', color: Colors.green.withOpacity(.08)),
        _TipData(icon: Icons.local_dining_outlined, title: 'Protein first',
            body: 'Prioritize lean protein to stay fuller for longer.'),
      ]);
    }
    switch (goal) {
      case 'lose':
        items.add(_TipData(icon: Icons.trending_down_outlined, title: 'Small deficit daily',
            body: 'Stick to your set daily target; consistency beats extremes.'));
        break;
      case 'gain':
        items.add(_TipData(icon: Icons.fitness_center_outlined, title: 'Fuel your training',
            body: 'Spread calories across 3–4 meals with ~25–35g protein each.'));
        break;
      default:
        items.add(_TipData(icon: Icons.balance_outlined, title: 'Balance',
            body: '½ veg, ¼ protein, ¼ carbs + healthy fats.'));
    }
    if (_sedentary) {
      items.add(_TipData(icon: Icons.directions_walk_outlined, title: 'Move a little',
          body: 'Stand, stretch, or take a 5–10 minute walk this hour.'));
    }
    return items.map((t) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card(context, alt: t.color),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(t.icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(t.body, style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]),
    )).toList();
  }

  BoxDecoration _card(BuildContext c, {Color? alt}) => BoxDecoration(
    color: alt ?? Theme.of(c).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 10))],
  );

  Widget _pill(BuildContext c, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(c).colorScheme.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Theme.of(c).colorScheme.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TipData {
  final IconData icon;
  final String title;
  final String body;
  final Color? color;
  _TipData({required this.icon, required this.title, required this.body, this.color});
}
