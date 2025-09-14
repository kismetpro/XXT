import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/dio.dart';
import 'package:xbt_client/utils/local_json.dart';
import 'package:xbt_client/services/qr_code_polling_service.dart';

class SignProgressPage extends StatefulWidget {
  final Map<String, dynamic> fixedParams;
  final Map<String, dynamic> specialParams;
  final List<Map<String, dynamic>> classmates;
  final SignType signType;
  final Function? signState;
  final QRPollingService? qrPollingService; // 添加轮询服务参数

  const SignProgressPage({
    super.key,
    required this.fixedParams,
    required this.specialParams,
    required this.signType,
    required this.classmates,
    this.signState,
    this.qrPollingService,
  });

  @override
  State<SignProgressPage> createState() => _SignProgressPageState();
}

class _SignProgressPageState extends State<SignProgressPage> {
  List timeline = [
    {"title": "查询签到状态", "subtitle": "等待中", 'time': ''},
  ];
  int nowIndex = 0;
  DateTime startTime = DateTime.now();

  // 添加最大重试次数限制
  final int maxRetries = 3;

  void addTimeline(title) {
    timeline.add({
      "title": title,
      "subtitle": '等待中',
      'time': '',
    });
    setState(() {
      timeline = timeline;
    });
  }

  void doneTimeline(subtitle) {
    timeline[nowIndex] = {
      "title": timeline[nowIndex]["title"],
      "subtitle": subtitle,
      'time':
          '${(DateTime.now().difference(startTime).inMilliseconds / 1000.0).toStringAsFixed(2)}s',
    };
    setState(() {
      timeline = timeline;
      nowIndex++;
    });
  }

  // 添加一个方法用于记录调试信息到时间线
  void addTimelineDebug(String message) {
    timeline[nowIndex]['subtitle'] =
        timeline[nowIndex]['subtitle'] + '\n调试: $message';
    setState(() {});
  }

  // 添加重试信息到时间线
  void addRetryInfo(int retryCount) {
    String retryMsg = '签到失败，正在获取最新二维码重试($retryCount/$maxRetries)...';
    timeline[nowIndex]['subtitle'] =
        timeline[nowIndex]['subtitle'] + '\n$retryMsg';
    setState(() {});
  }

