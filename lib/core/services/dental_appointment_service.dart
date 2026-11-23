import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/dental_appointment.dart';
import '../../data/services/supabase_service.dart';
import 'device_config_service.dart';

class DentalAppointmentService {
  static final DentalAppointmentService _instance =
      DentalAppointmentService._internal();
  factory DentalAppointmentService() => _instance;
  DentalAppointmentService._internal();

  static const String _storageKeyPrefix = 'dental_appointments_v1_';
  final SupabaseService _supabaseService = SupabaseService();

  Future<String> _getStorageKey() async {
    try {
      final deviceId = await DeviceConfigService.getDeviceId();
      if (deviceId.trim().isNotEmpty) {
        return '$_storageKeyPrefix${deviceId.trim()}';
      }
    } catch (e) {
      debugPrint('DentalAppointmentService deviceId error: $e');
    }
    return '${_storageKeyPrefix}default';
  }

  Future<List<DentalAppointment>> _getLocalAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(DentalAppointment.fromJson)
          .toList();
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    } catch (e) {
      debugPrint('Error loading local dental appointments: $e');
      return [];
    }
  }

  Future<void> _saveLocalAll(List<DentalAppointment> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey();
    final sorted = List<DentalAppointment>.from(items)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final encoded = jsonEncode(sorted.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  /// Önce Supabase'den randevuları çeker ve yerel önbelleği günceller.
  /// Supabase'de henüz kayıt yoksa ve yerelde mevcut kayıt varsa buluta aktarır.
  /// Çevrimdışı veya bağlantı hatası durumunda yerel önbelleğe düşer.
  Future<List<DentalAppointment>> getAppointments() async {
    final localItems = await _getLocalAppointments();
    try {
      final remoteItems = await _supabaseService.getDentalAppointments();
      if (remoteItems.isEmpty && localItems.isNotEmpty) {
        // İlk geçiş: yereldeki mevcut randevuları Supabase'e senkronize et
        for (final item in localItems) {
          await _supabaseService.upsertDentalAppointment(item);
        }
        return localItems;
      }
      await _saveLocalAll(remoteItems);
      return remoteItems;
    } catch (e) {
      debugPrint('Supabase getDentalAppointments fallback to local: $e');
      return localItems;
    }
  }

  Future<DentalAppointment?> getNextUpcomingAppointment() async {
    final all = await getAppointments();
    final upcoming = all.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<void> saveAppointment(DentalAppointment appointment) async {
    // 1. Anında yerel önbelleğe yaz (offline-safe)
    final all = await _getLocalAppointments();
    final idx = all.indexWhere((a) => a.id == appointment.id);
    if (idx >= 0) {
      all[idx] = appointment;
    } else {
      all.add(appointment);
    }
    await _saveLocalAll(all);

    // 2. Supabase'e senkronize et
    try {
      await _supabaseService.upsertDentalAppointment(appointment);
    } catch (e) {
      debugPrint('Supabase upsertDentalAppointment error: $e');
    }
  }

  Future<void> deleteAppointment(String id) async {
    // 1. Yerel önbellekten sil
    final all = await _getLocalAppointments();
    all.removeWhere((a) => a.id == id);
    await _saveLocalAll(all);

    // 2. Supabase'den sil
    try {
      await _supabaseService.deleteDentalAppointment(id);
    } catch (e) {
      debugPrint('Supabase deleteDentalAppointment error: $e');
    }
  }
}
