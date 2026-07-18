import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  EditorWebViewState createState() => EditorWebViewState();
}

class EditorWebViewState extends State<EditorWebView> {
  late WebViewController _controller;
  bool _isLoaded = false;
  String _currentContent = '';

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
  }

  @override
  void didUpdateWidget(EditorWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileId != widget.fileId) {
      _loadContent();
    } else if (oldWidget.content != widget.content && _isLoaded) {
      _setEditorContent(widget.content);
    }
    if (oldWidget.isDarkMode != widget.isDarkMode && _isLoaded) {
      _setTheme(widget.isDarkMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: Uri.dataFromString(_getHtml(), mimeType: 'text/html').toString(),
      onWebViewCreated: (controller) {
        _controller = controller;
        _controller.addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (message) {
            final data = jsonDecode(message.message);
            if (data['type'] == 'contentChanged') {
              final content = data['content'];
              _currentContent = content;
              widget.onContentChanged(content);
            }
          },
        );
      },
      onPageFinished: (url) {
        _isLoaded = true;
        _setTheme(widget.isDarkMode);
        _setEditorContent(widget.content);
      },
      javascriptMode: JavascriptMode.unrestricted,
    );
  }

  String _getHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; overflow: hidden; }
    #container { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <div id="container"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.1/min/vs/loader.min.js"></script>
  <script>
    let editor;
    let currentContent = '';
    let isDark = true;

    require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.1/min/vs' } });
    require(['vs/editor/editor.main'], function () {
      editor = monaco.editor.create(document.getElementById('container'), {
        value: '',
        language: 'plaintext',
        theme: isDark ? 'vs-dark' : 'vs',
        automaticLayout: true,
        lineNumbers: 'on',
        folding: true,
        bracketPairColorization: true,
        renderWhitespace: 'selection',
        scrollBeyondLastLine: false,
        fontSize: 14,
        minimap: { enabled: false },
      });

      editor.onDidChangeModelContent(() => {
        const val = editor.getValue();
        if (val !== currentContent) {
          currentContent = val;
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'contentChanged',
            content: val
          }));
        }
      });

      window.setLanguage = function(lang) {
        monaco.editor.setModelLanguage(editor.getModel(), lang);
      };

      window.setContent = function(content) {
        if (content !== currentContent) {
          currentContent = content;
          editor.setValue(content);
        }
      };

      window.setTheme = function(dark) {
        isDark = dark;
        monaco.editor.setTheme(dark ? 'vs-dark' : 'vs');
      };

      window.triggerFind = function() {
        editor.getAction('actions.find').run();
      };

      window.triggerReplace = function() {
        editor.getAction('editor.action.startFindReplaceAction').run();
      };

      window.undo = function() {
        editor.getAction('undo').run();
      };

      window.redo = function() {
        editor.getAction('redo').run();
      };
    });
  </script>
</body>
</html>
    ''';
  }

  void _setEditorContent(String content) {
    _controller.runJavaScript('setContent("${_escapeJs(content)}");');
  }

  void _setTheme(bool isDark) {
    _controller.runJavaScript('setTheme($isDark);');
  }

  void _loadContent() {
    _setEditorContent(widget.content);
  }

  String _escapeJs(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '');
  }

  void triggerFind() {
    _controller.runJavaScript('triggerFind();');
  }

  void triggerReplace() {
    _controller.runJavaScript('triggerReplace();');
  }

  void undo() {
    _controller.runJavaScript('undo();');
  }

  void redo() {
    _controller.runJavaScript('redo();');
  }

  void setLanguage(String language) {
    _controller.runJavaScript('setLanguage("$language");');
  }
}
