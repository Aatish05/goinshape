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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Foods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ...filtered.map(_foodTile),
              const SizedBox(height: 120),
            ],
          ),
        ),

        // Floating “Today’s Activity” popout button
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _openTodaySheet,
            icon: const Icon(Icons.today),
            label: const Text("Today's activity"),
          ),
        ),
      ],
    );
  }

  Widget _foodTile(FoodItem f) {
    final double grams = _qty[f.name] ?? 0.0; // keep as double
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
              onPressed: () => setState(() =>
              _qty[f.name] = (grams - 100).clamp(0.0, 5000.0).toDouble()),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() =>
              _qty[f.name] = (grams + 100).clamp(0.0, 5000.0).toDouble()),
            ),
            FilledButton(
              onPressed: grams <= 0
                  ? null
                  : () async {
                await AppDatabase.instance.addEntry(
                  userId: widget.userId,
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

  // ---------- Popout (bottom sheet) with instant refresh ----------
  Future<void> _openTodaySheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        int rev = 0; // revision token to refresh FutureBuilder

        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            void refreshSheet() {
              sheetSetState(() {
                rev++; // new key => new future => rebuild with fresh DB data
              });
              if (mounted) setState(() {}); // also refresh page totals
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (ctx2, scrollCtrl) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx).dividerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Today's activity",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: FutureBuilder<List<Map<String, Object?>>>(
                        key: ValueKey(rev), // forces refresh
                        future: _loadToday(),
                        builder: (context, s) {
                          if (!s.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = s.data!;
                          if (items.isEmpty) {
                            return const Center(child: Text('No foods yet. Add from the list above.'));
                          }
                          return ListView.builder(
                            controller: scrollCtrl,
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final e = items[i];
                              final id = e['id'] as int;
                              final name = e['food_name'] as String;
                              final grams = (e['grams'] as num).toDouble();
                              final kcal = e['kcal_total'] as int;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('${grams.round()} g • $kcal kcal'),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit grams',
                                        icon: const Icon(Icons.edit_square),
                                        onPressed: () => _editGramsDialog(
                                          id,
                                          grams,
                                          onSaved: refreshSheet, // refresh instantly
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          await AppDatabase.instance.deleteEntry(id);
                                          refreshSheet(); // refresh instantly
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
        );
      },
    );
    if (mounted) setState(() {}); // refresh after closing sheet (totals elsewhere)
  }

  Future<void> _editGramsDialog(int entryId, double current, {VoidCallback? onSaved}) async {
    final ctrl = TextEditingController(text: current.round().toString());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit grams'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.scale),
              hintText: 'Enter grams (e.g. 250)',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final n = double.tryParse(v);
              if (n == null) return 'Numbers only';
              if (n < 0 || n > 5000) return '0 – 5000g';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final n = double.parse(ctrl.text.trim());
              await AppDatabase.instance.updateEntry(entryId: entryId, grams: n);
              onSaved?.call();                 // tell sheet to refresh immediately
              if (ctx.mounted) Navigator.pop(ctx); // close dialog only
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
