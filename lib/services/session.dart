import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kUserId = 'user_id';

  static Future<void> setUserId(int? id) async {
    final sp = await SharedPreferences.getInstance();
    if (id == null) {
      await sp.remove(_kUserId);
    } else {
      await sp.setInt(_kUserId, id);
    }
  }

  static Future<int?> currentUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }
}
