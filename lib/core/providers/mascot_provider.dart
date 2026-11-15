import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/mascot_item.dart';
import '../../data/models/mascot_model.dart';
import '../../data/models/brushing_record.dart';

class MascotProvider extends ChangeNotifier {
  static const String _storageKey = 'funbrush_mascot_data_v1';
  
  MascotModel _mascot = const MascotModel();
  List<MascotItem> _recentUnlockedItems = [];

  MascotModel get mascot => _mascot;
  List<MascotItem> get recentUnlockedItems => _recentUnlockedItems;

  MascotProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final Map<String, dynamic> data = jsonDecode(jsonString);
        _mascot = MascotModel.fromJson(data);
      } else {
        // Varsayılan maskot
        _mascot = MascotModel(
          lastBrushedAt: DateTime.now().subtract(const Duration(hours: 4)),
        );
      }
      _recalculateStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading mascot data: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_mascot.toJson());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving mascot data: $e');
    }
  }

  /// Zaman geçtikçe mutluluk ve hijyeni doğal olarak azaltan hesaplama
  void _recalculateStats() {
    if (_mascot.lastBrushedAt == null) return;
    
    final elapsedHours = DateTime.now().difference(_mascot.lastBrushedAt!).inMinutes / 60.0;
    
    double calculatedHygiene;
    if (elapsedHours <= 2.0) {
      calculatedHygiene = 100.0;
    } else if (elapsedHours <= 10.0) {
      calculatedHygiene = 100.0 - ((elapsedHours - 2.0) * 4.0);
    } else if (elapsedHours <= 20.0) {
      calculatedHygiene = 68.0 - ((elapsedHours - 10.0) * 3.5);
    } else {
      calculatedHygiene = (33.0 - ((elapsedHours - 20.0) * 1.0)).clamp(10.0, 33.0);
    }

    double calculatedHappiness = _mascot.happiness.toDouble();
    if (elapsedHours > 8.0) {
      calculatedHappiness = calculatedHappiness - ((elapsedHours - 8.0) * 2.5);
    }
    if (calculatedHygiene < 30.0) {
      calculatedHappiness -= 10.0;
    }

    _mascot = _mascot.copyWith(
      hygiene: calculatedHygiene.round().clamp(10, 100),
      happiness: calculatedHappiness.round().clamp(10, 100),
    );
  }

  /// Veritabanındaki gerçek fırçalama kayıtlarına göre maskot durumunu senkronize eder
  Future<void> syncWithBrushingRecords(List<BrushingRecord> records) async {
    if (records.isEmpty) {
      _recalculateStats();
      notifyListeners();
      return;
    }

    // Kayıtları tarihe göre sırala (en eski -> en yeni)
    final sortedRecords = List<BrushingRecord>.from(records)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final lastRecord = sortedRecords.last;
    final lastBrushedAt = lastRecord.createdAt.toLocal();
    final now = DateTime.now();

    // Benzersiz fırçalama günlerini bul
    final uniqueDays = sortedRecords
        .map((r) => DateTime(r.createdAt.toLocal().year, r.createdAt.toLocal().month, r.createdAt.toLocal().day))
        .toSet()
        .toList()
      ..sort();

    // Streak (ardışık gün) hesapla
    int streak = 0;
    if (uniqueDays.isNotEmpty) {
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      
      final lastDay = uniqueDays.last;
      if (lastDay == today || lastDay == yesterday) {
        streak = 1;
        for (int i = uniqueDays.length - 1; i > 0; i--) {
          final diff = uniqueDays[i].difference(uniqueDays[i - 1]).inDays;
          if (diff == 1) {
            streak++;
          } else {
            break;
          }
        }
      }
    }

    // Her fırçalama 100 XP kazandırır
    final totalXp = sortedRecords.length * 100;

    // Kilit açma kontrolü
    final List<String> currentUnlocked = List.from(_mascot.unlockedItemIds);
    for (final item in MascotItem.allItems) {
      if (!currentUnlocked.contains(item.id)) {
        final streakCondition = item.requiredStreak == 0 || streak >= item.requiredStreak;
        final xpCondition = item.requiredXp == 0 || totalXp >= item.requiredXp;
        if (streakCondition && xpCondition) {
          currentUnlocked.add(item.id);
        }
      }
    }

    // --- TEMİZLİK (HİJYEN) HESABI ---
    // Son fırçalamadan beri geçen süre (saat cinsinden)
    final elapsedMinutes = now.difference(lastBrushedAt).inMinutes;
    final elapsedHours = elapsedMinutes / 60.0;

    // Fırçalama süresi kalitesi (120 sn ideal 2 dk hedefi)
    double baseHygiene = 100.0;
    if (lastRecord.durationSeconds > 0 && lastRecord.durationSeconds < 60) {
      baseHygiene = 70.0;
    } else if (lastRecord.durationSeconds > 0 && lastRecord.durationSeconds < 120) {
      baseHygiene = 88.0;
    }

    double calculatedHygiene;
    if (elapsedHours <= 2.0) {
      calculatedHygiene = baseHygiene;
    } else if (elapsedHours <= 10.0) {
      calculatedHygiene = baseHygiene - ((elapsedHours - 2.0) * 4.0);
    } else if (elapsedHours <= 20.0) {
      calculatedHygiene = 68.0 - ((elapsedHours - 10.0) * 3.5);
    } else if (elapsedHours <= 36.0) {
      calculatedHygiene = 33.0 - ((elapsedHours - 20.0) * 1.0);
    } else {
      calculatedHygiene = 10.0;
    }
    final int finalHygiene = calculatedHygiene.round().clamp(10, 100);

    // --- MUTLULUK HESABI ---
    // Bugün yapılan fırçalama sayısı
    final today = DateTime(now.year, now.month, now.day);
    final todayRecords = sortedRecords.where((r) {
      final d = r.createdAt.toLocal();
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();

    final int todayCount = todayRecords.length;
    double calculatedHappiness = 40.0;

    if (todayCount >= 2) {
      // Günde 2 kez fırçalama hedefi tamamlandı: Çok mutlu!
      calculatedHappiness = 95.0;
    } else if (todayCount == 1) {
      // Bugün 1 kez fırçalanmış: İyi
      calculatedHappiness = 75.0;
      if (elapsedHours <= 4.0) {
        calculatedHappiness += 10.0;
      }
    } else {
      // Bugün henüz hiç fırçalanmadı
      if (elapsedHours <= 14.0) {
        // Dün gece fırçalanmış, sabah henüz fırçalanmadı
        calculatedHappiness = 55.0;
      } else if (elapsedHours <= 24.0) {
        calculatedHappiness = 40.0;
      } else {
        // 1 günden fazladır fırçalanmamış
        calculatedHappiness = 20.0;
      }
    }

    // Seri (streak) bonusu
    if (streak >= 7) {
      calculatedHappiness += 10.0;
    } else if (streak >= 3) {
      calculatedHappiness += 5.0;
    }

    // Son fırçalama 2 dakika tam yapıldıysa ekstra neşe
    if (lastRecord.durationSeconds >= 120) {
      calculatedHappiness += 5.0;
    }

    // Temizlik barı çok düşükse maskotun keyfi kaçar
    if (finalHygiene <= 25) {
      calculatedHappiness -= 20.0;
    } else if (finalHygiene <= 45) {
      calculatedHappiness -= 10.0;
    }

    final int finalHappiness = calculatedHappiness.round().clamp(10, 100);

    _mascot = _mascot.copyWith(
      lastBrushedAt: lastBrushedAt,
      streakDays: streak > 0 ? streak : 1,
      xp: totalXp,
      hygiene: finalHygiene,
      happiness: finalHappiness,
      unlockedItemIds: currentUnlocked,
    );

    await _saveToPrefs();
    notifyListeners();
  }

  /// Çocuk dişini fırçaladığında çağrılır (Tamagotchi besleme/temizleme)
  Future<List<MascotItem>> recordBrushing() async {
    final now = DateTime.now();
    int newStreak = _mascot.streakDays;

    if (_mascot.lastBrushedAt != null) {
      final diffDays = now.difference(_mascot.lastBrushedAt!).inDays;
      if (diffDays == 1) {
        newStreak += 1;
      } else if (diffDays > 2) {
        newStreak = 1; // Seri bozuldu
      }
    } else {
      newStreak = 1;
    }

    final newXp = _mascot.xp + 100;
    final List<String> currentUnlocked = List.from(_mascot.unlockedItemIds);
    final List<MascotItem> newlyUnlocked = [];

    // Kilit açma kontrolü
    for (final item in MascotItem.allItems) {
      if (!currentUnlocked.contains(item.id)) {
        final streakCondition = item.requiredStreak == 0 || newStreak >= item.requiredStreak;
        final xpCondition = item.requiredXp == 0 || newXp >= item.requiredXp;
        if (streakCondition && xpCondition) {
          currentUnlocked.add(item.id);
          newlyUnlocked.add(item);
        }
      }
    }

    _recentUnlockedItems = newlyUnlocked;
    _mascot = _mascot.copyWith(
      happiness: 100,
      hygiene: 100,
      xp: newXp,
      streakDays: newStreak,
      lastBrushedAt: now,
      unlockedItemIds: currentUnlocked,
    );

    await _saveToPrefs();
    notifyListeners();
    return newlyUnlocked;
  }

  /// Aksesuar kuşanma
  Future<void> equipItem(MascotItem item) async {
    if (!_mascot.unlockedItemIds.contains(item.id)) return;

    switch (item.category) {
      case MascotItemCategory.hat:
        _mascot = _mascot.copyWith(equippedHatId: item.id);
        break;
      case MascotItemCategory.costume:
        _mascot = _mascot.copyWith(equippedCostumeId: item.id);
        break;
      case MascotItemCategory.tool:
        _mascot = _mascot.copyWith(equippedToolId: item.id);
        break;
    }

    await _saveToPrefs();
    notifyListeners();
  }

  /// İsim değiştirme
  Future<void> setCustomName(String name) async {
    if (name.trim().isEmpty) return;
    _mascot = _mascot.copyWith(customName: name.trim());
    await _saveToPrefs();
    notifyListeners();
  }

  void clearRecentUnlocked() {
    _recentUnlockedItems = [];
    notifyListeners();
  }
}
