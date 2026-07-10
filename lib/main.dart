import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'pages/file_list_page.dart';
import 'pages/editor_page.dart';
import 'pages/settings_page.dart';
import 'utils/theme_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: '移动端文本编辑器',
            theme: appState.themeMode == ThemeMode.light
                ? ThemeUtils.lightTheme
                : ThemeUtils.darkTheme,
            darkTheme: ThemeUtils.darkTheme,
            themeMode: appState.themeMode,
            initialRoute: '/',
            routes: {
              '/': (ctx) => const FileListPage(),
              '/editor': (ctx) => const EditorPage(),
              '/settings': (ctx) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}