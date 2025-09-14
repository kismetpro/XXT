import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRPollingService extends ChangeNotifier {
  static final QRPollingService _instance = QRPollingService._internal();
  factory QRPollingService() => _instance;
  QRPollingService._internal();

  // 当前二维码数据
  String? _currentEnc;
  String? _currentC;
  DateTime? _lastUpdateTime;

  // 轮询状态
  bool _isPolling = false;
  MobileScannerController? _scannerController;

  // 获取当前ENC值
  String? get currentEnc => _currentEnc;

  // 获取当前C值
  String? get currentC => _currentC;

  // 获取最后更新时间
  DateTime? get lastUpdateTime => _lastUpdateTime;

  // 检查是否正在轮询
  bool get isPolling => _isPolling;

  // 获取扫描控制器
  MobileScannerController? get scannerController => _scannerController;

  // 更新二维码数据
  void updateQRData(String enc, String c) {
    if (_currentEnc != enc || _currentC != c) {
      _currentEnc = enc;
      _currentC = c;
      _lastUpdateTime = DateTime.now();
      notifyListeners();
      debugPrint(
          'QRPollingService: 更新ENC值 - ${_currentEnc?.substring(0, 8)}...');
    }
  }

  // 开始轮询
  void startPolling(MobileScannerController controller) {
    if (_isPolling) return;

    _scannerController = controller;
    _isPolling = true;

    // 确保扫描器处于活动状态 - 修复isStarting错误
    if (_scannerController != null) {
      try {
        _scannerController!.start();
        debugPrint('QRPollingService: 成功启动扫描器');
      } catch (e) {
        debugPrint('QRPollingService: 启动扫描器失败 - $e');
      }
    }

    debugPrint('QRPollingService: 开始轮询扫描');
    notifyListeners();
  }

  // 停止轮询
  void stopPolling() {
    _isPolling = false;
    _currentEnc = null;
    _currentC = null;

    debugPrint('QRPollingService: 停止轮询扫描');
    notifyListeners();
  }

  // 重置数据但保持轮询状态
  void resetData() {
    _currentEnc = null;
    _currentC = null;
    _lastUpdateTime = null;
    notifyListeners();
  }

  // 添加检查两次扫描结果是否相同的方法
  bool isDifferentQRCode(String newEnc, String newC) {
    return _currentEnc != newEnc || _currentC != newC;
  }

  // 处理扫描结果
  void handleScanResult(BarcodeCapture capture) {
    if (!_isPolling) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;
      if (barcode.rawValue!.contains('mobilelearn.chaoxing.com')) {
        try {
          // 更健壮的URL解析方式
          Uri uri = Uri.parse(barcode.rawValue!);
          Map<String, String> queryParams = uri.queryParameters;

          if (queryParams.containsKey('enc') && queryParams.containsKey('c')) {
            String enc = queryParams['enc']!;
            String c = queryParams['c']!;

            // 仅当扫描到新的二维码时才更新
            if (isDifferentQRCode(enc, c)) {
              debugPrint(
                  'QRPollingService: 成功解析新的URL参数 enc=${enc.substring(0, 8)}..., c=$c');
              updateQRData(enc, c);
            }
            return; // 成功解析一个二维码后返回
          } else {
            // 尝试旧方法解析
            try {
              String enc = barcode.rawValue!.split('&enc=')[1].split('&')[0];
              String c = barcode.rawValue!.split('&c=')[1].split('&')[0];

              debugPrint(
                  'QRPollingService: 使用备用方法解析URL参数 enc=${enc.substring(0, 8)}..., c=$c');
              updateQRData(enc, c);
              return; // 成功解析一个二维码后返回
            } catch (e) {
              debugPrint('QRPollingService: 备用解析方法也失败 - $e');
            }

            debugPrint('QRPollingService: URL不包含必要参数: $queryParams');
          }
        } catch (e) {
          debugPrint('QRPollingService: 解析二维码URL失败 - $e');
        }
      }
    }
  }
}
