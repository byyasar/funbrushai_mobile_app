import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';

import '../widgets/app_banner.dart';

class ToothbrushCardScreen extends StatefulWidget {
  const ToothbrushCardScreen({super.key});

  @override
  State<ToothbrushCardScreen> createState() => _ToothbrushCardScreenState();
}

class _ToothbrushCardScreenState extends State<ToothbrushCardScreen> {
  bool _isLoading = true;
  List<Toothbrush> _toothbrushes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final toothbrushes = await SupabaseService().getAllToothbrushes();
    if (mounted) {
      setState(() {
        _toothbrushes = toothbrushes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              title: 'Diş Fırçalarım',
              showBackButton: true,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _toothbrushes.isEmpty
                      ? const Center(child: Text('No toothbrushes found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _toothbrushes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildToothbrushCard(_toothbrushes[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToothbrushCard(Toothbrush toothbrush) {
    final now = DateTime.now();
    // Use renewalDate as the effective start date if available, otherwise startDate
    final effectiveStartDate = toothbrush.renewalDate ?? toothbrush.startDate;
    
    // Calculate expiration based on effective start date + renewal period
    final expirationDate = toothbrush.expirationDate ??
        effectiveStartDate.add(Duration(days: toothbrush.renewalPeriodDays));

    final usageDays = now.difference(effectiveStartDate).inDays;
    // Total days is the renewal period
    final totalDays = toothbrush.renewalPeriodDays;
    final progress = (totalDays > 0) ? (usageDays / totalDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${toothbrush.fircaId} - ${toothbrush.userName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Başlangıç: ${DateFormat('dd.MM.yyyy').format(effectiveStartDate)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextLight,
                    ),
                  ),
                ],
              ),
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditNameDialog(toothbrush),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text('Düzenle'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.textLight,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        
                        if (picked != null) {
                          try {
                            await SupabaseService().updateToothbrushRenewalDate(toothbrush.id, picked);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Yenilenme tarihi güncellendi')),
                              );
                              _loadData(); // Refresh list
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: const Text('Sıfırla'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.backgroundLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? AppColors.redMissed : AppColors.primary,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '%${(progress * 100).toInt()} Kullanıldı',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalDays - usageDays} gün kaldı',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(Toothbrush toothbrush) async {
    final TextEditingController controller = TextEditingController(text: toothbrush.userName);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kullanıcı Adını Düzenle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı Adı',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    await SupabaseService().updateToothbrushUserName(toothbrush.id, newName);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kullanıcı adı güncellendi')),
                      );
                      _loadData();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }
}
