import 'package:flutter/services.dart';

/// 监听 Android「打开方式」发来的 VIEW intent。
/// 原生侧（MainActivity.kt）把 content:// 或 file:// 的内容复制到缓存目录，
/// 再通过 EventChannel 把本地路径发给这里。
class OpenIntentService {
  static const EventChannel _channel = EventChannel('mte/open_file');

  /// 注册监听。onFile 参数为已落到本地缓存的文件路径。
  static void init(void Function(String path) onFile) {
    _channel.receiveBroadcastStream().listen(
      (event) {
        if (event is String && event.isNotEmpty) onFile(event);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }
}
