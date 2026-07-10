import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            children: [
              ListTile(
                title: const Text('主题'),
                trailing: DropdownButton<ThemeMode>(
                  value: appState.themeMode,
                  onChanged: (mode) {
                    if (mode != null) appState.setThemeMode(mode);
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.light, child: Text('亮色')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('暗色')),
                  ],
                ),
              ),
              ListTile(
                title: const Text('默认编码'),
                trailing: DropdownButton<String>(
                  value: appState.defaultEncoding,
                  onChanged: (enc) {
                    if (enc != null) appState.setDefaultEncoding(enc);
                  },
                  items: const [
                    DropdownMenuItem(value: 'UTF-8', child: Text('UTF-8')),
                    DropdownMenuItem(value: 'GBK', child: Text('GBK')),
                    DropdownMenuItem(value: 'Big5', child: Text('Big5')),
                  ],
                ),
              ),
              const Divider(),
              const ListTile(
                title: Text('关于'),
                subtitle: Text('移动端文本编辑器 v1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }
}