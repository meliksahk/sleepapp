package com.nocta.nocta

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.max

/**
 * Native ses grafı — slice 2 (#173). Çok katmanı TEK `AudioTrack`'e **per-blok**
 * miksleyen native mikser; katman kazançları ÇALARKEN canlı değişir (anlık slider).
 *
 * ## Neden per-blok mikser, slice 1'in tek-buffer'ı değil
 *
 * Slice 1 (#172) tek önceden-mikslenmiş buffer çalıyordu → kazanç değişimi yeniden miks
 * ister, ANINDA olmaz. Canlı yola aday olmak için slider anında değişmeli (yetenek #1).
 * Burada her katman AYRI buffer olarak gelir (gain 1.0 render'lı); yazıcı thread her
 * blokta güncel kazançları okuyup toplar → kazanç değişimi bir sonraki blokta (~21 ms)
 * yansır: algısal olarak anında.
 *
 * ## Miks matematiği — Dart `Mixer`'ı AYNALAR (dolayısıyla zaten test'li)
 *
 * `out = Σ (katman_örneği · kazanç)`, sonra `[-1, 1]`'e **clamp** (kompresör). Bu, Dart
 * `Mixer` + `encodePcm16`'nın birebir aynısıdır (mixer_test.dart'ta test'li). Kotlin o
 * denenmiş davranışı yansıtır: N ayrı OS track'i yerine TEK track → OS-seviye kırpma yok.
 *
 * **Dürüstlük sınırı:** miksin cihazda ÇALIŞTIĞI (koştuğu) integration_test'te kanıtlanır;
 * KULAKLA temiz olduğu §1.1 (sonraya). Slice 2 canlı yolu DEFAULT yapmaz — o adım kulak
 * doğrulaması ister.
 *
 * **Thread güvenliği:** kazançlar copy-on-write bir `@Volatile` dizide tutulur; `setGain`
 * yeni dizi yayınlar, yazıcı her blok başında referansı bir kez okur → kilitsiz, görünür.
 */
class NativeMixPlayer {
    private companion object {
        // 1024 kare @48kHz ≈ 21 ms: kazanç değişimi gecikmesi (algısal anında) ile
        // underrun riski arasında denge. Uyku sesinde daha düşük gecikme gereksiz.
        const val BLOCK_FRAMES = 1024
        const val FULL_SCALE = 32767.0
    }

    private var track: AudioTrack? = null
    private var writer: Thread? = null
    private var layers: List<ShortArray> = emptyList()

    @Volatile
    private var playing = false

    // Copy-on-write: setGain yeni dizi atar (referans volatile) → yazıcı görür.
    @Volatile
    private var gains: DoubleArray = DoubleArray(0)

    /**
     * [buffers]: katman başına başlıksız 16-bit LE mono PCM. [initialGains]: katman
     * başına başlangıç kazancı [0,1]. Hepsi aynı uzunlukta beklenir (loopSeconds×sr).
     */
    fun play(buffers: List<ByteArray>, sampleRate: Int, initialGains: DoubleArray) {
        stop()
        layers = buffers.map(::toShorts)
        gains = initialGains.copyOf()

        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufSize = max(minBuf, BLOCK_FRAMES * 2 * 4)
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

        val frameCount = layers.minOfOrNull { it.size } ?: 0
        writer = Thread {
            val block = ShortArray(BLOCK_FRAMES)
            var pos = 0
            while (playing && frameCount > 0) {
                val g = gains // canlı kazançlar — blok başında bir kez oku (volatile)
                for (i in 0 until BLOCK_FRAMES) {
                    var acc = 0.0
                    for (l in layers.indices) {
                        // int16 → [-1,1] float, kazanç uygula, topla (Dart Mixer aynası).
                        acc += (layers[l][pos] / FULL_SCALE) * g[l]
                        // NOT: her katman aynı uzunlukta → tek pos hepsini döngüler.
                    }
                    val clamped = acc.coerceIn(-1.0, 1.0) // kompresör (OS-kırpma yok)
                    block[i] = (clamped * FULL_SCALE).toInt().toShort()
                    pos++
                    if (pos >= frameCount) pos = 0 // döngü dikişi Dart crossfade'li (#170)
                }
                val written = t.write(block, 0, BLOCK_FRAMES)
                if (written < 0) break // ERROR_DEAD_OBJECT vb. → çık
            }
        }.also { it.start() }
    }

    /** Katman [index] kazancını CANLI değiştirir → bir sonraki blokta yansır (anında). */
    fun setGain(index: Int, gain: Double) {
        val cur = gains
        if (index in cur.indices) {
            val next = cur.copyOf()
            next[index] = gain
            gains = next // volatile yayın → yazıcı bir sonraki blokta görür
        }
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
                // Zaten durdurulmuş/başlatılmamış → bırakmaya devam et.
            }
            t.release()
        }
        track = null
        layers = emptyList()
    }

    /** Başlıksız 16-bit LE PCM baytları → ShortArray (little-endian). */
    private fun toShorts(bytes: ByteArray): ShortArray {
        val out = ShortArray(bytes.size / 2)
        for (i in out.indices) {
            val lo = bytes[i * 2].toInt() and 0xFF
            val hi = bytes[i * 2 + 1].toInt() // işaretli üst bayt
            out[i] = ((hi shl 8) or lo).toShort()
        }
        return out
    }
}
