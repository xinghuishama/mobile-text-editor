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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  /// 关闭除当前外的所有标签（未保存的逐个询问）
  Future<void> _closeOtherTabs() async {
    final appState = context.read<AppState>();
    final others = appState.openedFiles
        .where((f) => f.id != appState.activeFileId)
        .map((f) => f.id)
        .toList();
    for (final id in others) {
      await _closeTab(id);
      if (!mounted) return;
    }
  }

  /// 新建文件并打开
  Future<void> _newFile() async {
    final appState = context.read<AppState>();
    try {
      final file = await appState.createNewFile();
      await appState.openFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// 打开外部文件
  Future<void> _openExternal() async {
    final appState = context.read<AppState>();
    try {
      final file = await appState.openExternalFile();
      if (file != null) await appState.openFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeFile = appState.activeFile;
    final isDark = appState.themeMode == ThemeMode.dark;

    return WillPopScope(
      onWillPop: () async {
        // 查找栏可见时，返回键先关闭查找栏
        if (_findBarVisible) {
          setState(() => _findBarVisible = false);
          return false;
        }
        await _syncCurrentContent();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(appState),
        appBar: AppBar(
          // 标题栏：左侧菜单键，标题 = 当前文件名，右侧常用操作
          leading: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '菜单',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(activeFile == null
              ? '编辑器'
              : '${activeFile.name}${activeFile.isDirty ? ' ●' : ''}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存',
              onPressed: activeFile == null ? null : _save,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '查找替换',
              onPressed: activeFile == null
                  ? null
                  : () {
                      // 打开查找栏前先收起系统键盘，避免输入法挡住查找栏
                      if (!_findBarVisible) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      }
                      setState(() => _findBarVisible = !_findBarVisible);
                    },
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                switch (value) {
                  case 'save_as': _saveAs(); break;
                  case 'goto_line': _gotoLine(); break;
                  case 'encoding': _changeEncoding(); break;
                  case 'close_others': _closeOtherTabs(); break;
                  case 'theme':
                    appState.setThemeMode(appState.themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'save_as', child: Text('另存为')),
                const PopupMenuItem(value: 'goto_line', child: Text('跳转到行')),
                const PopupMenuItem(value: 'encoding', child: Text('保存编码')),
                const PopupMenuItem(value: 'close_others', child: Text('关闭其他标签')),
                PopupMenuItem(
                  value: 'theme',
                  child: Text(isDark ? '切换为亮色主题' : '切换为暗色主题'),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(41),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabBar(appState),
                // 标题栏/Tab 与编辑区之间的分隔线
                const Divider(height: 1, thickness: 1),
              ],
            ),
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
                    // 查找栏贴工具栏上方 = 键盘弹起时直接位于键盘顶部，不会被遮挡
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

  /// 侧边抽屉：文件与设置导航
  Widget _buildDrawer(AppState appState) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '移动端文本编辑器',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('新建文件'),
              onTap: () {
                Navigator.pop(context);
                _newFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('打开文件'),
              onTap: () {
                Navigator.pop(context);
                _openExternal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('文件列表'),
              onTap: () async {
                Navigator.pop(context);
                await _syncCurrentContent();
                if (!mounted) return;
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
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
            if (!_findBarVisible) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
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
