import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/family_member_score.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';
import 'friend_history_screen.dart';

class FamilyLeaderboardScreen extends StatefulWidget {
  const FamilyLeaderboardScreen({super.key});

  @override
  State<FamilyLeaderboardScreen> createState() => _FamilyLeaderboardScreenState();
}

class _FamilyLeaderboardScreenState extends State<FamilyLeaderboardScreen> {
  List<FamilyMemberScore> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final data = await SupabaseService().getWeeklyFamilyLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner(
              title: 'Aile Skor Tablosu',
              showBackButton: true,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _leaderboard.isEmpty
                      ? const Center(child: Text('Henüz fırçalama kaydı bulunamadı.'))
                      : RefreshIndicator(
                          onRefresh: _loadLeaderboard,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Podyum (1., 2., 3. Sıralar)
                                _buildPodium(context),
                                const SizedBox(height: 20),

                                // Puanlama Bilgi Kartı
                                _buildInfoCard(context, isDark),
                                const SizedBox(height: 20),

                                // Tüm Aile Sıralaması Başlığı
                                Row(
                                  children: [
                                    const Icon(Icons.leaderboard, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tüm Aile Sıralaması',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Sıralama Listesi
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _leaderboard.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    return _buildRankCard(context, _leaderboard[index]);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(BuildContext context) {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();

    final first = _leaderboard.isNotEmpty ? _leaderboard[0] : null;
    final second = _leaderboard.length > 1 ? _leaderboard[1] : null;
    final third = _leaderboard.length > 2 ? _leaderboard[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            Colors.amber.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Şampiyon Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('👑', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'HAFTANIN HİJYEN LİDERİ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.amber,
                ),
              ),
              SizedBox(width: 8),
              Text('👑', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 24),

          // 3'lü Podyum Sütunları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2. Sıra (Gümüş)
              if (second != null)
                Expanded(
                  child: _buildPodiumColumn(
                    context,
                    item: second,
                    rankNumber: '2',
                    badge: '🥈',
                    height: 95,
                    color: Colors.blueGrey.shade300,
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              const SizedBox(width: 8),

              // 1. Sıra (Altın - Lider)
              if (first != null)
                Expanded(
                  child: _buildPodiumColumn(
                    context,
                    item: first,
                    rankNumber: '1',
                    badge: '👑',
                    height: 125,
                    color: Colors.amber,
                    isChampion: true,
                  ),
                ),

              const SizedBox(width: 8),

              // 3. Sıra (Bronz)
              if (third != null)
                Expanded(
                  child: _buildPodiumColumn(
                    context,
                    item: third,
                    rankNumber: '3',
                    badge: '🥉',
                    height: 75,
                    color: Colors.brown.shade300,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(
    BuildContext context, {
    required FamilyMemberScore item,
    required String rankNumber,
    required String badge,
    required double height,
    required Color color,
    bool isChampion = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendHistoryScreen(user: item.user),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rozet & Avatar
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(isChampion ? 3 : 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isChampion ? 3 : 2),
                    boxShadow: isChampion
                        ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: isChampion ? 28 : 22,
                    backgroundImage: item.user.avatarUrl.isNotEmpty
                        ? NetworkImage(item.user.avatarUrl)
                        : null,
                    onBackgroundImageError: item.user.avatarUrl.isNotEmpty ? (_, __) {} : null,
                    child: item.user.avatarUrl.isEmpty
                        ? Text(item.user.name.isNotEmpty ? item.user.name[0].toUpperCase() : '?')
                        : null,
                  ),
                ),
                Positioned(
                  top: -14,
                  child: Text(badge, style: TextStyle(fontSize: isChampion ? 20 : 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // İsim
          Text(
            item.user.name,
            style: TextStyle(
              fontSize: isChampion ? 13 : 11,
              fontWeight: FontWeight.bold,
              color: isChampion ? Colors.amber : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Puan
          Text(
            '${item.weeklyScore} Puan',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          // Podyum Basamağı Blok
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.85), color.withOpacity(0.45)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                rankNumber,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, FamilyMemberScore score) {
    Widget rankIcon;

    switch (score.rank) {
      case 1:
        rankIcon = const Text('👑', style: TextStyle(fontSize: 20));
        break;
      case 2:
        rankIcon = const Text('🥈', style: TextStyle(fontSize: 18));
        break;
      case 3:
        rankIcon = const Text('🥉', style: TextStyle(fontSize: 18));
        break;
      default:
        rankIcon = Text(
          '#${score.rank}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendHistoryScreen(user: score.user),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: score.isLeader ? Colors.amber.withOpacity(0.5) : Colors.transparent,
            width: score.isLeader ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Sıra Sütunu
            SizedBox(
              width: 32,
              child: Center(child: rankIcon),
            ),
            const SizedBox(width: 8),

            // Profil Avatarı
            CircleAvatar(
              radius: 20,
              backgroundImage: score.user.avatarUrl.isNotEmpty
                  ? NetworkImage(score.user.avatarUrl)
                  : null,
              onBackgroundImageError: score.user.avatarUrl.isNotEmpty ? (_, __) {} : null,
              child: score.user.avatarUrl.isEmpty
                  ? Text(score.user.name.isNotEmpty ? score.user.name[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 12),

            // İsim ve Alt Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          score.user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: score.isLeader ? Colors.amber : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (score.isLeader) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Lider',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '🪥 ${score.weeklyBrushingCount} Fırçalama',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '🔥 ${score.streakDays} Gün Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Haftalık Puan Rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: score.isLeader
                    ? Colors.amber.withOpacity(0.18)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${score.weeklyScore} P',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: score.isLeader ? Colors.amber : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Puanlama: Her fırçalama +15 Puan, 2 dk süresi +5 Puan, Günde 2 kez fırçalama +10 Bonus Puan kazandırır.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
