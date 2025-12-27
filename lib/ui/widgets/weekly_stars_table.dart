import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

class WeeklyStarsTable extends StatelessWidget {
  final DateTime month;
  final Map<int, Map<String, dynamic>> monthData;
  final String userName;
  final String? avatarUrl;

  const WeeklyStarsTable({
    super.key,
    required this.month,
    required this.monthData,
    required this.userName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final periods = _calculatePeriods();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Başarı Panosu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                onPressed: () => _generateAndSharePdf(context, periods),
                icon: const Icon(Icons.share, color: AppColors.primary),
                tooltip: 'PDF Paylaş',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade200),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2.5),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Dönem', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: Text('Yıldızlar', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color))),
                  ),
                ],
              ),
              ...periods.map((period) => _buildPeriodRow(context, period)),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildPeriodRow(BuildContext context, _PeriodData period) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${period.startDay}-${period.endDay} ${DateFormat('MMMM', 'tr').format(month)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: period.dailyStatus.map((status) {
              IconData icon;
              Color color;
              
              switch (status) {
                case StarStatus.full:
                  icon = Icons.star;
                  color = Colors.amber;
                  break;
                case StarStatus.partial:
                  icon = Icons.star_border;
                  color = Colors.amber;
                  break;
                case StarStatus.none:
                  icon = Icons.star_border;
                  color = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<_PeriodData> _calculatePeriods() {
    final periods = <_PeriodData>[];
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    
    int currentDay = 1;
    while (currentDay <= daysInMonth) {
      int endDay = currentDay + 4; // 5-day period
      if (endDay > daysInMonth) endDay = daysInMonth;

      final dailyStatus = <StarStatus>[];

      for (int i = currentDay; i <= endDay; i++) {
        final dayData = monthData[i];
        StarStatus status = StarStatus.none;
        
        if (dayData != null) {
          final bool morningSuccess = dayData['morning']['status'] == 'success';
          final bool eveningSuccess = dayData['evening']['status'] == 'success';

          if (morningSuccess && eveningSuccess) {
            status = StarStatus.full;
          } else if (morningSuccess || eveningSuccess) {
            status = StarStatus.partial;
          }
        }
        dailyStatus.add(status);
      }
      
      periods.add(_PeriodData(
        startDay: currentDay,
        endDay: endDay,
        dailyStatus: dailyStatus,
      ));

      currentDay = endDay + 1;
    }
    return periods;
  }

  Future<void> _generateAndSharePdf(BuildContext context, List<_PeriodData> periods) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    
    pw.ImageProvider? profileImage;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      try {
        profileImage = await networkImage(avatarUrl!);
      } catch (e) {
        debugPrint('Error loading profile image for PDF: $e');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Başarı Panosu', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                    pw.Text(DateFormat('MMMM yyyy', 'tr').format(month), style: pw.TextStyle(font: font, fontSize: 18)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  if (profileImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(right: 10),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        image: pw.DecorationImage(
                          image: profileImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                  pw.Text('Kullanıcı: $userName', style: pw.TextStyle(font: font, fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Dönem', style: pw.TextStyle(font: boldFont))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text('Yıldızlar', style: pw.TextStyle(font: boldFont)))),
                    ],
                  ),
                  ...periods.map((period) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${period.startDay}-${period.endDay} ${DateFormat('MMMM', 'tr').format(month)}', style: pw.TextStyle(font: font)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Center(
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: period.dailyStatus.map((status) {
                                return _PdfStar(status: status);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('* Siyah Çerçeve: Hiç fırçalama yapılmadı.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
              pw.Text('* Sarı Çerçeve: Sadece sabah veya akşam fırçalama yapıldı.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
              pw.Text('* Dolu Sarı Yıldız: Hem sabah hem akşam fırçalama yapıldı.', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'basari_panosu.pdf');
  }
}

enum StarStatus { none, partial, full }

class _PdfStar extends pw.StatelessWidget {
  final StarStatus status;

  _PdfStar({required this.status});

  @override
  pw.Widget build(pw.Context context) {
    const starSvg = 'M 12 0 L 14.5 9 L 24 9 L 16 14 L 19 23 L 12 17 L 5 23 L 8 14 L 0 9 L 9.5 9 Z';
    
    PdfColor fillColor;
    PdfColor strokeColor;

    switch (status) {
      case StarStatus.full:
        fillColor = PdfColors.amber;
        strokeColor = PdfColors.amber;
        break;
      case StarStatus.partial:
        fillColor = PdfColors.white; // None/Transparent
        strokeColor = PdfColors.amber;
        break;
      case StarStatus.none:
        fillColor = PdfColors.white; // None/Transparent
        strokeColor = PdfColors.black;
        break;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.SvgImage(
        svg: '<svg viewBox="0 0 24 24"><path d="$starSvg" fill="${fillColor.toHex()}" stroke="${strokeColor.toHex()}" stroke-width="1"/></svg>',
        width: 16,
        height: 16,
      ),
    );
  }
}

class _PeriodData {
  final int startDay;
  final int endDay;
  final List<StarStatus> dailyStatus;

  _PeriodData({required this.startDay, required this.endDay, required this.dailyStatus});
}
