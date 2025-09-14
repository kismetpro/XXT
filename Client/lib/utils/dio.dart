import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:xbt_client/config.dart';
import 'package:xbt_client/pages/login_page.dart';
import 'package:xbt_client/utils/constants.dart';

var dio = Dio();

List IGNORETOKENURL = ['/login'];

BuildContext? dioContext;

InterceptorsWrapper interceptorsWrapper = InterceptorsWrapper(
  onRequest: (options, handler) async {
    options.headers['version'] = version;
    for (var ignoreUrl in IGNORETOKENURL) {
      if (options.path.contains(ignoreUrl)) {
        return handler.next(options);
      }
    }

    String? token = await prefs.getString("token");
    if (token == '') {
      SmartDialog.showToast('请先登录');
      Navigator.push(
        dioContext!,
        MaterialPageRoute(builder: (context) {
          return const LoginPage(
            showBack: false,
          );
        }),
      );
    }
    options.headers["token"] = token;
    return handler.next(options);
  },
);
