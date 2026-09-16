package mn.hotuntlaa.hotuntlaa

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Дэлгэцийн хамгаалалт — GDD-10 §5.
 *
 * Нэмэлт пакет ашиглахгүйн тулд хоёр л тугийг MethodChannel-ээр удирдана.
 * `FLAG_SECURE` нь дүр харагдах дэлгэц дээр, `KEEP_SCREEN_ON` нь утас ширээн
 * дунд байх үед.
 */
class MainActivity : FlutterActivity() {
    private val channel = "mn.hotuntlaa/guard"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val on = call.argument<Boolean>("on") ?: false
                when (call.method) {
                    "setSecure" -> {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "setKeepAwake" -> {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
