package com.funbrushai.app

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.jvm.JvmStatic
import java.io.File
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class TtsSavePlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var tts: TextToSpeech? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentResult: Result? = null
    private var currentFilePath: String? = null
    private var latch: CountDownLatch? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.funbrushai.app/tts_save")
        channel?.setMethodCallHandler(this)
        context = binding.applicationContext
        initTts()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        tts?.shutdown()
        tts = null
        context = null
    }

    private fun initTts() {
        tts = TextToSpeech(context!!, TextToSpeech.OnInitListener { status ->
            if (status == TextToSpeech.SUCCESS) {
                Log.d("TtsSavePlugin", "TTS initialized successfully")
            } else {
                Log.e("TtsSavePlugin", "TTS initialization failed")
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "saveTtsToFile") {
            val text = call.argument<String>("text") ?: ""
            val filePath = call.argument<String>("filePath") ?: ""
            val language = call.argument<String>("language") ?: "tr-TR"
            val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
            val speechRate = call.argument<Double>("speechRate")?.toFloat() ?: 0.5f

            saveTtsToFile(text, filePath, language, pitch, speechRate, result)
        } else {
            result.notImplemented()
        }
    }

    private fun sendSuccess(value: Any?) {
        val res = currentResult ?: return
        currentResult = null
        currentFilePath = null
        mainHandler.post { res.success(value) }
    }

    private fun sendError(code: String, message: String?) {
        val res = currentResult ?: return
        currentResult = null
        currentFilePath = null
        mainHandler.post { res.error(code, message, null) }
    }

    private fun saveTtsToFile(
        text: String,
        filePath: String,
        language: String,
        pitch: Float,
        speechRate: Float,
        result: Result
    ) {
        if (tts == null) {
            result.error("TTS_NOT_INITIALIZED", "TextToSpeech not initialized", null)
            return
        }

        currentResult = result
        currentFilePath = filePath
        val localLatch = CountDownLatch(1)
        latch = localLatch

        // Set language
        val locale = parseLocale(language)
        val langResult = tts!!.setLanguage(locale)
        if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            sendError("LANGUAGE_NOT_SUPPORTED", "Language $language not supported")
            localLatch.countDown()
            return
        }

        // Set pitch and speech rate
        tts!!.setPitch(pitch)
        tts!!.setSpeechRate(speechRate)

        // Create file
        val file = File(filePath)
        file.parentFile?.mkdirs()

        // Use synthesizeToFile (API 21+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val utteranceId = "tts_save_${System.currentTimeMillis()}"
            val params = Bundle()

            tts!!.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String) {
                    Log.d("TtsSavePlugin", "TTS started: $utteranceId")
                }

                override fun onDone(utteranceId: String) {
                    Log.d("TtsSavePlugin", "TTS done: $utteranceId")
                    if (file.exists() && file.length() > 0) {
                        sendSuccess(true)
                    } else {
                        sendError("FILE_WRITE_FAILED", "Failed to write audio file")
                    }
                    localLatch.countDown()
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String) {
                    Log.e("TtsSavePlugin", "TTS error: $utteranceId")
                    sendError("TTS_ERROR", "TextToSpeech synthesis failed")
                    localLatch.countDown()
                }

                override fun onError(utteranceId: String, errorCode: Int) {
                    Log.e("TtsSavePlugin", "TTS error ($errorCode): $utteranceId")
                    sendError("TTS_ERROR", "TextToSpeech synthesis failed ($errorCode)")
                    localLatch.countDown()
                }
            })

            val status = tts!!.synthesizeToFile(text, params, file, utteranceId)
            if (status != TextToSpeech.SUCCESS) {
                Log.e("TtsSavePlugin", "synthesizeToFile failed with status: $status")
                sendError("SYNTHESIS_FAILED", "Failed to start synthesis")
                localLatch.countDown()
            }
        } else {
            sendError("API_TOO_LOW", "Android API 21+ required for file synthesis")
            localLatch.countDown()
        }

        // Timeout fallback
        Thread {
            try {
                if (!localLatch.await(30, TimeUnit.SECONDS)) {
                    Log.e("TtsSavePlugin", "TTS synthesis timeout")
                    sendError("TIMEOUT", "TTS synthesis timed out")
                }
            } catch (e: InterruptedException) {
                Log.e("TtsSavePlugin", "TTS synthesis interrupted", e)
            }
        }.start()
    }

    private fun parseLocale(language: String): Locale {
        val parts = language.split("-")
        return when (parts.size) {
            1 -> Locale(parts[0])
            2 -> Locale(parts[0], parts[1])
            else -> Locale(parts[0], parts[1])
        }
    }
}