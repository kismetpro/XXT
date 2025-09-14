import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xbt_client/config.dart';

late String baseURL;

// 初始化baseURL
Future<void> initBaseURL() async {
  baseURL = (await prefs.getString('base_url')) ?? config_baseURL;
}

int activesLimit = 5;
SharedPreferencesAsync prefs = SharedPreferencesAsync();

Map<String, String> IMAGEHEADER = {
  "Referer": "https://mooc1-1.chaoxing.com/",
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
};

loadStateChangedfunc(state) {
  if (state.extendedImageLoadState == LoadState.loading) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(3.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
  if (state.extendedImageLoadState == LoadState.failed) {
    return ExtendedImage.asset(
      "assets/images/unsupport.png",
    );
  }
}

enum SignType {
  normal(0, "普通签到", Icons.radio_button_checked_rounded),
  photo(1, "照片签到", Icons.photo_camera),
  qrCode(2, "二维码签到", Icons.qr_code),
  gesture(3, "手势签到", Icons.pattern),
  location(4, "位置签到", Icons.location_on_rounded),
  code(5, "签到码签到", Icons.password);

  final int id;
  final String name;
  final IconData icon;

  const SignType(this.id, this.name, this.icon);

  static SignType fromId(int id) {
    return SignType.values.firstWhere((type) => type.id == id);
  }
}

List<Map<String, dynamic>> locationPreset = config_locationPreset;
