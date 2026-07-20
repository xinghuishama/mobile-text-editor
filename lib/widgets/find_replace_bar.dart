import 'dart:async';
import 'package:flutter/material.dart';
import 'editor_webview.dart';

/// 查找替换面板：查找词即时搜索，支持大小写/正则/全词匹配，
/// 上一个/下一个导航，替换当前与全部替换。
class FindReplaceBar extends StatefulWidget {
  final GlobalKey<EditorWebViewState> editorKey;
  final VoidCallback onClose;

  const FindReplaceBar({
    Key? key,
    required this.editorKey,
    required this.onClose,
  }) : super(key: key);

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final TextEditingController _findCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  final FocusNode _findFocus = FocusNode();
  Timer? _debounce;

  bool _matchCase = false;
  bool _isRegex = false;
  bool _wholeWord = false;
  int _count = 0;
  int _index = -1;

  @override
  void dispose() {
    _debounce?.cancel();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _doFind);
  }

  Future<void> _doFind() async {
    final query = _findCtrl.text;
    if (query.isEmpty) {
      await widget.editorKey.currentState?.closeFind();
      if (mounted) setState(() { _count = 0; _index = -1; });
      return;
    }
    final res = await widget.editorKey.currentState
        ?.find(query, _matchCase, _isRegex, _wholeWord);
    if (!mounted) return;
    setState(() {
      _count = (res?['count'] as num?)?.toInt() ?? 0;
      _index = (res?['index'] as num?)?.toInt() ?? -1;
    });
  }

  Future<void> _findNext() async {
    final i = await widget.editorKey.currentState?.findNext();
    if (i != null && i >= 0 && mounted) setState(() => _index = i);
  }

  Future<void> _findPrev() async {
    final i = await widget.editorKey.currentState?.findPrev();
    if (i != null && i >= 0 && mounted) setState(() => _index = i);
  }

  Future<void> _replaceCurrent() async {
    final res = await widget.editorKey.currentState
        ?.replaceCurrent(_replaceCtrl.text);
    if (!mounted || res == null) return;
    setState(() {
      _count = (res['count'] as num?)?.toInt() ?? 0;
      _index = (res['index'] as num?)?.toInt() ?? -1;
    });
  }

  Future<void> _replaceAll() async {
    final n = await widget.editorKey.currentState
        ?.replaceAll(_replaceCtrl.text);
    if (!mounted) return;
    setState(() { _count = 0; _index = -1; });
    if ((n ?? 0) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已替换 $n 处'), duration: const Duration(seconds: 1)),
      );
    }
  }

  Widget _toggleButton(String label, String tooltip, bool active, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 30, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? color : Colors.grey, width: 1),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: active ? color : Colors.grey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 查找行：输入框占满剩余空间
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _findCtrl,
                    focusNode: _findFocus,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '查找',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => _onQueryChanged(),
                  ),
                ),
                const SizedBox(width: 4),
                _toggleButton('Aa', '区分大小写', _matchCase, () {
                  setState(() => _matchCase = !_matchCase);
                  _doFind();
                }),
                const SizedBox(width: 3),
                _toggleButton('.*', '正则表达式', _isRegex, () {
                  setState(() => _isRegex = !_isRegex);
                  _doFind();
                }),
                const SizedBox(width: 3),
                _toggleButton('ab', '全词匹配', _wholeWord, () {
                  setState(() => _wholeWord = !_wholeWord);
                  _doFind();
                }),
                const SizedBox(width: 4),
                SizedBox(
                  width: 40,
                  child: Text(
                    _count > 0 ? '${_index + 1}/$_count' : (_findCtrl.text.isEmpty ? '' : '0'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: _count > 0 ? _findPrev : null,
                    tooltip: '上一个',
                  ),
                ),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: _count > 0 ? _findNext : null,
                    tooltip: '下一个',
                  ),
                ),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      widget.editorKey.currentState?.closeFind();
                      widget.onClose();
                    },
                    tooltip: '关闭',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 替换行：输入框占满剩余空间
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '替换为（正则可用 \$1 引用分组）',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _count > 0 ? _replaceCurrent : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 34),
                  ),
                  child: const Text('替换'),
                ),
                TextButton(
                  onPressed: _count > 0 ? _replaceAll : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 34),
                  ),
                  child: const Text('全部替换'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
