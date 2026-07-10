import 'dart:typed_data';

class FileModel {
  final String id;          // 唯一标识 (使用时间戳或UUID)
  String name;              // 文件名
  String path;              // 完整路径 (应用目录下)
  String content;           // 当前内容 (UTF-16 字符串)
  Uint8List? rawContent;    // 原始字节 (用于编码转换)
  String encoding;          // 当前编码 (UTF-8, GBK, Big5...)
  bool isDirty;             // 是否未保存
  bool isNewFile;           // 是否是新建未保存文件

  FileModel({
    required this.id,
    required this.name,
    required this.path,
    this.content = '',
    this.rawContent,
    this.encoding = 'UTF-8',
    this.isDirty = false,
    this.isNewFile = false,
  });

  // 复制方法
  FileModel copyWith({
    String? id,
    String? name,
    String? path,
    String? content,
    Uint8List? rawContent,
    String? encoding,
    bool? isDirty,
    bool? isNewFile,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      content: content ?? this.content,
      rawContent: rawContent ?? this.rawContent,
      encoding: encoding ?? this.encoding,
      isDirty: isDirty ?? this.isDirty,
      isNewFile: isNewFile ?? this.isNewFile,
    );
  }
}