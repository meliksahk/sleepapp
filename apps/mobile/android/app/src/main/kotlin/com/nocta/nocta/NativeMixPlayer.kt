package com.nocta.nocta

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.max

/**
 * Native ses grafı — slice 1 (#172). Tek, in-app-mikslenmiş PCM16 buffer'ı `AudioTrack`
 * ile döngüde çalar.
 *
 * ## Neden var
 *
 * Bugün `MixPlayer` her katmanı AYRI `just_audio` player'ına çalıyor → toplama işletim
 * sistemi mikserinde oluyor ve yüksek toplam kazançta **OS-seviye kırpma** duyulabiliyor
 * (mix_player.dart'ta belgeli sınır). Buffer'ı Dart tarafında `renderMix` (katmanları
 * toplayıp SIKIŞTIRAN referans mikser) üzerinden geçirip TEK track olarak çalarsak o
 * kırpma canlı yolda çözülür. Dikiş `renderSeamlessLoop` crossfade'i ile sürekli.
 *
 * ## Neden AudioTrack, neden Oboe/C++ değil
 *
 * Uyku sesinde düşük gecikme kritik DEĞİL (tuşa basınca ses çıkması gerekmiyor). `AudioTrack`
 * streaming, NDK/C++ toolchain istemez ve `MixVideoEncoder`'ın kanıtlı MethodChannel
 * desenini birebir izler → emülatörde derlenip koşması garanti edilebilir bir dilim.
 * Oboe düşük gecikme getirir ama kanıtsız NDK derlemesi getirir; bu üründe kazancı yok.
 *
 * **Thread modeli:** `play` bir yazıcı thread'i başlatır; `write` (MODE_STREAM) bloklar,
 * bu yüzden ayrı thread ana thread'i (UI) dondurmaz. `stop` bayrağı indirir ve bekler.
 */
class NativeMixPlayer {
    private var track: AudioTrack? = null
    private var writer: Thread? = null

    @Volatile
    private var playing = false

    /** [pcm]: başlıksız 16-bit LE mono PCM (Dart `encodePcm16`). Döngüde çalar. */
    fun play(pcm: ByteArray, sampleRate: Int) {
        stop()
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        // En az 8 KB: çok küçük buffer underrun (kesinti) üretir; uyku sesinde gecikme
        // önemsiz, sağlamlık önemli.
        val bufSize = max(minBuf, 8192)
        val t = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(bufSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        track = t
        playing = true
        t.play()

        writer = Thread {
            var offset = 0
            while (playing && pcm.isNotEmpty()) {
                val toWrite = minOf(bufSize, pcm.size - offset)
                val written = t.write(pcm, offset, toWrite)
                if (written < 0) break // hata (ör. ERROR_DEAD_OBJECT) → döngüden çık
                offset += written
                // Döngü dikişi: pcm[son] → pcm[0]. Dart tarafında crossfade'li (#170)
                // olduğu için sürekli — burada ek işleme gerekmez.
                if (offset >= pcm.size) offset = 0
            }
        }.also { it.start() }
    }

    /** Susturur ve kaynakları bırakır. Zaten durmuşsa sorun değil. */
    fun stop() {
        playing = false
        writer?.join(300)
        writer = null
        track?.let { t ->
            try {
                t.pause()
                t.flush()
                t.stop()
            } catch (_: IllegalStateException) {
                // Zaten durdurulmuş/başlatılmamış track → bırakmaya devam et.
            }
            t.release()
        }
        track = null
    }
}
