import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';
import '../../data/models/social_user.dart';
import '../screens/friend_history_screen.dart';

class ToothbrushLifespanCard extends StatelessWidget {
  final Toothbrush toothbrush;
  final double? width;

  const ToothbrushLifespanCard({
    super.key,
    required this.toothbrush,
    this.width,
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

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final socialUser = SocialUser(
          id: toothbrush.id,
          name: toothbrush.userName,
          avatarUrl: toothbrush.avatar ?? '',
          brushId: toothbrush.fircaId,
          mascotName: toothbrush.mascotName,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendHistoryScreen(user: socialUser),
          ),
        );
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _CircularProgressBar(
                  progress: progress,
                  color: progressColor,
                  size: 54,
                  strokeWidth: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(3.5),
                    child: CircleAvatar(
                      backgroundImage: (toothbrush.avatar != null && toothbrush.avatar!.isNotEmpty)
                          ? NetworkImage(toothbrush.avatar!)
                          : null,
                      onBackgroundImageError: (toothbrush.avatar != null && toothbrush.avatar!.isNotEmpty)
                          ? (_, __) {}
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: (toothbrush.avatar == null || toothbrush.avatar!.isEmpty)
                          ? Text(
                              toothbrush.userName.isNotEmpty ? toothbrush.userName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              toothbrush.userName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              remainingDays > 0
                  ? '$remainingDays gün'
                  : '${remainingDays.abs()} g geçti',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: remainingDays > 0 ? Colors.grey[600] : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
  );
  }
}

class _CircularProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const _CircularProgressBar({
    required this.progress,
    required this.color,
    required this.size,
    this.strokeWidth = 3.5,
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
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
          ),
          CircularProgressIndicator(
            value: progress,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}
