import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/editor_webview.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({Key? key}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTabs();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabs();
  }

  void _updateTabs() {
    final appState = Provider.of<AppState>(context, listen: false);
    final count = appState.openedFiles.length;
    
    // 如果 _tabController 已存在且长度相同，不做任何事
    if (_tabController != null && _tabController!.length == count) {
      final activeIndex = appState.openedFiles.indexWhere((f) => f.id == appState.activeFileId);
      if (activeIndex != -1 && _tabController!.index != activeIndex) {
        _tabController!.animateTo(activeIndex);
      }
      return;
    }

    // 否则，dispose 旧的并创建新的
    if (_tabController != null) {
      _tabController!.dispose();
    }
    _tabController = TabController(length: count, vsync: this);
    final activeIndex = appState.openedFiles.indexWhere((f) => f.id == appState.activeFileId);
    if (activeIndex != -1) {
      _tabController!.index = activeIndex;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑器'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              final opened = appState.openedFiles;
              if (opened.isEmpty || _tabController == null) {
                return const SizedBox.shrink();
              }
              return TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicator: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                tabs: opened.map((file) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(file.name),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _closeTab(context, file.id),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onTap: (index) {
                  final file = opened[index];
                  context.read<AppState>().activeFileId = file.id;
                },
              );
            },
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final activeFile = appState.activeFile;
          if (activeFile == null) {
            return const Center(child: Text('没有打开的文件'));
          }
          final isDark = appState.themeMode == ThemeMode.dark;
          return EditorWebView(
            key: ValueKey(activeFile.id),
            fileId: activeFile.id,
            content: activeFile.content,
            language: _getLanguageFromFileName(activeFile.name),
            isDarkMode: isDark,
            onContentChanged: (content) {
              appState.updateContent(activeFile.id, content);
            },
          );
        },
      ),
      bottomNavigationBar: Consumer<AppState>(
        builder: (context, appState, child) {
          final activeFile = appState.activeFile;
          if (activeFile == null) return const SizedBox.shrink();
          return Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildIconButton(Icons.undo, '撤销', () {}),
                _buildIconButton(Icons.redo, '重做', () {}),
                _buildIconButton(Icons.search, '查找', () {}),
                _buildIconButton(Icons.find_replace, '替换', () {}),
                const VerticalDivider(),
                _buildIconButton(Icons.save, '保存', () async {
                  try {
                    await appState.saveFile(activeFile.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('保存成功')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('保存失败: $e')),
                    );
                  }
                }),
                _buildIconButton(Icons.save_as, '另存为', () async {
                  await appState.saveAsFile(activeFile.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('另存为成功')),
                  );
                }),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    appState.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                  ),
                  onPressed: () {
                    final newMode = appState.themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                    appState.setThemeMode(newMode);
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final appState = context.read<AppState>();
          final file = await appState.createNewFile();
          await appState.openFile(file);
          _updateTabs();
          // 不导航，留在编辑器页
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40),
        onPressed: onPressed,
      ),
    );
  }

  void _closeTab(BuildContext context, String fileId) async {
    final appState = context.read<AppState>();
    try {
      await appState.closeFile(fileId);
      _updateTabs();
    } catch (e) {
      final file = appState.openedFiles.firstWhere((f) => f.id == fileId);
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('未保存'),
          content: Text('文件 "${file.name}" 有未保存的更改，是否保存？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('不保存'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (result == true) {
        await appState.saveFile(fileId);
        await appState.closeFile(fileId, force: true);
        _updateTabs();
      } else {
        await appState.closeFile(fileId, force: true);
        _updateTabs();
      }
    }
  }

  String _getLanguageFromFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'js': return 'javascript';
      case 'py': return 'python';
      case 'html': return 'html';
      case 'css': return 'css';
      case 'json': return 'json';
      case 'xml': return 'xml';
      default: return 'plaintext';
    }
  }

  @override
  void dispose() {
    if (_tabController != null) {
      _tabController!.dispose();
    }
    super.dispose();
  }
}
