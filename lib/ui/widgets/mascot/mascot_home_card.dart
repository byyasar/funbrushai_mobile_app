import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/mascot_provider.dart';
import '../../../data/models/mascot_model.dart';
import '../../screens/mascot_wardrobe_screen.dart';
import 'mascot_view.dart';

class MascotHomeCard extends StatelessWidget {
  final String? userName;
  final String? userAvatarUrl;

  const MascotHomeCard({
    super.key,
    this.userName,
    this.userAvatarUrl,
  });

  void _showNameDialog(BuildContext context, MascotProvider provider) {
    final controller = TextEditingController(text: provider.mascot.customName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diş Dostuna İsim Ver'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Karakter İsmi',
            hintText: 'Örn: Pırıl, Köpük, Şimşek...',
          ),
          maxLength: 15,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setCustomName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MascotProvider>();
    final mascot = provider.mascot;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    switch (mascot.mood) {
      case MascotMood.sparkling:
        statusColor = Colors.amber;
        break;
      case MascotMood.happy:
        statusColor = const Color(0xFF4CAF50);
        break;
      case MascotMood.sleepy:
        statusColor = Colors.orange;
        break;
      case MascotMood.dirtyMicrobes:
        statusColor = Colors.redAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? Colors.grey.shade900 : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mascot.mood == MascotMood.dirtyMicrobes
              ? Colors.redAccent.withOpacity(0.4)
              : AppColors.primary.withOpacity(0.15),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık & İsim & Seviye
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    mascot.customName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showNameDialog(context, provider),
                    tooltip: 'İsmi Değiştir',
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Sv. ${mascot.level}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Orta Bölüm: Karakter Görünümü + Durum Barları
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sol: Zıplayan Sevimli Karakter
              MascotView(
                mascot: mascot,
                size: 110,
                onTap: () {
                  // Karakter dokununca konuşsun veya gardıroba gitsin
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${mascot.customName}: "${mascot.moodMessage}"'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),

              // Sağ: Tamagotchi İstatistikleri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Durum Mesajı Balonu
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        mascot.moodMessage,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mutluluk Barı
                    _buildStatBar(
                      context,
                      label: 'Mutluluk',
                      icon: '💖',
                      value: mascot.happiness / 100.0,
                      color: Colors.pinkAccent,
                    ),
                    const SizedBox(height: 6),

                    // Hijyen / Temizlik Barı
                    _buildStatBar(
                      context,
                      label: 'Temizlik',
                      icon: '🧼',
                      value: mascot.hygiene / 100.0,
                      color: Colors.lightBlueAccent,
                    ),
                    const SizedBox(height: 6),

                    // Günlük Fırçalama Serisi
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '${mascot.streakDays} Gün Seri',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Alt Aksiyon Butonu (Gardırop)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MascotWardrobeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.checkroom, size: 20),
              label: const Text('Gardırop & Aksesuarlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(
    BuildContext context, {
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
                Text(icon, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
            Text(
              '%${(value * 100).toInt()}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
