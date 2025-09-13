import 'package:flutter/material.dart';
import '../../models/food.dart';
import '../../services/db.dart';

class CounterTab extends StatefulWidget {
  final int userId;
  const CounterTab({super.key, required this.userId});

  @override
  State<CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<CounterTab> {
  String _q = '';
  final Map<String, double> _qty = {}; // name -> grams (100g steps)

  Future<List<Map<String, Object?>>> _loadToday() =>
      AppDatabase.instance.entriesForDay(widget.userId, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final filtered = kFoods
        .where((f) => f.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search foods (per 100g)',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          ...filtered.map(_foodTile),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Today's added",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _loadToday(),
            builder: (context, s) {
              if (!s.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final items = s.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('No foods yet. Add from above.'),
                );
              }
              return Column(
                children: items.map((e) {
                  final id = e['id'] as int;
                  final name = e['food_name'] as String;
                  final grams = (e['grams'] as num).toDouble();
                  final kcal = e['kcal_total'] as int;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('${grams.round()} g • $kcal kcal'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () async {
                              final newG =
                              (grams - 100).clamp(0.0, 5000.0).toDouble();
                              await AppDatabase.instance
                                  .updateEntry(entryId: id, grams: newG);
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final newG =
                              (grams + 100).clamp(0.0, 5000.0).toDouble();
                              await AppDatabase.instance
                                  .updateEntry(entryId: id, grams: newG);
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await AppDatabase.instance.deleteEntry(id);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _foodTile(FoodItem f) {
    final double grams = _qty[f.name] ?? 0.0; // ensure double
    final int kcal = (f.kcalPer100g * grams / 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                dense: true,
                title: Text(f.name),
                subtitle: Text(
                    '${f.kcalPer100g} kcal/100g  •  P ${f.protein}  C ${f.carbs}  F ${f.fat}'),
              ),
            ),
            Text('${grams.round()} g${grams == 0 ? '' : ' • $kcal kcal'}'),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() => _qty[f.name] =
                  (grams - 100).clamp(0.0, 5000.0).toDouble()),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _qty[f.name] =
                  (grams + 100).clamp(0.0, 5000.0).toDouble()),
            ),
            FilledButton(
              onPressed: grams <= 0
                  ? null
                  : () async {
                await AppDatabase.instance.addEntry(
                  userId: widget.userId, // use the prop directly
                  date: DateTime.now(),
                  foodName: f.name,
                  grams: grams,
                  kcalPer100g: f.kcalPer100g,
                );
                setState(() => _qty[f.name] = 0.0);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
