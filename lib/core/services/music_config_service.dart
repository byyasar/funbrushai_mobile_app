import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AlertSoundType {
  beep,
  tts,
}

class MusicConfig {
  final String? musicPath;
  final String? musicName;
  final AlertSoundType alertType;
  final String singleTtsText;
  final List<String> intervalTtsTexts;
  final bool useSeparateTexts;
  final double musicVolume;
  final double alertVolume;

  const MusicConfig({
    this.musicPath,
    this.musicName,
    this.alertType = AlertSoundType.tts,
    this.singleTtsText = 'Diğer bölgeye geçin',
    this.intervalTtsTexts = const [
      '1. Bölge bitti, diğer tarafa geçin',
      '2. Bölge bitti, alt dişlere geçin',
      '3. Bölge bitti, son tarafa geçin',
      'Harika! Fırçalama tamamlandı',
    ],
    this.useSeparateTexts = false,
    this.musicVolume = 0.8,
    this.alertVolume = 1.0,
  });

  MusicConfig copyWith({
    String? musicPath,
    String? musicName,
    AlertSoundType? alertType,
    String? singleTtsText,
    List<String>? intervalTtsTexts,
    bool? useSeparateTexts,
    double? musicVolume,
    double? alertVolume,
  }) {
    return MusicConfig(
      musicPath: musicPath ?? this.musicPath,
      musicName: musicName ?? this.musicName,
      alertType: alertType ?? this.alertType,
      singleTtsText: singleTtsText ?? this.singleTtsText,
      intervalTtsTexts: intervalTtsTexts ?? this.intervalTtsTexts,
      useSeparateTexts: useSeparateTexts ?? this.useSeparateTexts,
      musicVolume: musicVolume ?? this.musicVolume,
      alertVolume: alertVolume ?? this.alertVolume,
    );
  }
}

class MusicConfigService {
  static const String _keyMusicPath = 'brushing_music_path';
  static const String _keyMusicName = 'brushing_music_name';
  static const String _keyAlertType = 'brushing_alert_type';
  static const String _keySingleTts = 'brushing_single_tts';
  static const String _keyIntervalTtsPrefix = 'brushing_interval_tts_';
  static const String _keyUseSeparate = 'brushing_use_separate_tts';
  static const String _keyMusicVol = 'brushing_music_vol';
  static const String _keyAlertVol = 'brushing_alert_vol';

  static final MusicConfigService _instance = MusicConfigService._internal();
  factory MusicConfigService() => _instance;
  MusicConfigService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _alertPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  MusicConfig _config = const MusicConfig();
  MusicConfig get config => _config;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;

  Duration _totalDuration = Duration.zero;
  Duration get totalDuration => _totalDuration;

  final Set<int> _triggeredIntervals = {};
  StreamSubscription? _posSubscription;
  StreamSubscription? _durSubscription;
  StreamSubscription? _stateSubscription;

