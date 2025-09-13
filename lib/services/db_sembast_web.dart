import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _db;

  final _users   = intMapStoreFactory.store('users');   // key: int
  final _profile = intMapStoreFactory.store('profile'); // key: user_id
  final _entries = intMapStoreFactory.store('entries'); // key: int

  Future<void> ensureInitialized() async {
    if (_db != null) return;
    _db = await databaseFactoryWeb.openDatabase('goinshape.db');
  }

  Database get db => _db!;

  Future<void> deleteDatabaseFile() async {
    await _db?.close();
    _db = null;
    await databaseFactoryWeb.deleteDatabase('goinshape.db');
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- Users ----------
  Future<int> registerUser({required String name, required String email, required String password}) async {
    final dup = await _users.find(db, finder: Finder(filter: Filter.equals('email', email.toLowerCase().trim()), limit: 1));
    if (dup.isNotEmpty) { throw StateError('Email already registered'); }
    return (await _users.add(db, {'name': name, 'email': email.toLowerCase().trim(), 'password': password.trim()})) as int;
  }

  Future<int?> loginUser({required String email, required String password}) async {
    final rows = await _users.find(db, finder: Finder(
        filter: Filter.and([Filter.equals('email', email.toLowerCase().trim()), Filter.equals('password', password.trim())]), limit: 1));
    return rows.isEmpty ? null : rows.first.key as int;
  }

  Future<Map<String, Object?>?> getUser(int userId) async {
    final r = await _users.record(userId).get(db) as Map<String, Object?>?;
    return r == null ? null : {'id': userId, ...r};
  }

  // ---------- Profile ----------
  Future<Map<String, Object?>?> getProfile(int userId) async {
    final r = await _profile.record(userId).get(db) as Map<String, Object?>?;
    return r == null ? null : {'user_id': userId, ...r};
  }

  Future<void> upsertProfile({
    required int userId,
    required String sex,
    required int age,
    required int heightCm,
    required double weightKg,
    required String goal,
    required double ratePerWeek,
  }) async {
    final exist = await getProfile(userId);
    await _profile.record(userId).put(db, {
      'sex': sex,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal,
      'target_rate_kg_per_week': ratePerWeek,
      'sedentary_notify': (exist?['sedentary_notify'] as int?) ?? 0,
    });
  }

  Future<void> setSedentaryNotify(int userId, bool v) async {
    final exist = await getProfile(userId) ?? {};
    exist['sedentary_notify'] = v ? 1 : 0;
    await _profile.record(userId).put(db, exist);
  }

  Future<bool> getSedentaryNotify(int userId) async {
    final p = await getProfile(userId);
    return ((p?['sedentary_notify'] as int?) ?? 0) == 1;
  }

  // ---------- Entries ----------
  Future<void> addEntry({required int userId, required DateTime date, required String foodName, required double grams, required int kcalPer100g}) async {
    final total = (kcalPer100g * grams / 100).round();
    await _entries.add(db, {
      'user_id': userId, 'date': _date(date), 'food_name': foodName,
      'grams': grams, 'kcal_per_100g': kcalPer100g, 'kcal_total': total
    });
  }

  Future<void> updateEntry({required int entryId, required double grams}) async {
    final rec = await _entries.record(entryId).get(db) as Map<String, Object?>?;
    if (rec == null) return;
    final per100 = rec['kcal_per_100g'] as int;
    final total = (per100 * grams / 100).round();
    await _entries.record(entryId).put(db, {...rec, 'grams': grams, 'kcal_total': total});
  }

  Future<void> deleteEntry(int id) => _entries.record(id).delete(db);

  Future<List<Map<String, Object?>>> entriesForDay(int userId, DateTime date) async {
    final qs = await _entries.find(db, finder: Finder(filter: Filter.and([
      Filter.equals('user_id', userId), Filter.equals('date', _date(date))]), sortOrders: [SortOrder(Field.key, false)]));
    return qs.map((r) => {'id': r.key, ...r.value}).toList();
  }

  Future<int> totalForDay(int userId, DateTime date) async {
    final qs = await _entries.find(db, finder: Finder(filter: Filter.and([
      Filter.equals('user_id', userId), Filter.equals('date', _date(date))])));
    var sum = 0; for (final r in qs) { sum += (r.value['kcal_total'] as int?) ?? 0; } return sum;
  }

  Future<Map<DateTime, int>> last7Totals(int userId, DateTime endIncl) async {
    final out = <DateTime, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = DateTime(endIncl.year, endIncl.month, endIncl.day).subtract(Duration(days: i));
      out[d] = await totalForDay(userId, d);
    }
    return out;
  }
}
