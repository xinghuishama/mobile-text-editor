import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_model.dart';
import '../utils/file_utils.dart';

class AppState extends ChangeNotifier {
  // 所有已保存的文件列表 (显示在文件列表页)
  List<FileModel> savedFiles = [];

  // 当前打开的文件 (最多5个)
  List<FileModel> openedFiles = [];

  // 当前活动文件ID
  String? activeFileId;

  // 主题设置
  ThemeMode themeMode = ThemeMode.dark;

  // 默认编码
  String defaultEncoding = 'UTF-8';

  AppState() {
    _loadSettings();
    _loadSavedFiles();
  }

  // ---------- 设置 ----------
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode') ?? 'dark';
    themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    defaultEncoding = prefs.getString('defaultEncoding') ?? 'UTF-8';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setDefaultEncoding(String encoding) async {
    defaultEncoding = encoding;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultEncoding', encoding);
    notifyListeners();
  }

  // ---------- 文件管理 ----------
  Future<void> _loadSavedFiles() async {
    final files = await FileUtils.loadFileList();
    savedFiles = files;
    notifyListeners();
  }

  Future<void> refreshSavedFiles() async {
    await _loadSavedFiles();
  }

  // 新建文件
  Future<FileModel> createNewFile({String? content}) async {
    final file = await FileUtils.createNewFile(content: content ?? '', encoding: defaultEncoding);
    savedFiles.add(file);
    await _saveFileList();
    notifyListeners();
    return file;
  }

  // 打开外部文件 (通过 file_picker)
  Future<FileModel?> openExternalFile() async {
    final file = await FileUtils.openExternalFile();
    if (file != null) {
      savedFiles.add(file);
      await _saveFileList();
      notifyListeners();
      return file;
    }
    return null;
  }

  // 打开已有文件 (从savedFiles中)
  Future<void> openFile(FileModel file) async {
    // 如果已经打开，切换活动
    if (openedFiles.any((f) => f.id == file.id)) {
      activeFileId = file.id;
      notifyListeners();
      return;
    }
    // 检查上限
    if (openedFiles.length >= 5) {
      throw Exception('已达最大打开文件数 (5个)');
    }
    // 确保内容最新
    final content = await FileUtils.readFileWithEncoding(file.path, file.encoding);
    final updatedFile = file.copyWith(content: content, isDirty: false);
    openedFiles.add(updatedFile);
    activeFileId = updatedFile.id;
    notifyListeners();
  }

  // 关闭文件
  Future<void> closeFile(String fileId, {bool force = false}) async {
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    if (index == -1) return;

    final file = openedFiles[index];
    if (file.isDirty && !force) {
      // 需要提示用户保存 (由UI层处理)
      // 抛出异常，由调用方捕获并显示对话框
      throw Exception('文件未保存');
    }

    // 如果文件是新建的且未保存，则从savedFiles中移除
    if (file.isNewFile && !file.isDirty) {
      savedFiles.removeWhere((f) => f.id == fileId);
      await _saveFileList();
    }

    openedFiles.removeAt(index);
    if (activeFileId == fileId) {
      activeFileId = openedFiles.isNotEmpty ? openedFiles.last.id : null;
    }
    notifyListeners();
  }

  // 保存文件
  Future<void> saveFile(String fileId, {String? encoding}) async {
    final file = openedFiles.firstWhere((f) => f.id == fileId);
    final enc = encoding ?? file.encoding;
    await FileUtils.saveFile(file, enc);
    // 更新模型
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    openedFiles[index] = file.copyWith(isDirty: false, encoding: enc);
    // 更新savedFiles列表
    final savedIndex = savedFiles.indexWhere((f) => f.id == fileId);
    if (savedIndex != -1) {
      savedFiles[savedIndex] = openedFiles[index];
    }
    await _saveFileList();
    notifyListeners();
  }

  // 另存为
  Future<void> saveAsFile(String fileId, {String? encoding}) async {
    final file = openedFiles.firstWhere((f) => f.id == fileId);
    final newPath = await FileUtils.saveAsFile(file, encoding: encoding);
    if (newPath != null) {
      // 更新模型，转为已保存文件
      final newFile = file.copyWith(
        path: newPath,
        name: newPath.split('/').last,
        isNewFile: false,
        isDirty: false,
        encoding: encoding ?? file.encoding,
      );
      final index = openedFiles.indexWhere((f) => f.id == fileId);
      openedFiles[index] = newFile;
      // 添加到savedFiles（如果原来存在则替换）
      final existing = savedFiles.indexWhere((f) => f.id == fileId);
      if (existing != -1) {
        savedFiles[existing] = newFile;
      } else {
        savedFiles.add(newFile);
      }
      await _saveFileList();
      notifyListeners();
    }
  }

  // 更新内容 (由WebView通知)
  void updateContent(String fileId, String content) {
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    if (index != -1) {
      openedFiles[index] = openedFiles[index].copyWith(
        content: content,
        isDirty: true,
      );
      // 同时更新savedFiles中对应的条目
      final savedIndex = savedFiles.indexWhere((f) => f.id == fileId);
      if (savedIndex != -1) {
        savedFiles[savedIndex] = openedFiles[index];
      }
      notifyListeners();
    }
  }

  // 获取当前活动文件
  FileModel? get activeFile {
    if (activeFileId == null) return null;
    try {
      return openedFiles.firstWhere((f) => f.id == activeFileId);
    } catch (_) {
      return null;
    }
  }

  // 保存文件列表到本地 (用于快速加载)
  Future<void> _saveFileList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = savedFiles.map((f) => f.path).toList();
    await prefs.setStringList('savedFiles', list);
  }

  // 删除文件 (从磁盘和列表)
  Future<void> deleteFile(String fileId) async {
    final file = savedFiles.firstWhere((f) => f.id == fileId);
    await FileUtils.deleteFile(file.path);
    savedFiles.removeWhere((f) => f.id == fileId);
    // 如果已打开，则关闭
    if (openedFiles.any((f) => f.id == fileId)) {
      await closeFile(fileId, force: true);
    }
    await _saveFileList();
    notifyListeners();
  }
}