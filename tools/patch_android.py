#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 flutter create 生成的 Android 工程打补丁（幂等，可重复执行）：

1. AndroidManifest.xml 注册文本文件 VIEW intent-filter（系统「打开方式」）
2. launchMode 改为 singleTask（复用已运行的实例）
3. 写入处理 VIEW intent 的 MainActivity.kt（包名自动跟随工程）

用法：python3 tools/patch_android.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'android/app/src/main/AndroidManifest.xml'
KOTLIN_DIR = ROOT / 'android/app/src/main/kotlin'
TEMPLATE = pathlib.Path(__file__).resolve().parent / 'android/MainActivity.kt'

# 支持「打开方式」的文本类扩展名
EXTENSIONS = [
    'txt', 'text', 'log', 'md', 'markdown', 'csv',
    'html', 'htm', 'xml', 'json', 'svg',
    'js', 'mjs', 'jsx', 'ts', 'tsx', 'css', 'scss', 'less',
    'py', 'java', 'c', 'h', 'cpp', 'cc', 'cxx', 'hpp', 'cs',
    'go', 'rs', 'php', 'rb', 'sql', 'yml', 'yaml', 'sh', 'bash',
    'kt', 'kts', 'swift', 'dart', 'lua', 'pl', 'r',
    'ini', 'toml', 'conf', 'gradle', 'properties',
]

VIEW_FILTERS = '''
        <!-- [mte] 文本文件「打开方式」支持，由 tools/patch_android.py 注入 -->
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="content" />
            <data android:mimeType="text/*" />
        </intent-filter>
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="content" />
            <data android:mimeType="application/octet-stream" />
        </intent-filter>
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <data android:scheme="file" />
            <data android:host="*" />
            <data android:mimeType="*/*" />
''' + ''.join(
    f'            <data android:pathPattern=".*\\\\.{ext}" />\n' for ext in EXTENSIONS
) + '''        </intent-filter>
        <!-- [mte] end -->
'''


def patch_manifest() -> None:
    if not MANIFEST.exists():
        print(f'[patch] 未找到 {MANIFEST}，跳过（请先 flutter create 生成工程）')
        return
    text = MANIFEST.read_text(encoding='utf-8')
    changed = False

    if 'android.intent.action.VIEW' not in text:
        # 在 </activity> 前插入 intent-filter
        new_text, n = re.subn(r'(\n\s*</activity>)', VIEW_FILTERS + r'\1', text, count=1)
        if n == 0:
            print('[patch] 错误：manifest 中未找到 </activity>')
            sys.exit(1)
        text = new_text
        changed = True
        print('[patch] 已注入 VIEW intent-filter')
    else:
        print('[patch] intent-filter 已存在，跳过')

    m = re.search(r'android:launchMode="([^"]+)"', text)
    if m and m.group(1) != 'singleTask':
        text = text.replace(m.group(0), 'android:launchMode="singleTask"')
        changed = True
        print('[patch] launchMode 已改为 singleTask')
    elif not m:
        # 没有 launchMode 时补一个（挂在 activity 标签上）
        text, n = re.subn(
            r'(<activity\s+android:name="[^"]*MainActivity")',
            r'\1\n            android:launchMode="singleTask"',
            text, count=1)
        if n:
            changed = True
            print('[patch] 已补充 launchMode="singleTask"')

    if changed:
        MANIFEST.write_text(text, encoding='utf-8')


def patch_main_activity() -> None:
    # 找现有 MainActivity.kt 以获取真实包名与路径
    existing = list(KOTLIN_DIR.rglob('MainActivity.kt')) if KOTLIN_DIR.exists() else []
    if existing:
        target = existing[0]
        m = re.search(r'package\s+([\w.]+)', target.read_text(encoding='utf-8'))
        package = m.group(1) if m else 'com.example.mobile_text_editor'
    else:
        package = 'com.example.mobile_text_editor'
        target = KOTLIN_DIR / pathlib.Path(*package.split('.')) / 'MainActivity.kt'

    body = TEMPLATE.read_text(encoding='utf-8').replace('PACKAGE_NAME', package)
    if target.exists() and target.read_text(encoding='utf-8') == body:
        print('[patch] MainActivity.kt 已是最新，跳过')
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding='utf-8')
    print(f'[patch] 已写入 {target}（package={package}）')


if __name__ == '__main__':
    patch_manifest()
    patch_main_activity()
    print('[patch] 完成')
