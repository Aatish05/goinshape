import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kUserId = 'user_id';

  static Future<int?> currentUserId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUserId);
  }

  static Future<void> setUserId(int? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_kUserId);
    } else {
      await p.setInt(_kUserId, id);
    }
  }
}
