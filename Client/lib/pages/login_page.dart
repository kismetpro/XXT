import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/dio.dart';
import 'package:xbt_client/utils/encode.dart';
import 'package:xbt_client/utils/local_json.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

class LoginPage extends StatefulWidget {
  final showBack;
  const LoginPage({super.key, this.showBack = true});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    TextEditingController passwordController = TextEditingController();
    TextEditingController mobileController = TextEditingController();
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        body: SafeArea(
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "学不通",
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.primary,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(0, 0, 0, 0.2),
                              offset: Offset(1, 1),
                              blurRadius: 18,
                            )
                          ]),
                    ),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: "手机号", hintText: "请输入手机号"),
                    ),
                    TextField(
                      obscureText: true,
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: "密码",
                        hintText: "请输入学不(习)通密码",
                      ),
                    ),
                    const Text(
                        "注册即代表同意本软件收集您的第三方网站隐私信息。其中包括: 姓名，手机号，密码，课程信息等。您的密码将仅用于登录第三方网站，已经过非对称加密处理，本软件保证您的密码不会进行明文存储以及传输。"),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      margin: const EdgeInsets.only(top: 32),
                      height: 44,
                      width: double.infinity,
                      child: MaterialButton(
                        onPressed: () async {
                          String mobile = mobileController.text;
                          String password = passwordController.text;
                          SmartDialog.showLoading(msg: "登录中...");
                          String token = await encodeToken(mobile, password);
                          var resp = await dio.post("$baseURL/login", data: {
                            "token": token,
                          });
                          SmartDialog.dismiss();
                          if (!resp.data["suc"]) {
                            SmartDialog.showNotify(
                                msg: resp.data["msg"],
                                notifyType: NotifyType.failure);
                            return;
                          }
                          var localUserList =
                              await LocalJson.getItem("localUserList")!;
                          for (var i = 0; i < localUserList.length; i++) {
                            if (localUserList[i]["mobile"] == mobile) {
                              localUserList.removeAt(i);
                              break;
                            }
                          }
                          localUserList.insert(0, {
                            "token": token,
                            "mobile": mobile,
                            "uid": resp.data["data"]["uid"],
                            "name": resp.data["data"]["name"],
                            "avatar": resp.data["data"]["avatar"],
                          });
                          await prefs.clear();
                          await prefs.setString("token", token);
                          await LocalJson.setItem(
                              "localUserList", localUserList);
                          Navigator.maybePop(context);
                          SmartDialog.showNotify(
                              msg: "登录成功", notifyType: NotifyType.success);
                          if (localUserList.length > 1) {
                            Restart.restartApp();
                          }
                        },
                        child: const Text("登录 / 注册",
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                    if (widget.showBack)
                      TextButton(
                          onPressed: () {
                            Navigator.maybePop(context);
                          },
                          child: const Text("返回")),
                    // 添加分隔线和配置按钮
                    const Divider(height: 32),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await showTextInputDialog(
                          context: context,
                          title: '配置服务器地址',
                          message: '请输入服务器地址',
                          okLabel: '确定',
                          cancelLabel: '取消',
                          textFields: [
                            DialogTextField(
                              hintText: 'https://example.com',
                              initialText:
                                  await prefs.getString('base_url') ?? baseURL,
                            ),
                          ],
                        );
                        if (result != null && result.isNotEmpty) {
                          await prefs.setString('base_url', result[0]);
                          baseURL = result[0]; // 直接更新当前运行时的baseURL
                          SmartDialog.showNotify(
                            msg: "服务器地址已更新",
                            notifyType: NotifyType.success,
                          );
                        }
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('配置服务器地址'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
