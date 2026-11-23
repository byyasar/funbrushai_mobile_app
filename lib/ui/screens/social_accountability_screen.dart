import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/brushing_record.dart';
import '../../data/models/social_user.dart';
import '../../data/services/supabase_service.dart';
import 'friend_history_screen.dart';

import '../widgets/app_banner.dart';

class SocialAccountabilityScreen extends StatefulWidget {
  const SocialAccountabilityScreen({super.key});

  @override
  State<SocialAccountabilityScreen> createState() => _SocialAccountabilityScreenState();
}

class _SocialAccountabilityScreenState extends State<SocialAccountabilityScreen> {
  List<SocialUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await SupabaseService().getSocialUsers();
    if (mounted) {
      setState(() {
        _users = users;
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
            AppBanner(
              title: 'Sorumluluk Duvarı',
              showBackButton: true,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildUserGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1, // Mobile first, maybe 2 for tablet but 1 is safe for detailed cards
        mainAxisSpacing: 16,
        childAspectRatio: 2, // Adjust based on card content
      ),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_users[index]);
      },
    );
  }

  Widget _buildUserCard(SocialUser user) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendHistoryScreen(
              user: user,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2), // Border width
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                    onBackgroundImageError: user.avatarUrl.isNotEmpty
                        ? (_, __) {
                            // Handle error silently, child will be shown
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Son 7 gün',
                      style: TextStyle(
                        color: AppColors.secondaryTextLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendHistoryScreen(
                          user: user,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMiniCalendar(user),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar(SocialUser user) {
    return FutureBuilder<List<BrushingRecord>>(
      future: SupabaseService().getLast7DaysRecords(user.brushId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final records = snapshot.data!;
        final now = DateTime.now();
        // Generate last 7 days including today
        final last7Days = List.generate(7, (index) {
          return now.subtract(Duration(days: 6 - index));
        });

        final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.map((date) {
                // weekday is 1-7 (Mon-Sun), array index 0-6
                final dayName = days[date.weekday - 1];
                return Expanded(
                  child: Center(
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryTextLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.map((date) {
                // Check if there is a record for this date
                // Simple check: match year, month, day
                final hasRecord = records.any((r) {
                  final rDate = r.createdAt.toLocal();
                  return rDate.year == date.year && 
                         rDate.month == date.month && 
                         rDate.day == date.day;
                });

                // Logic: 
                // - If hasRecord -> Success (Green check)
                // - If no record AND date is in the past -> Missed (Red cancel)
                // - If no record AND date is today -> Neutral/Pending (Grey)
                
                // Note: "date is in the past" means strictly before today's start of day
                final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

                Color bgColor;
                Color iconColor;
                IconData icon;

                if (hasRecord) {
                  bgColor = AppColors.greenSuccess.withOpacity(0.2);
                  iconColor = AppColors.greenSuccess;
                  icon = Icons.check_circle;
                } else if (isPast) {
                  bgColor = AppColors.redMissed.withOpacity(0.2);
                  iconColor = AppColors.redMissed;
                  icon = Icons.cancel;
                } else {
                  // Today or future (though we only generate up to today)
                  bgColor = Colors.grey.withOpacity(0.2);
                  iconColor = Colors.transparent;
                  icon = Icons.circle; // Placeholder
                }

                return Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: hasRecord || isPast ? Icon(
                        icon,
                        color: iconColor,
                        size: 16,
                      ) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
