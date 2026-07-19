class FileTemplate {
  final String name;
  final String extension;
  final String content;
  final String language;

  const FileTemplate({
    required this.name,
    required this.extension,
    required this.content,
    required this.language,
  });

  static const List<FileTemplate> templates = [
    FileTemplate(
      name: 'HTML',
      extension: 'html',
      language: 'html',
      content: '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>新建页面</title>
</head>
<body>
  <h1>Hello World</h1>
</body>
</html>''',
    ),
    FileTemplate(
      name: 'React',
      extension: 'jsx',
      language: 'javascript',
      content: '''import React from 'react';

function App() {
  return (
    <div className="App">
      <h1>Hello React</h1>
    </div>
  );
}

export default App;''',
    ),
    FileTemplate(
      name: 'Python',
      extension: 'py',
      language: 'python',
      content: '''#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def main():
    print("Hello World")

if __name__ == "__main__":
    main()''',
    ),
    FileTemplate(
      name: 'JavaScript',
      extension: 'js',
      language: 'javascript',
      content: '''// JavaScript 文件
console.log("Hello World");''',
    ),
    FileTemplate(
      name: 'TypeScript',
      extension: 'ts',
      language: 'typescript',
      content: '''// TypeScript 文件
const greet = (name: string): void => {
  console.log("Hello, " + name);
};

greet("World");''',
    ),
    FileTemplate(
      name: 'CSS',
      extension: 'css',
      language: 'css',
      content: '''/* CSS 样式 */
body {
  margin: 0;
  padding: 20px;
  font-family: sans-serif;
}''',
    ),
    FileTemplate(
      name: 'JSON',
      extension: 'json',
      language: 'json',
      content: '''{
  "name": "项目名称",
  "version": "1.0.0",
  "description": "描述"
}''',
    ),
    FileTemplate(
      name: 'Markdown',
      extension: 'md',
      language: 'markdown',
      content: '''# 标题

这是Markdown文档。

## 二级标题

- 列表项1
- 列表项2

**粗体** *斜体* `代码`''',
    ),
    FileTemplate(
      name: 'Shell',
      extension: 'sh',
      language: 'shell',
      content: '''#!/bin/bash
# Shell 脚本

echo "Hello World"''',
    ),
    FileTemplate(
      name: '空白文件',
      extension: 'txt',
      language: 'plaintext',
      content: '',
    ),
  ];
}
