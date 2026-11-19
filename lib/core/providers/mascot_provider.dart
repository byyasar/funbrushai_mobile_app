import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/mascot_item.dart';
import '../../data/models/mascot_model.dart';
import '../../data/models/brushing_record.dart';
import '../../data/services/supabase_service.dart';

class MascotProvider extends ChangeNotifier {
  static const String _defaultStorageKey = 'funbrush_mascot_data_v1';
  
  String? _activeBrushId;
  final Map<String, MascotModel> _mascotsByBrush = {};
  List<MascotItem> _recentUnlockedItems = [];

  String? get activeBrushId => _activeBrushId;
  MascotModel get mascot => getMascotForBrush(_activeBrushId);
  List<MascotItem> get recentUnlockedItems => _recentUnlockedItems;

  MascotProvider() {
    _loadFromPrefs();
  }

  String _sanitizeKey(String? brushId) {
    if (brushId == null || brushId.trim().isEmpty) {
      return 'default';
    }
    return brushId.trim();
  }

  String _storageKey(String sanitizedKey) {
    if (sanitizedKey == 'default') {
      return _defaultStorageKey;
    }
    return '${_defaultStorageKey}_$sanitizedKey';
  }

  MascotModel getMascotForBrush(String? brushId) {
    final key = _sanitizeKey(brushId);
    return _mascotsByBrush[key] ?? const MascotModel();
  }

