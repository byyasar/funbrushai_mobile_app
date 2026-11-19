import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/tts_save_service.dart';
import '../widgets/app_banner.dart';

class AudioTestScreen extends StatefulWidget {
  const AudioTestScreen({super.key});

  @override
  State<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends State<AudioTestScreen> {
  final AudioRecordingService _recordingService = AudioRecordingService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  String? _ttsFilePath;
  List<File> _recordings = [];

  @override
  void initState() {
    super.initState();
    _initRecording();
    _loadRecordings();
  }

  Future<void> _initRecording() async {
    try {
      await _recordingService.initialize();
    } catch (e) {
      debugPrint('Recording init error: $e');
    }
  }

  Future<void> _loadRecordings() async {
    final files = await _recordingService.getRecordings();
    if (mounted) {
      setState(() {
        _recordings = files.whereType<File>().toList();
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final path = await _recordingService.startRecordingMp3();
      if (path != null) {
        setState(() {
          _isRecording = true;
          _recordedFilePath = path;
        });
      }
    } catch (e) {
      _showError('Kayıt başlatılamadı: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recordingService.stopRecordingMp3();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordedFilePath = path;
        });
        await _loadRecordings();
        _showSuccess('Kayıt tamamlandı: $path');
      }
    } catch (e) {
      _showError('Kayıt durdurulamadı: $e');
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      setState(() => _isPlaying = true);
      await _audioPlayer.play(DeviceFileSource(path));
      await _audioPlayer.onPlayerComplete.first;
      if (mounted) setState(() => _isPlaying = false);
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
      _showError('Oynatma hatası: $e');
    }
  }

  Future<void> _saveTtsAsMp3() async {
    try {
      final path = await TtsSaveService.saveTtsToMp3(
        text: 'Hoşgeldin test kullanıcısı, bu bir test mesajıdır.',
        language: 'tr-TR',
        pitch: 1.0,
        speechRate: 0.5,
      );
      
      if (path != null) {
        setState(() {
          _ttsFilePath = path;
        });
        await _loadRecordings();
        _showSuccess('TTS MP3 kaydedildi: $path');
      } else {
        _showError('TTS MP3 kaydedilemedi');
      }
    } catch (e) {
      _showError('TTS hatası: $e');
    }
  }

  Future<void> _deleteRecording(String path) async {
    await _recordingService.deleteRecording(path);
    await _loadRecordings();
    _showSuccess('Dosya silindi');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.greenSuccess,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.redMissed,
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              title: 'Ses Testi',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ses Kaydetme Bölümü
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ses Kaydet (MP3)',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isRecording ? _stopRecording : _startRecording,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isRecording ? AppColors.redMissed : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 24),
                                    label: Text(
                                      _isRecording ? 'Durdur' : 'Kaydet',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isRecording) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.redMissed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.redMissed.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.fiber_manual_record, color: AppColors.redMissed, size: 12),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Kayıt devam ediyor...',
                                      style: TextStyle(
                                        color: AppColors.redMissed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_recordedFilePath != null && !_isRecording) ...[
                              const SizedBox(height: 12),
                              _buildAudioPlayerCard(_recordedFilePath!, 'Kaydedilen Ses'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TTS MP3 Kaydetme Bölümü
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TTS → MP3 Kaydet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _saveTtsAsMp3,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successBright,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.download, size: 24),
                              label: const Text(
                                'Hoşgeldin Mesajını MP3 Olarak Kaydet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_ttsFilePath != null) ...[
                              const SizedBox(height: 12),
                              _buildAudioPlayerCard(_ttsFilePath!, 'TTS MP3'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kayıtlı Dosyalar Listesi
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kayıtlı Ses Dosyaları',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_recordings.isEmpty)
                              Center(
                                child: Text(
                                  'Henüz kayıt yok',
                                  style: TextStyle(
                                    color: isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recordings.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final file = _recordings[index];
                                  final fileName = file.path.split('/').last;
                                  return ListTile(
                                    leading: const Icon(Icons.audiotrack),
                                    title: Text(fileName),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.play_arrow),
                                          onPressed: () => _playRecording(file.path),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: AppColors.redMissed),
                                          onPressed: () => _deleteRecording(file.path),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayerCard(String filePath, String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  filePath.split('/').last,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isPlaying ? null : () => _playRecording(filePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: _isPlaying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_isPlaying ? 'Oynatılıyor...' : 'Oynat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}