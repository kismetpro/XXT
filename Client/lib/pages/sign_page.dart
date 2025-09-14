import 'dart:io';
import 'dart:async';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:coordtransform_dart/coordtransform_dart.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gesture_password/gesture_view.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // 替换为 mobile_scanner
import 'package:xbt_client/main.dart';
import 'package:xbt_client/pages/sign_progress_page.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xbt_client/services/qr_code_polling_service.dart';

class SignPage extends StatefulWidget {
  final Map<String, dynamic>? signData;
  final Map<String, dynamic>? courseData;
  const SignPage({super.key, this.signData, this.courseData});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> with RouteAware {
  Map<String, dynamic>? locationData;
  String code = '';
  List<Map<String, dynamic>> classmates = [];
  bool isSigning = false;

  // MobileScanner 相关变量
  late MobileScannerController _scannerController;
  Barcode? result;

  // 添加缩放控制相关变量
  double _currentZoom = 0.0; // 改为0.0作为最小值，与slider 0-100%对应
  double _baseZoom = 0.0; // 基准缩放值，在开始缩放手势时保存
  final double _minZoom = 0.0;
  final double _maxZoom = 1.0; // 最大值为1.0，表示100%
  bool _isZoomInitialized = false;
  bool _isCameraStarted = false; // 添加相机启动状态标志

  // 添加上次设置的缩放值记录
  final double _lastSetZoom = 1.0;

  // 标记相机控制器是否已经初始化
  bool _isControllerInitialized = false;

  // 确保位置预设列表有效
  List<Map<String, dynamic>> _getLocationPresets() {
    // 检查locationPreset是否为空，如果为空则提供备用数据
    if (locationPreset.isEmpty) {
      print('警告: locationPreset为空，使用备用数据');
      return [
        {
          "name": "学校",
          "lng": '116.397428',
          "lat": '39.90923',
          "description": "北京市东城区东华门街道"
        },
        {
          "name": "图书馆",
          "lng": '116.397428',
          "lat": '39.90923',
          "description": "北京市东城区东华门街道-图书馆"
        },
      ];
    }
    return locationPreset;
  }

  // 添加QR码轮询服务
  final QRPollingService _qrPollingService = QRPollingService();
  Timer? _pollingStatusTimer;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _scannerController.stop();
      _isCameraStarted = false; // 重置相机状态
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MyApp.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    isSigning = false;
  }

