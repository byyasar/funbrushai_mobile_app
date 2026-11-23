import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/device_config_service.dart';
import '../models/brushing_record.dart';
import '../models/dental_appointment.dart';
import '../models/social_user.dart';
import '../models/toothbrush.dart';
import '../models/family_member_score.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _customClient;
  String? _currentDeviceId;

  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  void updateClient(String url, String anonKey, {String? deviceId}) {
    _customClient = SupabaseClient(url, anonKey);
    if (deviceId != null) {
      _currentDeviceId = deviceId;
    }
  }

  void setDeviceId(String deviceId) {
    _currentDeviceId = deviceId;
  }

  void resetClient() {
    _customClient = null;
    _currentDeviceId = null;
  }

  Future<String> _getDeviceId() async {
    if (_currentDeviceId != null && _currentDeviceId!.trim().isNotEmpty) {
      return _currentDeviceId!.trim();
    }
    _currentDeviceId = await DeviceConfigService.getDeviceId();
    return _currentDeviceId!.trim();
  }

  Future<void> testConnection({String? url, String? anonKey, String? deviceId}) async {
    final clientToTest = (url != null && anonKey != null && url.isNotEmpty && anonKey.isNotEmpty)
        ? SupabaseClient(url, anonKey)
        : _client;

    final targetDeviceId = deviceId ?? await _getDeviceId();

    var query = clientToTest.from('dis_fircalari').select();
    if (targetDeviceId.isNotEmpty) {
      query = query.eq('cihaz_id', targetDeviceId);
    }
    await query.limit(1);
  }

  Future<List<BrushingRecord>> getBrushingRecords({
    required String brushId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final deviceId = await _getDeviceId();

    try {
      var query = _client
          .from('fircalama_kayitlari')
          .select()
          .eq('firca_id', brushId);

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BrushingRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching records: $e');
      return [];
    }
  }

  Future<List<BrushingRecord>> getAllRecordsForBrush(String brushId) async {
    final deviceId = await _getDeviceId();
    try {
      var query = _client
          .from('fircalama_kayitlari')
          .select()
          .eq('firca_id', brushId);

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query.order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BrushingRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching all records for brush: $e');
      return [];
    }
  }

  Future<List<BrushingRecord>> getAllRecordsForDevice({String? deviceId}) async {
    final targetDeviceId = deviceId ?? await _getDeviceId();
    try {
      var query = _client.from('fircalama_kayitlari').select();

      if (targetDeviceId.isNotEmpty) {
        query = query.eq('cihaz_id', targetDeviceId);
      }

      final response = await query.order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BrushingRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching all records for device: $e');
      return [];
    }
  }

  Future<void> linkBrushToUser(String userId, String brushId) async {
    // No-op for now
  }

  Future<List<SocialUser>> getSocialUsers() async {
    final deviceId = await _getDeviceId();
    try {
      var query = _client.from('dis_fircalari').select();

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query;

      final inactiveSet = await DeviceConfigService.getInactiveBrushIds(deviceId);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => SocialUser.fromJson(json))
          .where((u) => !inactiveSet.contains(u.brushId))
          .toList();
    } catch (e) {
      debugPrint('Error fetching social users: $e');
      return [];
    }
  }

  Future<List<BrushingRecord>> getLast7DaysRecords(String brushId) async {
    final deviceId = await _getDeviceId();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    // Start from the beginning of the 7th day ago
    final startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
    
    try {
      var query = _client
          .from('fircalama_kayitlari')
          .select()
          .eq('firca_id', brushId);

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', now.toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BrushingRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching last 7 days records: $e');
      return [];
    }
  }

  Future<List<FamilyMemberScore>> getWeeklyFamilyLeaderboard() async {
    try {
      final users = await getSocialUsers();
      final List<FamilyMemberScore> scores = [];

      for (final user in users) {
        final records = await getLast7DaysRecords(user.brushId);
        int totalScore = 0;
        final Map<int, int> dayCountMap = {};

        for (final r in records) {
          totalScore += 15; // Taban fırçalama puanı
          if (r.durationSeconds >= 120) {
            totalScore += 5; // 2 dk hedefi bonusu
          }
          final dayKey = r.createdAt.toLocal().day;
          dayCountMap[dayKey] = (dayCountMap[dayKey] ?? 0) + 1;
        }

        // Günde 2 kez fırçalama yapılan günlere +10 bonus
        for (final count in dayCountMap.values) {
          if (count >= 2) {
            totalScore += 10;
          }
        }

        // Aktif gün sayısı
        final streak = dayCountMap.keys.length;

        scores.add(FamilyMemberScore(
          user: user,
          weeklyBrushingCount: records.length,
          weeklyScore: totalScore,
          streakDays: streak,
        ));
      }

      // Skorlara göre azalan sırada sırala
      scores.sort((a, b) {
        final scoreCompare = b.weeklyScore.compareTo(a.weeklyScore);
        if (scoreCompare != 0) return scoreCompare;
        return b.weeklyBrushingCount.compareTo(a.weeklyBrushingCount);
      });

      // Dereceleri (rank) ata
      final List<FamilyMemberScore> rankedScores = [];
      for (int i = 0; i < scores.length; i++) {
        rankedScores.add(FamilyMemberScore(
          user: scores[i].user,
          weeklyBrushingCount: scores[i].weeklyBrushingCount,
          weeklyScore: scores[i].weeklyScore,
          streakDays: scores[i].streakDays,
          rank: i + 1,
        ));
      }

      return rankedScores;
    } catch (e) {
      debugPrint('Error getting weekly family leaderboard: $e');
      return [];
    }
  }

  Future<Toothbrush?> getToothbrushDetails(String brushId) async {
    debugPrint('Fetching toothbrush details for brushId: $brushId');
    final deviceId = await _getDeviceId();
    try {
      var query = _client
          .from('dis_fircalari')
          .select()
          .eq('firca_id', brushId);

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query.single();

      debugPrint('Toothbrush details response: $response');
      return Toothbrush.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching toothbrush details: $e');
      return null;
    }
  }

  /// Belirtilen cihaz ID'si için veritabanını kontrol eder.
  /// 5 adet fırça (Firca1, Firca2, Firca3, Firca4, Firca5) yoksa eksik olanları
  /// kullanici_adi boş olacak şekilde dis_fircalari tablosuna ekler.
  Future<void> ensureDeviceToothbrushesExist(String deviceId) async {
    final cleanDeviceId = deviceId.trim();
    if (cleanDeviceId.isEmpty) return;

    try {
      final response = await _client
          .from('dis_fircalari')
          .select('firca_id')
          .eq('cihaz_id', cleanDeviceId);

      final List<dynamic> existingList = response as List<dynamic>;
      final Set<String> existingBrushIds = existingList
          .map((item) => item['firca_id']?.toString() ?? '')
          .toSet();

      final requiredBrushes = ['Firca1', 'Firca2', 'Firca3', 'Firca4', 'Firca5'];
      final missingBrushes = requiredBrushes
          .where((brushId) => !existingBrushIds.contains(brushId))
          .toList();

      if (missingBrushes.isNotEmpty) {
        debugPrint('Adding ${missingBrushes.length} missing brushes for device: $cleanDeviceId');
        
        // En yüksek ID'yi bularak primary key çakışmalarını önleyelim
        int nextId = 1;
        try {
          final maxIdRes = await _client
              .from('dis_fircalari')
              .select('id')
              .order('id', ascending: false)
              .limit(1);
          if (maxIdRes.isNotEmpty && maxIdRes.first['id'] != null) {
            nextId = (int.tryParse(maxIdRes.first['id'].toString()) ?? 0) + 1;
          }
        } catch (e) {
          debugPrint('Error finding max id: $e');
        }

        final now = DateTime.now();
        final renewalDate = now.add(const Duration(days: 90));
        final renewalDateStr = '${renewalDate.day.toString().padLeft(2, '0')}.${renewalDate.month.toString().padLeft(2, '0')}.${renewalDate.year}';

        final newRecords = missingBrushes.map((brushId) {
          return {
            'id': nextId++,
            'cihaz_id': cleanDeviceId,
            'firca_id': brushId,
            'kullanici_adi': '',
            'yenilenme_tarihi': renewalDateStr,
            'yenilenme_zamani': '90',
            'created_at': now.toIso8601String(),
          };
        }).toList();

        await _client.from('dis_fircalari').insert(newRecords);
        debugPrint('Successfully added missing toothbrushes for $cleanDeviceId: $missingBrushes');
      }
    } catch (e) {
      debugPrint('Error ensuring device toothbrushes exist: $e');
    }
  }

  Future<List<Toothbrush>> getAllToothbrushes({String? targetDeviceId}) async {
    final deviceId = targetDeviceId ?? await _getDeviceId();
    try {
      if (deviceId.isNotEmpty) {
        await ensureDeviceToothbrushesExist(deviceId);
      }

      var query = _client.from('dis_fircalari').select();

      if (deviceId.isNotEmpty) {
        query = query.eq('cihaz_id', deviceId);
      }

      final response = await query.order('id', ascending: true);

      final inactiveSet = await DeviceConfigService.getInactiveBrushIds(deviceId);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final brush = Toothbrush.fromJson(json);
        final isActive = !inactiveSet.contains(brush.fircaId);
        return brush.copyWith(isActive: isActive);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all toothbrushes: $e');
      return [];
    }
  }

  Future<void> updateToothbrushRenewalDate(String id, DateTime newDate) async {
    try {
      // Format as DD.MM.YYYY to match existing data format
      final dateStr = '${newDate.day.toString().padLeft(2, '0')}.${newDate.month.toString().padLeft(2, '0')}.${newDate.year}';
      
      await _client
          .from('dis_fircalari')
          .update({'yenilenme_tarihi': dateStr})
          .eq('id', id);
          
      debugPrint('Updated renewal date for brush $id to $dateStr');
    } catch (e) {
      debugPrint('Error updating renewal date: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  Future<void> updateToothbrushUserName(String id, String newName) async {
    try {
      await _client
          .from('dis_fircalari')
          .update({'kullanici_adi': newName})
          .eq('id', id);
          
      debugPrint('Updated user name for brush $id to $newName');
    } catch (e) {
      debugPrint('Error updating user name: $e');
      throw e;
    }
  }

  Future<String?> uploadBrushAvatar(File imageFile, String brushId) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${brushId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      await _client.storage.from('brush_avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _client.storage.from('brush_avatars').getPublicUrl(filePath);
      debugPrint('Uploaded avatar: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> updateToothbrushAvatar(String id, String avatarUrl) async {
    try {
      await _client
          .from('dis_fircalari')
          .update({'avatar': avatarUrl})
          .eq('id', id);
          
      debugPrint('Updated avatar for brush $id to $avatarUrl');
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      throw e;
    }
  }

  Future<void> updateToothbrushMascotName({
    required String brushId,
    required String mascotName,
    String? id,
  }) async {
    final deviceId = await _getDeviceId();
    try {
      if (id != null && id.isNotEmpty) {
        await _client
            .from('dis_fircalari')
            .update({'maskot_adi': mascotName})
            .eq('id', id);
      } else {
        var query = _client
            .from('dis_fircalari')
            .update({'maskot_adi': mascotName})
            .eq('firca_id', brushId);

        if (deviceId.isNotEmpty) {
          query = query.eq('cihaz_id', deviceId);
        }

        await query;
      }
      debugPrint('Updated mascot name for brush $brushId to $mascotName');
    } catch (e) {
      debugPrint('Error updating mascot name in Supabase: $e');
    }
  }

  // --- Diş Randevuları (dis_randevulari) ---

  Future<List<DentalAppointment>> getDentalAppointments({
    String? targetDeviceId,
  }) async {
    final deviceId = (targetDeviceId ?? await _getDeviceId()).trim();
    var query = _client.from('dis_randevulari').select();
    if (deviceId.isNotEmpty) {
      query = query.eq('cihaz_id', deviceId);
    }
    final response = await query.order('randevu_tarihi', ascending: true);
    final List<dynamic> data = response as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(DentalAppointment.fromSupabaseJson)
        .toList();
  }

  Future<void> upsertDentalAppointment(
    DentalAppointment appointment, {
    String? targetDeviceId,
  }) async {
    final deviceId = (targetDeviceId ?? await _getDeviceId()).trim();
    final effectiveDeviceId =
        deviceId.isNotEmpty ? deviceId : DeviceConfigService.defaultDeviceId;
    await _client
        .from('dis_randevulari')
        .upsert(appointment.toSupabaseJson(effectiveDeviceId));
  }

  Future<void> deleteDentalAppointment(
    String id, {
    String? targetDeviceId,
  }) async {
    final deviceId = (targetDeviceId ?? await _getDeviceId()).trim();
    var query = _client.from('dis_randevulari').delete().eq('id', id);
    if (deviceId.isNotEmpty) {
      query = query.eq('cihaz_id', deviceId);
    }
    await query;
  }
}
