import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 编辑器回调：光标/选区变化
typedef CursorChangedCallback = void Function(int line, int column, int selected);

/// 基于 WebView + Monaco Editor 的代码编辑器组件。
/// JS 侧协议见 assets/editor/index.html。
class EditorWebView extends StatefulWidget {
  final String fileId;
  final String content;
  final String language;
  final bool isDarkMode;
  final int fontSize;
  final Function(String) onContentChanged;
  final CursorChangedCallback? onCursorChanged;
  final Function(String mode)? onEditorReady; // mode: 'monaco' | 'fallback'

  const EditorWebView({
    Key? key,
    required this.fileId,
    required this.content,
    required this.language,
    required this.isDarkMode,
    required this.onContentChanged,
    this.fontSize = 14,
    this.onCursorChanged,
    this.onEditorReady,
  }) : super(key: key);

  @override
  EditorWebViewState createState() => EditorWebViewState();
}

class EditorWebViewState extends State<EditorWebView> {
  late final WebViewController _controller;
  bool _editorReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {},
      ))
      ..addJavaScriptChannel(
        'EditorBridge',
        onMessageReceived: _onJsMessage,
      )
      ..loadFlutterAsset('assets/editor/index.html');
  }

  void _onJsMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'ready':
        _editorReady = true;
        // 编辑器就绪后初始化外观与内容
        setDarkMode(widget.isDarkMode);
        setFontSize(widget.fontSize);
        setContent(widget.content, widget.language);
        widget.onEditorReady?.call(data['mode']?.toString() ?? 'unknown');
        break;
      case 'content':
        widget.onContentChanged(data['text']?.toString() ?? '');
        break;
      case 'cursor':
        widget.onCursorChanged?.call(
          (data['line'] as num?)?.toInt() ?? 1,
          (data['column'] as num?)?.toInt() ?? 1,
          (data['selected'] as num?)?.toInt() ?? 0,
        );
        break;
    }
  }

  @override
  void didUpdateWidget(EditorWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editorReady) return;
    if (oldWidget.fileId != widget.fileId) {
      // 切换文件：载入新内容（内容回调中已按"内容相同则忽略"处理，不会误标脏）
      setContent(widget.content, widget.language);
      return;
    }
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      setDarkMode(widget.isDarkMode);
    }
    if (oldWidget.fontSize != widget.fontSize) {
      setFontSize(widget.fontSize);
    }
    if (oldWidget.language != widget.language) {
      setLanguage(widget.language);
    }
  }

  /// 把 Dart 字符串转成安全的 JS 字符串字面量
  static String _jsString(String s) {
    return jsonEncode(s)
        .replaceAll('\u{2028}', '\\u2028')
        .replaceAll('\u{2029}', '\\u2029');
  }

  Future<void> _run(String js) async {
    if (!_editorReady) return;
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<Object?> _runReturning(String js) async {
    if (!_editorReady) return null;
    try {
      return await _controller.runJavaScriptReturningResult(js);
    } catch (_) {
      return null;
    }
  }

  /// 解析返回 JSON 对象的方法调用（Android 双重编码 / iOS 单层）
  Future<Map<String, dynamic>?> _callJson(String expr) async {
    try {
      dynamic r = await _runReturning(expr);
      if (r is String) r = jsonDecode(r);
      if (r is String) r = jsonDecode(r);
      if (r is Map) return Map<String, dynamic>.from(r);
    } catch (_) {}
    return null;
  }

  Future<int> _callInt(String expr) async {
    final r = await _runReturning(expr);
    if (r is int) return r;
    if (r is num) return r.toInt();
    return int.tryParse(r?.toString() ?? '') ?? -1;
  }

  bool get isReady => _editorReady;

  // ---------------- 公共 API ----------------

  Future<void> setContent(String text, [String? language]) async {
    final lang = language == null ? 'null' : _jsString(language);
    await _run('window.editorApi && window.editorApi.setContent(${_jsString(text)}, $lang)');
  }

  /// 获取编辑器当前内容（保存/切换标签前应调用以确保拿到最新内容）
  /// 走 JSON 包装返回，避免 Android/iOS 返回值编码差异导致的解析歧义。
  Future<String> getContent() async {
    final res = await _callJson(
        'JSON.stringify({text: window.editorApi.getContent()})');
    return res?['text']?.toString() ?? '';
  }

  Future<void> setLanguage(String language) async {
    await _run('window.editorApi && window.editorApi.setLanguage(${_jsString(language)})');
  }

  Future<void> setDarkMode(bool dark) async {
    await _run('window.editorApi && window.editorApi.setDarkMode($dark)');
  }

  Future<void> setFontSize(int size) async {
    await _run('window.editorApi && window.editorApi.setFontSize($size)');
  }

  Future<void> undo() => _run('window.editorApi && window.editorApi.undo()');

  Future<void> redo() => _run('window.editorApi && window.editorApi.redo()');

  /// 查找。返回 {count, index}，index 为当前匹配序号
  Future<Map<String, dynamic>?> find(
          String query, bool matchCase, bool isRegex, bool wholeWord) =>
      _callJson(
          'window.editorApi.find(${_jsString(query)}, $matchCase, $isRegex, $wholeWord)');

  Future<int> findNext() => _callInt('window.editorApi.findNext()');

  Future<int> findPrev() => _callInt('window.editorApi.findPrev()');

  /// 替换当前匹配，返回 {replaced, count, index}
  Future<Map<String, dynamic>?> replaceCurrent(String replacement) => _callJson(
      'window.editorApi.replaceCurrent(${_jsString(replacement)})');

  /// 全部替换，返回替换次数
  Future<int> replaceAll(String replacement) => _callInt(
      'window.editorApi.replaceAll(${_jsString(replacement)})');

  Future<void> closeFind() =>
      _run('window.editorApi && window.editorApi.closeFind()');

  Future<void> gotoLine(int line) =>
      _run('window.editorApi && window.editorApi.gotoLine($line)');

  Future<void> insertText(String text) => _run(
      'window.editorApi && window.editorApi.insertText(${_jsString(text)})');

  /// 状态信息 {line, column, chars, lines, selected}
  Future<Map<String, dynamic>?> getStats() =>
      _callJson('window.editorApi.getStats()');

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
