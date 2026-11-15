import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/models/mascot_model.dart';

class MascotPainter extends CustomPainter {
  final MascotMood mood;
  final String hatId;
  final String costumeId;
  final String toolId;
  final double animationValue; // 0.0 - 1.0 (zıplama veya nefes alma)

  MascotPainter({
    required this.mood,
    required this.hatId,
    required this.costumeId,
    required this.toolId,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + (sin(animationValue * 2 * pi) * 4));
    final width = size.width * 0.72;
    final height = size.height * 0.65;

    // 1. KOSTÜM / PELERİN KATMANI (Arka plan)
    _drawBackCostume(canvas, center, width, height);

    // 2. DİŞ GÖVDESİ (Ana Katman)
    _drawToothBody(canvas, center, width, height);

    // 3. KOSTÜM ÖN KATMANI (Zırh veya önlük)
    _drawFrontCostume(canvas, center, width, height);

    // 4. YÜZ İFADESİ (Gözler, allık, ağız)
    _drawFace(canvas, center, width, height);

    // 5. MİKROPLAR VEYA IŞILTILAR
    if (mood == MascotMood.dirtyMicrobes) {
      _drawMicrobes(canvas, center, width, height);
    } else if (mood == MascotMood.sparkling) {
      _drawSparkles(canvas, center, width, height);
    }

    // 6. ŞAPKA KATMANI
    _drawHat(canvas, center, width, height);

    // 7. EL ALETİ / FIRÇA KATMANI
    _drawTool(canvas, center, width, height);
  }

  void _drawBackCostume(Canvas canvas, Offset center, double w, double h) {
    if (costumeId == 'costume_cape') {
      // Kahraman Pelerini
      final paint = Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(center.dx - w * 0.4, center.dy - h * 0.1)
        ..quadraticBezierTo(center.dx - w * 0.65, center.dy + h * 0.6, center.dx - w * 0.5, center.dy + h * 0.65)
        ..quadraticBezierTo(center.dx, center.dy + h * 0.5, center.dx + w * 0.5, center.dy + h * 0.65)
        ..quadraticBezierTo(center.dx + w * 0.65, center.dy + h * 0.6, center.dx + w * 0.4, center.dy - h * 0.1)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawToothBody(Canvas canvas, Offset center, double w, double h) {
    // Diş Gövdesi Yolu (Klasik Sevimli İki Tepeli Diş Formu)
    final toothPath = Path();
    final top = center.dy - h * 0.5;
    final bottom = center.dy + h * 0.5;
    final left = center.dx - w * 0.5;
    final right = center.dx + w * 0.5;

    // Üst sol tepe
    toothPath.moveTo(center.dx, top + h * 0.12);
    toothPath.cubicTo(
      center.dx - w * 0.25, top - h * 0.08,
      left, top + h * 0.05,
      left + w * 0.05, center.dy - h * 0.05,
    );
    // Sol kök
    toothPath.cubicTo(
      left, center.dy + h * 0.35,
      left + w * 0.2, bottom,
      center.dx - w * 0.12, bottom,
    );
    // Kökler arası vadi
    toothPath.quadraticBezierTo(
      center.dx, center.dy + h * 0.2,
      center.dx + w * 0.12, bottom,
    );
    // Sağ kök
    toothPath.cubicTo(
      right - w * 0.2, bottom,
      right, center.dy + h * 0.35,
      right - w * 0.05, center.dy - h * 0.05,
    );
    // Üst sağ tepe
    toothPath.cubicTo(
      right, top + h * 0.05,
      center.dx + w * 0.25, top - h * 0.08,
      center.dx, top + h * 0.12,
    );
    toothPath.close();

    // Gövde Rengi & Gölgesi
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: mood == MascotMood.dirtyMicrobes
            ? [const Color(0xFFF1F5E0), const Color(0xFFD6DEC0)] // Kirli soluk sarımsı
            : [Colors.white, const Color(0xFFE8F4FD)],          // Parlak temiz beyaz-mavi
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));

    // Dış gölge
    canvas.drawShadow(toothPath, Colors.black.withOpacity(0.12), 10, true);
    // Gövde dolgusu
    canvas.drawPath(toothPath, bodyPaint);

    // Pürüzsüz dış kontür çizgisi
    final strokePaint = Paint()
      ..color = mood == MascotMood.dirtyMicrobes ? const Color(0xFF8CA06E) : const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(toothPath, strokePaint);
  }

