cat > README.md <<'EOF'
# 移动端文本编辑器 (Mobile Text Editor)

一款基于 Flutter + Monaco Editor 的专业移动端代码编辑器，支持语法高亮、代码折叠、符号匹配、多标签页（最多5个）、文件管理、查找替换、撤销重做、主题切换、多种编码（UTF-8/GBK/Big5）。

## 功能特点
- 📁 文件管理：新建、打开、保存、另存为、删除
- 🏷️ 多标签页：同时打开最多5个文件，快速切换
- 🎨 语法高亮：支持 JavaScript、Python、HTML、CSS、JSON、XML 等
- 📐 代码折叠与行号显示
- 🔍 查找与替换（支持正则表达式）
- ↩️ 撤销/重做
- 🌗 暗色/亮色主题
- 🔤 编码选择（UTF-8, GBK, Big5）

## 技术栈
- Flutter (跨平台)
- Monaco Editor (WebView 内嵌)

## 构建与运行
```bash
flutter pub get
flutter run