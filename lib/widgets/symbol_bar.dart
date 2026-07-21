import 'package:flutter/material.dart';
import 'editor_webview.dart';

/// 底部标点符号快捷条（Acode 风格）：
/// 点击将符号插入编辑器光标处，可横向滑动。
class SymbolBar extends StatelessWidget {
  final GlobalKey<EditorWebViewState> editorKey;

  const SymbolBar({Key? key, required this.editorKey}) : super(key: key);

  /// 常用编程符号，按使用频率排序
  static const List<String> _symbols = [
    '{', '}', '(', ')', '[', ']', '<', '>',
    '"', "'", '`',
    ';', ':', ',', '.',
    '=', '+', '-', '*', '/', '\\', '|', '_',
    '&', '%', '\$', '#', '@', '!', '?', '~', '^',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          _key(context, '⇥', '\t', 'Tab'),
          for (final s in _symbols) _key(context, s, s, null),
        ],
      ),
    );
  }

  Widget _key(BuildContext context, String label, String insert, String? tooltip) {
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        onTap: () => editorKey.currentState?.insertText(insert),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
