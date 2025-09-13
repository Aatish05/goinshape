// lib/pages/tabs/weekly_tab.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../services/targets.dart';

class WeeklyTab extends StatefulWidget {
  final int userId;
  const WeeklyTab({super.key, required this.userId});

  @override
  State<WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<WeeklyTab> {
  Map<DateTime, int> _display = {};
  int _dailyTarget = 0;
  bool _isDemo = false; // true when any day is being shown with random filler

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;

    // 1) daily target from profile
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

    // 2) real last-7 totals from DB
    final real = await db.last7Totals(widget.userId, DateTime.now());

    // 3) ensure all 7 keys exist & fill zeros with random display-only values
    final filled = _fillWeekWithRandoms(real, daily);
    final anyRandom =
    _hasAnyRandom(real, filled); // true if any day was zero/missing

    setState(() {
      _dailyTarget = daily;
      _display = filled; // use this for chart + table
      _isDemo = anyRandom;
    });
  }

  /// Returns a map with **all last 7 days** present (date-only keys),
  /// where missing/zero days are replaced with random values around the target.
  Map<DateTime, int> _fillWeekWithRandoms(
      Map<DateTime, int> real, int dailyTarget) {
    final rnd = math.Random();
    final base = (dailyTarget > 0 ? dailyTarget : 2000);
    final now = DateTime.now();

    // Normalize real keys to date-only and lookups by string key.
    final normalized = <String, int>{};
    real.forEach((d, v) {
      final k = _dateKey(DateTime(d.year, d.month, d.day));
      normalized[k] = v;
    });

    final out = <DateTime, int>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final key = _dateKey(day);
      final v = normalized[key] ?? 0;

      if (v > 0) {
        out[day] = v; // keep real value
      } else {
        // --- NEW RANGE: 85%..110% of target ---
        final percent = 0.85 + rnd.nextDouble() * 0.25; // 0.85..1.10
        final n = (base * percent).round();
        out[day] = n;
      }
    }
    return out;
  }

  /// True if any day in [filled] was zero/missing in [real].
  bool _hasAnyRandom(Map<DateTime, int> real, Map<DateTime, int> filled) {
    final realKeys = real.map((d, v) =>
        MapEntry(_dateKey(DateTime(d.year, d.month, d.day)), v));
    bool changed = false;
    filled.forEach((d, v) {
      final k = _dateKey(d);
      if ((realKeys[k] ?? 0) <= 0) changed = true;
    });
    return changed;
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    final weeklyTarget = _dailyTarget * 7;
    final weeklyTotal = _display.values.fold<int>(0, (a, b) => a + b);
    final remaining = weeklyTarget - weeklyTotal;
    final over = remaining < 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Last 7 days',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              if (_isDemo)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withOpacity(.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      SizedBox(width: 6),
                      Text('Red line = exceeding intake target',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: [
              _chip(context, Icons.flag, 'Weekly target $weeklyTarget'),
              _chip(context, Icons.local_fire_department, 'This week $weeklyTotal'),
              _chip(
                context,
                over ? Icons.warning_amber : Icons.check_circle,
                over ? 'Over by ${-remaining}' : 'Remaining $remaining',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BarChart(data: _display, dailyTarget: _dailyTarget),
          const SizedBox(height: 12),
          _table(),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(.6),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(ctx).dividerColor.withOpacity(.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Theme.of(ctx).colorScheme.primary),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
          color: Theme.of(ctx).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]),
  );

  Widget _table() {
    if (_display.isEmpty) return const SizedBox.shrink();
    final rows = _display.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String _label(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: rows
            .map(
              (e) => ListTile(
            dense: true,
            title: Text(_label(e.key)),
            trailing: Text('${e.value} kcal',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        )
            .toList(),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<DateTime, int> data;
  final int dailyTarget;
  const _BarChart({required this.data, required this.dailyTarget});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('No data for last 7 days')),
      );
    }

    final items = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    double maxVal = [
      dailyTarget.toDouble(),
      ...items.map((e) => e.value.toDouble()),
    ].reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) maxVal = 1.0;

    const double chartHeight = 220.0;
    const double topPad = 10.0;
    const double labelReserve = 22.0;
    final double maxBarHeight =
    (chartHeight - topPad - labelReserve).clamp(0.0, chartHeight);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (ctx, c) {
              const double spacing = 16.0;
              const double minBarWidth = 28.0;

              final double naturalBarWidth =
                  (c.maxWidth - 20.0) / (items.length * 1.6);
              final bool useScroll = naturalBarWidth < minBarWidth;
              final double barWidth = useScroll ? minBarWidth : naturalBarWidth;

              final double targetY =
                  topPad + (1.0 - (dailyTarget / maxVal)) * maxBarHeight;

              final barsRow = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: useScroll
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceAround,
                children: items.map((e) {
                  final double h =
                  ((e.value / maxVal) * maxBarHeight).clamp(0.0, maxBarHeight);
                  final String lbl = '${e.key.month}/${e.key.day}';
                  final bool over = e.value > dailyTarget;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: useScroll ? spacing / 2 : 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            final msg = '${e.key.month}/${e.key.day}: ${e.value} kcal';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: barWidth,
                            height: h.isFinite ? h : 0.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: over
                                    ? [Colors.redAccent, Colors.red]
                                    : [
                                  Theme.of(ctx)
                                      .colorScheme
                                      .primary
                                      .withOpacity(.95),
                                  Theme.of(ctx).colorScheme.primary
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: labelReserve,
                          child: Text(lbl,
                              style: Theme.of(ctx).textTheme.labelSmall),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              final chartBody = useScroll
                  ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: (items.length * (barWidth + spacing)) + spacing,
                  child: barsRow,
                ),
              )
                  : barsRow;

              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: targetY.isFinite ? targetY : topPad,
                    child: Container(
                      height: 2,
                      color: Theme.of(ctx).colorScheme.primary.withOpacity(.25),
                    ),
                  ),
                  chartBody,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
