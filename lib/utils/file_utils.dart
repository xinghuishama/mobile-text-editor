import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_model.dart';

class FileUtils {
  static Future<String> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static String generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  static Future<String> readFile(String path) async {
    final file = File(path);
    return await file.readAsString(encoding: utf8);
  }

  static Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content, encoding: utf8);
  }

  static Future<FileModel> createNewFile({String content = '', String encoding = 'UTF-8'}) async {
    final dir = await getAppDir();
    final fileName = '新文件_${DateTime.now().millisecondsSinceEpoch}.txt';
    final filePath = path.join(dir, fileName);
    await writeFile(filePath, content);
    return FileModel(
      id: generateId(),
      name: fileName,
      path: filePath,
      content: content,
      encoding: encoding,
      isDirty: false,
      isNewFile: false,
    );
  }

  static Future<FileModel?> openExternalFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes!;
    final originalName = file.name;
    final dir = await getAppDir();
    final newPath = path.join(dir, originalName);
    final newFile = File(newPath);
    await newFile.writeAsBytes(bytes);
    String content = utf8.decode(bytes, allowMalformed: true);
    return FileModel(
      id: generateId(),
      name: originalName,
      path: newPath,
      content: content,
      encoding: 'UTF-8',
      isDirty: false,
      isNewFile: false,
    );
  }

  static Future<void> saveFile(FileModel file, String encoding) async {
    await writeFile(file.path, file.content);
  }

  static Future<String?> saveAsFile(FileModel file, {String? encoding}) async {
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: file.name,
    );
    if (outputPath == null) return null;
    await writeFile(outputPath, file.content);
    return outputPath;
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<List<FileModel>> loadFileList() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('savedFiles') ?? [];
    List<FileModel> files = [];
    for (var p in paths) {
      final file = File(p);
      if (await file.exists()) {
        files.add(FileModel(
          id: generateId(),
          name: path.basename(p),
          path: p,
          content: '',
          encoding: 'UTF-8',
          isDirty: false,
          isNewFile: false,
        ));
      }
    }
    return files;
  }
}
