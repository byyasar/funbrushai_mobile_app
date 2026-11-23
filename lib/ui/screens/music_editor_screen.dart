import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/music_config_service.dart';
import '../widgets/app_banner.dart';

class MusicEditorScreen extends StatefulWidget {
  const MusicEditorScreen({super.key});

  @override
  State<MusicEditorScreen> createState() => _MusicEditorScreenState();
}

class _MusicEditorScreenState extends State<MusicEditorScreen> {
  final MusicConfigService _musicService = MusicConfigService();

  late AlertSoundType _alertType;
  late TextEditingController _singleTtsController;
  late List<TextEditingController> _intervalControllers;
  late bool _useSeparateTexts;
  late double _musicVolume;
  late double _alertVolume;

  String? _currentMusicPath;
  String? _currentMusicName;
  bool _isLoadingFile = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = _musicService.config;
    _alertType = config.alertType;
    _currentMusicPath = config.musicPath;
    _currentMusicName = config.musicName;
    _singleTtsController = TextEditingController(text: config.singleTtsText);
    _useSeparateTexts = config.useSeparateTexts;
    _musicVolume = config.musicVolume;
    _alertVolume = config.alertVolume;

    _intervalControllers = List.generate(4, (i) {
      final text = (i < config.intervalTtsTexts.length)
          ? config.intervalTtsTexts[i]
          : const MusicConfig().intervalTtsTexts[i];
      return TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    _musicService.stopPreview();
    _singleTtsController.dispose();
    for (final c in _intervalControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMusicFile() async {
    setState(() => _isLoadingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final rawPath = result.files.single.path!;
        final fileName = result.files.single.name;

        // Uygulama dizinine kalıcı olarak kopyala
        final savedPath = await _musicService.copyMusicToAppStorage(rawPath, fileName);
        if (savedPath != null) {
          setState(() {
            _currentMusicPath = savedPath;
            _currentMusicName = fileName;
          });

          await _saveCurrentConfig(silent: true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Müzik yüklendi: $fileName')),
                  ],
                ),
                backgroundColor: AppColors.greenSuccess,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçilirken hata oluştu: $e'),
            backgroundColor: AppColors.redMissed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFile = false);
      }
    }
  }

  Future<void> _showSaveDialog() async {
    final hasMusic = _currentMusicPath != null && File(_currentMusicPath!).existsSync();
    if (!hasMusic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir müzik dosyası seçin veya yükleyin.'),
          backgroundColor: AppColors.redMissed,
        ),
      );
      return;
    }

    final originalExt = _currentMusicPath!.split('.').last;
    final defaultBaseName = (_currentMusicName != null && _currentMusicName!.isNotEmpty)
        ? _currentMusicName!.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        : 'fircalama_muzigi';

