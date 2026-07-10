import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gbk/gbk.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:charset_detector/charset_detector.dart';
import '../models/file_model.dart';

class FileUtils {
  // 获取应用文档目录
  static Future<String> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // 生成唯一ID
  static String generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  // 读取文件内容 (自动检测编码)
  static Future<String> readFileWithEncoding(String path, String encoding) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    // 如果指定编码，直接转换
    if (encoding == 'UTF-8') {
      return utf8.decode(bytes);
    } else if (encoding == 'GBK') {
      return gbk.decode(bytes);
    } else if (encoding == 'Big5') {
      final result = await CharsetConverter.decode('big5', bytes);
      return result;
    } else {
      // 尝试自动检测
      final detected = await CharsetDetector.detect(bytes);
      if (detected != null && detected.charset != null) {
        return await CharsetConverter.decode(detected.charset!, bytes);
      }
      // 默认UTF-8
      return utf8.decode(bytes);
    }
  }

  // 写入文件 (指定编码)
  static Future<void> writeFileWithEncoding(String path, String content, String encoding) async {
    final file = File(path);
    Uint8List bytes;
    if (encoding == 'UTF-8') {
      bytes = utf8.encode(content) as Uint8List;
    } else if (encoding == 'GBK') {
      bytes = gbk.encode(content) as Uint8List;
    } else if (encoding == 'Big5') {
      final encoded = await CharsetConverter.encode('big5', content);
      bytes = encoded;
    } else {
      bytes = utf8.encode(content) as Uint8List;
    }
    await file.writeAsBytes(bytes);
  }

  // 创建新文件
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

  // 打开外部文件 (通过文件选择器)
  static Future<FileModel?> openExternalFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes!;
    final originalName = file.name;
    // 检测编码
    final detected = await CharsetDetector.detect(bytes);
    String encoding = 'UTF-8';
    if (detected != null && detected.charset != null) {
      encoding = detected.charset!;
    }
    // 复制到应用目录
    final dir = await getAppDir();
    final newPath = path.join(dir, originalName);
    final newFile = File(newPath);
    await newFile.writeAsBytes(bytes);
    // 读取内容
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

  // 保存文件 (覆盖)
  static Future<void> saveFile(FileModel file, String encoding) async {
    await writeFileWithEncoding(file.path, file.content, encoding);
  }

  // 另存为
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

  // 删除文件
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // 加载已保存文件列表 (从SharedPreferences读取路径)
  static Future<List<FileModel>> loadFileList() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('savedFiles') ?? [];
    List<FileModel> files = [];
    for (var p in paths) {
      final file = File(p);
      if (await file.exists()) {
        // 读取内容（只读取前几行用于显示？但为了简便，我们只存储路径，内容在打开时加载）
        // 这里只创建模型，不加载内容
        files.add(FileModel(
          id: generateId(),
          name: path.basename(p),
          path: p,
          content: '', // 稍后加载
          encoding: 'UTF-8', // 稍后检测
          isDirty: false,
          isNewFile: false,
        ));
      }
    }
    return files;
  }
}