  final ValueNotifier<MusicConfig> configNotifier = ValueNotifier(const MusicConfig());
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);

  Future<void> init() async {
    await _initTts();
    await loadConfig();
    _initAudioListeners();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('tr-TR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _restoreMusicVolume();
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _restoreMusicVolume();
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  void _initAudioListeners() {
    _posSubscription = _musicPlayer.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      positionNotifier.value = pos;
      _checkIntervals(pos);
    });

    _durSubscription = _musicPlayer.onDurationChanged.listen((dur) {
      _totalDuration = dur;
    });

    _stateSubscription = _musicPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
      isPlayingNotifier.value = _isPlaying;
    });
  }

  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicPath = prefs.getString(_keyMusicPath);
      final musicName = prefs.getString(_keyMusicName);
      final alertTypeStr = prefs.getString(_keyAlertType) ?? 'tts';
      final singleTts = prefs.getString(_keySingleTts) ?? 'Diğer bölgeye geçin';
      final useSeparate = prefs.getBool(_keyUseSeparate) ?? false;
      final musicVol = prefs.getDouble(_keyMusicVol) ?? 0.8;
      final alertVol = prefs.getDouble(_keyAlertVol) ?? 1.0;

      final intervalTexts = <String>[];
      for (int i = 0; i < 4; i++) {
        final text = prefs.getString('$_keyIntervalTtsPrefix$i');
        if (text != null && text.isNotEmpty) {
          intervalTexts.add(text);
        } else {
          intervalTexts.add(const MusicConfig().intervalTtsTexts[i]);
        }
      }

      _config = MusicConfig(
        musicPath: (musicPath != null && File(musicPath).existsSync()) ? musicPath : null,
        musicName: musicName,
        alertType: alertTypeStr == 'beep' ? AlertSoundType.beep : AlertSoundType.tts,
        singleTtsText: singleTts,
        intervalTtsTexts: intervalTexts,
        useSeparateTexts: useSeparate,
        musicVolume: musicVol,
        alertVolume: alertVol,
      );
      configNotifier.value = _config;
    } catch (e) {
      debugPrint('Error loading music config: $e');
    }
  }

  Future<void> saveConfig(MusicConfig newConfig) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newConfig.musicPath != null) {
        await prefs.setString(_keyMusicPath, newConfig.musicPath!);
      } else {
        await prefs.remove(_keyMusicPath);
      }

      if (newConfig.musicName != null) {
        await prefs.setString(_keyMusicName, newConfig.musicName!);
      } else {
        await prefs.remove(_keyMusicName);
      }

      await prefs.setString(
        _keyAlertType,
        newConfig.alertType == AlertSoundType.beep ? 'beep' : 'tts',
      );
      await prefs.setString(_keySingleTts, newConfig.singleTtsText);
      await prefs.setBool(_keyUseSeparate, newConfig.useSeparateTexts);
      await prefs.setDouble(_keyMusicVol, newConfig.musicVolume);
      await prefs.setDouble(_keyAlertVol, newConfig.alertVolume);

      for (int i = 0; i < newConfig.intervalTtsTexts.length; i++) {
        await prefs.setString('$_keyIntervalTtsPrefix$i', newConfig.intervalTtsTexts[i]);
      }

      _config = newConfig;
      configNotifier.value = _config;
    } catch (e) {
      debugPrint('Error saving music config: $e');
    }
  }

  Future<String?> copyMusicToAppStorage(String sourcePath, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/brushing_music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final ext = sourcePath.split('.').last;
      final targetPath = '${musicDir.path}/custom_brushing_music.$ext';
      final targetFile = File(targetPath);

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final savedFile = await File(sourcePath).copy(targetPath);
      return savedFile.path;
    } catch (e) {
      debugPrint('Error copying music file: $e');
      return null;
    }
  }

  void _checkIntervals(Duration pos) {
    final seconds = pos.inSeconds;
    // 4 çeyrek aralıkları: 30., 60., 90., 120. saniyeler
    final intervals = [30, 60, 90, 120];

    for (int i = 0; i < intervals.length; i++) {
      final intervalSec = intervals[i];
      if (seconds >= intervalSec && !_triggeredIntervals.contains(intervalSec)) {
        _triggeredIntervals.add(intervalSec);
        _triggerCueAlert(i);
        break;
      }
    }
  }

  Future<void> _triggerCueAlert(int intervalIndex) async {
    // 1. Ducking: Müziğin sesini kıs
    await _musicPlayer.setVolume(_config.musicVolume * 0.25);

    if (_config.alertType == AlertSoundType.beep) {
      await _playBeepSound();
    } else {
      await _playTtsSpeech(intervalIndex);
    }
  }

  Future<void> _playBeepSound() async {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      
      // Bip sonrası müziği 1.2 saniye sonra normale döndür
      Future.delayed(const Duration(milliseconds: 1200), () {
        _restoreMusicVolume();
      });
    } catch (e) {
      debugPrint('Error playing beep sound: $e');
      _restoreMusicVolume();
    }
  }

  Future<void> _playTtsSpeech(int intervalIndex) async {
    try {
      HapticFeedback.mediumImpact();
      final textToSpeak = _config.useSeparateTexts
          ? (_config.intervalTtsTexts.length > intervalIndex
              ? _config.intervalTtsTexts[intervalIndex]
              : _config.singleTtsText)
          : _config.singleTtsText;

      await _flutterTts.setVolume(_config.alertVolume);
      await _flutterTts.speak(textToSpeak);
      // Not: completion handler'da _restoreMusicVolume çağrılır
    } catch (e) {
      debugPrint('Error speaking TTS: $e');
      _restoreMusicVolume();
    }
  }

  Future<void> _restoreMusicVolume() async {
    if (_isPlaying) {
      await _musicPlayer.setVolume(_config.musicVolume);
    }
  }

  Future<void> playPreview() async {
    if (_config.musicPath == null || !File(_config.musicPath!).existsSync()) {
      return;
    }

    try {
      _triggeredIntervals.clear();
      await _musicPlayer.setVolume(_config.musicVolume);
      await _musicPlayer.play(DeviceFileSource(_config.musicPath!));
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  Future<void> pausePreview() async {
    try {
      await _musicPlayer.pause();
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error pausing preview: $e');
    }
  }

  Future<void> stopPreview() async {
    try {
      await _musicPlayer.stop();
      await _flutterTts.stop();
      _triggeredIntervals.clear();
      _currentPosition = Duration.zero;
      positionNotifier.value = Duration.zero;
    } catch (e) {
      debugPrint('Error stopping preview: $e');
    }
  }

  Future<void> seekPreview(Duration pos) async {
    try {
      _triggeredIntervals.removeWhere((sec) => sec > pos.inSeconds);
      await _musicPlayer.seek(pos);
    } catch (e) {
      debugPrint('Error seeking preview: $e');
    }
  }

  Future<void> testCue(int intervalIndex) async {
    final prevPlaying = _isPlaying;
    if (_isPlaying) {
      await _musicPlayer.setVolume(_config.musicVolume * 0.25);
    }

    if (_config.alertType == AlertSoundType.beep) {
      await _playBeepSound();
    } else {
      await _playTtsSpeech(intervalIndex);
    }

    if (!prevPlaying) {
      // Çalmıyorsa sadece dinleme amaçlı
      Future.delayed(const Duration(milliseconds: 1500), () {
        _restoreMusicVolume();
      });
    }
  }

  void dispose() {
    _posSubscription?.cancel();
    _durSubscription?.cancel();
    _stateSubscription?.cancel();
    _musicPlayer.dispose();
    _alertPlayer.dispose();
    _flutterTts.stop();
  }
}
