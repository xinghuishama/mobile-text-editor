import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'pages/file_list_page.dart';
import 'pages/editor_page.dart';
import 'pages/settings_page.dart';
import 'services/open_intent_service.dart';
import 'utils/theme_utils.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  final appState = AppState();
  // 注册「打开方式」监听：从文件管理器用本应用打开文本文件时触发
  OpenIntentService.init((path) async {
    final file = await appState.importOpenedFile(path);
    if (file != null) {
      // 回到根路由再进编辑器，避免叠加多个编辑器页
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/editor',
        (route) => route.isFirst,
      );
    }
  });
  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  final AppState appState;
  const MyApp({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: '移动端文本编辑器',
            theme: appState.themeMode == ThemeMode.light
                ? ThemeUtils.lightTheme
                : ThemeUtils.darkTheme,
            darkTheme: ThemeUtils.darkTheme,
            themeMode: appState.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en'),
            ],
            locale: const Locale('zh', 'CN'),
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
