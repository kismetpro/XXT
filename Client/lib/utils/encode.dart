import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart';

Future<String> encodeString(String content) async {
  final publicPem = await rootBundle.loadString('assets/keys/public.pem');
  dynamic publicKey = RSAKeyParser().parse(publicPem);
  final encrypter = Encrypter(RSA(publicKey: publicKey));
  return encrypter.encrypt(content).base64; //返回加密后的base64格式文件
}

Future<String> encodeToken(String mobile, String password) async {
  return encodeString(jsonEncode({
    "mobile": mobile,
    "password": password,
  }));
}
