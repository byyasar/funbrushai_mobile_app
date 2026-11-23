import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lame/flutter_lame.dart';
import 'package:path_provider/path_provider.dart';

class TtsSaveService {
  static const MethodChannel _channel = MethodChannel('com.funbrushai.app/tts_save');

  /// TTS metnini geçici veya belirtilen yola 16-bit PCM WAV olarak sentezler.
  static Future<String?> synthesizeTtsToWav({
    required String text,
    required String outputWavPath,
    String language = 'tr-TR',
    double pitch = 1.0,
    double speechRate = 0.5,
  }) async {
    try {
      final result = await _channel.invokeMethod('saveTtsToFile', {
        'text': text,
        'filePath': outputWavPath,
        'language': language,
        'pitch': pitch,
        'speechRate': speechRate,
      });

      if (result == true && await File(outputWavPath).exists()) {
        return outputWavPath;
      }
      debugPrint('TTS WAV synthesis failed: $result');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Platform error synthesizing TTS WAV: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error synthesizing TTS WAV: $e');
      return null;
    }
  }

  /// TTS sesini MP3 olarak kaydet
  /// [text] - Söylenecek metin
  /// [fileName] - Dosya adı (opsiyonel, otomatik oluşturulur)
  /// [language] - Dil kodu (örn: 'tr-TR', 'en-US')
  /// Returns: Kaydedilen dosyanın yolu veya null (hata durumunda)
  static Future<String?> saveTtsToMp3({
    required String text,
    String? fileName,
    String language = 'tr-TR',
    double pitch = 1.0,
    double speechRate = 0.5,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      var name = fileName ?? 'tts_$timestamp.mp3';
      if (!name.toLowerCase().endsWith('.mp3')) {
        name = '$name.mp3';
      }
      final mp3FilePath = '${directory.path}/$name';
      final tempWavPath = '${directory.path}/_temp_tts_$timestamp.wav';

      final wavPath = await synthesizeTtsToWav(
        text: text,
        outputWavPath: tempWavPath,
        language: language,
        pitch: pitch,
        speechRate: speechRate,
      );

      if (wavPath != null) {
        final encodedPath = await convertWavToMp3(tempWavPath, mp3FilePath);
        final tempFile = File(tempWavPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        if (encodedPath != null) {
          debugPrint('TTS saved to MP3: $encodedPath');
          return encodedPath;
        }
      }
      debugPrint('TTS save failed');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Platform error saving TTS: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error saving TTS: $e');
      return null;
    }
  }

  /// 16-bit PCM WAV dosyasını LAME ile gerçek MP3 dosyasına dönüştürür
  static Future<String?> convertWavToMp3(String wavPath, String mp3Path) async {
    final wavFile = File(wavPath);
    if (!await wavFile.exists()) return null;

    final bytes = await wavFile.readAsBytes();
    if (bytes.length < 44) return null;

    final bd = ByteData.sublistView(bytes);
    // WAV header'dan fmt ve data chunk'larını bul
    int offset = 12;
    int numChannels = 1;
    int sampleRate = 22050;
    int bitsPerSample = 16;
    int audioFormat = 1;
    Uint8List? pcmData;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;

      if (chunkId == 'fmt ' && chunkDataStart + 16 <= bytes.length) {
        audioFormat = bd.getUint16(chunkDataStart, Endian.little);
        numChannels = bd.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = bd.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = bd.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        final end = (chunkDataStart + chunkSize <= bytes.length)
            ? chunkDataStart + chunkSize
            : bytes.length;
        pcmData = bytes.sublist(chunkDataStart, end);
        break;
      }

      offset = chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (pcmData == null || pcmData.isEmpty) return null;

    final Int16List samples;
    if (audioFormat == 3 && bitsPerSample == 32) {
      // 32-bit float PCM -> 16-bit int PCM
      final floatCount = pcmData.length ~/ 4;
      final pcmBd = ByteData.sublistView(pcmData);
      samples = Int16List(floatCount);
      for (int i = 0; i < floatCount; i++) {
        final f = pcmBd.getFloat32(i * 4, Endian.little).clamp(-1.0, 1.0);
        samples[i] = (f * 32767).round();
      }
    } else {
      // 16-bit int PCM
      final sampleCount = pcmData.length ~/ 2;
      final pcmBd = ByteData.sublistView(pcmData);
      samples = Int16List(sampleCount);
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = pcmBd.getInt16(i * 2, Endian.little);
      }
    }

    final encoder = LameMp3Encoder(
      sampleRate: sampleRate,
      numChannels: numChannels,
    );

    final mp3File = File(mp3Path);
    if (await mp3File.exists()) {
      await mp3File.delete();
    }
    final sink = mp3File.openWrite();

    try {
      const chunkFrames = 4096;
      if (numChannels == 1) {
        for (int i = 0; i < samples.length; i += chunkFrames) {
          final end = (i + chunkFrames < samples.length) ? i + chunkFrames : samples.length;
          final chunk = Int16List.sublistView(samples, i, end);
          final mp3Bytes = await encoder.encode(leftChannel: chunk);
          if (mp3Bytes.isNotEmpty) {
            sink.add(mp3Bytes);
          }
        }
      } else {
        final totalFrames = samples.length ~/ numChannels;
        for (int frame = 0; frame < totalFrames; frame += chunkFrames) {
          final count = (frame + chunkFrames < totalFrames) ? chunkFrames : (totalFrames - frame);
          final left = Int16List(count);
          final right = Int16List(count);
          for (int j = 0; j < count; j++) {
            final idx = (frame + j) * numChannels;
            left[j] = samples[idx];
            right[j] = samples[idx + 1];
          }
          final mp3Bytes = await encoder.encode(leftChannel: left, rightChannel: right);
          if (mp3Bytes.isNotEmpty) {
            sink.add(mp3Bytes);
          }
        }
      }

      final flushBytes = await encoder.flush();
      if (flushBytes.isNotEmpty) {
        sink.add(flushBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
      await encoder.close();
    }

    return mp3Path;
  }

  /// Kaydedilen TTS dosyalarını listele
  static Future<List<FileSystemEntity>> getSavedTtsFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.listSync().where((file) {
      final ext = file.path.split('.').last.toLowerCase();
      return ext == 'mp3';
    }).toList();
  }

  /// TTS dosyasını sil
  static Future<void> deleteTtsFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// TTS dosyasını paylaş
  static Future<void> shareTtsFile(String filePath, {String? subject}) async {
    // share_plus paketi ile paylaşım yapılabilir
    // Bu metod sadece dosya yolunu döndürür, paylaşım UI çağıran yerde yapılır
  }
}