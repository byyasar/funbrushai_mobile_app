import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/dental_appointment.dart';
import 'device_config_service.dart';

class DentalAppointmentService {
  static final DentalAppointmentService _instance =
      DentalAppointmentService._internal();
  factory DentalAppointmentService() => _instance;
  DentalAppointmentService._internal();

  static const String _storageKeyPrefix = 'dental_appointments_v1_';

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

  Future<List<DentalAppointment>> getAppointments() async {
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
      debugPrint('Error loading dental appointments: $e');
      return [];
    }
  }

  Future<DentalAppointment?> getNextUpcomingAppointment() async {
    final all = await getAppointments();
    final upcoming = all.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<void> _saveAll(List<DentalAppointment> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  Future<void> saveAppointment(DentalAppointment appointment) async {
    final all = await getAppointments();
    final idx = all.indexWhere((a) => a.id == appointment.id);
    if (idx >= 0) {
      all[idx] = appointment;
    } else {
      all.add(appointment);
    }
    all.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _saveAll(all);
  }

  Future<void> deleteAppointment(String id) async {
    final all = await getAppointments();
    all.removeWhere((a) => a.id == id);
    await _saveAll(all);
  }
}
