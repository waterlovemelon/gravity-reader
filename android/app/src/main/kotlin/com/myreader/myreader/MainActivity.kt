package com.myreader.myreader

import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "myreader/tts"
    private var tts: TextToSpeech? = null
    private var speechRate = 1.0f
    private var pitch = 1.0f
    private var volume = 1.0f
    private var isPaused = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // 初始化 TTS
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                // 设置语言为中文
                val result = tts?.setLanguage(Locale.CHINESE)
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    // 如果中文不支持，尝试使用默认语言
                    tts?.setLanguage(Locale.getDefault())
                }
            }
        }

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1.0f
                    val pitchArg = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val volumeArg = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    if (text != null) {
                        speak(text, rate, pitchArg, volumeArg)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text not provided", null)
                    }
                }
                "stop" -> {
                    stop()
                    result.success(null)
                }
                "pause" -> {
                    pause()
                    result.success(null)
                }
                "resume" -> {
                    resume()
                    result.success(null)
                }
                "setSpeechRate" -> {
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1.0f
                    setSpeechRate(rate)
                    result.success(null)
                }
                "setPitch" -> {
                    val pitchArg = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    setPitch(pitchArg)
                    result.success(null)
                }
                "setVolume" -> {
                    val volumeArg = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    setVolume(volumeArg)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun speak(text: String, rate: Float, pitch: Float, volume: Float) {
        // 停止当前的语音播放
        tts?.stop()
        
        // 更新参数
        speechRate = rate.coerceIn(0.5f, 2.0f)
        this.pitch = pitch.coerceIn(0.5f, 2.0f)
        this.volume = volume.coerceIn(0f, 1f)
        isPaused = false

        tts?.apply {
            setSpeechRate(speechRate)
            setPitch(pitch)
            // Android TTS 无法直接设置 volume，需要通过 AudioManager

            // 设置监听器
            setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    // 语音开始播放
                }

                override fun onDone(utteranceId: String?) {
                    // 语音播放完成
                }

                override fun onError(utteranceId: String?) {
                    // 播放错误
                }
            })

            // 播放语音
            speak(text, TextToSpeech.QUEUE_FLUSH, null, "myreader_tts")
        }
    }

    private fun stop() {
        tts?.stop()
        isPaused = false
    }

    private fun pause() {
        // Android TTS 不支持真正的暂停，使用 stop 代替
        tts?.stop()
        isPaused = true
    }

    private fun resume() {
        if (isPaused) {
            // 无法恢复，需要重新 speak
            // 但我们没有保存最后的文本，所以只能设置状态
            isPaused = false
        }
    }

    private fun setSpeechRate(rate: Float) {
        speechRate = rate.coerceIn(0.5f, 2.0f)
        tts?.setSpeechRate(speechRate)
    }

    private fun setPitch(pitch: Float) {
        this.pitch = pitch.coerceIn(0.5f, 2.0f)
        tts?.setPitch(pitch)
    }

    private fun setVolume(volume: Float) {
        this.volume = volume.coerceIn(0f, 1f)
        // Android TTS 无法直接设置 volume
        // 可以通过 AudioManager 控制音量，但这会影响系统音量
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
