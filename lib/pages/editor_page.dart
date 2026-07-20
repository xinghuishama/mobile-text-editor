import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/editor_webview.dart';
import '../widgets/find_replace_bar.dart';

class _CursorInfo {
  final int line;
  final int column;
  final int selected;
  const _CursorInfo({this.line = 1, this.column = 1, this.selected = 0});
}

class EditorPage extends StatefulWidget {
  const EditorPage({Key? key}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final GlobalKey<EditorWebViewState> _editorKey = GlobalKey<EditorWebViewState>();
  final ValueNotifier<_CursorInfo> _cursor =
      ValueNotifier(const _CursorInfo());
  final ValueNotifier<int> _charCount = ValueNotifier(0);
  bool _findBarVisible = false;
  String _editorMode = '';

  @override
  void dispose() {
    _cursor.dispose();
    _charCount.dispose();
    super.dispose();
  }

  /// 从 JS 侧拉取最新内容并同步到 AppState。
  /// 保存、切换标签、关闭标签、返回上一页前必须调用，
  /// 否则 JS 防抖窗口内的最后几个字符会丢失。
  Future<void> _syncCurrentContent() async {
    final appState = context.read<AppState>();
    final file = appState.activeFile;
    final state = _editorKey.currentState;
    if (file == null || state == null || !state.isReady) return;
    final content = await state.getContent();
    if (content != file.content) {
      appState.updateContent(file.id, content);
    }
  }

  Future<void> _save() async {
    final appState = context.read<AppState>();
    final file = appState.activeFile;
    if (file == null) return;
    await _syncCurrentContent();
    try {
      await appState.saveFile(file.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _saveAs() async {
    final appState = context.read<AppState>();
    final file = appState.activeFile;
    if (file == null) return;
    await _syncCurrentContent();
    final ok = await appState.saveAsFile(file.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '另存为成功' : '另存为已取消或失败'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _gotoLine() async {
    final controller = TextEditingController();
    final line = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳转到行'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '输入行号'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (line != null && line > 0) {
      _editorKey.currentState?.gotoLine(line);
    }
  }

  void _changeEncoding() {
    final appState = context.read<AppState>();
    final file = appState.activeFile;
    if (file == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('保存编码', style: TextStyle(fontWeight: FontWeight.bold))),
              for (final enc in const ['UTF-8', 'GBK', 'Big5'])
                RadioListTile<String>(
                  title: Text(enc),
                  value: enc,
                  groupValue: file.encoding,
                  onChanged: (v) {
                    if (v != null) appState.setFileEncoding(file.id, v);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _closeTab(String fileId) async {
    final appState = context.read<AppState>();
    // 关闭的是当前标签时先同步内容，确保 dirty 判断基于最新内容
    if (appState.activeFileId == fileId) {
      await _syncCurrentContent();
    }
    try {
      await appState.closeFile(fileId);
    } catch (_) {
      if (!mounted) return;
      final file = appState.openedFiles.firstWhere((f) => f.id == fileId);
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('未保存的更改'),
          content: Text('文件 "${file.name}" 有未保存的更改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('不保存', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (result == 'save') {
        await appState.saveFile(fileId);
        await appState.closeFile(fileId, force: true);
      } else if (result == 'discard') {
        await appState.closeFile(fileId, force: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeFile = appState.activeFile;
    final isDark = appState.themeMode == ThemeMode.dark;

    return WillPopScope(
      onWillPop: () async {
        await _syncCurrentContent();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(activeFile == null
              ? '编辑器'
              : '${activeFile.name}${activeFile.isDirty ? ' ●' : ''}'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: _buildTabBar(appState),
          ),
        ),
        body: activeFile == null
            ? const Center(child: Text('没有打开的文件'))
            : EditorWebView(
                key: _editorKey,
                fileId: activeFile.id,
                content: activeFile.content,
                language: _getLanguageFromFileName(activeFile.name),
                isDarkMode: isDark,
                fontSize: appState.fontSize,
                onContentChanged: (content) {
                  final id = context.read<AppState>().activeFileId;
                  if (id != null) {
                    context.read<AppState>().updateContent(id, content);
                  }
                  _charCount.value = content.length;
                },
                onCursorChanged: (line, column, selected) {
                  _cursor.value =
                      _CursorInfo(line: line, column: column, selected: selected);
                },
                onEditorReady: (mode) {
                  if (mounted) setState(() => _editorMode = mode);
                  final f = context.read<AppState>().activeFile;
                  if (f != null) _charCount.value = f.content.length;
                },
              ),
        bottomNavigationBar: activeFile == null
            ? null
            : SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_findBarVisible)
                      FindReplaceBar(
                        editorKey: _editorKey,
                        onClose: () => setState(() => _findBarVisible = false),
                      ),
                    _buildStatusBar(appState, activeFile.encoding,
                        _getLanguageFromFileName(activeFile.name)),
                    _buildToolbar(appState),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabBar(AppState appState) {
    final opened = appState.openedFiles;
    if (opened.isEmpty) return const SizedBox.shrink();
    final activeIndex =
        opened.indexWhere((f) => f.id == appState.activeFileId);
    return DefaultTabController(
      key: ValueKey(opened.length),
      length: opened.length,
      initialIndex: activeIndex < 0 ? 0 : activeIndex,
      child: TabBar(
        isScrollable: true,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).colorScheme.primary,
        onTap: (index) async {
          final target = opened[index];
          if (target.id == appState.activeFileId) return;
          await _syncCurrentContent();
          if (mounted) context.read<AppState>().setActiveFile(target.id);
        },
        tabs: [
          for (final file in opened)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${file.name}${file.isDirty ? ' ●' : ''}'),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _closeTab(file.id),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(AppState appState, String encoding, String language) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ValueListenableBuilder<_CursorInfo>(
        valueListenable: _cursor,
        builder: (context, cursor, _) {
          return ValueListenableBuilder<int>(
            valueListenable: _charCount,
            builder: (context, chars, _) {
              final sel =
                  cursor.selected > 0 ? ' | 选中 ${cursor.selected}' : '';
              final mode = _editorMode == 'monaco' ? 'Monaco' : '基础';
              return Text(
                '行 ${cursor.line}, 列 ${cursor.column}$sel | $chars 字符 | $encoding | $language | $mode',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildToolbar(AppState appState) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _toolBtn(Icons.undo, '撤销', () => _editorKey.currentState?.undo()),
          _toolBtn(Icons.redo, '重做', () => _editorKey.currentState?.redo()),
          _toolBtn(Icons.search, '查找替换', () {
            setState(() => _findBarVisible = !_findBarVisible);
          }),
          _toolBtn(Icons.format_list_numbered, '跳转到行', _gotoLine),
          _toolBtn(Icons.save, '保存', _save),
          _toolBtn(Icons.save_as, '另存为', _saveAs),
          _toolBtn(Icons.translate, '保存编码', _changeEncoding),
          const Spacer(),
          IconButton(
            icon: Icon(appState.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            tooltip: '切换主题',
            onPressed: () {
              appState.setThemeMode(appState.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark);
            },
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: onPressed,
      ),
    );
  }

  static const Map<String, String> _extLangMap = {
    'js': 'javascript', 'mjs': 'javascript', 'jsx': 'javascript',
    'ts': 'typescript', 'tsx': 'typescript',
    'py': 'python',
    'html': 'html', 'htm': 'html', 'vue': 'html',
    'css': 'css', 'scss': 'scss', 'less': 'less',
    'json': 'json',
    'xml': 'xml', 'svg': 'xml',
    'md': 'markdown',
    'java': 'java',
    'c': 'c', 'h': 'c',
    'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp',
    'cs': 'csharp',
    'go': 'go',
    'rs': 'rust',
    'php': 'php',
    'rb': 'ruby',
    'sql': 'sql',
    'yml': 'yaml', 'yaml': 'yaml',
    'sh': 'shell', 'bash': 'shell',
    'kt': 'kotlin', 'kts': 'kotlin',
    'swift': 'swift',
    'dart': 'dart',
    'lua': 'lua',
    'pl': 'perl',
    'r': 'r',
    'ini': 'ini', 'toml': 'ini', 'conf': 'ini',
    'dockerfile': 'dockerfile',
  };

  String _getLanguageFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == 'dockerfile') return 'dockerfile';
    final ext = lower.contains('.') ? lower.split('.').last : '';
    return _extLangMap[ext] ?? 'plaintext';
  }
}
