package PACKAGE_NAME

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * 1) 处理「打开方式」(ACTION_VIEW) intent：
 *    把 content:// 或 file:// 指向的内容复制到缓存目录，
 *    通过 EventChannel("mte/open_file") 把本地路径发给 Dart 侧。
 * 2) IME 通道 MethodChannel("mte/ime")：
 *    Monaco 编辑器的输入框焦点由 JS 程序触发，Android WebView 不会
 *    自动弹系统键盘；Dart 侧在用户触摸编辑器导致 focus 时调用 "show"，
 *    这里对 WebView 强制 requestFocus + showSoftInput。
 *
 * 注意：本文件由 tools/patch_android.py 写入，
 * PACKAGE_NAME 会被替换为工程实际的包名。
 */
class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mte/open_file"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                // 冷启动：App 由「打开方式」拉起，此时 Dart 刚开始监听，补发初始 intent
                intent?.let { handleIntent(it) }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mte/ime")
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    showKeyboardOnWebView()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /** 让视图树中的 WebView 获得焦点并弹出系统输入法 */
    private fun showKeyboardOnWebView() {
        try {
            val root = activity.window?.decorView?.rootView ?: return
            val webView = findWebView(root) ?: return
            webView.requestFocus()
            val imm = activity.getSystemService(Context.INPUT_METHOD_SERVICE)
                as InputMethodManager
            imm.showSoftInput(webView, InputMethodManager.SHOW_IMPLICIT)
        } catch (_: Exception) {
        }
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findWebView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        try {
            val path = copyToCache(uri)
            if (path != null) eventSink?.success(path)
        } catch (_: Exception) {
        }
    }

    /** 把任意 Uri 的内容流复制到缓存文件，返回绝对路径 */
    private fun copyToCache(uri: Uri): String? {
        val name = getDisplayName(uri) ?: "opened_${System.currentTimeMillis()}.txt"
        val outFile = File(cacheDir, "opened_${System.currentTimeMillis()}_$name")
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output -> input.copyTo(output) }
        } ?: return null
        return outFile.absolutePath
    }

    private fun getDisplayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0 && cursor.moveToFirst()) return cursor.getString(idx)
                }
            } catch (_: Exception) {
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }
}
