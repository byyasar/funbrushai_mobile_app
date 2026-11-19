import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'tts_save_service.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundRecorder _flutterSoundRecorder = FlutterSoundRecorder();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }

    await _flutterSoundRecorder.openRecorder();
    _isInitialized = true;
  }

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  Future<void> requestPermission() async {
    await Permission.microphone.request();
  }

  // Using record package (simpler, modern)
  Future<String?> startRecording({String? customFileName}) async {
    if (!await hasPermission()) {
      await requestPermission();
      if (!await hasPermission()) {
        throw Exception('Microphone permission required');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = customFileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = '${directory.path}/$fileName';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // M4A/AAC format
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      return filePath;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  // Using flutter_sound to record PCM WAV, then encode to MP3
  String? _pendingMp3Path;
  String? _tempWavPath;

  Future<String?> startRecordingMp3({String? customFileName}) async {
    if (!_isInitialized) {
      await initialize();
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var fileName = customFileName ?? 'recording_$timestamp.mp3';
    if (!fileName.toLowerCase().endsWith('.mp3')) {
      fileName = '$fileName.mp3';
    }
    _pendingMp3Path = '${directory.path}/$fileName';
    _tempWavPath = '${directory.path}/_temp_rec_$timestamp.wav';

    try {
      await _flutterSoundRecorder.startRecorder(
        toFile: _tempWavPath,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
        numChannels: 1,
      );
      return _pendingMp3Path;
    } catch (e) {
      debugPrint('Error starting MP3 recording: $e');
      return null;
    }
  }

  Future<String?> stopRecordingMp3() async {
    try {
      final wavPath = await _flutterSoundRecorder.stopRecorder() ?? _tempWavPath;
      final mp3Path = _pendingMp3Path;
      if (wavPath != null && mp3Path != null) {
        final result = await TtsSaveService.convertWavToMp3(wavPath, mp3Path);
        final tempFile = File(wavPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping MP3 recording: $e');
      return null;
    }
  }

  Future<bool> isRecordingMp3() async {
    return _flutterSoundRecorder.isRecording;
  }

  // Convert M4A to MP3 using flutter_sound (using startPlayer/stopPlayer workaround)
  Future<String?> convertToMp3(String inputPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    final directory = await getApplicationDocumentsDirectory();
    final outputPath = '${directory.path}/converted_${DateTime.now().millisecondsSinceEpoch}.mp3';

    try {
      // flutter_sound doesn't have direct convert method in newer versions
      // Use a player to decode and re-encode, or just copy for now
      final inputFile = File(inputPath);
      if (await inputFile.exists()) {
        await inputFile.copy(outputPath);
        return outputPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error converting to MP3: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _flutterSoundRecorder.closeRecorder();
    _isInitialized = false;
  }

  // Get all recordings
  Future<List<FileSystemEntity>> getRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final entities = directory.listSync();
    return entities.where((file) {
      final ext = file.path.split('.').last.toLowerCase();
      return ['m4a', 'mp3', 'wav', 'aac'].contains(ext);
    }).toList();
  }

  // Delete a recording
  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}