import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/dental_appointment_service.dart';
import '../../data/models/dental_appointment.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import 'dental_appointment_form_screen.dart';

class DentalAppointmentDetailScreen extends StatefulWidget {
  final DentalAppointment appointment;
  final List<Toothbrush> familyBrushes;

  const DentalAppointmentDetailScreen({
    super.key,
    required this.appointment,
    required this.familyBrushes,
  });

  @override
  State<DentalAppointmentDetailScreen> createState() =>
      _DentalAppointmentDetailScreenState();
}

class _DentalAppointmentDetailScreenState
    extends State<DentalAppointmentDetailScreen> {
  late DentalAppointment _appointment;
  bool _isGeneratingPdf = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
  }

  Future<void> _toggleChecklistItem(int index) async {
    final updatedList = List<AppointmentChecklistItem>.from(_appointment.checklist);
    updatedList[index] = updatedList[index].copyWith(
      done: !updatedList[index].done,
    );
    final updated = _appointment.copyWith(checklist: updatedList);
    setState(() {
      _appointment = updated;
      _hasChanges = true;
    });
    await DentalAppointmentService().saveAppointment(updated);
  }

  Future<void> _editAppointment() async {
    final result = await Navigator.of(context).push<DentalAppointment>(
      MaterialPageRoute(
        builder: (_) => DentalAppointmentFormScreen(
          familyBrushes: widget.familyBrushes,
          existingAppointment: _appointment,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _appointment = result;
        _hasChanges = true;
      });
    }
  }

  Future<void> _toggleCompletedOrScheduleNext() async {
    if (!_appointment.isCompleted) {
      final updated = _appointment.copyWith(isCompleted: true);
      await DentalAppointmentService().saveAppointment(updated);
      if (mounted) {
        setState(() {
          _appointment = updated;
          _hasChanges = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Randevu tamamlandı olarak işaretlendi!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // 6 ay sonrası için yeni randevu planlama formunu aç
      final nextDate = DateTime(
        _appointment.dateTime.year,
        _appointment.dateTime.month + 6,
        _appointment.dateTime.day,
        _appointment.dateTime.hour,
        _appointment.dateTime.minute,
      );
      final result = await Navigator.of(context).push<DentalAppointment>(
        MaterialPageRoute(
          builder: (_) => DentalAppointmentFormScreen(
            familyBrushes: widget.familyBrushes,
            initialMemberName: _appointment.memberName,
            initialBrushId: _appointment.brushId,
            initialDateTime: nextDate,
          ),
        ),
      );
      if (result != null && mounted) {
        _hasChanges = true;
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _deleteAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Randevuyu Sil'),
        content: const Text('Bu diş randevusunu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redMissed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DentalAppointmentService().deleteAppointment(_appointment.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  String _asciiSafe(String input) {
    return input
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }

  Future<void> _shareBrushingPdfReport() async {
    setState(() => _isGeneratingPdf = true);
    try {
      int totalBrushings30d = 0;
      int avgDurationSec = 0;
      int activeDays = 0;

      if (_appointment.brushId != null && _appointment.brushId!.isNotEmpty) {
        final records = await SupabaseService()
            .getAllRecordsForBrush(_appointment.brushId!);
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final recent =
            records.where((r) => r.createdAt.isAfter(cutoff)).toList();
        totalBrushings30d = recent.length;
        if (recent.isNotEmpty) {
          final totalDur =
              recent.fold<int>(0, (sum, r) => sum + r.durationSeconds);
          avgDurationSec = (totalDur / recent.length).round();
          final uniqueDays = recent
              .map((r) =>
                  '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}')
              .toSet();
          activeDays = uniqueDays.length;
        }
      }

      final pdf = pw.Document();
      final dateStr =
          DateFormat('dd.MM.yyyy HH:mm').format(_appointment.dateTime);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#2979FF'),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'FunBrushBoxApp - Dis Hekimi Ozeti',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Hasta: ${_asciiSafe(_appointment.memberName)}',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          dateStr,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Randevu Bilgileri',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(),
                  pw.Text('Islem Turu: ${_asciiSafe(_appointment.appointmentType)}'),
                  pw.SizedBox(height: 4),
                  pw.Text('Dis Hekimi: ${_asciiSafe(_appointment.doctorName)}'),
                  pw.SizedBox(height: 4),
                  pw.Text('Klinik: ${_asciiSafe(_appointment.clinicName)}'),
                  if (_appointment.notes.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Notlar: ${_asciiSafe(_appointment.notes)}'),
                  ],
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'Son 30 Gunluk Fircalama Performansi',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfMetricBox('Toplam Fircalama', '$totalBrushings30d kez'),
                      _pdfMetricBox('Aktif Gun', '$activeDays / 30 gun'),
                      _pdfMetricBox('Ort. Sure', '$avgDurationSec sn'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final safeName =
          _asciiSafe(_appointment.memberName).replaceAll(' ', '_').toLowerCase();
      final file = File('${dir.path}/fircalama_raporu_$safeName.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '${_appointment.memberName} - Diş Randevusu & Son 30 Gün Fırçalama Raporu',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF raporu oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  pw.Widget _pdfMetricBox(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;
    final doneCount = _appointment.checklist.where((c) => c.done).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Randevu Detayı',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Düzenle',
              onPressed: _editAppointment,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Özet Başlık Kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _appointment.isUpcoming
                              ? AppColors.primary.withValues(alpha: 0.14)
                              : AppColors.greenSuccess.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _appointment.isUpcoming
                              ? '● ${_appointment.countdownLabel}'
                              : '✓ Tamamlandı',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _appointment.isUpcoming
                                ? AppColors.primary
                                : AppColors.greenSuccess,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '👤 ${_appointment.memberName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${_appointment.typeEmoji} ${_appointment.appointmentType}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appointment.doctorName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          context,
                          label: 'Tarih',
                          value: DateFormat('d MMM yyyy', 'tr')
                              .format(_appointment.dateTime),
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoTile(
                          context,
                          label: 'Saat',
                          value: DateFormat('HH:mm').format(_appointment.dateTime),
                          icon: Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _appointment.clinicName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (_appointment.address.isNotEmpty)
                              Text(
                                _appointment.address,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: mutedColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Randevu Öncesi Hazırlık Kontrol Listesi
            if (_appointment.checklist.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📋 Randevu Öncesi Hazırlık',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$doneCount/${_appointment.checklist.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_appointment.checklist.length, (idx) {
                      final item = _appointment.checklist[idx];
                      return InkWell(
                        onTap: () => _toggleChecklistItem(idx),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: item.done
                                      ? AppColors.greenSuccess
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: item.done
                                        ? AppColors.greenSuccess
                                        : mutedColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: item.done
                                    ? const Icon(Icons.check,
                                        size: 15, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: item.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.done ? mutedColor : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Hekimle Fırçalama PDF Raporu Paylaş Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📄 Hekimle Fırçalama Raporu Paylaş',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_appointment.memberName} için son 30 günlük fırçalama özetini PDF oluştur',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isGeneratingPdf ? null : _shareBrushingPdfReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isGeneratingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'PDF Paylaş',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notlar ve Hatırlatıcılar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📝 Notlar & Hatırlatıcılar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _appointment.notes.isNotEmpty
                        ? _appointment.notes
                        : 'Henüz not eklenmedi.',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._appointment.reminders.map(
                        (r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🔔 $r',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ),
                      if (_appointment.syncWithCalendar)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.greenSuccess.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '📆 Takvimde',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greenSuccess,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Alt Aksiyonlar
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _toggleCompletedOrScheduleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(_appointment.isCompleted
                        ? Icons.event_repeat_rounded
                        : Icons.check_circle_outline_rounded),
                    label: Text(
                      _appointment.isCompleted
                          ? '6 Ay Sonra Planla'
                          : 'Tamamlandı İşaretle',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteAppointment,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.redMissed,
                      side: const BorderSide(color: AppColors.redMissed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'Sil',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withValues(alpha: 0.6)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: mutedColor)),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
