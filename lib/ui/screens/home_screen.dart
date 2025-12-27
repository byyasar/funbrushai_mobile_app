import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';
import '../widgets/toothbrush_lifespan_card.dart';
import 'social_accountability_screen.dart';
import 'toothbrush_card_screen.dart';
import 'settings_screen.dart';
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
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              onMenuPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              onSettingsPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 80, // Compact height for Row layout
                        child: _buildNavigationCard(
                          context,
                          title: 'Diş Fırçalarım',
                          icon: Icons.format_list_bulleted,
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ToothbrushCardScreen(),
                              ),
                            ).then((_) => _loadToothbrushes());
                          },
                        ),
                      ),
                      const SizedBox(height: 12), // Reduced spacing
                      SizedBox(
                        height: 80, // Compact height for Row layout
                        child: _buildNavigationCard(
                          context,
                          title: 'Sorumluluk Duvarı',
                          icon: Icons.people_outline,
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SocialAccountabilityScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_toothbrushes.isNotEmpty) ...[
                        Text(
                          'Diş Fırçaları Kullanım Durumları',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                // color: AppColors.textLight, // Removed to use theme color
                              ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2, // Increased aspect ratio for shorter cards
                          ),
                          itemCount: _toothbrushes.length,
                          itemBuilder: (context, index) {
                            return ToothbrushLifespanCard(
                              toothbrush: _toothbrushes[index],
                            );
                          },
                        ),
                    ],
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

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).cardTheme.color ?? Colors.white,
                Theme.of(context).cardTheme.color?.withOpacity(0.9) ?? Colors.grey.shade50,
              ],
            ),
          ),
          child: Row( // Changed to Row for better vertical space usage
            children: [
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
