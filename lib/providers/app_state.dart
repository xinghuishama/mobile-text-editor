import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_model.dart';
import '../utils/file_utils.dart';

class AppState extends ChangeNotifier {
  List<FileModel> savedFiles = [];
  List<FileModel> openedFiles = [];
  String? activeFileId;
  ThemeMode themeMode = ThemeMode.dark;
  String defaultEncoding = 'UTF-8';

  AppState() {
    _loadSettings();
    _loadSavedFiles();
  }

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

  Future<void> _loadSavedFiles() async {
    final files = await FileUtils.loadFileList();
    savedFiles = files;
    notifyListeners();
  }

  Future<void> refreshSavedFiles() async {
    await _loadSavedFiles();
  }

  Future<FileModel> createNewFile({String? content}) async {
    final file = await FileUtils.createNewFile(content: content ?? '', encoding: defaultEncoding);
    savedFiles.add(file);
    await _saveFileList();
    notifyListeners();
    return file;
  }

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

  Future<void> openFile(FileModel file) async {
    if (openedFiles.any((f) => f.id == file.id)) {
      activeFileId = file.id;
      notifyListeners();
      return;
    }
    if (openedFiles.length >= 5) {
      throw Exception('已达最大打开文件数 (5个)');
    }
    // 使用 readFile（不再有 readFileWithEncoding）
    final content = await FileUtils.readFile(file.path);
    final updatedFile = file.copyWith(content: content, isDirty: false);
    openedFiles.add(updatedFile);
    activeFileId = updatedFile.id;
    notifyListeners();
  }

  Future<void> closeFile(String fileId, {bool force = false}) async {
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    if (index == -1) return;
    final file = openedFiles[index];
    if (file.isDirty && !force) {
      throw Exception('文件未保存');
    }
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

  Future<void> saveFile(String fileId, {String? encoding}) async {
    final file = openedFiles.firstWhere((f) => f.id == fileId);
    final enc = encoding ?? file.encoding;
    await FileUtils.saveFile(file, enc);
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    openedFiles[index] = file.copyWith(isDirty: false, encoding: enc);
    final savedIndex = savedFiles.indexWhere((f) => f.id == fileId);
    if (savedIndex != -1) {
      savedFiles[savedIndex] = openedFiles[index];
    }
    await _saveFileList();
    notifyListeners();
  }

  Future<void> saveAsFile(String fileId, {String? encoding}) async {
    final file = openedFiles.firstWhere((f) => f.id == fileId);
    final newPath = await FileUtils.saveAsFile(file, encoding: encoding);
    if (newPath != null) {
      final newFile = file.copyWith(
        path: newPath,
        name: newPath.split('/').last,
        isNewFile: false,
        isDirty: false,
        encoding: encoding ?? file.encoding,
      );
      final index = openedFiles.indexWhere((f) => f.id == fileId);
      openedFiles[index] = newFile;
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

  void updateContent(String fileId, String content) {
    final index = openedFiles.indexWhere((f) => f.id == fileId);
    if (index != -1) {
      openedFiles[index] = openedFiles[index].copyWith(
        content: content,
        isDirty: true,
      );
      final savedIndex = savedFiles.indexWhere((f) => f.id == fileId);
      if (savedIndex != -1) {
        savedFiles[savedIndex] = openedFiles[index];
      }
      notifyListeners();
    }
  }

  FileModel? get activeFile {
    if (activeFileId == null) return null;
    try {
      return openedFiles.firstWhere((f) => f.id == activeFileId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFileList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = savedFiles.map((f) => f.path).toList();
    await prefs.setStringList('savedFiles', list);
  }

  Future<void> deleteFile(String fileId) async {
  Future<void> renameFile(String fileId, String newName) async {
    final file = savedFiles.firstWhere((f) => f.id == fileId);
    final newPath = file.path.replaceAll(file.name, newName);
    final newFile = File(newPath);
    await file.file.rename(newPath);
    file.name = newName;
    file.path = newPath;
    await _saveFileList();
    notifyListeners();
  }
    final file = savedFiles.firstWhere((f) => f.id == fileId);
    await FileUtils.deleteFile(file.path);
    savedFiles.removeWhere((f) => f.id == fileId);
    if (openedFiles.any((f) => f.id == fileId)) {
      await closeFile(fileId, force: true);
    }
    await _saveFileList();
    notifyListeners();
  }
}
