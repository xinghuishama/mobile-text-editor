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

/// 跳转到编辑器页。冷启动时 navigator 可能尚未挂载，重试几次。
void _navigateToEditor([int retry = 10]) {
  final nav = navigatorKey.currentState;
  if (nav != null) {
    nav.pushNamedAndRemoveUntil('/editor', (route) => route.isFirst);
  } else if (retry > 0) {
    Future.delayed(const Duration(milliseconds: 200),
        () => _navigateToEditor(retry - 1));
  }
}

void main() {
  // 必须先初始化绑定：下面的 OpenIntentService.init 要使用平台通道，
  // 否则「打开方式」的消息根本注册不上监听。
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();

  // 注册「打开方式」监听：从文件管理器用本应用打开文本文件时触发
  OpenIntentService.init((path) async {
    final file = await appState.importOpenedFile(path);
    if (file != null) {
      // 回到根路由再进编辑器，避免叠加多个编辑器页
      _navigateToEditor();
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