  @override
  void initState() {
    // 初始化位置数据
    print('初始化位置数据: ${_getLocationPresets()}');

    updateClassmates();

    // 重新初始化相机控制器
    _initializeCamera();

    // 添加定时检查轮询状态的计时器
    _pollingStatusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _qrPollingService.lastUpdateTime != null) {
        setState(() {}); // 触发UI更新显示最新的轮询状态
      }
    });

    super.initState();
  }

  // 彻底重构相机初始化流程
  void _initializeCamera() async {
    try {
      print('开始重新初始化相机...');

      // 检查控制器是否已初始化，而不是检查它是否为null
      if (_isControllerInitialized) {
        print('停止现有相机...');
        try {
          await _scannerController.stop();
          _scannerController.dispose();
        } catch (e) {
          print('停止现有相机出错: $e');
        }
      }

      // 重新创建控制器
      print('创建新的相机控制器...');
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: [BarcodeFormat.qrCode], // 仅限QR码提高性能
        returnImage: false, // 禁用返回图像以提高性能
      );
      _isControllerInitialized = true;

      // 启动相机
      print('尝试启动相机...');
      bool started = false;

      try {
        // 修复start()调用方式，mobile_scanner库的start()没有返回值
        await _scannerController.start();
        started = true;
        print('相机启动成功');
      } catch (e) {
        print('相机启动异常: $e');
        started = false;
      }

      // 更新状态
      _isCameraStarted = started;
      _isZoomInitialized = started;

      print('相机初始化状态: 启动=$_isCameraStarted, 缩放初始化=$_isZoomInitialized');

      // 开始轮询服务
      _qrPollingService.startPolling(_scannerController);

      if (mounted) setState(() {});
    } catch (e) {
      print('初始化相机失败: $e');
      _isCameraStarted = false;
      _isZoomInitialized = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相机初始化失败，请检查相机权限或重启应用')),
        );
      }
    }
  }

  // 简化重置缩放方法
  void _resetZoom() {
    if (!_isCameraStarted || !_isControllerInitialized) {
      print('相机未准备好，无法重置缩放');
      return;
    }

    try {
      setState(() {
        _currentZoom = 0.0;
        _baseZoom = 0.0;
        _scannerController.setZoomScale(0.0);
      });
      print('已重置缩放');
    } catch (e) {
      print('重置缩放失败: $e');
    }
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    // 安全释放相机资源
    if (_isControllerInitialized) {
      try {
        _scannerController.stop();
        _scannerController.dispose();
        print('相机资源已释放');
      } catch (e) {
        print('释放相机资源时出错: $e');
      }
    }
    _pollingStatusTimer?.cancel();
    _qrPollingService.stopPolling();
    super.dispose();
  }

  void updateClassmates() async {
    SmartDialog.showLoading(msg: "获取同学中...");
    var resp = await dio.post('$baseURL/getClassmates', data: {
      "courseId": widget.signData!['courseId'],
      'classId': widget.signData!['classId']
    });
    classmates = List<Map<String, dynamic>>.from(resp.data['data']);
    for (int i = 0; i < classmates.length; i++) {
      classmates[i]['isSelected'] = true;
    }
    setState(() {
      classmates = classmates;
    });
    SmartDialog.dismiss();
  }

  // 修改sign方法，使用最新的enc值
  void sign(Map<String, dynamic> args, SignType signType) async {
    if (isSigning) return;
    isSigning = true;

    // 对于二维码签到，使用最新的轮询数据
    if (signType == SignType.qrCode && _qrPollingService.currentEnc != null) {
      // 更新enc和c值为最新
      args['enc'] = _qrPollingService.currentEnc;
      args['c'] = _qrPollingService.currentC;

      print('使用最新的enc值签到: ${args['enc']?.substring(0, 8)}...');
    }

    Map<String, dynamic> fixedParams = {
      "courseId": widget.courseData!['courseId'],
      "classId": widget.courseData!['classId'],
      "activeId": widget.signData!['activeId'],
      "ifRefreshEwm": widget.signData!['ifRefreshEwm'],
      "uid": widget.signData!['uid'],
    };

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SignProgressPage(
              fixedParams: fixedParams,
              specialParams: args,
              classmates: classmates,
              signType: signType,
              signState: (v) {
                isSigning = v;
              },
              qrPollingService: _qrPollingService, // 传递轮询服务
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(SignType.fromId(widget.signData!["signType"]).name),
        elevation: 3,
        shadowColor: Theme.of(context).colorScheme.shadow,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "签到信息: ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                "签到标题: ${widget.signData!["name"]}\n开始时间: ${DateTime.fromMillisecondsSinceEpoch(widget.signData!["startTime"]).toString().substring(0, 19)}\n结束时间: ${widget.signData!["endTime"] == 64060559999000 ? '手动结束' : DateTime.fromMillisecondsSinceEpoch(widget.signData!["endTime"]).toString().substring(0, 19)}",
                style: TextStyle(height: 1.15, color: Colors.grey[900]),
              ),
            ),
            if (widget.signData!["signType"] == SignType.location.id)
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: Container(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          locationData == null
                              ? '点击选择位置'
                              : locationData!['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 18),
                        ),
                        subtitle: locationData == null
                            ? null
                            : Text(
                                locationData!['description']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                        leading: Icon(SignType.location.icon,
                            color: Theme.of(context).colorScheme.primary),
                        onTap: () async {
                          List<Map<String, dynamic>> locations =
                              _getLocationPresets();
                          print('点击位置选择，可用位置数: ${locations.length}');
                          try {
                            var res = await showConfirmationDialog(
                              context: context,
                              title: "请选择位置",
                              okLabel: "确定",
                              cancelLabel: "取消",
                              contentMaxHeight: 400,
                              actions: [
                                for (int i = 0; i < locations.length; i++)
                                  AlertDialogAction(
                                      key: i, label: locations[i]['name']!)
                              ],
                            );
                            print('选择结果: $res');
                            if (res == null) return;
                            setState(() {
                              locationData = locations[res];
                            });
                          } catch (e) {
                            print('显示位置选择对话框失败: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('位置选择失败，请检查配置或重启应用')),
                            );
                          }
                        },
                      ),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      Container(
                        width: double.infinity,
                        height: 40,
                        color: locationData == null
                            ? Colors.grey[500]
                            : Theme.of(context).colorScheme.primary,
                        child: MaterialButton(
                          onPressed: () {
                            if (locationData == null) {
                              SmartDialog.showNotify(
                                  msg: "请先选择位置",
                                  notifyType: NotifyType.warning);
                              return;
                            }
                            sign({
                              'longitude': locationData!['lng'],
                              'latitude': locationData!['lat'],
                              'description': locationData!['description'],
                            }, SignType.location);
                          },
                          child: const Text(
                            "签到",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.signData!["signType"] == SignType.gesture.id)
              Card(
                elevation: 4,
                child: LayoutBuilder(builder: (context, constraints) {
                  return Center(
                    child: GestureView(
                      width: constraints.maxWidth * 0.6,
                      height: 222,
                      listener: (arr) {
                        String signCode = arr.map((v) => v + 1).join('');
                        sign({"signCode": signCode}, SignType.gesture);
                      },
                    ),
                  );
                }),
              ),
            if (widget.signData!["signType"] == SignType.code.id)
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: Container(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "签到码",
                            hintText: "请输入签到码",
                            icon: Icon(
                              Icons.password,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              code = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      Container(
                        width: double.infinity,
                        height: 40,
                        color: code.length < 4 || code.length > 8
                            ? Colors.grey[500]
                            : Theme.of(context).colorScheme.primary,
                        child: MaterialButton(
                          onPressed: () {
                            sign({"signCode": code}, SignType.code);
                          },
                          child: const Text(
                            "签到",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.signData!["signType"] == SignType.qrCode.id)
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // 位置选择部分
                    ListTile(
                      title: Text(
                        locationData == null
                            ? '点击选择位置（可选）'
                            : locationData!['name']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 18),
                      ),
                      subtitle: locationData == null
                          ? null
                          : Text(
                              locationData!['description']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                      leading: Icon(SignType.location.icon,
                          color: Theme.of(context).colorScheme.primary),
                      onTap: () async {
                        List<Map<String, dynamic>> locations =
                            _getLocationPresets();
                        print('点击位置选择，可用位置数: ${locations.length}');
                        try {
                          var res = await showConfirmationDialog(
                            context: context,
                            title: "请选择位置",
                            okLabel: "确定",
                            cancelLabel: "取消",
                            contentMaxHeight: 400,
                            actions: [
                              for (int i = 0; i < locations.length; i++)
                                AlertDialogAction(
                                    key: i, label: locations[i]['name']!)
                            ],
                          );
                          print('选择结果: $res');
                          if (res == null) return;
                          setState(() {
                            locationData = locations[res];
                          });
                        } catch (e) {
                          print('显示位置选择对话框失败: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('位置选择失败，请检查配置或重启应用')),
                          );
                        }
                      },
                    ),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.grey[300],
                    ),
                    // 扫码部分
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            // 完全重写相机预览部分
                            Container(
                              color: Colors.black,
                              child: Builder(
                                builder: (context) {
                                  // 显示加载指示器，直到相机启动
                                  if (!_isCameraStarted ||
                                      !_isControllerInitialized) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          const Text('正在启动相机...',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              print('手动尝试重新初始化相机');
                                              _initializeCamera();
                                            },
                                            child: const Text('重试'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  print('尝试渲染相机预览...');
                                  // 使用更简单的MobileScanner实现
                                  try {
                                    return MobileScanner(
                                      controller: _scannerController,
                                      fit: BoxFit.cover,
                                      onDetect: (BarcodeCapture capture) {
                                        // 使用轮询服务处理扫描结果
                                        _qrPollingService
                                            .handleScanResult(capture);

                                        // 如果之前没有扫描结果，显示成功通知
                                        if (result == null &&
                                            capture.barcodes.isNotEmpty) {
                                          final barcode =
                                              capture.barcodes.first;
                                          if (barcode.rawValue != null &&
                                              barcode.rawValue!.contains(
                                                  'mobilelearn.chaoxing.com')) {
                                            // 不再在这里直接调用sign方法，而是显示通知让用户知道可以点击"签到"按钮
                                            SmartDialog.showNotify(
                                                msg: "二维码识别成功，持续获取最新二维码中",
                                                notifyType: NotifyType.success);

                                            setState(() {
                                              result = barcode;
                                            });
                                          }
                                        } else if (_qrPollingService
                                                .lastUpdateTime !=
                                            null) {
                                          // 检测到二维码变化时更新状态
                                          if (mounted) setState(() {});
                                        }
                                      },
                                    );
                                  } catch (e) {
                                    print('渲染相机预览时出错: $e');
                                    // 渲染失败时显示错误信息
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error,
                                              color: Colors.red, size: 48),
                                          const SizedBox(height: 16),
                                          const Text('相机预览出错',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _isCameraStarted = false;
                                                _isControllerInitialized =
                                                    false;
                                              });
                                              _initializeCamera();
                                            },
                                            child: const Text('重新初始化相机'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            // 重置缩放按钮
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.restart_alt,
                                      color: Colors.white),
                                  onPressed: _resetZoom,
                                ),
                              ),
                            ),
                            // 缩放滑动条
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.zoom_out,
                                        color: Colors.white, size: 20),
                                    Expanded(
                                      child: Slider(
                                        value: _currentZoom,
                                        min: _minZoom,
                                        max: _maxZoom,
                                        onChanged: (value) {
                                          if (!_isCameraStarted ||
                                              !_isControllerInitialized) return;
                                          try {
                                            setState(() {
                                              _currentZoom = value;
                                              _baseZoom = value;
                                              _scannerController
                                                  .setZoomScale(value);
                                              print('设置缩放比例: $value');
                                            });
                                          } catch (e) {
                                            print('设置缩放失败: $e');
                                          }
                                        },
                                      ),
                                    ),
                                    const Icon(Icons.zoom_in,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 扫描状态指示器
                    if (_qrPollingService.lastUpdateTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.black87,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '已获取最新二维码 (${DateTime.now().difference(_qrPollingService.lastUpdateTime!).inSeconds}秒前)',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 修改签到按钮逻辑，始终使用最新的enc值
                    Container(
                      width: double.infinity,
                      height: 50,
                      color: _qrPollingService.currentEnc == null
                          ? Colors.grey[500]
                          : Theme.of(context).colorScheme.primary,
                      child: MaterialButton(
                        onPressed: () {
                          if (_qrPollingService.currentEnc == null) {
                            SmartDialog.showNotify(
                                msg: "请先扫描二维码", notifyType: NotifyType.warning);
                            return;
                          }

                          debugPrint(
                              '开始签到，使用最新ENC值：${_qrPollingService.currentEnc!.substring(0, 8)}...');

                          Map<String, dynamic> args = {
                            "enc": _qrPollingService.currentEnc,
                            "c": _qrPollingService.currentC,
                          };

                          if (locationData != null) {
                            args['location'] = {
                              "result": 1,
                              "latitude": double.parse(locationData!['lat']),
                              "longitude": double.parse(locationData!['lng']),
                              "mockData": {"strategy": 0, "probability": -1},
                              "address": locationData!['description']
                            };
                          }

                          sign(args, SignType.qrCode);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "使用最新二维码签到",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (_qrPollingService.lastUpdateTime != null)
                              Text(
                                " (${DateTime.now().difference(_qrPollingService.lastUpdateTime!).inSeconds}秒前)",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.signData!["signType"] == SignType.normal.id)
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxWidth * 0.6,
                    width: constraints.maxWidth * 0.6,
                    child: Center(
                      child: Container(
                        width: constraints.maxWidth * 0.6 * 0.5,
                        height: constraints.maxWidth * 0.6 * 0.5,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          borderRadius: BorderRadius.circular(
                              constraints.maxWidth * 0.6 * 0.5 / 2),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha(160),
                              offset: const Offset(1, 1),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: MaterialButton(
                          onPressed: () {
                            sign({}, SignType.normal);
                          },
                          child: Text(
                            "签到",
                            style: TextStyle(
                                fontSize: constraints.maxWidth * 0.6 * 0.1,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            const Text(
              "你将为以下同学代签: ",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, height: 3),
            ),
            Expanded(
              child: ListView(
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < classmates.length; i++) ...[
                          ListTile(
                            title: Text(classmates[i]['name']),
                            subtitle: Text(classmates[i]['mobile']
                                .toString()
                                .replaceRange(3, 7, "****")),
                            leading: ExtendedImage.network(
                              classmates[i]['avatar'],
                              width: 48,
                              height: 48,
                              borderRadius: BorderRadius.circular(8),
                              headers: IMAGEHEADER,
                              shape: BoxShape.rectangle,
                              loadStateChanged: (state) {
                                return loadStateChangedfunc(state);
                              },
                            ),
                            onTap: () {
                              setState(() {
                                classmates[i]['isSelected'] =
                                    !classmates[i]['isSelected'];
                              });
                            },
                            trailing: Checkbox(
                              value: classmates[i]['isSelected'],
                              onChanged: (v) {
                                setState(() {
                                  classmates[i]['isSelected'] = v;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
