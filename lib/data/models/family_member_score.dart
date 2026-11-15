import 'social_user.dart';

class FamilyMemberScore {
  final SocialUser user;
  final int weeklyBrushingCount;
  final int weeklyScore;
  final int streakDays;
  final int rank;

  const FamilyMemberScore({
    required this.user,
    required this.weeklyBrushingCount,
    required this.weeklyScore,
    required this.streakDays,
    this.rank = 1,
  });

  bool get isLeader => rank == 1 && weeklyScore > 0;
}
