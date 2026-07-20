import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
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

  /// 由路径生成稳定 id（同一文件多次加载 id 一致，避免重复打开检测失效）
  static String idForPath(String p) => p.hashCode.abs().toString();

  // ---------------- 编码 ----------------

  /// 按指定编码解码字节。UTF-8 走内置 codec，其余走平台原生转换。
  static Future<String> decodeBytes(Uint8List bytes, String encoding) async {
    if (encoding.toUpperCase() == 'UTF-8' || encoding.toUpperCase() == 'UTF8') {
      return utf8.decode(bytes, allowMalformed: true);
    }
    try {
      return await CharsetConverter.decode(encoding, bytes);
    } catch (_) {
      // 平台不支持该编码时退回 UTF-8
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 按指定编码编码文本。
  static Future<Uint8List> encodeText(String text, String encoding) async {
    if (encoding.toUpperCase() == 'UTF-8' || encoding.toUpperCase() == 'UTF8') {
      return Uint8List.fromList(utf8.encode(text));
    }
    try {
      return await CharsetConverter.encode(encoding, text);
    } catch (_) {
      return Uint8List.fromList(utf8.encode(text));
    }
  }

  /// 自动检测编码：严格 UTF-8 解码成功即视为 UTF-8，否则按回退编码（通常 GBK）。
  static Future<MapEntry<String, String>> detectAndDecode(
      Uint8List bytes, String fallbackEncoding) async {
    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return MapEntry('UTF-8', utf8.decode(bytes.sublist(3), allowMalformed: true));
    }
    try {
      // 严格模式：含非法序列会抛异常
      utf8.decode(bytes, allowMalformed: false);
      return MapEntry('UTF-8', utf8.decode(bytes));
    } catch (_) {
      final enc = fallbackEncoding.toUpperCase() == 'UTF-8' ? 'GBK' : fallbackEncoding;
      final text = await decodeBytes(bytes, enc);
      return MapEntry(enc, text);
    }
  }

  // ---------------- 读写 ----------------

  static Future<String> readFile(String filePath, [String encoding = 'UTF-8']) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return decodeBytes(bytes, encoding);
  }

  static Future<void> writeFile(String filePath, String content,
      [String encoding = 'UTF-8']) async {
    final file = File(filePath);
    final bytes = await encodeText(content, encoding);
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<FileModel> createNewFile({String content = '', String encoding = 'UTF-8'}) async {
    final dir = await getAppDir();
    final fileName = '新文件_${DateTime.now().millisecondsSinceEpoch}.txt';
    final filePath = path.join(dir, fileName);
    await writeFile(filePath, content, encoding);
    return FileModel(
      id: idForPath(filePath),
      name: fileName,
      path: filePath,
      content: content,
      encoding: encoding,
      isDirty: false,
      isNewFile: false,
    );
  }

  static Future<FileModel?> openExternalFile({String fallbackEncoding = 'UTF-8'}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // 部分平台不读数据时 bytes 为 null，下面有兜底
      );
      if (result == null) return null;
      final picked = result.files.single;

      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) return null;

      // 自动检测编码（UTF-8 / 回退编码）
      final detected = await detectAndDecode(bytes, fallbackEncoding);

      // 拷贝原始字节到应用目录
      final dir = await getAppDir();
      final newPath = path.join(dir, picked.name);
      await File(newPath).writeAsBytes(bytes, flush: true);

      return FileModel(
        id: idForPath(newPath),
        name: picked.name,
        path: newPath,
        content: detected.value,
        rawContent: bytes,
        encoding: detected.key,
        isDirty: false,
        isNewFile: false,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveFile(FileModel file, String encoding) async {
    await writeFile(file.path, file.content, encoding);
  }

  static Future<String?> saveAsFile(FileModel file, {String? encoding}) async {
    try {
      final enc = encoding ?? file.encoding;
      final bytes = await encodeText(file.content, enc);
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: file.name,
        bytes: bytes, // Android/iOS 由系统直接写入所选位置
      );
      if (outputPath == null) return null;
      // 桌面平台 saveFile 只返回路径，需要自己写；
      // Android 返回 content:// URI 时字节已由系统写入，不能按文件路径再写。
      if (!outputPath.startsWith('content://') &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        await File(outputPath).writeAsBytes(bytes, flush: true);
      }
      return outputPath;
    } catch (e) {
      return null;
    }
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
          id: idForPath(p),
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
