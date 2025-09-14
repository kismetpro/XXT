import 'dart:convert';

import 'package:xbt_client/utils/constants.dart';

class LocalJson {
  static setItem(String key, dynamic obj) {
    prefs.setString(key, jsonEncode(obj));
  }

  static getItem(String key) async {
    var data = await (prefs).getString(key);
    if (data == null) {
      return null;
    }
    return jsonDecode(data);
  }
}
