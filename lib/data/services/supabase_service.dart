import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brushing_record.dart';
import '../models/social_user.dart';
import '../models/toothbrush.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<BrushingRecord>> getBrushingRecords({
    required String brushId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    try {
      final response = await _client
          .from('fircalama_kayitlari')
          .select()
          .eq('firca_id', brushId) // Changed from brush_id
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

  Future<void> linkBrushToUser(String userId, String brushId) async {
    // No-op for now
  }

  Future<List<SocialUser>> getSocialUsers() async {
    try {
      final response = await _client
          .from('dis_fircalari')
          .select();

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => SocialUser.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching social users: $e');
      return [];
    }
  }

  Future<List<BrushingRecord>> getLast7DaysRecords(String brushId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    // Start from the beginning of the 7th day ago
    final startDate = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
    
    try {
      final response = await _client
          .from('fircalama_kayitlari')
          .select()
          .eq('firca_id', brushId)
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

  Future<Toothbrush?> getToothbrushDetails(String brushId) async {
    debugPrint('Fetching toothbrush details for brushId: $brushId');
    try {
      final response = await _client
          .from('dis_fircalari')
          .select()
          .eq('firca_id', brushId)
          .single();

      debugPrint('Toothbrush details response: $response');
      return Toothbrush.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching toothbrush details: $e');
      return null;
    }
  }

  Future<List<Toothbrush>> getAllToothbrushes() async {
    try {
      final response = await _client
          .from('dis_fircalari')
          .select()
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Toothbrush.fromJson(json)).toList();
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
}
