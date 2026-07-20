import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/file_model.dart';

class FileListPage extends StatelessWidget {
  const FileListPage({Key? key}) : super(key: key);

  Future<void> _openFile(BuildContext context, FileModel file) async {
    final appState = context.read<AppState>();
    try {
      await appState.openFile(file);
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/editor');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final files = appState.savedFiles;
          if (files.isEmpty) {
            return const Center(child: Text('没有文件，点击右下角创建或打开'));
          }
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (ctx, index) {
              final file = files[index];
              return ListTile(
                title: Text(file.name),
                subtitle: Text(file.path, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _showDeleteConfirm(context, file.id);
                  },
                ),
                onTap: () => _openFile(context, file),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'new',
            tooltip: '新建文件',
            onPressed: () async {
              final appState = context.read<AppState>();
              final file = await appState.createNewFile();
              if (!context.mounted) return;
              await _openFile(context, file);
            },
            child: const Icon(Icons.note_add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'open',
            tooltip: '打开文件',
            onPressed: () async {
              final appState = context.read<AppState>();
              final file = await appState.openExternalFile();
              if (file == null || !context.mounted) return;
              await _openFile(context, file);
            },
            child: const Icon(Icons.folder_open),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String fileId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: const Text('确定要删除此文件吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deleteFile(fileId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文件已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
