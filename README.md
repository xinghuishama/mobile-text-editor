# 移动端文本编辑器 (Mobile Text Editor)

一款基于 Flutter + Monaco Editor 的专业移动端代码编辑器，支持语法高亮、代码折叠、符号匹配、多标签页（最多5个）、文件管理、查找替换、撤销重做、主题切换、多种编码（UTF-8/GBK/Big5）。

## 功能特点
- 📁 文件管理：新建、打开（自动检测编码）、保存、另存为、删除
- 🏷️ 多标签页：同时打开最多5个文件，快速切换，未保存文件带 ● 标记
- 🎨 语法高亮：JavaScript/TypeScript、Python、HTML、CSS、JSON、XML、Java、C/C++、Go、Rust、PHP、Ruby、SQL、YAML、Shell、Kotlin、Swift、Dart、Markdown 等 30+ 种语言
- 📐 代码折叠、行号、括号匹配、自动闭合
- 🔍 查找与替换：区分大小写 / 正则表达式 / 全词匹配，上一个/下一个导航，替换当前/全部替换（正则替换支持 $1 分组引用）
- ↩️ 撤销/重做
- 📍 跳转到指定行
- 🌗 暗色/亮色主题（编辑器联动切换）
- 🔤 编码支持：UTF-8 / GBK / Big5（打开时自动检测，保存时可指定编码）
- 📊 状态栏：实时显示行列号、选中字数、总字符数、编码、语言、编辑器模式
- ⌨️ 标点符号快捷条（Acode 风格）：默认折叠，点底部工具栏右侧箭头展开/收起，点击符号插入光标处
- ⇥ 缩进/减少缩进按钮：作用于当前行或选中行（Monaco 用编辑器内置动作，降级模式按行首增删 Tab）
- 📥 「打开方式」支持：在文件管理器里选择 txt/md/html 等文本文件时，可直接用本应用打开（Android）
- 🔠 编辑器字号可调（设置页）
- 📴 离线降级：Monaco 加载失败（无网络）时自动切换内置基础编辑器，查找替换/撤销重做等功能全部可用

## 技术架构

```
Flutter UI (Dart)
   │  ┌─────────────────────────────────────────┐
   │  │ WebView (webview_flutter)               │
   ▼  │  ┌───────────────────────────────────┐  │
assets/editor/index.html                     │  │
   │  │  Monaco Editor (CDN 加载，双源重试)   │  │
   │  │  ↓ 加载失败/超时自动降级              │  │
   │  │  Fallback 编辑器 (textarea+行号)      │  │
   │  └───────────────────────────────────┘  │
   │     ▲ EditorBridge.postMessage (JS→Dart) │
   │     ▼ runJavaScript (Dart→JS)            │
   └─────────────────────────────────────────┘
```

### JS 桥接协议
- **JS → Dart**：`EditorBridge.postMessage(JSON)`
  - `{type:'ready', mode}` 编辑器就绪（monaco / fallback）
  - `{type:'content', text}` 内容变化（200ms 防抖）
  - `{type:'cursor', line, column, selected}` 光标/选区变化
- **Dart → JS**：`window.editorApi.*`
  - `setContent/getContent/setLanguage/setDarkMode/setFontSize`
  - `undo/redo`
  - `find/findNext/findPrev/replaceCurrent/replaceAll/closeFind`
  - `gotoLine/insertText/getStats`

## 目录结构
```
lib/
├── main.dart                  # 入口，主题与路由
├── models/file_model.dart     # 文件模型
├── providers/app_state.dart   # 全局状态（文件列表、打开的标签、设置）
├── pages/
│   ├── file_list_page.dart    # 文件列表页
│   ├── editor_page.dart       # 编辑器页（标签栏、工具栏、状态栏）
│   └── settings_page.dart     # 设置页（主题/编码/字号）
├── widgets/
│   ├── editor_webview.dart    # WebView 编辑器封装与 JS 桥接
│   ├── find_replace_bar.dart  # 查找替换面板
│   └── symbol_bar.dart        # 标点符号快捷条
├── services/
│   └── open_intent_service.dart # 「打开方式」intent 监听
└── utils/
    ├── file_utils.dart        # 文件读写、编码转换、自动检测
    └── theme_utils.dart       # 主题定义
assets/editor/index.html       # 编辑器页面（Monaco + 离线降级）
tools/patch_android.py         # Android 工程补丁（注册打开方式），CI 自动执行
tools/android/MainActivity.kt  # 处理 VIEW intent 的原生代码模板
```

## 构建与运行
```bash
flutter pub get
flutter run
```

注意事项：
- Monaco Editor 通过 CDN 加载，**Android release 构建需确保** `android/app/src/main/AndroidManifest.xml` 中有 `<uses-permission android:name="android.permission.INTERNET"/>`（`flutter create` 模板默认已包含）。无网络时会自动降级为基础编辑器，功能不受影响（无语法高亮）。
- 编码转换（GBK/Big5）依赖平台原生能力（charset_converter），Android/iOS 均内置支持。

## 「打开方式」说明（Android）
- GitHub Actions 构建时会自动执行 `tools/patch_android.py`，向 `AndroidManifest.xml` 注入 VIEW intent-filter 并写入处理 intent 的 `MainActivity.kt`，APK 装好后即可在文件管理器的「打开方式」里看到本应用。
- 本地构建若 `android/` 是自己 `flutter create` 生成的，需手动执行一次：
  ```bash
  python3 tools/patch_android.py
  ```
  脚本幂等，可重复执行；包名自动跟随工程。
- 打开的文件会被复制到应用文档目录后再编辑，原文件不会被改动。

## 移动端输入法说明
Monaco 的输入框焦点由 JS 程序转移产生，Android WebView 对此不会自动弹系统键盘。
本项目的处理：编辑器页面监听「用户触摸导致的 focus」，通过 `MethodChannel("mte/ime")`
通知原生，原生侧对 WebView 执行 `requestFocus() + showSoftInput()`。
程序性焦点（如查找跳转）不会误弹键盘。

## 应用图标
本包已附带生成好的图标资源，解压后合并到项目对应位置即可：
- **Android**：`android/app/src/main/res/mipmap-*/ic_launcher.png`（方形）与 `ic_launcher_round.png`（圆形），覆盖 `flutter create` 生成的默认图标。Manifest 引用 `@mipmap/ic_launcher` 无需修改。
- **iOS**：`ios/Runner/Assets.xcassets/AppIcon.appiconset/` 全套尺寸 + `Contents.json`，直接替换整个目录。
- 若有更高清的原图（建议 1024×1024），替换后重新生成各尺寸效果更佳。

## 更新日志

### v1.1.0
- 实现真正的 Monaco Editor（此前 index.html 为空文件，编辑器只是纯文本框）
- 接通撤销/重做/查找/替换（此前按钮均为空实现）
- 新增查找替换面板：正则、大小写、全词、导航、替换/全部替换
- 新增状态栏（行列号/字数/编码/语言/模式）与跳转到行
- GBK/Big5 编码真正落地：打开自动检测、按编码保存
- 修复：点击标签不切换内容（activeFileId 未通知）、TabController 泄漏、
  击键即全页重建的性能问题、切换标签丢失防抖窗口内字符、另存为无反馈、
  文件 id 不稳定导致重复打开检测失效、file_picker 未读 bytes 崩溃
- 新增编辑器字号设置、离线降级编辑器、另存为成功反馈
