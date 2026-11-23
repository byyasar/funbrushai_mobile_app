import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'music_config_service.dart';
import 'tts_save_service.dart';

class AudioMixerService {
  static const MethodChannel _channel = MethodChannel('com.funbrushai.app/audio_mixer');

  /// Arka plan müziği ile 30, 60, 90 ve 120. saniyelerdeki bip veya TTS uyarılarını
  /// tek bir gerçek MP3 dosyasında birleştirir.
  static Future<String> exportMixedBrushingMusic({
    required String sourceMusicPath,
    required String outputMp3Path,
    required AlertSoundType alertType,
    required String singleTtsText,
    required List<String> intervalTtsTexts,
    required bool useSeparateTexts,
    double musicVolume = 0.8,
    double alertVolume = 1.0,
    List<int> intervalSeconds = const [30, 60, 90, 120],
    void Function(String status)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Ses birleştirme şu an yalnızca Android cihazlarda desteklenmektedir.');
    }

    final sourceFile = File(sourceMusicPath);
    if (!await sourceFile.exists()) {
      throw Exception('Kaynak müzik dosyası bulunamadı.');
    }

    final tempDir = await getTemporaryDirectory();
    final runId = DateTime.now().millisecondsSinceEpoch;
    final tempFilesToDelete = <String>[];

    try {
      final cueWavPaths = <String>[];

      if (alertType == AlertSoundType.tts) {
        onProgress?.call('Konuşma uyarıları hazırlanıyor...');
        if (useSeparateTexts) {
          for (int i = 0; i < intervalSeconds.length; i++) {
            final rawText = (i < intervalTtsTexts.length && intervalTtsTexts[i].trim().isNotEmpty)
                ? intervalTtsTexts[i].trim()
                : (singleTtsText.trim().isNotEmpty ? singleTtsText.trim() : 'Diğer bölgeye geçin');

            final wavPath = '${tempDir.path}/_cue_${runId}_$i.wav';
            final synthesized = await TtsSaveService.synthesizeTtsToWav(
              text: rawText,
              outputWavPath: wavPath,
              language: 'tr-TR',
              pitch: 1.0,
              speechRate: 0.5,
            );
            if (synthesized == null) {
              throw Exception('${i + 1}. bölge seslendirmesi oluşturulamadı.');
            }
            tempFilesToDelete.add(synthesized);
            cueWavPaths.add(synthesized);
          }
        } else {
          final text = singleTtsText.trim().isNotEmpty ? singleTtsText.trim() : 'Diğer bölgeye geçin';
          final wavPath = '${tempDir.path}/_cue_${runId}_single.wav';
          final synthesized = await TtsSaveService.synthesizeTtsToWav(
            text: text,
            outputWavPath: wavPath,
            language: 'tr-TR',
            pitch: 1.0,
            speechRate: 0.5,
          );
          if (synthesized == null) {
            throw Exception('Seslendirme metni oluşturulamadı.');
          }
          tempFilesToDelete.add(synthesized);
          for (int i = 0; i < intervalSeconds.length; i++) {
            cueWavPaths.add(synthesized);
          }
        }
      } else {
        onProgress?.call('Bip uyarıları hazırlanıyor...');
      }

      onProgress?.call('Müzik ve 30 sn uyarıları birleştiriliyor...');
      final tempMixedWavPath = '${tempDir.path}/_mixed_$runId.wav';
      tempFilesToDelete.add(tempMixedWavPath);

      final mixedWav = await _channel.invokeMethod<String>('mixAudio', {
        'musicPath': sourceMusicPath,
        'outputWavPath': tempMixedWavPath,
        'alertType': alertType == AlertSoundType.tts ? 'tts' : 'beep',
        'cueWavPaths': cueWavPaths,
        'intervalSeconds': intervalSeconds,
        'musicVolume': musicVolume,
        'alertVolume': alertVolume,
      });

      if (mixedWav == null || !await File(mixedWav).exists()) {
        throw Exception('Ses birleştirme dosyası oluşturulamadı.');
      }

      onProgress?.call('MP3 dosyası oluşturuluyor...');
      final tempMp3Path = '${tempDir.path}/_mixed_$runId.mp3';
      tempFilesToDelete.add(tempMp3Path);

      final encodedMp3 = await TtsSaveService.convertWavToMp3(mixedWav, tempMp3Path);
      if (encodedMp3 == null || !await File(encodedMp3).exists()) {
        throw Exception('Birleştirilmiş ses MP3 formatına dönüştürülemedi.');
      }

      // Hedef konuma kopyala
      final destFile = File(outputMp3Path);
      await destFile.parent.create(recursive: true);
      if (await destFile.exists()) {
        await destFile.delete();
      }
      await File(encodedMp3).copy(outputMp3Path);

      return outputMp3Path;
    } on PlatformException catch (e) {
      debugPrint('AudioMixerService PlatformException: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Ses birleştirme sırasında platform hatası oluştu.');
    } finally {
      for (final path in tempFilesToDelete) {
        try {
          final f = File(path);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
  }
}
