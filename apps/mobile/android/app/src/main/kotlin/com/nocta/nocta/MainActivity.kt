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

    // Native ses grafı slice 1 (#172): tek in-app-mikslenmiş buffer'ı çalan AudioTrack.
    private val nativeMix = NativeMixPlayer()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nocta/mix_video")
            .setMethodCallHandler(::onMethodCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nocta/native_mix")
            .setMethodCallHandler(::onNativeMixCall)
    }

    override fun onDestroy() {
        // Kullanıcı export sırasında çıkarsa codec sızmasın.
        encoderThread.execute { encoder?.release(); encoder = null }
        encoderThread.shutdown()
        // Ses track'i süreç kapanırken bırakılmazsa sistemde asılı kalır.
        nativeMix.stop()
        super.onDestroy()
    }

    /**
     * `nocta/native_mix` kanalı — sözleşme `lib/core/audio_engine/native_mix_player.dart`
     * ile eşleşir (Dart tarafında `setMockMethodCallHandler` ile testli). AudioTrack
     * çağrıları ANA thread'den güvenli (kendi yazıcı thread'ini kurar) → executor gerekmez.
     */
    private fun onNativeMixCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "play" -> {
                    @Suppress("UNCHECKED_CAST")
                    val buffers = call.argument<List<ByteArray>>("buffers")!!
                    val gains = (call.argument<List<Double>>("gains")!!).toDoubleArray()
                    nativeMix.play(
                        buffers = buffers,
                        sampleRate = call.argument<Int>("sampleRate")!!,
                        initialGains = gains,
                    )
                    result.success(null)
                }

                "setGain" -> {
                    nativeMix.setGain(
                        index = call.argument<Int>("index")!!,
                        gain = call.argument<Double>("gain")!!,
                    )
                    result.success(null)
                }

                "stop" -> {
                    nativeMix.stop()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            // Yutulmaz: çağıran bir cevap almalı (CLAUDE.md §4).
            result.error("native_mix_failed", e.message, null)
        }
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
