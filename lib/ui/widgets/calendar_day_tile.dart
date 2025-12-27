import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CalendarDayTile extends StatelessWidget {
  final int day;
  final String morningStatus; // 'success', 'missed', 'none'
  final String eveningStatus; // 'success', 'missed', 'none'
  final bool hasJournalEntry;
  final VoidCallback onTap;

  const CalendarDayTile({
    super.key,
    required this.day,
    required this.morningStatus,
    required this.eveningStatus,
    required this.hasJournalEntry,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return AppColors.successBright;
      case 'missed':
        return AppColors.missedRed;
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryLight.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.toString(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.primaryLight : AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny,
                        size: 14,
                        color: _getStatusColor(morningStatus),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.nightlight_round,
                        size: 14,
                        color: _getStatusColor(eveningStatus),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasJournalEntry)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.edit,
                  size: 10,
                  color: isDarkMode ? AppColors.primaryLight.withOpacity(0.7) : AppColors.primary.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
