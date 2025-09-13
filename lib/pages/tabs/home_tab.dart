import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../services/targets.dart';

class HomeTab extends StatefulWidget {
  final int userId;
  const HomeTab({super.key, required this.userId});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, Object?>? _profile;
  int _today = 0;
  int _dailyTarget = 0;
  int _weeklyTarget = 0;
  bool _sedentary = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final prof = await db.getProfile(widget.userId);
    final total = await db.totalForDay(widget.userId, DateTime.now());
    bool sed = await db.getSedentaryNotify(widget.userId);

    int target = 0;
    if (prof != null) {
      final sex = (prof['sex'] as String?) ?? 'male';
      final age = (prof['age'] as int?) ?? 25;
      final h = (prof['height_cm'] as int?) ?? 170;
      final w = (prof['weight_kg'] as num?)?.toDouble() ?? 70.0;
      final goal = (prof['goal'] as String?) ?? 'maintain';
      final rate = (prof['target_rate_kg_per_week'] as num?)?.toDouble() ?? 0.0;
      target = computeDailyTarget(
        sex: sex,
        age: age,
        heightCm: h,
        weightKg: w,
        goal: goal,
        ratePerWeek: rate,
        sedentary: sed,
      ).round();
    }

    setState(() {
      _profile = prof;
      _today = total;
      _dailyTarget = target;
      _weeklyTarget = target * 7;
      _sedentary = sed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No profile yet. Go to the Profile tab and complete setup.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          DonutSummaryCard(
            todayKcal: _today,
            dailyTarget: _dailyTarget,
            weeklyTarget: _weeklyTarget,
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SwitchListTile(
              value: _sedentary,
              onChanged: (v) async {
                await AppDatabase.instance.setSedentaryNotify(widget.userId, v);
                setState(() => _sedentary = v);
                _load();
              },
              title: const Text('Sedentary activity'),
              secondary: const Icon(Icons.accessibility_new),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Tips for today', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          _tipCard(
            context,
            leading: Icons.check_circle_outline,
            title: _today <= _dailyTarget ? 'On track' : 'Over target',
            text: _today <= _dailyTarget
                ? 'You have ${_dailyTarget - _today} kcal remaining — plan a balanced meal.'
                : 'You are over by ${_today - _dailyTarget} kcal. Go light for the rest of the day.',
            tint: _today <= _dailyTarget ? Colors.green : Colors.red,
          ),
          _tipCard(
            context,
            leading: Icons.restaurant_menu_outlined,
            title: 'Protein first',
            text: 'Prioritize a protein-rich meal to stay full longer.',
            tint: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _tipCard(BuildContext ctx,
      {required IconData leading, required String title, required String text, required Color tint}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: tint.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        leading: Icon(leading, color: tint),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(text),
      ),
    );
  }
}

// ===== Donut widget =====
class DonutSummaryCard extends StatelessWidget {
  const DonutSummaryCard({
    super.key,
    required this.todayKcal,
    required this.dailyTarget,
    required this.weeklyTarget,
  });

  final int todayKcal;
  final int dailyTarget;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = dailyTarget <= 0 ? 0.0 : todayKcal / dailyTarget;
    final pctText = (pct * 100).round().clamp(0, 999);
    final remaining = dailyTarget - todayKcal;
    final ringColor = pct <= 1.0 ? theme.colorScheme.primary : Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 520;
            final double ringSize = isNarrow
                ? math.min(c.maxWidth - 40.0, 260.0).toDouble()
                : math.min(c.maxWidth * 0.42, 280.0).toDouble();

            final ring = SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _DonutPainter(
                      progress: pct.clamp(0.0, 1.0).toDouble(),
                      color: ringColor,
                      strokeWidth: ringSize * 0.12,
                    ),
                    size: Size.square(ringSize),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pctText%',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text('of daily', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6))),
                    ],
                  ),
                ],
              ),
            );

            final details = ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200),
              child: Column(
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text('Today: $todayKcal / $dailyTarget kcal',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: isNarrow ? TextAlign.center : TextAlign.start),
                  const SizedBox(height: 6),
                  Text(
                    remaining >= 0 ? 'Remaining $remaining kcal' : 'Over by ${remaining.abs()} kcal',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: remaining >= 0 ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: isNarrow ? WrapAlignment.center : WrapAlignment.start,
                    children: [
                      _chip(context, Icons.local_fire_department, 'Daily target $dailyTarget'),
                      _chip(context, Icons.view_week, 'Weekly $weeklyTarget kcal'),
                    ],
                  ),
                ],
              ),
            );

            return isNarrow
                ? Column(children: [Center(child: ring), const SizedBox(height: 16), details])
                : Row(children: [ring, const SizedBox(width: 20), Expanded(child: details)]);
          },
        ),
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.primary.withOpacity(.08), borderRadius: BorderRadius.circular(24)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Theme.of(ctx).colorScheme.primary),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  _DonutPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - strokeWidth) / 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFDCE0DC);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi, false, bg);
    final double sweep = 2 * math.pi * progress.clamp(0.0, 1.0).toDouble();
    if (sweep > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.color != color || old.strokeWidth != strokeWidth;
}