  void refreshPage() async {
    startTime = DateTime.now();
    var selfInfo = (await LocalJson.getItem('localUserList'))[0];
    var classmatesIgnoreNonSelected =
        widget.classmates.where((element) => element['isSelected']).toList();
    var classmates = [
          {'uid': selfInfo['uid'], 'name': selfInfo['name']}
        ] +
        classmatesIgnoreNonSelected;
    var nonSign = [];
    String subtitle = '';

    // 第一步: 查询签到状态
    var resp = await dio.post('$baseURL/getSignStateFromDataBase', data: {
      "activeId": widget.fixedParams["activeId"],
      "classmates": classmatesIgnoreNonSelected.map((e) => e["uid"]).toList(),
    });

    for (var classmate in classmates) {
      var res = resp.data['data'][classmate['uid'].toString()];
      if (res['suc']) {
        // 签到了
        subtitle += '${classmate['name']}: 已签到(${res['comment']})\n';
      } else {
        nonSign.add(classmate);
        subtitle += '${classmate['name']}: 未签到\n';
      }
    }

    for (var i = 0; i < nonSign.length; i++) {
      addTimeline(nonSign[i]['uid'] == selfInfo['uid']
          ? "签到: ${selfInfo['name']}"
          : "代签: ${nonSign[i]['name']}");
    }
    doneTimeline(subtitle);

    // 逐个签到
    for (var i = 0; i < nonSign.length; i++) {
      int retryCount = 0;
      bool signSuccess = false;

      while (!signSuccess && retryCount <= maxRetries) {
        Map<String, dynamic> specialParams =
            Map<String, dynamic>.from(widget.specialParams);

        // 对于二维码签到，每次都尝试获取最新的enc值
        if (widget.signType == SignType.qrCode &&
            widget.qrPollingService != null &&
            widget.qrPollingService!.currentEnc != null) {
          // 为每个用户重新获取最新的enc和c值
          specialParams['enc'] = widget.qrPollingService!.currentEnc;
          specialParams['c'] = widget.qrPollingService!.currentC;

          // 记录日志，便于调试
          String encPrefix = specialParams['enc'].substring(0, 8);
          String logMsg =
              '${retryCount > 0 ? '重试(${retryCount}/${maxRetries}): ' : ''}使用最新enc值: $encPrefix...';
          debugPrint(logMsg);
          addTimelineDebug(logMsg);
        }

        try {
          var resp = await dio.post('$baseURL/sign', data: {
            "fixedParams": widget.fixedParams,
            "specialParams": specialParams,
            "signType": widget.signType.id,
            "uid": nonSign[i]['uid'],
          });

          // 检查是否是由于enc过期导致的失败
          bool isEncFailure = !resp.data['suc'] &&
              widget.signType == SignType.qrCode &&
              (resp.data['msg'].contains('签到失败') ||
                  resp.data['msg'].contains('请重新扫描'));

          if (isEncFailure && retryCount < maxRetries) {
            // 签到失败并且是ENC问题，进行重试
            retryCount++;
            addRetryInfo(retryCount);

            // 等待一小段时间以获取新的二维码
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }

          // 处理结果
          signSuccess = resp.data['suc'] || !isEncFailure;
          doneTimeline(
              resp.data['msg'] + (retryCount > 0 ? ' (重试$retryCount次)' : ''));
        } catch (e) {
          signSuccess = true; // 出错也停止重试
          doneTimeline('请求失败: ${e.toString()}');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    refreshPage();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
        child: Container(
      color: Colors.black.withAlpha(88),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Center(
        child: Card(
          elevation: 8,
          child: IntrinsicHeight(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "签到进度：",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Stack(
                      children: [
                        Positioned(
                          left: 10.1,
                          top: 8,
                          bottom: 8,
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Theme.of(context).colorScheme.inversePrimary,
                                  Theme.of(context).colorScheme.primary,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            (() {
                              List<Widget> children = [];
                              for (int i = 0; i < timeline.length; i++) {
                                children.add(
                                  ListTile(
                                    title: Text(
                                      timeline[i]["title"],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: i == nowIndex
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.black),
                                    ),
                                    subtitle: Text(timeline[i]["subtitle"]),
                                    contentPadding:
                                        const EdgeInsets.only(right: 16),
                                    trailing: Text(timeline[i]["time"]),
                                    leading: i == nowIndex
                                        ? Container(
                                            width: 24,
                                            height: 24,
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withAlpha(88),
                                                    offset: const Offset(0, 0),
                                                    blurRadius: 8,
                                                  )
                                                ]),
                                            child:
                                                const CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: i < nowIndex
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withAlpha(88),
                                                    offset: const Offset(0, 0),
                                                    blurRadius: 8,
                                                  )
                                                ]),
                                            child: Center(
                                                child: Text('${i + 1}',
                                                    style: TextStyle(
                                                        color: i > nowIndex
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Colors.white,
                                                        fontSize: 14,
                                                        height: 1,
                                                        fontWeight:
                                                            FontWeight.w900))),
                                          ),
                                  ),
                                );
                              }
                              return Column(
                                children: children,
                              );
                            })()
                          ],
                        ),
                      ],
                    ),
                    Container(
                        width: double.infinity,
                        height: 40,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: nowIndex < timeline.length
                              ? Colors.grey[500]
                              : Theme.of(context).colorScheme.primary,
                        ),
                        child: MaterialButton(
                          onPressed: () {
                            if (nowIndex < timeline.length) {
                              SmartDialog.showNotify(
                                  msg: "请等待签到完成",
                                  notifyType: NotifyType.warning);
                              return;
                            }
                            Navigator.pop(context);
                            if (widget.signState != null) {
                              widget.signState!(false);
                            }
                          },
                          child: const Text(
                            "完成",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ))
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
