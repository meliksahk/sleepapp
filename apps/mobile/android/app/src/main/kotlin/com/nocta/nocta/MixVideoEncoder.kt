package com.nocta.nocta

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * Mix-to-video (viral kanca #3) — 9:16 mp4 üretimi.
 *
 * ## Neden native, neden ffmpeg değil (docs/04 §134 spike'ı)
 *
 * docs/04 §134 bu spike'ı faz başında şart koşmuştu. Sonuç (DECISIONS D-14):
 * - `arthenica/ffmpeg-kit` GitHub'da **ARŞİVLENMİŞ**; `ffmpeg_kit_flutter`ın pub'daki
 *   son sürümü 2023-09-18.
 * - Tek canlı fork `ffmpeg_kit_flutter_new` **"Full GPL"** — GPL, kapalı kaynak ticari
 *   bir uygulamayı kirletir.
 *
 * `MediaCodec` + `MediaMuxer` Android'in kendi API'si: sıfır bağımlılık, sıfır lisans
 * riski, sıfır terk edilmiş kod.
 *
 * ## Neden OTURUM — kareler neden tek seferde verilmiyor
 *
 * Bu sınıfın ilk hâli `encode(frames: List<IntArray>)` idi ve **çalışamazdı**:
 * 1080×1920 ARGB = kare başına 8,3 MB; 15 sn × 30 fps = **3,7 GB**. Ne kanaldan geçer
 * ne RAM'e sığar. Bu yüzden kareler `pushFrame` ile TEK TEK gelir, anında kodlanır ve
 * ham hâli atılır. Bellekte kalan yalnızca KODLANMIŞ örneklerdir (8 Mbps × 15 sn ≈
 * 15 MB) — o da muxer track sırası yüzünden şart (aşağıya bak).
 *
 * ## Neden kodlanmış örnekler yine de biriktiriliyor
 *
 * `MediaMuxer.addTrack` GERÇEK çıktı formatını ister; format ancak codec ilk çıktıyı
 * verdikten sonra bilinir ve `start()`tan sonra track eklenemez. Yani muxer, iki akışın
 * da formatı bilinmeden başlayamaz. Çözüm: örnekleri tut, sonunda track'leri ekle,
 * başlat, zamana göre iç içe yaz. ~15 MB kabul edilebilir.
 *
 * ## Neden H.264 + AAC
 *
 * Instagram/TikTok/WhatsApp'ın hepsinin sorunsuz kabul ettiği kombinasyon. H.265/AV1
 * daha küçük dosya verir ama hedef uyumluluk — **paylaşılamayan video, viral kanca
 * değildir**.
 *
 * Thread-safe DEĞİL: tek bir arka plan thread'inden kullanılır (bkz. `MainActivity`).
 */
class MixVideoEncoder(
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    private val sampleRate: Int,
) {
    companion object {
        private const val VIDEO_MIME = "video/avc"
        private const val AUDIO_MIME = "audio/mp4a-latm"
        private const val TIMEOUT_US = 10_000L

        /**
         * 8 Mbps: gradyan gibi düşük hareketli içerik için fazlasıyla yeterli. Daha
         * düşüğü gradyanlarda **banding** yapar — uygulamanın tüm estetiği gradyan,
         * orada bant görünmesi ürünü bozar.
         */
        private const val VIDEO_BITRATE = 8_000_000
        private const val AUDIO_BITRATE = 128_000
    }

    private class Sample(val data: ByteArray, val ptsUs: Long, val flags: Int)

    private var videoCodec: MediaCodec? = null
    private var videoFormat: MediaFormat? = null
    private val videoSamples = mutableListOf<Sample>()
    private var frameIndex = 0

    init {
        require(width % 2 == 0 && height % 2 == 0) { "YUV420 çift boyut ister" }
        require(fps > 0) { "fps > 0 olmalı" }
        require(sampleRate > 0) { "sampleRate > 0 olmalı" }
    }

    fun start() {
        check(videoCodec == null) { "zaten başlatıldı" }
        val format = MediaFormat.createVideoFormat(VIDEO_MIME, width, height).apply {
            // YUV420Flexible: cihazlar arasında EN GENİŞ desteklenen giriş formatı.
            // Surface girişi daha hızlı olurdu ama kareler Dart'tan bayt olarak geliyor.
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            // Saniyede bir anahtar kare: paylaşım uygulaması videoyu kırparsa
            // (story kesme) her noktadan çözülebilsin.
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        videoCodec = MediaCodec.createEncoderByType(VIDEO_MIME).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }
    }

    /**
     * [rgba]: width*height*4 baytlık RGBA8888. Kare kodlanır, ham hâli atılır.
     *
     * Neden RGBA bayt, neden ARGB `IntArray` değil: Flutter'ın `toByteData` çağrısı
     * zaten `rawRgba` üretiyor. `IntArray` istemek Dart'ta 2 milyon pikselde fazladan
     * bir dönüşüm turu demekti — kare başına boşa iş.
     */
    fun pushFrame(rgba: ByteArray) {
        val codec = videoCodec ?: error("start() çağrılmadı")
        require(rgba.size == width * height * 4) {
            "kare boyutu uyuşmuyor: ${rgba.size} != ${width * height * 4}"
        }

        // Girdi arabelleği hazır olana kadar bekle; bu arada çıkışı boşalt, yoksa
        // codec çıkış arabellekleri dolar ve girdi bir daha asla serbest kalmaz.
        val idx = awaitInputBuffer(codec, videoSamples) { videoFormat = it }
        val image = codec.getInputImage(idx)
            ?: error("codec YUV420 Image vermedi (beklenmeyen renk formatı)")
        writeYuv420(image, rgba)
        codec.queueInputBuffer(idx, 0, width * height * 3 / 2, ptsUs(frameIndex), 0)
        frameIndex++
        drain(codec, videoSamples) { videoFormat = it }
    }

    /**
     * Kareleri kapatır, sesi kodlar ve mp4'ü yazar.
     *
     * [pcm]: 16-bit LE mono. Hata durumunda **ATAR** — sessizce bozuk dosya döndürmek,
     * kullanıcının ancak paylaştıktan sonra fark edeceği bir hata olurdu.
     */
    fun finish(pcm: ByteArray, output: File): File {
        val codec = videoCodec ?: error("start() çağrılmadı")
        check(frameIndex > 0) { "hiç kare verilmedi" }

        try {
            val idx = awaitInputBuffer(codec, videoSamples) { videoFormat = it }
            codec.queueInputBuffer(
                idx, 0, 0, ptsUs(frameIndex), MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            while (!drain(codec, videoSamples) { videoFormat = it }) { /* EOS'a kadar */ }
        } finally {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            videoCodec = null
        }

        val vFormat = videoFormat ?: error("video formatı alınamadı")
        val (aFormat, audioSamples) = encodeAudio(pcm)

        val muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val videoTrack = muxer.addTrack(vFormat)
            val audioTrack = muxer.addTrack(aFormat)
            muxer.start()

            // Zamana göre iç içe yaz: oynatıcılar iki akışı birlikte akıtır; hepsini
            // arka arkaya yazmak bazı oynatıcılarda gecikme/atlama yapar.
            var vi = 0
            var ai = 0
            while (vi < videoSamples.size || ai < audioSamples.size) {
                val takeVideo = ai >= audioSamples.size ||
                    (vi < videoSamples.size && videoSamples[vi].ptsUs <= audioSamples[ai].ptsUs)
                if (takeVideo) writeSample(muxer, videoTrack, videoSamples[vi++])
                else writeSample(muxer, audioTrack, audioSamples[ai++])
            }
            muxer.stop()
        } finally {
            runCatching { muxer.release() }
            videoSamples.clear()
        }
        return output
    }

    /** Yarıda bırakılan oturumun codec'ini sızdırmadan kapatır. */
    fun release() {
        runCatching { videoCodec?.stop() }
        runCatching { videoCodec?.release() }
        videoCodec = null
        videoSamples.clear()
    }

    private fun ptsUs(frame: Int): Long = frame * 1_000_000L / fps

    private fun awaitInputBuffer(
        codec: MediaCodec,
        out: MutableList<Sample>,
        onFormat: (MediaFormat) -> Unit,
    ): Int {
        while (true) {
            val idx = codec.dequeueInputBuffer(TIMEOUT_US)
            if (idx >= 0) return idx
            drain(codec, out, onFormat)
        }
    }

    private fun writeSample(muxer: MediaMuxer, track: Int, s: Sample) {
        val info = MediaCodec.BufferInfo().apply { set(0, s.data.size, s.ptsUs, s.flags) }
        muxer.writeSampleData(track, ByteBuffer.wrap(s.data), info)
    }

    private fun encodeAudio(pcm: ByteArray): Pair<MediaFormat, List<Sample>> {
        val format = MediaFormat.createAudioFormat(AUDIO_MIME, sampleRate, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
        }
        val codec = MediaCodec.createEncoderByType(AUDIO_MIME)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()

        val out = mutableListOf<Sample>()
        var outFormat: MediaFormat? = null
        var offset = 0
        var inputDone = false

        try {
            while (true) {
                if (!inputDone) {
                    val idx = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        val buf = codec.getInputBuffer(idx)!!
                        val chunk = minOf(buf.capacity(), pcm.size - offset)
                        // PTS örnek sayısından: 16-bit mono → 2 bayt/örnek.
                        val ptsUs = offset.toLong() / 2 * 1_000_000L / sampleRate
                        if (chunk > 0) {
                            buf.clear()
                            buf.put(pcm, offset, chunk)
                            codec.queueInputBuffer(idx, 0, chunk, ptsUs, 0)
                            offset += chunk
                        } else {
                            codec.queueInputBuffer(
                                idx, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        }
                    }
                }
                if (drain(codec, out) { outFormat = it }) break
            }
        } finally {
            runCatching { codec.stop() }
            runCatching { codec.release() }
        }
        return (outFormat ?: error("ses formatı alınamadı")) to out
    }

    /** Codec çıkışını boşaltır; akış bittiyse true. */
    private fun drain(
        codec: MediaCodec,
        out: MutableList<Sample>,
        onFormat: (MediaFormat) -> Unit,
    ): Boolean {
        val info = MediaCodec.BufferInfo()
        while (true) {
            when (val idx = codec.dequeueOutputBuffer(info, TIMEOUT_US)) {
                MediaCodec.INFO_TRY_AGAIN_LATER -> return false
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> onFormat(codec.outputFormat)
                else -> {
                    if (idx < 0) return false
                    val buf = codec.getOutputBuffer(idx)!!
                    // CODEC_CONFIG (SPS/PPS) muxer'a AYRI yazılmaz: format zaten taşır.
                    // Yazılırsa bazı oynatıcılar ilk kareyi bozuk çözer.
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                        val data = ByteArray(info.size)
                        buf.position(info.offset)
                        buf.get(data)
                        out.add(Sample(data, info.presentationTimeUs, info.flags))
                    }
                    codec.releaseOutputBuffer(idx, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return true
                }
            }
        }
    }

    /**
     * RGBA8888 → codec'in verdiği YUV420 [image]'ına yazar.
     *
     * ## Neden `Image`, neden düz bayt dizisi DEĞİL (emülatörde GÖRÜLDÜ)
     *
     * İlk hâli NV12 (iç içe UV) varsayıp tek bir `ByteArray` besliyordu ve **dosya
     * üretti, ffprobe temiz raporladı, video oynadı** — ama çözülen karede metnin ve
     * dalga formunun soluk RENKLİ hayaletleri vardı. Luma kusursuzdu; bozuk olan
     * yalnızca chroma'ydı: bu cihazın `COLOR_FormatYUV420Flexible`ı **düzlemsel I420**
     * veriyor, yani iç içe yazdığımız UV baytları "önce U düzlemi, sonra V düzlemi"
     * diye okunuyordu.
     *
     * Ders: "mp4 üretildi" ve "ffprobe geçti" bir karenin DOĞRU olduğunu kanıtlamaz.
     *
     * `getInputImage` düzlemleri kendi `rowStride`/`pixelStride`'larıyla verir; bu kod
     * onlara uyar, dolayısıyla I420 da NV12 de (ve satır dolgusu da) kendiliğinden
     * doğru çalışır. Hiçbir cihaza dair varsayım kalmadı.
     *
     * BT.601 katsayıları: `MediaCodec`in SDR video için beklediği uzay. BT.709
     * kullansaydık renkler oynatıcıda kayardı — gradyanlarımızda fark edilir şekilde.
     *
     * Alfa atılıyor: video saydamlık taşımaz, kare zaten opak gradyan üzerine çizilir.
     */
    private fun writeYuv420(image: Image, rgba: ByteArray) {
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        val yBuf = yPlane.buffer
        val uBuf = uPlane.buffer
        val vBuf = vPlane.buffer

        for (j in 0 until height) {
            for (i in 0 until width) {
                val p = (j * width + i) * 4
                val r = rgba[p].toInt() and 0xff
                val g = rgba[p + 1].toInt() and 0xff
                val b = rgba[p + 2].toInt() and 0xff

                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yBuf.put(j * yPlane.rowStride + i * yPlane.pixelStride, y.coerceIn(0, 255).toByte())

                // Chroma 2×2 alt-örneklenir: her dört pikselde bir örnek.
                if (j % 2 == 0 && i % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    val cj = j / 2
                    val ci = i / 2
                    uBuf.put(cj * uPlane.rowStride + ci * uPlane.pixelStride, u.coerceIn(0, 255).toByte())
                    vBuf.put(cj * vPlane.rowStride + ci * vPlane.pixelStride, v.coerceIn(0, 255).toByte())
                }
            }
        }
    }
}
