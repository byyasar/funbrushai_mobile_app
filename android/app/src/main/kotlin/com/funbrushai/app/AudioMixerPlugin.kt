package com.funbrushai.app

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

class AudioMixerPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    companion object {
        private const val TAG = "AudioMixerPlugin"
        private const val CHANNEL_NAME = "com.funbrushai.app/audio_mixer"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "mixAudio") {
            val musicPath = call.argument<String>("musicPath")
            val outputWavPath = call.argument<String>("outputWavPath")
            val alertType = call.argument<String>("alertType") ?: "beep"
            val cueWavPaths = call.argument<List<String>>("cueWavPaths") ?: emptyList()
            val intervalSeconds = call.argument<List<Int>>("intervalSeconds") ?: listOf(30, 60, 90, 120)
            val musicVolume = (call.argument<Double>("musicVolume") ?: 0.8).toFloat()
            val alertVolume = (call.argument<Double>("alertVolume") ?: 1.0).toFloat()

            if (musicPath.isNullOrEmpty() || outputWavPath.isNullOrEmpty()) {
                result.error("INVALID_ARGS", "musicPath ve outputWavPath zorunludur", null)
                return
            }

            executor.execute {
                try {
                    mixAudioInternal(
                        musicPath = musicPath,
                        outputWavPath = outputWavPath,
                        alertType = alertType,
                        cueWavPaths = cueWavPaths,
                        intervalSeconds = intervalSeconds,
                        musicVolume = musicVolume,
                        alertVolume = alertVolume
                    )
                    mainHandler.post { result.success(outputWavPath) }
                } catch (e: Exception) {
                    Log.e(TAG, "Audio mixing failed", e)
                    mainHandler.post {
                        result.error("MIX_FAILED", e.message ?: "Ses birleştirme başarısız oldu", null)
                    }
                }
            }
        } else {
            result.notImplemented()
        }
    }

    private data class DecodedPcmInfo(
        val pcmFile: File,
        val sampleRate: Int,
        val channels: Int,
        val totalFrames: Long
    )

    private data class CueTrack(
        val startFrame: Long,
        val samples: ShortArray // interleaved with target channels
    ) {
        fun endFrame(channels: Int): Long = startFrame + (samples.size / channels).toLong()
    }

    private fun mixAudioInternal(
        musicPath: String,
        outputWavPath: String,
        alertType: String,
        cueWavPaths: List<String>,
        intervalSeconds: List<Int>,
        musicVolume: Float,
        alertVolume: Float
    ) {
        val outputFile = File(outputWavPath)
        outputFile.parentFile?.mkdirs()

        val tempPcmFile = File(outputFile.parentFile, "_temp_decoded_${System.currentTimeMillis()}.pcm")
        try {
            // 1. Arka plan müziğini 16-bit PCM dosyasına decode et
            val pcmInfo = decodeToPcmFile(musicPath, tempPcmFile)
            if (pcmInfo.totalFrames <= 0) {
                throw IllegalStateException("Müzik dosyası çözümlenemedi (boş ses akışı).")
            }

            val sampleRate = pcmInfo.sampleRate
            val channels = pcmInfo.channels

            // 2. Uyarı seslerini (bip veya TTS WAV) hedef sampleRate/channels formatında hazırla
            val cues = mutableListOf<CueTrack>()
            for (i in intervalSeconds.indices) {
                val sec = intervalSeconds[i]
                val startFrame = sec.toLong() * sampleRate.toLong()

                val cueSamples: ShortArray = if (alertType == "tts" && cueWavPaths.isNotEmpty()) {
                    val wavPath = if (i < cueWavPaths.size) cueWavPaths[i] else cueWavPaths.last()
                    readAndResampleWav(wavPath, sampleRate, channels)
                } else {
                    val isFinal = (i == intervalSeconds.lastIndex)
                    generateChimeCue(sampleRate, channels, isFinal)
                }

                if (cueSamples.isNotEmpty()) {
                    cues.add(CueTrack(startFrame = startFrame, samples = cueSamples))
                }
            }

            // 3. Toplam çıkış uzunluğunu hesapla
            // Müzik 120 sn'den kısaysa son uyarının bitimine (+0.5 sn) kadar döngüye al; uzunsa orijinal uzunluğu koru
            val lastCueEndFrame = cues.maxOfOrNull { it.endFrame(channels) } ?: 0L
            val minTargetFrames = lastCueEndFrame + (sampleRate / 2)
            val outputTotalFrames = max(pcmInfo.totalFrames, minTargetFrames)

            // 4. Stream ederek ducking + mixing uygula ve çıkış WAV dosyasına yaz
            writeMixedWav(
                sourcePcmFile = pcmInfo.pcmFile,
                sourceTotalFrames = pcmInfo.totalFrames,
                outputWavFile = outputFile,
                outputTotalFrames = outputTotalFrames,
                sampleRate = sampleRate,
                channels = channels,
                cues = cues,
                musicVolume = musicVolume.coerceIn(0f, 1.5f),
                alertVolume = alertVolume.coerceIn(0f, 1.5f)
            )
        } finally {
            if (tempPcmFile.exists()) {
                tempPcmFile.delete()
            }
        }
    }

    private fun decodeToPcmFile(inputPath: String, outPcmFile: File): DecodedPcmInfo {
        // Düz PCM WAV ise doğrudan oku (MediaExtractor bazı WAV dosyalarını açamayabilir)
        if (inputPath.lowercase().endsWith(".wav")) {
            val direct = tryExtractPlainWavToPcm(inputPath, outPcmFile)
            if (direct != null) return direct
        }

        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        var audioTrackIndex = -1
        var inputFormat: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                inputFormat = format
                break
            }
        }

        if (audioTrackIndex < 0 || inputFormat == null) {
            extractor.release()
            throw IllegalArgumentException("Dosyada ses kanalı bulunamadı: $inputPath")
        }

        extractor.selectTrack(audioTrackIndex)
        val mime = inputFormat.getString(MediaFormat.KEY_MIME)!!
        var sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(inputFormat, null, null, 0)
        codec.start()

        var totalBytesWritten = 0L
        val bufferInfo = MediaCodec.BufferInfo()
        var sawInputEOS = false
        var sawOutputEOS = false

        BufferedOutputStream(FileOutputStream(outPcmFile), 65536).use { outStream ->
            while (!sawOutputEOS) {
                if (!sawInputEOS) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)!!
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputIndex, 0, 0, 0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            sawInputEOS = true
                        } else {
                            val pts = extractor.sampleTime
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, pts, 0)
                            extractor.advance()
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outputIndex >= 0 -> {
                        val outBuffer = codec.getOutputBuffer(outputIndex)
                        if (outBuffer != null && bufferInfo.size > 0) {
                            outBuffer.position(bufferInfo.offset)
                            outBuffer.limit(bufferInfo.offset + bufferInfo.size)

                            if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
                                val floatCount = bufferInfo.size / 4
                                val fb = outBuffer.order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
                                val shortBytes = ByteArray(floatCount * 2)
                                val sb = ByteBuffer.wrap(shortBytes).order(ByteOrder.LITTLE_ENDIAN)
                                for (i in 0 until floatCount) {
                                    val v = (fb.get().coerceIn(-1f, 1f) * 32767f).roundToInt().toShort()
                                    sb.putShort(v)
                                }
                                outStream.write(shortBytes)
                                totalBytesWritten += shortBytes.size
                            } else {
                                val chunk = ByteArray(bufferInfo.size)
                                outBuffer.get(chunk)
                                outStream.write(chunk)
                                totalBytesWritten += chunk.size
                            }
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            sawOutputEOS = true
                        }
                    }
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val newFormat = codec.outputFormat
                        if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                        if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            channels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                        if (newFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmEncoding = newFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        }
                        Log.d(TAG, "Decoded format: ${sampleRate}Hz, ${channels}ch, enc=$pcmEncoding")
                    }
                }
            }
            outStream.flush()
        }

        codec.stop()
        codec.release()
        extractor.release()

        val bytesPerFrame = channels * 2
        val totalFrames = if (bytesPerFrame > 0) totalBytesWritten / bytesPerFrame else 0L
        return DecodedPcmInfo(outPcmFile, sampleRate, channels, totalFrames)
    }

    private fun tryExtractPlainWavToPcm(wavPath: String, outPcmFile: File): DecodedPcmInfo? {
        return try {
            val bytes = File(wavPath).readBytes()
            if (bytes.size < 44) return null
            val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            if (String(bytes, 0, 4) != "RIFF" || String(bytes, 8, 4) != "WAVE") return null

            var offset = 12
            var audioFormat = 1
            var channels = 1
            var sampleRate = 44100
            var bitsPerSample = 16
            var dataStart = -1
            var dataSize = 0

            while (offset + 8 <= bytes.size) {
                val id = String(bytes, offset, 4)
                val size = bb.getInt(offset + 4)
                val chunkData = offset + 8
                if (id == "fmt " && chunkData + 16 <= bytes.size) {
                    audioFormat = bb.getShort(chunkData).toInt() and 0xFFFF
                    channels = bb.getShort(chunkData + 2).toInt() and 0xFFFF
                    sampleRate = bb.getInt(chunkData + 4)
                    bitsPerSample = bb.getShort(chunkData + 14).toInt() and 0xFFFF
                } else if (id == "data") {
                    dataStart = chunkData
                    dataSize = min(size, bytes.size - chunkData)
                    break
                }
                offset = chunkData + size + (if (size % 2 != 0) 1 else 0)
            }

            if (dataStart < 0 || dataSize <= 0) return null
            if (audioFormat != 1 || bitsPerSample != 16) return null

            FileOutputStream(outPcmFile).use { it.write(bytes, dataStart, dataSize) }
            val totalFrames = (dataSize / (channels * 2)).toLong()
            DecodedPcmInfo(outPcmFile, sampleRate, channels, totalFrames)
        } catch (e: Exception) {
            Log.w(TAG, "Direct WAV parse fallback to MediaExtractor: ${e.message}")
            null
        }
    }

    private fun readAndResampleWav(wavPath: String, targetSampleRate: Int, targetChannels: Int): ShortArray {
        val file = File(wavPath)
        if (!file.exists()) return ShortArray(0)
        val bytes = file.readBytes()
        if (bytes.size < 44) return ShortArray(0)

        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var offset = 12
        var audioFormat = 1
        var srcChannels = 1
        var srcSampleRate = 22050
        var bitsPerSample = 16
        var dataStart = -1
        var dataSize = 0

        while (offset + 8 <= bytes.size) {
            val id = String(bytes, offset, 4)
            val size = bb.getInt(offset + 4)
            val chunkData = offset + 8
            if (id == "fmt " && chunkData + 16 <= bytes.size) {
                audioFormat = bb.getShort(chunkData).toInt() and 0xFFFF
                srcChannels = bb.getShort(chunkData + 2).toInt() and 0xFFFF
                srcSampleRate = bb.getInt(chunkData + 4)
                bitsPerSample = bb.getShort(chunkData + 14).toInt() and 0xFFFF
            } else if (id == "data") {
                dataStart = chunkData
                dataSize = min(size, bytes.size - chunkData)
                break
            }
            offset = chunkData + size + (if (size % 2 != 0) 1 else 0)
        }

        if (dataStart < 0 || dataSize <= 0) return ShortArray(0)

        // Önce mono/interleaved float dizisine dönüştür
        val srcFrames: Int
        val srcSamples: FloatArray
        if (audioFormat == 3 && bitsPerSample == 32) {
            val count = dataSize / 4
            srcFrames = count / srcChannels
            srcSamples = FloatArray(count)
            for (i in 0 until count) {
                srcSamples[i] = bb.getFloat(dataStart + i * 4).coerceIn(-1f, 1f)
            }
        } else {
            val count = dataSize / 2
            srcFrames = count / srcChannels
            srcSamples = FloatArray(count)
            for (i in 0 until count) {
                srcSamples[i] = bb.getShort(dataStart + i * 2) / 32768f
            }
        }

        if (srcFrames <= 0) return ShortArray(0)

        val ratio = targetSampleRate.toDouble() / srcSampleRate.toDouble()
        val dstFrames = max(1, (srcFrames * ratio).roundToInt())
        val out = ShortArray(dstFrames * targetChannels)

        for (df in 0 until dstFrames) {
            val srcPos = df / ratio
            val idx0 = min(srcPos.toInt(), srcFrames - 1)
            val idx1 = min(idx0 + 1, srcFrames - 1)
            val frac = (srcPos - idx0).toFloat()

            for (ch in 0 until targetChannels) {
                val srcCh = if (ch < srcChannels) ch else 0
                val s0 = srcSamples[idx0 * srcChannels + srcCh]
                val s1 = srcSamples[idx1 * srcChannels + srcCh]
                val interp = s0 + (s1 - s0) * frac
                out[df * targetChannels + ch] = (interp.coerceIn(-1f, 1f) * 32767f).roundToInt().toShort()
            }
        }
        return out
    }

    /**
     * 30/60/90. saniyeler için net, hoş çift-tonlu bip/çan;
     * 120. saniye (bitiş) için 3 notalı kutlama melodisi üretir.
     */
    private fun generateChimeCue(sampleRate: Int, channels: Int, isFinal: Boolean): ShortArray {
        val notes: List<Triple<Double, Double, Double>> = if (isFinal) {
            // (freqHz, startSec, durationSec) -> C6 - E6 - G6
            listOf(
                Triple(1046.50, 0.00, 0.28),
                Triple(1318.51, 0.22, 0.28),
                Triple(1567.98, 0.44, 0.50)
            )
        } else {
            // (freqHz, startSec, durationSec) -> A5 - D6
            listOf(
                Triple(880.00, 0.00, 0.24),
                Triple(1174.66, 0.18, 0.38)
            )
        }

        val totalSec = notes.maxOf { it.second + it.third }
        val totalFrames = (totalSec * sampleRate).roundToInt()
        val mono = FloatArray(totalFrames)

        for ((freq, startSec, durSec) in notes) {
            val startFrame = (startSec * sampleRate).roundToInt()
            val noteFrames = (durSec * sampleRate).roundToInt()
            val attackFrames = max(1, (0.015 * sampleRate).roundToInt())

            for (f in 0 until noteFrames) {
                val outIdx = startFrame + f
                if (outIdx >= totalFrames) break
                val t = f.toDouble() / sampleRate
                // Yumuşak attack + üstel sönümleme (çan hissi)
                val attack = if (f < attackFrames) f.toFloat() / attackFrames else 1f
                val decay = kotlin.math.exp(-4.5 * (f.toDouble() / noteFrames)).toFloat()
                val tailFade = if (f > noteFrames - attackFrames) {
                    (noteFrames - f).toFloat() / attackFrames
                } else 1f
                val env = attack * decay * tailFade

                // Temel frekans + hafif 2. harmonik
                val wave = (sin(2.0 * PI * freq * t) * 0.78 + sin(2.0 * PI * freq * 2.0 * t) * 0.22).toFloat()
                mono[outIdx] += wave * env * 0.85f
            }
        }

        val out = ShortArray(totalFrames * channels)
        for (f in 0 until totalFrames) {
            val s = (mono[f].coerceIn(-1f, 1f) * 32767f).roundToInt().toShort()
            for (ch in 0 until channels) {
                out[f * channels + ch] = s
            }
        }
        return out
    }

    private fun writeMixedWav(
        sourcePcmFile: File,
        sourceTotalFrames: Long,
        outputWavFile: File,
        outputTotalFrames: Long,
        sampleRate: Int,
        channels: Int,
        cues: List<CueTrack>,
        musicVolume: Float,
        alertVolume: Float
    ) {
        val bytesPerFrame = channels * 2
        val rampFrames = max(1L, (0.20 * sampleRate).toLong())
        val duckFactor = 0.25f

        val chunkFrames = 4096
        val readBuf = ByteArray(chunkFrames * bytesPerFrame)
        val writeBuf = ByteArray(chunkFrames * bytesPerFrame)

        var srcStream = BufferedInputStream(FileInputStream(sourcePcmFile), 65536)
        var srcFramesRemaining = sourceTotalFrames

        BufferedOutputStream(FileOutputStream(outputWavFile), 65536).use { outStream ->
            // 44 byte WAV header placeholder
            outStream.write(ByteArray(44))

            var currentFrame = 0L
            while (currentFrame < outputTotalFrames) {
                val framesToProcess = min(chunkFrames.toLong(), outputTotalFrames - currentFrame).toInt()
                val bytesNeeded = framesToProcess * bytesPerFrame

                // Kaynak PCM'den oku (bitti ise başa sar / loop)
                var filled = 0
                while (filled < bytesNeeded) {
                    if (srcFramesRemaining <= 0) {
                        srcStream.close()
                        srcStream = BufferedInputStream(FileInputStream(sourcePcmFile), 65536)
                        srcFramesRemaining = sourceTotalFrames
                    }
                    val maxRead = min(bytesNeeded - filled, (srcFramesRemaining * bytesPerFrame).toInt())
                    val n = srcStream.read(readBuf, filled, maxRead)
                    if (n <= 0) {
                        // Beklenmeyen EOF durumunda başa sar
                        srcStream.close()
                        srcStream = BufferedInputStream(FileInputStream(sourcePcmFile), 65536)
                        srcFramesRemaining = sourceTotalFrames
                        continue
                    }
                    filled += n
                    srcFramesRemaining -= (n / bytesPerFrame)
                }

                val inBB = ByteBuffer.wrap(readBuf).order(ByteOrder.LITTLE_ENDIAN)
                val outBB = ByteBuffer.wrap(writeBuf).order(ByteOrder.LITTLE_ENDIAN)

                for (f in 0 until framesToProcess) {
                    val globalFrame = currentFrame + f

                    // Ducking katsayısını hesapla
                    var gainMultiplier = 1.0f
                    for (cue in cues) {
                        val cStart = cue.startFrame
                        val cEnd = cue.endFrame(channels)
                        if (globalFrame in (cStart - rampFrames) until cStart) {
                            val progress = (globalFrame - (cStart - rampFrames)).toFloat() / rampFrames
                            val smooth = (1f - cos(progress * PI.toFloat())) * 0.5f
                            val g = 1f - smooth * (1f - duckFactor)
                            if (g < gainMultiplier) gainMultiplier = g
                        } else if (globalFrame in cStart until cEnd) {
                            if (duckFactor < gainMultiplier) gainMultiplier = duckFactor
                        } else if (globalFrame in cEnd until (cEnd + rampFrames)) {
                            val progress = (globalFrame - cEnd).toFloat() / rampFrames
                            val smooth = (1f - cos(progress * PI.toFloat())) * 0.5f
                            val g = duckFactor + smooth * (1f - duckFactor)
                            if (g < gainMultiplier) gainMultiplier = g
                        }
                    }

                    val effectiveMusicGain = musicVolume * gainMultiplier

                    for (ch in 0 until channels) {
                        val sampleByteIdx = (f * channels + ch) * 2
                        var mixed = inBB.getShort(sampleByteIdx).toFloat() * effectiveMusicGain

                        for (cue in cues) {
                            val cStart = cue.startFrame
                            val cEnd = cue.endFrame(channels)
                            if (globalFrame in cStart until cEnd) {
                                val cueFrame = (globalFrame - cStart).toInt()
                                mixed += cue.samples[cueFrame * channels + ch].toFloat() * alertVolume
                            }
                        }

                        val clamped = mixed.roundToInt().coerceIn(-32768, 32767).toShort()
                        outBB.putShort(sampleByteIdx, clamped)
                    }
                }

                outStream.write(writeBuf, 0, bytesNeeded)
                currentFrame += framesToProcess
            }
            outStream.flush()
        }

        srcStream.close()

        // WAV başlığını gerçek boyutlarla güncelle
        val dataBytes = outputTotalFrames * bytesPerFrame
        writeWavHeader(outputWavFile, dataBytes, sampleRate, channels, 16)
    }

    private fun writeWavHeader(
        file: File,
        dataLength: Long,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int
    ) {
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = (channels * bitsPerSample / 8).toShort()
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((36 + dataLength).toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16) // PCM chunk size
        header.putShort(1) // PCM format
        header.putShort(channels.toShort())
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort(blockAlign)
        header.putShort(bitsPerSample.toShort())
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataLength.toInt())

        RandomAccessFile(file, "rw").use { raf ->
            raf.seek(0)
            raf.write(header.array())
        }
    }
}
