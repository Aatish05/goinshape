import 'package:flutter/material.dart';
import '../../services/db.dart';
import '../../utils/safe_flags.dart';

class Food {
  final String name;
  final int kcalPer100g;
  final int proteinG;
  final int carbsG;
  final int fatG;
  Food(this.name, this.kcalPer100g, this.proteinG, this.carbsG, this.fatG);
}

final List<Food> kFoods = [
  Food('Apple', 52, 0, 14, 0),
  Food('Banana', 89, 1, 23, 0),
  Food('Chicken Breast (grilled)', 165, 31, 0, 4),
  Food('Rice (cooked)', 130, 2, 28, 0),
  Food('Egg (boiled)', 155, 13, 1, 11),
  Food('Oats (dry)', 389, 17, 66, 7),
];

class CounterTab extends StatefulWidget {
  final int userId;
  const CounterTab({super.key, required this.userId});

  @override
  State<CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<CounterTab> {
  final Map<String, int> _grams = {};
  final TextEditingController _search = TextEditingController();
  List<Map<String, Object?>> _todayEntries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final f in kFoods) {
      _grams[f.name] = 0;
    }
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await AppDatabase.instance.entriesForDay(widget.userId, DateTime.now());
    if (!mounted) return;
    setState(() {
      _todayEntries = entries;
      _loading = false;
    });
  }

  void _inc(Food f) => setState(() => _grams[f.name] = (_grams[f.name] ?? 0) + 100);
  void _dec(Food f) => setState(() {
    final g = (_grams[f.name] ?? 0) - 100;
    _grams[f.name] = g < 0 ? 0 : g;
  });

  Future<void> _addFood(Food f) async {
    final grams = (_grams[f.name] ?? 0);
    if (grams <= 0) return;
    await AppDatabase.instance.addEntry(
      userId: widget.userId,
      date: DateTime.now(),
      foodName: f.name,
      grams: grams.toDouble(),
      kcalPer100g: f.kcalPer100g,
    );
    setState(() => _grams[f.name] = 0);
    await _load();

    // Desktop-safe: show entries as full page; Mobile: show as bottom sheet
    if (desktopSafeMode) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TodayEntriesPage(userId: widget.userId),
      ));
    } else {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => TodayEntriesSheet(
          entries: _todayEntries,
          onEdit: (row) async {
            Navigator.pop(ctx);
            await _editEntry(row);
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => TodayEntriesSheet(entries: _todayEntries, onEdit: _editEntry, onDelete: (id) => _deleteEntry(id)),
            );
          },
          onDelete: (id) async {
            await _deleteEntry(id);
            if (!mounted) return;
            Navigator.pop(ctx);
            showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => TodayEntriesSheet(entries: _todayEntries, onEdit: _editEntry, onDelete: (id) => _deleteEntry(id)),
            );
          },
        ),
      );
    }
  }

  Future<void> _editEntry(Map<String, Object?> row) async {
    final id = row['id'] as int;
    final grams = (row['grams'] as num).toDouble();
    final ctrl = TextEditingController(text: grams.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit grams'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Grams', hintText: 'e.g., 150'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final newGrams = double.tryParse(ctrl.text.trim());
    if (newGrams == null || newGrams <= 0) return;
    await AppDatabase.instance.updateEntry(entryId: id, grams: newGrams);
    await _load();
  }

  Future<void> _deleteEntry(int id) async {
    await AppDatabase.instance.deleteEntry(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final q = _search.text.trim().toLowerCase();
    final foods = q.isEmpty ? kFoods : kFoods.where((f) => f.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search food (e.g., apple, rice)',
              labelText: 'Search',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text('Add food', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          if (foods.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No foods match your search.'),
            )
          else
            ListView.separated(
              itemCount: foods.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final f = foods[index];
                final grams = _grams[f.name] ?? 0;
                final kcal = (f.kcalPer100g * grams / 100).round();

                return LayoutBuilder(
                  builder: (context, cons) {
                    final narrow = cons.maxWidth < 360;

                    final content = narrow
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(child: Text(f.name[0].toUpperCase())),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('${f.kcalPer100g} kcal/100g · P${f.proteinG} C${f.carbsG} F${f.fatG}\n$grams g → $kcal kcal',
                                    style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: _CounterControls(
                              grams: grams,
                              onMinus: () => _dec(f),
                              onPlus: () => _inc(f),
                              onAdd: () => _addFood(f),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Row(
                      children: [
                        CircleAvatar(child: Text(f.name[0].toUpperCase())),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${f.kcalPer100g} kcal/100g · P${f.proteinG} C${f.carbsG} F${f.fatG}\n$grams g → $kcal kcal',
                                  style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          fit: FlexFit.loose,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: _CounterControls(
                              grams: grams,
                              onMinus: () => _dec(f),
                              onPlus: () => _inc(f),
                              onAdd: () => _addFood(f),
                            ),
                          ),
                        ),
                      ],
                    );

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 6))],
                      ),
                      child: content,
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (desktopSafeMode) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TodayEntriesPage(userId: widget.userId),
            ));
          } else {
            showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => TodayEntriesSheet(entries: _todayEntries, onEdit: _editEntry, onDelete: (id) => _deleteEntry(id)),
            );
          }
        },
        icon: const Icon(Icons.today),
        label: const Text('Today\'s entries'),
      ),
    );
  }
}