  void _drawFrontCostume(Canvas canvas, Offset center, double w, double h) {
    if (costumeId == 'costume_armor') {
      // Köpük Zırhı Göğüs Plakası
      final paint = Paint()
        ..color = const Color(0xFF4FC3F7)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = const Color(0xFF0288D1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final path = Path()
        ..moveTo(center.dx - w * 0.28, center.dy + h * 0.05)
        ..lineTo(center.dx + w * 0.28, center.dy + h * 0.05)
        ..lineTo(center.dx + w * 0.2, center.dy + h * 0.25)
        ..lineTo(center.dx, center.dy + h * 0.35)
        ..lineTo(center.dx - w * 0.2, center.dy + h * 0.25)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, border);

      // Zırh amblemi (Yıldız)
      final starPaint = Paint()..color = Colors.amber;
      canvas.drawCircle(Offset(center.dx, center.dy + h * 0.18), 6, starPaint);
    } else if (costumeId == 'costume_doctor') {
      // Doktor Önlüğü / Steteskop
      final coatPaint = Paint()
        ..color = const Color(0xFFECEFF1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(center.dx, center.dy + h * 0.05),
        Offset(center.dx, center.dy + h * 0.28),
        coatPaint,
      );
      // Minik kırmızı haç
      final redCross = Paint()
        ..color = Colors.red
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(center.dx + w * 0.18, center.dy + h * 0.1), Offset(center.dx + w * 0.18, center.dy + h * 0.18), redCross);
      canvas.drawLine(Offset(center.dx + w * 0.14, center.dy + h * 0.14), Offset(center.dx + w * 0.22, center.dy + h * 0.14), redCross);
    }
  }

  void _drawFace(Canvas canvas, Offset center, double w, double h) {
    final leftEye = Offset(center.dx - w * 0.18, center.dy - h * 0.08);
    final rightEye = Offset(center.dx + w * 0.18, center.dy - h * 0.08);

    // 1. ALLIKLAR (Cheeks)
    final blushPaint = Paint()
      ..color = const Color(0xFFFF8A80).withOpacity(mood == MascotMood.dirtyMicrobes ? 0.3 : 0.65);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - w * 0.28, center.dy), width: w * 0.12, height: h * 0.07),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + w * 0.28, center.dy), width: w * 0.12, height: h * 0.07),
      blushPaint,
    );

    // 2. GÖZLER
    if (mood == MascotMood.sleepy) {
      // Yarı kapalı uykulu göz çizgileri
      final eyePaint = Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: leftEye, width: 14, height: 10), pi, pi, false, eyePaint);
      canvas.drawArc(Rect.fromCenter(center: rightEye, width: 14, height: 10), pi, pi, false, eyePaint);
    } else if (mood == MascotMood.dirtyMicrobes) {
      // Üzgün şaşkın gözler (> < veya yuvarlak endişeli)
      final eyePaint = Paint()..color = const Color(0xFF37474F);
      canvas.drawCircle(leftEye, 5.5, eyePaint);
      canvas.drawCircle(rightEye, 5.5, eyePaint);
      // Gözyaşı damlası
      final tearPaint = Paint()..color = Colors.lightBlueAccent;
      canvas.drawCircle(Offset(leftEye.dx - 2, leftEye.dy + 8), 3, tearPaint);
    } else {
      // Neşeli sevimli gözler + parıltı noktaları
      final eyePaint = Paint()..color = const Color(0xFF212121);
      canvas.drawCircle(leftEye, 7, eyePaint);
      canvas.drawCircle(rightEye, 7, eyePaint);

      final shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(leftEye.dx - 2.5, leftEye.dy - 2.5), 2.5, shinePaint);
      canvas.drawCircle(Offset(rightEye.dx - 2.5, rightEye.dy - 2.5), 2.5, shinePaint);
    }

    // 3. AĞIZ
    final mouthPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final mouthCenter = Offset(center.dx, center.dy + h * 0.04);

    if (mood == MascotMood.dirtyMicrobes) {
      // Dalgalı / Üzgün ağız
      final mouthPath = Path()
        ..moveTo(mouthCenter.dx - 12, mouthCenter.dy + 4)
        ..quadraticBezierTo(mouthCenter.dx - 6, mouthCenter.dy - 4, mouthCenter.dx, mouthCenter.dy)
        ..quadraticBezierTo(mouthCenter.dx + 6, mouthCenter.dy + 4, mouthCenter.dx + 12, mouthCenter.dy - 2);
      canvas.drawPath(mouthPath, mouthPaint);
    } else if (mood == MascotMood.sleepy) {
      // Küçük uykulu ağız 'o'
      final yawnPaint = Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromCenter(center: mouthCenter, width: 8, height: 10), yawnPaint);
    } else {
      // Büyük gülen ağız
      final smilePath = Path()
        ..moveTo(mouthCenter.dx - 14, mouthCenter.dy)
        ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + 14, mouthCenter.dx + 14, mouthCenter.dy);
      canvas.drawPath(smilePath, mouthPaint);
    }
  }

  void _drawMicrobes(Canvas canvas, Offset center, double w, double h) {
    // Sevimli küçük yeşil bakteri mikropları
    final microbeOffsets = [
      Offset(center.dx - w * 0.32, center.dy + h * 0.22),
      Offset(center.dx + w * 0.26, center.dy - h * 0.26),
      Offset(center.dx + w * 0.30, center.dy + h * 0.15),
    ];

    for (int i = 0; i < microbeOffsets.length; i++) {
      final pos = microbeOffsets[i];
      final mPaint = Paint()..color = i == 1 ? const Color(0xFF7CB342) : const Color(0xFF8E24AA);
      // Mikrop gövdesi
      canvas.drawCircle(pos, 8, mPaint);
      // Minik dikenler
      final spikePaint = Paint()..color = mPaint.color..strokeWidth = 2;
      canvas.drawLine(pos, Offset(pos.dx - 6, pos.dy - 6), spikePaint);
      canvas.drawLine(pos, Offset(pos.dx + 6, pos.dy - 6), spikePaint);
      canvas.drawLine(pos, Offset(pos.dx, pos.dy + 7), spikePaint);
      // Minik çarpı gözler
      final eyePaint = Paint()..color = Colors.white..strokeWidth = 1.2;
      canvas.drawLine(Offset(pos.dx - 3, pos.dy - 2), Offset(pos.dx - 1, pos.dy), eyePaint);
      canvas.drawLine(Offset(pos.dx + 1, pos.dy - 2), Offset(pos.dx + 3, pos.dy), eyePaint);
    }
  }

  void _drawSparkles(Canvas canvas, Offset center, double w, double h) {
    // Yıldızlar ve Işıltı Efektleri
    final starOffsets = [
      Offset(center.dx - w * 0.42, center.dy - h * 0.2),
      Offset(center.dx + w * 0.42, center.dy - h * 0.15),
      Offset(center.dx - w * 0.35, center.dy + h * 0.3),
      Offset(center.dx + w * 0.38, center.dy + h * 0.28),
    ];

    final starPaint = Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.fill;

    for (final pos in starOffsets) {
      final starPath = Path()
        ..moveTo(pos.dx, pos.dy - 8)
        ..lineTo(pos.dx + 2.5, pos.dy - 2.5)
        ..lineTo(pos.dx + 8, pos.dy)
        ..lineTo(pos.dx + 2.5, pos.dy + 2.5)
        ..lineTo(pos.dx, pos.dy + 8)
        ..lineTo(pos.dx - 2.5, pos.dy + 2.5)
        ..lineTo(pos.dx - 8, pos.dy)
        ..lineTo(pos.dx - 2.5, pos.dy - 2.5)
        ..close();
      canvas.drawPath(starPath, starPaint);
    }
  }

  void _drawHat(Canvas canvas, Offset center, double w, double h) {
    final hatBase = Offset(center.dx, center.dy - h * 0.45);

    if (hatId == 'hat_crown') {
      // Altın Taç
      final crownPaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = const Color(0xFFFF6F00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path()
        ..moveTo(hatBase.dx - w * 0.28, hatBase.dy + 8)
        ..lineTo(hatBase.dx - w * 0.28, hatBase.dy - 16)
        ..lineTo(hatBase.dx - w * 0.12, hatBase.dy - 4)
        ..lineTo(hatBase.dx, hatBase.dy - 24)
        ..lineTo(hatBase.dx + w * 0.12, hatBase.dy - 4)
        ..lineTo(hatBase.dx + w * 0.28, hatBase.dy - 16)
        ..lineTo(hatBase.dx + w * 0.28, hatBase.dy + 8)
        ..close();
      canvas.drawPath(path, crownPaint);
      canvas.drawPath(path, border);

      // Yakut taşları
      final gemPaint = Paint()..color = const Color(0xFFD81B60);
      canvas.drawCircle(Offset(hatBase.dx, hatBase.dy - 18), 3.5, gemPaint);
      canvas.drawCircle(Offset(hatBase.dx - w * 0.25, hatBase.dy - 12), 2.5, gemPaint);
      canvas.drawCircle(Offset(hatBase.dx + w * 0.25, hatBase.dy - 12), 2.5, gemPaint);
    } else if (hatId == 'hat_cap') {
      // Spor Şapka (Cap)
      final capPaint = Paint()..color = const Color(0xFF1E88E5);
      final path = Path()
        ..addArc(Rect.fromCenter(center: Offset(hatBase.dx, hatBase.dy + 2), width: w * 0.55, height: h * 0.35), pi, pi);
      canvas.drawPath(path, capPaint);
      // Şapka Siperliği
      final visor = Path()
        ..moveTo(hatBase.dx + w * 0.1, hatBase.dy + 2)
        ..quadraticBezierTo(hatBase.dx + w * 0.42, hatBase.dy + 2, hatBase.dx + w * 0.45, hatBase.dy + 8)
        ..lineTo(hatBase.dx + w * 0.1, hatBase.dy + 4)
        ..close();
      canvas.drawPath(visor, Paint()..color = const Color(0xFF1565C0));
    } else if (hatId == 'hat_grad') {
      // Mezuniyet Kepi
      final gradPaint = Paint()..color = const Color(0xFF263238);
      final rhomb = Path()
        ..moveTo(hatBase.dx, hatBase.dy - 18)
        ..lineTo(hatBase.dx + w * 0.32, hatBase.dy - 8)
        ..lineTo(hatBase.dx, hatBase.dy + 2)
        ..lineTo(hatBase.dx - w * 0.32, hatBase.dy - 8)
        ..close();
      canvas.drawPath(rhomb, gradPaint);
      // Püskül
      final tasselPaint = Paint()..color = Colors.amber..strokeWidth = 2;
      canvas.drawLine(Offset(hatBase.dx, hatBase.dy - 8), Offset(hatBase.dx + w * 0.28, hatBase.dy + 4), tasselPaint);
      canvas.drawCircle(Offset(hatBase.dx + w * 0.28, hatBase.dy + 4), 3, Paint()..color = Colors.amber);
    } else if (hatId == 'hat_pirate') {
      // Korsan Şapkası
      final piratePaint = Paint()..color = const Color(0xFF212121);
      final pPath = Path()
        ..moveTo(hatBase.dx - w * 0.35, hatBase.dy + 6)
        ..quadraticBezierTo(hatBase.dx, hatBase.dy - 22, hatBase.dx + w * 0.35, hatBase.dy + 6)
        ..lineTo(hatBase.dx + w * 0.2, hatBase.dy + 6)
        ..quadraticBezierTo(hatBase.dx, hatBase.dy - 6, hatBase.dx - w * 0.2, hatBase.dy + 6)
        ..close();
      canvas.drawPath(pPath, piratePaint);
      // Kafatası amblemi
      canvas.drawCircle(Offset(hatBase.dx, hatBase.dy - 6), 3, Paint()..color = Colors.white);
    }
  }

  void _drawTool(Canvas canvas, Offset center, double w, double h) {
    final toolPos = Offset(center.dx + w * 0.42, center.dy + h * 0.1);

    if (toolId == 'tool_sparkle_brush') {
      // Sevimli Diş Fırçası
      final handlePaint = Paint()
        ..color = const Color(0xFF00B0FF)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(toolPos, Offset(toolPos.dx + 12, toolPos.dy - 28), handlePaint);

      // Fırça kılları
      final bristlePaint = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(toolPos.dx + 4, toolPos.dy - 34, 14, 8), const Radius.circular(3)),
        bristlePaint,
      );
      // Macun köpüğü
      canvas.drawCircle(Offset(toolPos.dx + 11, toolPos.dy - 34), 3.5, Paint()..color = Colors.lightBlueAccent);
    } else if (toolId == 'tool_magic_wand') {
      // Sihirli Asa
      final wandPaint = Paint()
        ..color = const Color(0xFF8E24AA)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(toolPos, Offset(toolPos.dx + 10, toolPos.dy - 26), wandPaint);
      // Asa ucu yıldızı
      canvas.drawCircle(Offset(toolPos.dx + 10, toolPos.dy - 26), 5, Paint()..color = Colors.amber);
    }
  }

  @override
  bool shouldRepaint(covariant MascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.hatId != hatId ||
        oldDelegate.costumeId != costumeId ||
        oldDelegate.toolId != toolId ||
        oldDelegate.animationValue != animationValue;
  }
}
