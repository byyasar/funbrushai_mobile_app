import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class DayDetailDrawer extends StatelessWidget {
  final int day;
  final Map<String, dynamic> data;

  const DayDetailDrawer({
    super.key,
    required this.day,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final morning = data['morning'] ?? {};
    final evening = data['evening'] ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppColors.primaryLight.withOpacity(0.5),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40), // Spacer for centering
              Text(
                'Gün $day',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSessionInfo(context, 'Sabah', Icons.wb_sunny, morning),
              _buildSessionInfo(context, 'Akşam', Icons.nightlight_round, evening),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Notlar:',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['notes'] ?? 'Bu gün için not yok.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(BuildContext context, String label, IconData icon, Map<String, dynamic> sessionData) {
    final status = sessionData['status'] ?? 'missed';
    final time = sessionData['time'] ?? '-';
    final duration = sessionData['duration'] ?? '0:00';
    
    final color = status == 'success' 
        ? (Theme.of(context).brightness == Brightness.dark ? AppColors.successDark : AppColors.successBright)
        : AppColors.missedRed;

    return Column(
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 8),
        Text(
          time,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
       Text(
          'Süre: $duration',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
