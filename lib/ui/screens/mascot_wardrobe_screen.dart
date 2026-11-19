import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/mascot_provider.dart';
import '../../data/models/mascot_item.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';
import '../widgets/mascot/mascot_view.dart';

class MascotWardrobeScreen extends StatefulWidget {
  final String? brushId;
  final String? userName;

  const MascotWardrobeScreen({
    super.key,
    this.brushId,
    this.userName,
  });

  @override
  State<MascotWardrobeScreen> createState() => _MascotWardrobeScreenState();
}

class _MascotWardrobeScreenState extends State<MascotWardrobeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _syncMascotWithLatestRecords();
  }

  Future<void> _syncMascotWithLatestRecords() async {
    try {
      if (widget.brushId != null && widget.brushId!.isNotEmpty) {
        final records = await SupabaseService().getAllRecordsForBrush(widget.brushId!);
        if (mounted && records.isNotEmpty) {
          context.read<MascotProvider>().syncWithBrushingRecords(records, brushId: widget.brushId);
        }
      } else {
        final records = await SupabaseService().getAllRecordsForDevice();
        if (mounted && records.isNotEmpty) {
          context.read<MascotProvider>().syncWithBrushingRecords(records);
        }
      }
    } catch (e) {
      debugPrint('Error syncing mascot in wardrobe: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MascotProvider>();
    final mascot = provider.getMascotForBrush(widget.brushId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              title: widget.userName != null && widget.userName!.isNotEmpty
                  ? '${mascot.customName} (${widget.userName})'
                  : '${mascot.customName} Odası',
              showBackButton: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      // Büyük Karakter Önizleme Alanı
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? (isDark ? Colors.grey.shade900 : Colors.white),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            MascotView(
                              mascot: mascot,
                              size: 170,
                              showSpeechBubble: true,
                            ),
                            const SizedBox(height: 12),
                            // Seviye ve XP İlerleme
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Seviye ${mascot.level}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '(${mascot.xpInCurrentLevel}/200 XP)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: mascot.levelProgress,
                                minHeight: 8,
                                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Mutluluk & Temizlik Barları
                            Row(
                              children: [
                                Expanded(
                                  child: _buildWardrobeStatBar(
                                    label: 'Mutluluk',
                                    icon: '💖',
                                    value: mascot.happiness / 100.0,
                                    color: Colors.pinkAccent,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildWardrobeStatBar(
                                    label: 'Temizlik',
                                    icon: '🧼',
                                    value: mascot.hygiene / 100.0,
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Kategori TabBar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.primary,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.black87,
                          tabs: const [
                            Tab(icon: Icon(Icons.face, size: 18), text: 'Şapkalar'),
                            Tab(icon: Icon(Icons.checkroom, size: 18), text: 'Kostümler'),
                            Tab(icon: Icon(Icons.brush, size: 18), text: 'Aletler'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // TabView Eşya Izgarası
                      SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildItemGrid(context, provider, MascotItemCategory.hat),
                            _buildItemGrid(context, provider, MascotItemCategory.costume),
                            _buildItemGrid(context, provider, MascotItemCategory.tool),
                          ],
                        ),
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

  Widget _buildItemGrid(
    BuildContext context,
    MascotProvider provider,
    MascotItemCategory category,
  ) {
    final items = MascotItem.allItems.where((i) => i.category == category).toList();
    final mascot = provider.getMascotForBrush(widget.brushId);

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnlocked = mascot.unlockedItemIds.contains(item.id);
        
        bool isEquipped = false;
        switch (category) {
          case MascotItemCategory.hat:
            isEquipped = mascot.equippedHatId == item.id;
            break;
          case MascotItemCategory.costume:
            isEquipped = mascot.equippedCostumeId == item.id;
            break;
          case MascotItemCategory.tool:
            isEquipped = mascot.equippedToolId == item.id;
            break;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEquipped
                  ? AppColors.primary
                  : Colors.grey.withOpacity(0.2),
              width: isEquipped ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.icon, style: const TextStyle(fontSize: 26)),
                  if (isEquipped)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Kuşanıldı',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (!isUnlocked)
                    const Icon(Icons.lock, size: 18, color: Colors.grey),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked
                        ? item.description
                        : (item.requiredStreak > 0
                            ? '${item.requiredStreak} Gün Seri Gerekli'
                            : '${item.requiredXp} XP Gerekli'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUnlocked ? Colors.grey : Colors.orange,
                      fontWeight: isUnlocked ? FontWeight.normal : FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped
                        ? Colors.grey.shade400
                        : (isUnlocked ? AppColors.primary : Colors.grey.shade300),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isUnlocked
                      ? () {
                          provider.equipItem(item, brushId: widget.brushId);
                        }
                      : null,
                  child: Text(
                    isEquipped ? 'Takılı' : (isUnlocked ? 'Kuşan' : 'Kilitli'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWardrobeStatBar({
    required String label,
    required String icon,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(
              '%${(value * 100).toInt()}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
