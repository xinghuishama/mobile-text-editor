import 'package:flutter/material.dart';

class EditorWebView extends StatefulWidget {
  final String fileId;
  final String content;
  final String language;
  final bool isDarkMode;
  final Function(String) onContentChanged;

  const EditorWebView({
    Key? key,
    required this.fileId,
    required this.content,
    required this.language,
    required this.isDarkMode,
    required this.onContentChanged,
  }) : super(key: key);

  @override
  _EditorWebViewState createState() => _EditorWebViewState();
}

class _EditorWebViewState extends State<EditorWebView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _controller.addListener(() {
      widget.onContentChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(EditorWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _controller.text = widget.content;
    }
    if (oldWidget.content != widget.content && _controller.text != widget.content) {
      _controller.text = widget.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件: ${widget.fileId}  语言: ${widget.language}',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void triggerFind() {}
  void triggerReplace() {}
  void undo() {}
  void redo() {}
  void setLanguage(String language) {}
}
