import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/file_model.dart';
import '../models/file_template.dart';

class FileListPage extends StatelessWidget {
  const FileListPage({Key? key}) : super(key: key);

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
          final recentFiles = files.isNotEmpty
              ? files.reversed.take(3).toList()
              : <FileModel>[];

          if (files.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('没有文件，点击右下角创建或打开'),
                ],
              ),
            );
          }

          return ListView(
            children: [
              if (recentFiles.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '最近编辑',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentFiles.length,
                    itemBuilder: (ctx, index) {
                      final file = recentFiles[index];
                      return GestureDetector(
                        onTap: () async {
                          try {
                            await appState.openFile(file);
                            Navigator.pushNamed(context, '/editor');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
              ],
              ...files.map((file) {
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(file.name),
                  subtitle: Text(
                    file.path.split('/').last,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _showDeleteConfirm(context, file.id),
                      ),
                    ],
                  ),
                  onTap: () async {
                    try {
                      await appState.openFile(file);
                      Navigator.pushNamed(context, '/editor');
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'new',
            onPressed: () => _showTemplateDialog(context),
            child: const Icon(Icons.note_add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'open',
            onPressed: () async {
              final file = await context.read<AppState>().openExternalFile();
              if (file != null) {
                await context.read<AppState>().openFile(file);
                Navigator.pushNamed(context, '/editor');
              }
            },
            child: const Icon(Icons.folder_open),
          ),
        ],
      ),
    );
  }

  void _showTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: FileTemplate.templates.length,
            itemBuilder: (context, index) {
              final template = FileTemplate.templates[index];
              return InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final appState = context.read<AppState>();
                  final file = await appState.createNewFile(
                    content: template.content,
                  );
                  await appState.openFile(file);
                  Navigator.pushNamed(context, '/editor');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.insert_drive_file,
                        size: 32,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
