// lib/services/db.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Desktop (Windows/Linux/macOS)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Web (Chrome)
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _db;

  Future<void> ensureInitialized() async {
    if (_db != null) return;

    // ---- Choose the right database factory per platform ----
    if (kIsWeb) {
      // IndexedDB-backed implementation for web.
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      // Mobile platforms already provide a factory via sqflite.
      // Desktop needs FFI.
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    }

    final path = await _resolvePath();

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE profile (
            user_id INTEGER PRIMARY KEY,
            sex TEXT DEFAULT 'male',
            age INTEGER,
            height_cm INTEGER,
            weight_kg REAL,
            goal TEXT DEFAULT 'maintain',                -- 'lose' | 'gain' | 'maintain'
            target_rate_kg_per_week REAL DEFAULT 0,      -- negative for lose
            sedentary_notify INTEGER DEFAULT 0,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            date TEXT NOT NULL,                          -- YYYY-MM-DD
            food_name TEXT NOT NULL,
            grams REAL NOT NULL,
            kcal_per_100g INTEGER NOT NULL,
            kcal_total INTEGER NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');

        await db.execute(
          'CREATE INDEX idx_entries_user_date ON entries(user_id, date);',
        );
      },
    );
  }

  Future<String> _resolvePath() async {
    // On web the "path" is virtual (IndexedDB); a simple file name is fine.
    if (kIsWeb) return 'goinshape.db';
    final dir = await getDatabasesPath();
    return p.join(dir, 'goinshape.db');
  }

  Database get db => _db!;

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final path = await _resolvePath();
    await databaseFactory.deleteDatabase(path);
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ------------------- Users / Auth -------------------
  Future<int> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    return db.insert('users', {
      'name': name,
      'email': email.toLowerCase().trim(),
      'password': password.trim(), // NOTE: hash in real apps
    });
  }

  Future<int?> loginUser({
    required String email,
    required String password,
  }) async {
    final rows = await db.query(
      'users',
      where: 'email=? AND password=?',
      whereArgs: [email.toLowerCase().trim(), password.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<Map<String, Object?>?> getUser(int userId) async {
    final rows =
    await db.query('users', where: 'id=?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // ------------------- Profile -------------------
  Future<Map<String, Object?>?> getProfile(int userId) async {
    final rows = await db.query('profile',
        where: 'user_id=?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertProfile({
    required int userId,
    required String sex,
    required int age,
    required int heightCm,
    required double weightKg,
    required String goal, // lose/gain/maintain
    required double ratePerWeek, // negative for lose, positive for gain
  }) async {
    final map = {
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
      await db.insert('profile', map);
    } else {
      await db.update('profile', map,
          where: 'user_id=?', whereArgs: [userId]);
    }
  }

  Future<void> setSedentaryNotify(int userId, bool value) async {
    final exists = await getProfile(userId);
    final map = {'sedentary_notify': value ? 1 : 0, 'user_id': userId};
    if (exists == null) {
      await db.insert('profile', map);
    } else {
      await db.update('profile', map,
          where: 'user_id=?', whereArgs: [userId]);
    }
  }

  Future<bool> getSedentaryNotify(int userId) async {
    final p = await getProfile(userId);
    final v = (p?['sedentary_notify'] as int?) ?? 0;
    return v == 1;
  }

  // ------------------- Entries -------------------
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
      'date': _dateOnly(date),
      'food_name': foodName,
      'grams': grams,
      'kcal_per_100g': kcalPer100g,
      'kcal_total': kcalTotal,
    });
  }

  Future<void> updateEntry({
    required int entryId,
    required double grams,
  }) async {
    final row = (await db
        .query('entries', where: 'id=?', whereArgs: [entryId], limit: 1))
        .first;
    final per100 = row['kcal_per_100g'] as int;
    final total = (per100 * grams / 100).round();
    await db.update('entries', {'grams': grams, 'kcal_total': total},
        where: 'id=?', whereArgs: [entryId]);
  }

  Future<void> deleteEntry(int entryId) async {
    await db.delete('entries', where: 'id=?', whereArgs: [entryId]);
  }

  Future<List<Map<String, Object?>>> entriesForDay(
      int userId, DateTime date) async {
    return db.query('entries',
        where: 'user_id=? AND date=?',
        whereArgs: [userId, _dateOnly(date)],
        orderBy: 'id DESC');
  }

  Future<int> totalForDay(int userId, DateTime date) async {
    final res = await db.rawQuery(
      'SELECT IFNULL(SUM(kcal_total),0) AS sumk FROM entries WHERE user_id=? AND date=?',
      [userId, _dateOnly(date)],
    );
    return (res.first['sumk'] as int?) ?? 0;
  }

  Future<Map<DateTime, int>> last7Totals(int userId, DateTime endIncl) async {
    final map = <DateTime, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = endIncl.subtract(Duration(days: i));
      map[DateTime(d.year, d.month, d.day)] = await totalForDay(userId, d);
    }
    return map;
  }
}
