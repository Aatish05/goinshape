import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _db;

  Future<String> _resolvePath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, 'goinshape.db');
  }

  Future<void> ensureInitialized() async {
    if (_db != null) return;

    // Desktop: use FFI
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolvePath();
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE profile(
          user_id INTEGER PRIMARY KEY,
          sex TEXT,
          age INTEGER,
          height_cm INTEGER,
          weight_kg REAL,
          goal TEXT,
          target_rate_kg_per_week REAL,
          sedentary_notify INTEGER DEFAULT 0,
          FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          food_name TEXT NOT NULL,
          grams REAL NOT NULL,
          kcal_per_100g INTEGER NOT NULL,
          kcal_total INTEGER NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX idx_entries_user_date ON entries(user_id, date);');
    });
  }

  Database get db => _db!;

  Future<void> deleteDatabaseFile() async {
    final path = await _resolvePath();
    await close();
    await databaseFactory.deleteDatabase(path);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- Users/Auth ----------
  Future<int> registerUser({required String name, required String email, required String password}) =>
      db.insert('users', {'name': name, 'email': email.toLowerCase().trim(), 'password': password.trim()});

  Future<int?> loginUser({required String email, required String password}) async {
    final r = await db.query('users', where: 'email=? AND password=?', whereArgs: [email.toLowerCase().trim(), password.trim()], limit: 1);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  Future<Map<String, Object?>?> getUser(int userId) async {
    final r = await db.query('users', where: 'id=?', whereArgs: [userId], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  // ---------- Profile ----------
  Future<Map<String, Object?>?> getProfile(int userId) async {
    final r = await db.query('profile', where: 'user_id=?', whereArgs: [userId], limit: 1);
    return r.isEmpty ? null : r.first;
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
    final data = {
      'user_id': userId,
      'sex': sex,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal,
      'target_rate_kg_per_week': ratePerWeek,
    };
    final exists = await getProfile(userId);
    if (exists == null) {
      await db.insert('profile', data);
    } else {
      await db.update('profile', data, where: 'user_id=?', whereArgs: [userId]);
    }
  }

  Future<void> setSedentaryNotify(int userId, bool v) async {
    final exists = await getProfile(userId);
    if (exists == null) {
      await db.insert('profile', {'user_id': userId, 'sedentary_notify': v ? 1 : 0});
    } else {
      await db.update('profile', {'sedentary_notify': v ? 1 : 0}, where: 'user_id=?', whereArgs: [userId]);
    }
  }

  Future<bool> getSedentaryNotify(int userId) async {
    final p = await getProfile(userId);
    final v = (p?['sedentary_notify'] as int?) ?? 0;
    return v == 1;
  }

  // ---------- Entries ----------
  Future<void> addEntry({
    required int userId,
    required DateTime date,
    required String foodName,
    required double grams,
    required int kcalPer100g,
  }) async {
    final kcalTotal = (kcalPer100g * grams / 100).round();
    await db.insert('entries', {
      'user_id': userId,
      'date': _date(date),
      'food_name': foodName,
      'grams': grams,
      'kcal_per_100g': kcalPer100g,
      'kcal_total': kcalTotal,
    });
  }

  Future<void> updateEntry({required int entryId, required double grams}) async {
    final row = (await db.query('entries', where: 'id=?', whereArgs: [entryId], limit: 1)).first;
    final p100 = row['kcal_per_100g'] as int;
    final total = (p100 * grams / 100).round();
    await db.update('entries', {'grams': grams, 'kcal_total': total}, where: 'id=?', whereArgs: [entryId]);
  }

  Future<void> deleteEntry(int id) => db.delete('entries', where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> entriesForDay(int userId, DateTime date) =>
      db.query('entries', where: 'user_id=? AND date=?', whereArgs: [userId, _date(date)], orderBy: 'id DESC');

  Future<int> totalForDay(int userId, DateTime date) async {
    final res = await db.rawQuery(
      'SELECT IFNULL(SUM(kcal_total),0) AS s FROM entries WHERE user_id=? AND date=?',
      [userId, _date(date)],
    );
    return (res.first['s'] as int?) ?? 0;
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