class _CounterControls extends StatelessWidget {
  final int grams;
  final VoidCallback onMinus, onPlus, onAdd;
  const _CounterControls({required this.grams, required this.onMinus, required this.onPlus, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove), tooltip: '-100 g', onPressed: grams <= 0 ? null : onMinus),
        Expanded(child: Text('$grams g', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add), tooltip: '+100 g', onPressed: onPlus),
      ]),
      const SizedBox(height: 4),
      SizedBox(width: double.infinity, height: 36, child: FilledButton.tonal(onPressed: onAdd, child: const Text('Add'))),
    ]);
  }
}

/// Bottom sheet content (mobile/tablet)
class TodayEntriesSheet extends StatelessWidget {
  final List<Map<String, Object?>> entries;
  final Future<void> Function(Map<String, Object?> row) onEdit;
  final Future<void> Function(int id) onDelete;
  const TodayEntriesSheet({super.key, required this.entries, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (s, e) => s + (e['kcal_total'] as int));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Today\'s entries', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Total today: $total kcal', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Flexible(
            child: entries.isEmpty
                ? const Center(child: Text('No entries yet.'))
                : ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final e = entries[i];
                final id = e['id'] as int;
                final name = e['food_name'] as String;
                final grams = (e['grams'] as num).toDouble();
                final kcal = e['kcal_total'] as int;
                return Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text('${grams.toStringAsFixed(0)} g • $kcal kcal'),
                    trailing: Wrap(spacing: 8, children: [
                      IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit), onPressed: () => onEdit(e)),
                      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => onDelete(id)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Full page for desktop-safe mode
class TodayEntriesPage extends StatefulWidget {
  final int userId;
  const TodayEntriesPage({super.key, required this.userId});

  @override
  State<TodayEntriesPage> createState() => _TodayEntriesPageState();
}

class _TodayEntriesPageState extends State<TodayEntriesPage> {
  List<Map<String, Object?>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppDatabase.instance.entriesForDay(widget.userId, DateTime.now());
    if (!mounted) return;
    setState(() {
      _entries = e;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, Object?> row) async {
    final id = row['id'] as int;
    final grams = (row['grams'] as num).toDouble();
    final ctrl = TextEditingController(text: grams.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit grams'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Grams', hintText: 'e.g., 150'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final newGrams = double.tryParse(ctrl.text.trim());
    if (newGrams == null || newGrams <= 0) return;
    await AppDatabase.instance.updateEntry(entryId: id, grams: newGrams);
    await _load();
  }

  Future<void> _delete(int id) async {
    await AppDatabase.instance.deleteEntry(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final total = _entries.fold<int>(0, (s, e) => s + (e['kcal_total'] as int));
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s entries')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: Text('Total today: $total kcal')),
            const SizedBox(height: 8),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('No entries yet.'))
                  : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final e = _entries[i];
                  final id = e['id'] as int;
                  final name = e['food_name'] as String;
                  final grams = (e['grams'] as num).toDouble();
                  final kcal = e['kcal_total'] as int;
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('${grams.toStringAsFixed(0)} g • $kcal kcal'),
                      trailing: Wrap(spacing: 8, children: [
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit), onPressed: () => _edit(e)),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(id)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
