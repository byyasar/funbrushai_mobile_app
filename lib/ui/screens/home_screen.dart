import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';
import '../widgets/toothbrush_lifespan_card.dart';
import 'social_accountability_screen.dart';
import 'toothbrush_card_screen.dart';
import 'settings_screen.dart';
import 'family_leaderboard_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Toothbrush> _toothbrushes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToothbrushes();
  }

  Future<void> _loadToothbrushes() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final brushes = await SupabaseService().getAllToothbrushes();
      if (mounted) {
        setState(() {
          _toothbrushes = brushes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading toothbrushes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onRefreshNeeded: _loadToothbrushes,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              onMenuPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadToothbrushes,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst Bölüm: Kullanıcılar ve Diş Fırçaları Durumları
                      if (_isLoading)
                        const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_toothbrushes.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final activeBrushes = _toothbrushes.where((b) => b.isActive).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionHeaderCard(
                                  context,
                                  title: 'Kullanıcılar',
                                  subtitle: 'Fırça durumları ve kullanım süreleri',
                                  icon: Icons.people_alt_rounded,
                                  color: const Color(0xFF2563EB),
                                  count: activeBrushes.length,
                                ),
                                const SizedBox(height: 12),
                                _buildToothbrushGrid(activeBrushes),
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Alt Bölüm: Navigasyon Kartları
                      SizedBox(
                        height: 74,
                        child: _buildNavigationCard(
                          context,
                          title: 'Diş Fırçalarım',
                          subtitle: 'Fırça durumları ve kullanım ömürleri',
                          icon: Icons.cleaning_services_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ToothbrushCardScreen(),
                              ),
                            ).then((_) => _loadToothbrushes());
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 74,
                        child: _buildNavigationCard(
                          context,
                          title: 'Sorumluluk Duvarı',
                          subtitle: 'Fırçalama fotoğrafları ve geçmiş',
                          icon: Icons.photo_library_rounded,
                          color: const Color(0xFF7C3AED),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SocialAccountabilityScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 74,
                        child: _buildNavigationCard(
                          context,
                          title: 'Aile Skor Tablosu',
                          subtitle: 'Haftanın Hijyen Lideri 👑',
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFD97706),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FamilyLeaderboardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 74,
                        child: _buildNavigationCard(
                          context,
                          title: 'Kullanıcı Avatarını Düzenle',
                          subtitle: 'Profil fotoğrafı ve avatar seçimi',
                          icon: Icons.account_circle_rounded,
                          color: const Color(0xFF059669),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ).then((_) => _loadToothbrushes());
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // İkon Kutusu
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                // Metin Alanı
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.secondaryTextDark
                                : AppColors.secondaryTextLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ Ok Rozeti
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isDark ? Colors.white70 : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    int? count,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // Sol İkon Kutusu
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          // Başlık ve Alt Başlık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryTextLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Sağ Rozet (Varsa)
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '$count Kullanıcı',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToothbrushGrid(List<Toothbrush> brushes) {
    if (brushes.isEmpty) {
      return const SizedBox.shrink();
    }

    if (brushes.length == 4) {
      // Aile 4 kişi olduğunda 2x2 düzeni
      final row1 = brushes.take(2).toList();
      final row2 = brushes.skip(2).take(2).toList();

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row1.map((brush) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: ToothbrushLifespanCard(
                  toothbrush: brush,
                  width: 155,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row2.map((brush) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: ToothbrushLifespanCard(
                  toothbrush: brush,
                  width: 155,
                ),
              );
            }).toList(),
          ),
        ],
      );
    } else if (brushes.length <= 3) {
      // 1, 2 veya 3 kişi tek satır
      final cardWidth = brushes.length == 3 ? 106.0 : (brushes.length == 2 ? 155.0 : 180.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: brushes.map((brush) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: ToothbrushLifespanCard(
              toothbrush: brush,
              width: cardWidth,
            ),
          );
        }).toList(),
      );
    } else {
      // 5 veya daha fazla fırça: 3 + 2 düzeni
      final row1 = brushes.take(3).toList();
      final row2 = brushes.skip(3).take(3).toList();

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row1.map((brush) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ToothbrushLifespanCard(
                  toothbrush: brush,
                  width: 106,
                ),
              );
            }).toList(),
          ),
          if (row2.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row2.map((brush) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ToothbrushLifespanCard(
                    toothbrush: brush,
                    width: 106,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      );
    }
  }
}
