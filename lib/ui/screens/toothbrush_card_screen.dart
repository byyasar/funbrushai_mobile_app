import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/tts_save_service.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';

import '../widgets/app_banner.dart';

class ToothbrushCardScreen extends StatefulWidget {
  const ToothbrushCardScreen({super.key});

  @override
  State<ToothbrushCardScreen> createState() => _ToothbrushCardScreenState();
}

class _ToothbrushCardScreenState extends State<ToothbrushCardScreen> {
  bool _isLoading = true;
  List<Toothbrush> _toothbrushes = [];
  final FlutterTts _flutterTts = FlutterTts();
  String? _speakingBrushId;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadData();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('tr-TR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingBrushId = null);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _speakingBrushId = null);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _speakingBrushId = null);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadData() async {
    final toothbrushes = await SupabaseService().getAllToothbrushes();
    final activeToothbrushes = toothbrushes.where((b) => b.isActive).toList();
    if (mounted) {
      setState(() {
        _toothbrushes = activeToothbrushes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(title: 'Diş Fırçalarım', showBackButton: true),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _toothbrushes.isEmpty
                  ? const Center(child: Text('No toothbrushes found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _toothbrushes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildToothbrushCard(_toothbrushes[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToothbrushCard(Toothbrush toothbrush) {
    final now = DateTime.now();
    // Use renewalDate as the effective start date if available, otherwise startDate
    final effectiveStartDate = toothbrush.renewalDate ?? toothbrush.startDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final usageDays = now.difference(effectiveStartDate).inDays;
    // Total days is the renewal period
    final totalDays = toothbrush.renewalPeriodDays;
    final progress = (totalDays > 0)
        ? (usageDays / totalDays).clamp(0.0, 1.0)
        : 0.0;
    final isSpeakingThis = _speakingBrushId == toothbrush.id;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${toothbrush.fircaId} - ${toothbrush.userName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      // color: AppColors.textLight, // Removed for theme
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Başlangıç: ${DateFormat('dd.MM.yyyy').format(effectiveStartDate)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextLight,
                    ),
                  ),
                ],
              ),
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditNameDialog(toothbrush),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Theme.of(context).cardColor
                            : Colors.white,
                        foregroundColor: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text('Düzenle'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: isDark
                                    ? const ColorScheme.dark(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: AppColors.cardDark,
                                        onSurface: Colors.white,
                                      )
                                    : const ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                dialogBackgroundColor: isDark
                                    ? AppColors.backgroundDark
                                    : Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          try {
                            await SupabaseService().updateToothbrushRenewalDate(
                              toothbrush.id,
                              picked,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Yenilenme tarihi güncellendi'),
                                ),
                              );
                              _loadData(); // Refresh list
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.primaryDark
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        elevation: 4,
                        shadowColor:
                            (isDark ? AppColors.primaryDark : AppColors.primary)
                                .withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: const Text('Sıfırla'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? AppColors.redMissed : AppColors.primary,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '%${(progress * 100).toInt()} Kullanıldı',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalDays - usageDays} gün kaldı',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // TTS, Save MP3 and Share Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSpeakingThis
                      ? null
                      : () => _speakWelcome(toothbrush),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSpeakingThis
                        ? AppColors.primary.withOpacity(0.6)
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    elevation: isSpeakingThis ? 0 : 2,
                  ),
                  icon: isSpeakingThis
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.volume_up, size: 18),
                  label: Text(
                    isSpeakingThis ? 'Söyleniyor...' : 'Hoşgeldin Söyle',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveWelcomeAsMp3(toothbrush),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successBright,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text(
                          'MP3 Kaydet',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareWelcomeText(toothbrush.userName),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'Paylaş',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _speakWelcome(Toothbrush toothbrush) async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() => _speakingBrushId = toothbrush.id);
    }
    final text = 'Hoşgeldin ${toothbrush.userName}';
    await _flutterTts.speak(text);
  }

  Future<void> _saveWelcomeAsMp3(Toothbrush toothbrush) async {
    final text = 'Hoşgeldin ${toothbrush.userName}';
    final rawBrushName = toothbrush.fircaId.trim().isNotEmpty
        ? toothbrush.fircaId.trim()
        : toothbrush.userName.trim();
    final safeBrushName = rawBrushName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    try {
      final filePath = await TtsSaveService.saveTtsToMp3(
        text: text,
        fileName: '$safeBrushName.mp3',
        language: 'tr-TR',
        pitch: 1.0,
        speechRate: 0.5,
      );

      if (context.mounted) {
        if (filePath != null) {
          final fileName = filePath.split('/').last;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.greenSuccess),
                  SizedBox(width: 8),
                  Expanded(child: Text('MP3 Kaydedildi')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dosya Adı: $fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Konum: $filePath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'Kapat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _shareMp3File(filePath);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'Paylaş',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('MP3 kaydedilemedi'),
              backgroundColor: AppColors.redMissed,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.redMissed,
          ),
        );
      }
    }
  }

  Future<void> _shareMp3File(String filePath) async {
    await Share.shareXFiles([
      XFile(filePath),
    ], subject: 'Hoşgeldin Ses Dosyası');
  }

  Future<void> _shareWelcomeText(String userName) async {
    final text =
        'Hoşgeldin $userName! 🪥\n\nFunBrush AI - Diş Fırçala Takip Uygulaması';
    await Share.share(text, subject: 'Hoşgeldin Mesajı');
  }

  Future<void> _showEditNameDialog(Toothbrush toothbrush) async {
    final TextEditingController controller = TextEditingController(
      text: toothbrush.userName,
    );

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kullanıcı Adını Düzenle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı Adı',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    await SupabaseService().updateToothbrushUserName(
                      toothbrush.id,
                      newName,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kullanıcı adı güncellendi'),
                        ),
                      );
                      _loadData();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