    final nameController = TextEditingController(text: defaultBaseName);
    final nameFocusNode = FocusNode();
    String? selectedDirectory;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Çekmece Göstergesi
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Başlık
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.save_as_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Müziği Kaydet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'Kaydedilecek dosya ismini ve depolama yerini belirleyin:',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        // Dosya İsmi Girişi (Otomatik odaklı & dokunulduğunda klavye açılır)
                        TextField(
                          controller: nameController,
                          focusNode: nameFocusNode,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          enableInteractiveSelection: true,
                          onTap: () {
                            nameFocusNode.requestFocus();
                          },
                          decoration: InputDecoration(
                            labelText: 'Dosya İsmi',
                            hintText: 'Örn: cocuk_fircalama_muzigi',
                            suffixText: '.$originalExt',
                            prefixIcon: const Icon(Icons.drive_file_rename_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kayıt Yeri / Klasör Seçimi
                        Text(
                          'Kayıt Konumu:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedDirectory != null
                                      ? selectedDirectory!
                                      : 'Uygulama Belgeleri (Varsayılan)',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  nameFocusNode.unfocus();
                                  final pickedDir = await FilePicker.platform.getDirectoryPath(
                                    dialogTitle: 'Müziğin Kaydedileceği Klasörü Seçin',
                                  );
                                  if (pickedDir != null) {
                                    setSheetState(() {
                                      selectedDirectory = pickedDir;
                                    });
                                  }
                                },
                                child: const Text('Değiştir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Butonlar
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  nameFocusNode.unfocus();
                                  Navigator.pop(sheetCtx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Vazgeç'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  nameFocusNode.unfocus();
                                  final cleanName = nameController.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                                  final finalFileName = cleanName.isNotEmpty ? '$cleanName.$originalExt' : 'fircalama_muzigi.$originalExt';

                                  Navigator.pop(sheetCtx);
                                  await _performSaveWithLocationAndName(
                                    targetDirectory: selectedDirectory,
                                    fileName: finalFileName,
                                    baseName: cleanName.isNotEmpty ? cleanName : 'fircalama_muzigi',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameFocusNode.dispose();
    nameController.dispose();
  }

  Future<void> _performSaveWithLocationAndName({
    String? targetDirectory,
    required String fileName,
    required String baseName,
  }) async {
    setState(() => _isSaving = true);
    try {
      String savedPath;

      if (targetDirectory != null && Directory(targetDirectory).existsSync()) {
        final destPath = '$targetDirectory/$fileName';
        final destFile = File(destPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        await File(_currentMusicPath!).copy(destPath);
        savedPath = destPath;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${appDir.path}/brushing_music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        final destPath = '${musicDir.path}/$fileName';
        final destFile = File(destPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        await File(_currentMusicPath!).copy(destPath);
        savedPath = destPath;
      }

      setState(() {
        _currentMusicPath = savedPath;
        _currentMusicName = fileName;
      });

      final updatedConfig = MusicConfig(
        musicPath: savedPath,
        musicName: fileName,
        alertType: _alertType,
        singleTtsText: _singleTtsController.text.trim().isNotEmpty
            ? _singleTtsController.text.trim()
            : 'Diğer bölgeye geçin',
        intervalTtsTexts: _intervalControllers.map((c) => c.text.trim()).toList(),
        useSeparateTexts: _useSeparateTexts,
        musicVolume: _musicVolume,
        alertVolume: _alertVolume,
      );

      await _musicService.saveConfig(updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Müzik "$fileName" adıyla başarıyla kaydedildi!'),
                ),
              ],
            ),
            backgroundColor: AppColors.greenSuccess,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Paylaş',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(savedPath)], text: 'FunBrush Fırçalama Müziği: $fileName');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt sırasında hata oluştu: $e'),
            backgroundColor: AppColors.redMissed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveCurrentConfig({bool silent = false}) async {
    setState(() => _isSaving = true);
    try {
      final updatedConfig = MusicConfig(
        musicPath: _currentMusicPath,
        musicName: _currentMusicName,
        alertType: _alertType,
        singleTtsText: _singleTtsController.text.trim().isNotEmpty
            ? _singleTtsController.text.trim()
            : 'Diğer bölgeye geçin',
        intervalTtsTexts: _intervalControllers.map((c) => c.text.trim()).toList(),
        useSeparateTexts: _useSeparateTexts,
        musicVolume: _musicVolume,
        alertVolume: _alertVolume,
      );

      await _musicService.saveConfig(updatedConfig);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Müzik ve 30 sn uyarı ayarları başarıyla kaydedildi!'),
              ],
            ),
            backgroundColor: AppColors.greenSuccess,
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt hatası: $e'),
            backgroundColor: AppColors.redMissed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? AppColors.cardDark : Colors.white);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner(
              title: 'Müzik Düzenleme',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Açıklama Başlığı
                    Text(
                      'Fırçalama Müziği ve 30 Sn Uyarıları',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2 dakikalık standart diş fırçalama süresi 4 çeyreğe bölünür. Müziğiniz çalarken her 30 saniyede bir seçtiğiniz ses ile yönlendirilirsiniz.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 1. KART: MÜZİK YÜKLEME ALANI
                    _buildMusicUploadCard(cardColor, isDark),
                    const SizedBox(height: 16),

                    // 2. KART: 30 SN UYARI TÜRÜ (BİP / METİN SESLENDİRME)
                    _buildAlertTypeCard(cardColor, isDark),
                    const SizedBox(height: 16),

                    // 3. KART: 4 ÇEYREK ZAMAN ÇİZELGESİ (TIMELINE)
                    _buildTimelineCard(cardColor, isDark),
                    const SizedBox(height: 16),

                    // 4. KART: CANLI ÖNİZLEME & OYNATICI
                    _buildPreviewPlayerCard(cardColor, isDark),
                    const SizedBox(height: 24),

                    // KAYDET BUTONU
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _showSaveDialog(),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Kaydediliyor...' : 'Fırçalama Müziğini Kaydet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Müzik Dosyası Yükleme Kartı
  Widget _buildMusicUploadCard(Color cardColor, bool isDark) {
    final hasMusic = _currentMusicPath != null && File(_currentMusicPath!).existsSync();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasMusic ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Arka Plan Müziği',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      hasMusic ? 'Müzik hazır ve yüklendi' : 'Telefonunuzdan müzik yükleyin',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasMusic ? AppColors.greenSuccess : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasMusic) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.audio_file_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentMusicName ?? 'Özel Müzik',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Fırçalama müziği olarak etkin',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.change_circle_outlined, color: AppColors.primary),
                    tooltip: 'Farklı Müzik Seç',
                    onPressed: _isLoadingFile ? null : _pickMusicFile,
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _isLoadingFile ? null : _pickMusicFile,
              icon: _isLoadingFile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_isLoadingFile ? 'Yükleniyor...' : 'Cihazdan Müzik Seç (.mp3 / .m4a / .wav)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 2. 30 Saniye Uyarı Türü Kartı
  Widget _buildAlertTypeCard(Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Her 30 Sn\'de Eklenecek Uyarı',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '30, 60, 90 ve 120. saniyelerde 4 defa çalar',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seçenekler: Bip vs TTS
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  title: '🔔 Bip / Melodi',
                  subtitle: 'Kısa uyarı sesi',
                  isSelected: _alertType == AlertSoundType.beep,
                  onTap: () {
                    setState(() => _alertType = AlertSoundType.beep);
                    _saveCurrentConfig(silent: true);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(
                  title: '🗣️ Metin Seslendirme',
                  subtitle: 'Konuşan rehber (TTS)',
                  isSelected: _alertType == AlertSoundType.tts,
                  onTap: () {
                    setState(() => _alertType = AlertSoundType.tts);
                    _saveCurrentConfig(silent: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Eğer TTS seçildiyse metin giriş alanları
          if (_alertType == AlertSoundType.tts) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aralık Mesajları:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '4 Bölgeye Ayrı Metin',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    Switch.adaptive(
                      value: _useSeparateTexts,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _useSeparateTexts = val);
                        _saveCurrentConfig(silent: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_useSeparateTexts) ...[
              // Tek metin girişi
              TextFormField(
                controller: _singleTtsController,
                decoration: InputDecoration(
                  labelText: 'Seslendirilecek Metin (Her 30 sn)',
                  hintText: 'Örn: Diğer bölgeye geçin',
                  prefixIcon: const Icon(Icons.record_voice_over),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: AppColors.primary),
                    tooltip: 'Sesi Test Et',
                    onPressed: () => _musicService.testCue(0),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _saveCurrentConfig(silent: true),
              ),
            ] else ...[
              // 4 çeyrek için ayrı metinler
              for (int i = 0; i < 4; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _intervalControllers[i],
                    decoration: InputDecoration(
                      labelText: '${(i + 1) * 30}. Saniye (${i + 1}. Çeyrek)',
                      prefixIcon: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 20),
                        tooltip: 'Test Et',
                        onPressed: () => _musicService.testCue(i),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => _saveCurrentConfig(silent: true),
                  ),
                ),
              ],
            ],
          ] else ...[
            // Bip sesi seçildiğinde test butonu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '30, 60, 90 ve 120. saniyelerde net bip/çan uyarısı verilir.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _musicService.testCue(0),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Bip Dinle', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 3. 4 Çeyrek Zaman Çizelgesi (Timeline) Kartı
  Widget _buildTimelineCard(Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timeline_rounded, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. 2 Dakikalık Fırçalama Akışı',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Her 30 saniyede bir tetiklenen 4 bölge',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4 Çeyrek Rozetleri
          Row(
            children: [
              _buildQuarterBadge(1, '30s', '1. Çeyrek\n(Sağ Üst)', isDark),
              const SizedBox(width: 6),
              _buildQuarterBadge(2, '60s', '2. Çeyrek\n(Sol Üst)', isDark),
              const SizedBox(width: 6),
              _buildQuarterBadge(3, '90s', '3. Çeyrek\n(Sol Alt)', isDark),
              const SizedBox(width: 6),
              _buildQuarterBadge(4, '120s', '4. Çeyrek\n(Sağ Alt 🏁)', isDark),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Canlı Önizleme & Oynatıcı Kartı
  Widget _buildPreviewPlayerCard(Color cardColor, bool isDark) {
    final hasMusic = _currentMusicPath != null && File(_currentMusicPath!).existsSync();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_outline, color: Color(0xFF059669), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4. Canlı Önizleme & Dinleme',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Müzik çalarken 30 saniye aralıklarını dinleyin',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasMusic) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Önizleme yapabilmek için yukarıdan bir müzik dosyası seçin.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            // Zaman ve İlerleme Çubuğu
            ValueListenableBuilder<Duration>(
              valueListenable: _musicService.positionNotifier,
              builder: (context, pos, _) {
                final total = _musicService.totalDuration;
                final maxSec = total.inSeconds > 0 ? total.inSeconds.toDouble() : 120.0;
                final curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

                return Column(
                  children: [
                    Slider(
                      value: curSec,
                      min: 0,
                      max: maxSec,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        _musicService.seekPreview(Duration(seconds: val.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(pos), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(
                            total.inSeconds > 0 ? _formatDuration(total) : '02:00',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Oynat / Duraklat Butonları
            ValueListenableBuilder<bool>(
              valueListenable: _musicService.isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.replay_10_rounded),
                      tooltip: '10 Saniye Geri',
                      onPressed: () {
                        final cur = _musicService.currentPosition;
                        final target = cur - const Duration(seconds: 10);
                        _musicService.seekPreview(target < Duration.zero ? Duration.zero : target);
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 42,
                        color: Colors.white,
                        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: () {
                          if (isPlaying) {
                            _musicService.pausePreview();
                          } else {
                            _musicService.playPreview();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.forward_10_rounded),
                      tooltip: '10 Saniye İleri',
                      onPressed: () {
                        final cur = _musicService.currentPosition;
                        _musicService.seekPreview(cur + const Duration(seconds: 10));
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Hızlı 30 sn Atlayıcılar (Test Kolaylığı)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuickJumpButton('25s (1. Bip)', 25),
                const SizedBox(width: 6),
                _buildQuickJumpButton('55s (2. Bip)', 55),
                const SizedBox(width: 6),
                _buildQuickJumpButton('85s (3. Bip)', 85),
                const SizedBox(width: 6),
                _buildQuickJumpButton('115s (Son)', 115),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickJumpButton(String label, int seconds) {
    return InkWell(
      onTap: () {
        _musicService.seekPreview(Duration(seconds: seconds));
        if (!_musicService.isPlaying) {
          _musicService.playPreview();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildQuarterBadge(int quarter, String time, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.purple,
              child: Text(
                '$quarter',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppColors.primary : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
