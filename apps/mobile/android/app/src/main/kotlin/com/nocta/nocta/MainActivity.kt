package com.nocta.nocta

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Mix-to-video kanalı (viral kanca #3).
 *
 * Kanal ve yöntem adları `lib/core/media/mix_video_channel.dart` ile eşleşmeli;
 * Dart tarafında aynı sabitler var ve sözleşme orada `setMockMethodCallHandler` ile
 * test ediliyor. Buradaki bir isim değişirse o test kırılır — kasıtlı.
 *
 * ## Neden tek thread'li executor
 *
 * `MixVideoEncoder` durumlu ve thread-safe DEĞİL: `start`/`pushFrame`/`finish` aynı
 * thread'den, sırayla çağrılmalı. Tek thread'li executor bunu yapı gereği garanti
 * eder. Ana thread'de kodlamak ise UI'ı dondurur (ANR) — kodlama saniyeler sürer.
 */
class MainActivity : FlutterActivity() {

    private val encoderThread = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var encoder: MixVideoEncoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nocta/mix_video")
            .setMethodCallHandler(::onMethodCall)
    }

    override fun onDestroy() {
        // Kullanıcı export sırasında çıkarsa codec sızmasın.
        encoderThread.execute { encoder?.release(); encoder = null }
        encoderThread.shutdown()
        super.onDestroy()
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> onEncoderThread(result) {
                encoder?.release()
                encoder = MixVideoEncoder(
                    width = call.argument<Int>("width")!!,
                    height = call.argument<Int>("height")!!,
                    fps = call.argument<Int>("fps")!!,
                    sampleRate = call.argument<Int>("sampleRate")!!,
                ).apply { start() }
                null
            }

            "pushFrame" -> onEncoderThread(result) {
                val enc = encoder ?: error("start() çağrılmadı")
                enc.pushFrame(call.argument<ByteArray>("rgba")!!)
                null
            }

            "finish" -> onEncoderThread(result) {
                val enc = encoder ?: error("start() çağrılmadı")
                try {
                    // Önbellek dizini: paylaşıldıktan sonra sistem temizleyebilir.
                    // Kalıcı depolamaya yazmak, kullanıcının silemediği çöp bırakırdı.
                    val out = File(cacheDir, "nocta-mix-${call.argument<String>("name")}.mp4")
                    enc.finish(call.argument<ByteArray>("pcm")!!, out).absolutePath
                } finally {
                    encoder = null
                }
            }

            "cancel" -> onEncoderThread(result) {
                encoder?.release()
                encoder = null
                null
            }

            else -> result.notImplemented()
        }
    }

    /**
     * [block]'u kodlama thread'inde çalıştırır, sonucu ana thread'den bildirir
     * (`MethodChannel.Result` ana thread'den çağrılmalıdır).
     */
    private fun onEncoderThread(result: MethodChannel.Result, block: () -> Any?) {
        encoderThread.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Throwable) {
                // Yutulmaz: kullanıcı "video oluştur"a bastı, bir cevap almalı.
                // Teknik detay Dart'ta loglanır; kullanıcıya sade metin gösterilir
                // (CLAUDE.md §4: gösterilen mesaj ile loglanan detay ayrı).
                encoder?.release()
                encoder = null
                mainHandler.post { result.error("encode_failed", e.message, null) }
            }
        }
    }
}
