import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:charset/charset.dart' as charset;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_model.dart';

class FileUtils {
  static Future<String> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static String generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  static Future<String> readFileWithEncoding(String path, String encoding) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (encoding == 'UTF-8') {
      return utf8.decode(bytes);
    } else if (encoding == 'GBK') {
      return charset.decode(bytes, charset.gbk);
    } else if (encoding == 'Big5') {
      return charset.decode(bytes, charset.big5);
    } else {
      try {
        final detected = charset.detect(bytes);
        if (detected != null) {
          return charset.decode(bytes, detected);
        }
      } catch (_) {}
      return utf8.decode(bytes);
    }
  }

  static Future<void> writeFileWithEncoding(String path, String content, String encoding) async {
    final file = File(path);
    List<int> bytes;
    if (encoding == 'UTF-8') {
      bytes = utf8.encode(content);
    } else if (encoding == 'GBK') {
      bytes = charset.encode(content, charset.gbk);
    } else if (encoding == 'Big5') {
      bytes = charset.encode(content, charset.big5);
    } else {
      bytes = utf8.encode(content);
    }
    await file.writeAsBytes(bytes);
  }

  static Future<FileModel> createNewFile({String content = '', String encoding = 'UTF-8'}) async {
    final dir = await getAppDir();
    final fileName = '新文件_${DateTime.now().millisecondsSinceEpoch}.txt';
    final filePath = path.join(dir, fileName);
    final file = File(filePath);
    await file.create(recursive: true);
    await writeFileWithEncoding(filePath, content, encoding);
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
    String encoding = 'UTF-8';
    try {
      final detected = charset.detect(bytes);
      if (detected != null) {
        encoding = detected.name;
      }
    } catch (_) {}
    final dir = await getAppDir();
    final newPath = path.join(dir, originalName);
    final newFile = File(newPath);
    await newFile.writeAsBytes(bytes);
    String content = await readFileWithEncoding(newPath, encoding);
    return FileModel(
      id: generateId(),
      name: originalName,
      path: newPath,
      content: content,
      encoding: encoding,
      isDirty: false,
      isNewFile: false,
    );
  }

  static Future<void> saveFile(FileModel file, String encoding) async {
    await writeFileWithEncoding(file.path, file.content, encoding);
  }

  static Future<String?> saveAsFile(FileModel file, {String? encoding}) async {
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: file.name,
    );
    if (outputPath == null) return null;
    final enc = encoding ?? file.encoding;
    await writeFileWithEncoding(outputPath, file.content, enc);
    return outputPath;
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
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