  void setActiveBrushId(String? brushId) {
    _activeBrushId = brushId;
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Varsayılan anahtarı yükle
      final defaultJson = prefs.getString(_defaultStorageKey);
      if (defaultJson != null) {
        final Map<String, dynamic> data = jsonDecode(defaultJson);
        _mascotsByBrush['default'] = MascotModel.fromJson(data);
      } else {
        _mascotsByBrush['default'] = MascotModel(
          lastBrushedAt: DateTime.now().subtract(const Duration(hours: 4)),
        );
      }

      // Kullanıcı/fırça bazlı anahtarları tara ve belleğe yükle
      final prefix = '${_defaultStorageKey}_';
      final allKeys = prefs.getKeys().where((k) => k.startsWith(prefix));
      for (final storageKey in allKeys) {
        final jsonStr = prefs.getString(storageKey);
        if (jsonStr != null) {
          final Map<String, dynamic> data = jsonDecode(jsonStr);
          final brushKey = storageKey.substring(prefix.length);
          _mascotsByBrush[brushKey] = MascotModel.fromJson(data);
        }
      }

      _recalculateStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading mascot data: $e');
    }
  }

  Future<void> _saveToPrefs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final target = _mascotsByBrush[key];
      if (target != null) {
        final jsonString = jsonEncode(target.toJson());
        await prefs.setString(_storageKey(key), jsonString);
      }
    } catch (e) {
      debugPrint('Error saving mascot data for $key: $e');
    }
  }

  /// Belirli bir fırça için maskotu SharedPreferences veya varsayılandan yükler
  Future<void> loadForBrush(String? brushId, {List<BrushingRecord>? records, String? initialName}) async {
    _activeBrushId = brushId;
    final key = _sanitizeKey(brushId);

    if (!_mascotsByBrush.containsKey(key)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString(_storageKey(key));
        if (jsonString != null) {
          final Map<String, dynamic> data = jsonDecode(jsonString);
          _mascotsByBrush[key] = MascotModel.fromJson(data);
        } else {
          _mascotsByBrush[key] = MascotModel(
            customName: (initialName != null && initialName.trim().isNotEmpty) ? initialName.trim() : 'Pırıl Diş',
            lastBrushedAt: DateTime.now().subtract(const Duration(hours: 4)),
          );
        }
      } catch (e) {
        debugPrint('Error loading mascot for brush $brushId: $e');
        _mascotsByBrush[key] = const MascotModel();
      }
    }

    // Veritabanından gelen isim varsa ve yerelde farklıysa güncelle
    if (initialName != null && initialName.trim().isNotEmpty) {
      final current = getMascotForBrush(brushId);
      if (current.customName != initialName.trim()) {
        _mascotsByBrush[key] = current.copyWith(customName: initialName.trim());
        await _saveToPrefs(key);
      }
    }

    if (records != null) {
      await syncWithBrushingRecords(records, brushId: brushId);
    } else {
      _recalculateStats(brushId: brushId);
      notifyListeners();
    }
  }

  /// Zaman geçtikçe mutluluk ve hijyeni doğal olarak azaltan hesaplama
  void _recalculateStats({String? brushId}) {
    final targetBrushId = brushId ?? _activeBrushId;
    final key = _sanitizeKey(targetBrushId);
    final targetMascot = getMascotForBrush(targetBrushId);

    if (targetMascot.lastBrushedAt == null) return;
    
    final elapsedHours = DateTime.now().difference(targetMascot.lastBrushedAt!).inMinutes / 60.0;
    
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

    double calculatedHappiness = targetMascot.happiness.toDouble();
    if (elapsedHours > 8.0) {
      calculatedHappiness = calculatedHappiness - ((elapsedHours - 8.0) * 2.5);
    }
    if (calculatedHygiene < 30.0) {
      calculatedHappiness -= 10.0;
    }

    _mascotsByBrush[key] = targetMascot.copyWith(
      hygiene: calculatedHygiene.round().clamp(10, 100),
      happiness: calculatedHappiness.round().clamp(10, 100),
    );
  }

  /// Veritabanındaki gerçek fırçalama kayıtlarına göre maskot durumunu senkronize eder
  Future<void> syncWithBrushingRecords(List<BrushingRecord> records, {String? brushId}) async {
    final targetBrushId = brushId ?? _activeBrushId;
    final key = _sanitizeKey(targetBrushId);

    if (!_mascotsByBrush.containsKey(key)) {
      await loadForBrush(targetBrushId);
    }
    final currentMascot = getMascotForBrush(targetBrushId);

    if (records.isEmpty) {
      _recalculateStats(brushId: targetBrushId);
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
    final List<String> currentUnlocked = List.from(currentMascot.unlockedItemIds);
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
    final elapsedMinutes = now.difference(lastBrushedAt).inMinutes;
    final elapsedHours = elapsedMinutes / 60.0;

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
    final today = DateTime(now.year, now.month, now.day);
    final todayRecords = sortedRecords.where((r) {
      final d = r.createdAt.toLocal();
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();

    final int todayCount = todayRecords.length;
    double calculatedHappiness = 40.0;

    if (todayCount >= 2) {
      calculatedHappiness = 95.0;
    } else if (todayCount == 1) {
      calculatedHappiness = 75.0;
      if (elapsedHours <= 4.0) {
        calculatedHappiness += 10.0;
      }
    } else {
      if (elapsedHours <= 14.0) {
        calculatedHappiness = 55.0;
      } else if (elapsedHours <= 24.0) {
        calculatedHappiness = 40.0;
      } else {
        calculatedHappiness = 20.0;
      }
    }

    if (streak >= 7) {
      calculatedHappiness += 10.0;
    } else if (streak >= 3) {
      calculatedHappiness += 5.0;
    }

    if (lastRecord.durationSeconds >= 120) {
      calculatedHappiness += 5.0;
    }

    if (finalHygiene <= 25) {
      calculatedHappiness -= 20.0;
    } else if (finalHygiene <= 45) {
      calculatedHappiness -= 10.0;
    }

    final int finalHappiness = calculatedHappiness.round().clamp(10, 100);

    // Kişiye özel customName korunur
    _mascotsByBrush[key] = currentMascot.copyWith(
      lastBrushedAt: lastBrushedAt,
      streakDays: streak > 0 ? streak : 1,
      xp: totalXp,
      hygiene: finalHygiene,
      happiness: finalHappiness,
      unlockedItemIds: currentUnlocked,
    );

    await _saveToPrefs(key);
    notifyListeners();
  }

  /// Çocuk dişini fırçaladığında çağrılır (Tamagotchi besleme/temizleme)
  Future<List<MascotItem>> recordBrushing({String? brushId}) async {
    final targetBrushId = brushId ?? _activeBrushId;
    final key = _sanitizeKey(targetBrushId);
    final currentMascot = getMascotForBrush(targetBrushId);

    final now = DateTime.now();
    int newStreak = currentMascot.streakDays;

    if (currentMascot.lastBrushedAt != null) {
      final diffDays = now.difference(currentMascot.lastBrushedAt!).inDays;
      if (diffDays == 1) {
        newStreak += 1;
      } else if (diffDays > 2) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final newXp = currentMascot.xp + 100;
    final List<String> currentUnlocked = List.from(currentMascot.unlockedItemIds);
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
    _mascotsByBrush[key] = currentMascot.copyWith(
      happiness: 100,
      hygiene: 100,
      xp: newXp,
      streakDays: newStreak,
      lastBrushedAt: now,
      unlockedItemIds: currentUnlocked,
    );

    await _saveToPrefs(key);
    notifyListeners();
    return newlyUnlocked;
  }

  /// Aksesuar kuşanma
  Future<void> equipItem(MascotItem item, {String? brushId}) async {
    final targetBrushId = brushId ?? _activeBrushId;
    final key = _sanitizeKey(targetBrushId);
    final currentMascot = getMascotForBrush(targetBrushId);

    if (!currentMascot.unlockedItemIds.contains(item.id)) return;

    MascotModel updated = currentMascot;
    switch (item.category) {
      case MascotItemCategory.hat:
        updated = currentMascot.copyWith(equippedHatId: item.id);
        break;
      case MascotItemCategory.costume:
        updated = currentMascot.copyWith(equippedCostumeId: item.id);
        break;
      case MascotItemCategory.tool:
        updated = currentMascot.copyWith(equippedToolId: item.id);
        break;
    }

    _mascotsByBrush[key] = updated;
    await _saveToPrefs(key);
    notifyListeners();
  }

  /// İsim değiştirme (Kişiye/fırçaya özel ve Supabase ile senkronize)
  Future<void> setCustomName(String name, {String? brushId}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final targetBrushId = brushId ?? _activeBrushId;
    final key = _sanitizeKey(targetBrushId);

    if (!_mascotsByBrush.containsKey(key)) {
      await loadForBrush(targetBrushId);
    }

    final currentMascot = getMascotForBrush(targetBrushId);
    _mascotsByBrush[key] = currentMascot.copyWith(customName: trimmedName);
    await _saveToPrefs(key);
    notifyListeners();

    // Veritabanına kaydet
    if (targetBrushId != null && targetBrushId.isNotEmpty && targetBrushId != 'default') {
      try {
        await SupabaseService().updateToothbrushMascotName(
          brushId: targetBrushId,
          mascotName: trimmedName,
        );
      } catch (e) {
        debugPrint('Supabase mascot name update skipped or failed: $e');
      }
    }
  }

  void clearRecentUnlocked() {
    _recentUnlockedItems = [];
    notifyListeners();
  }
}
