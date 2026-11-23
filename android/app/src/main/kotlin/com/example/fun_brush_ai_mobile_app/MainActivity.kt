package com.example.fun_brush_ai_mobile_app

import android.content.Intent
import android.provider.CalendarContract
import com.funbrushai.app.AudioMixerPlugin
import com.funbrushai.app.TtsSavePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(TtsSavePlugin())
        flutterEngine.plugins.add(AudioMixerPlugin())

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.funbrushai.app/calendar"
        ).setMethodCallHandler { call, result ->
            if (call.method == "upsertEvent" || call.method == "addEvent") {
                val title = call.argument<String>("title") ?: "Diş Randevusu"
                val notes = call.argument<String>("notes") ?: ""
                val location = call.argument<String>("location") ?: ""
                val startMillis = call.argument<Number>("startMillis")?.toLong()
                val endMillis = call.argument<Number>("endMillis")?.toLong()

                if (startMillis == null || endMillis == null) {
                    result.success(mapOf("success" to false, "error" to "invalid_arguments"))
                    return@setMethodCallHandler
                }

                try {
                    val intent = Intent(Intent.ACTION_INSERT).apply {
                        data = CalendarContract.Events.CONTENT_URI
                        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                        putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                        putExtra(CalendarContract.Events.TITLE, title)
                        putExtra(CalendarContract.Events.DESCRIPTION, notes)
                        putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                    }
                    startActivity(intent)
                    result.success(mapOf("success" to true, "updated" to false))
                } catch (e: Exception) {
                    result.success(mapOf("success" to false, "error" to (e.message ?: "unknown")))
                }
            } else if (call.method == "deleteEvent") {
                result.success(mapOf("success" to true, "deleted" to false))
            } else {
                result.notImplemented()
            }
        }
    }
}
