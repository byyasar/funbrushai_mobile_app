import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';

class ToothbrushLifespanCard extends StatelessWidget {
  final Toothbrush toothbrush;

  const ToothbrushLifespanCard({
    super.key,
    required this.toothbrush,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStartDate = toothbrush.renewalDate ?? toothbrush.startDate;
    final daysUsed = DateTime.now().difference(effectiveStartDate).inDays;
    final totalDays = toothbrush.renewalPeriodDays;
    final remainingDays = totalDays - daysUsed;
    final progress = (daysUsed / totalDays).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    // Determine color based on usage
    Color progressColor = AppColors.primary;
    if (progress > 0.9) {
      progressColor = Colors.red;
    } else if (progress > 0.75) {
      progressColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircularProgressBar(
            progress: progress,
            color: progressColor,
            size: 40, // Reduced size further
            child: Text(
              '$percentage%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10, // Reduced font size
              ),
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          Text(
            toothbrush.userName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12, // Reduced font size
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            remainingDays > 0
                ? '$remainingDays gün kaldı'
                : '${remainingDays.abs()} gün geçti',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: remainingDays > 0 ? Colors.grey[600] : Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 10, // Reduced font size
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CircularProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final Widget? child;

  const _CircularProgressBar({
    required this.progress,
    required this.color,
    required this.size,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade100),
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
          ),
          CircularProgressIndicator(
            value: progress,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}
