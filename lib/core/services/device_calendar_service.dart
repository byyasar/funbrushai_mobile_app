import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/dental_appointment.dart';

class CalendarSyncResult {
  final bool success;
  final String message;

  const CalendarSyncResult({
    required this.success,
    required this.message,
  });
}

class DeviceCalendarService {
  static const MethodChannel _channel =
      MethodChannel('com.funbrushai.app/calendar');
  static const String _eventIdPrefix = 'dental_cal_event_id_';

  static Future<String?> _getStoredEventId(String appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_eventIdPrefix$appointmentId');
  }

  static Future<void> _saveStoredEventId(
    String appointmentId,
    String eventId,
  ) async {
    if (eventId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_eventIdPrefix$appointmentId', eventId);
  }

  static Future<void> _removeStoredEventId(String appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_eventIdPrefix$appointmentId');
  }

  static List<int> _reminderLabelsToMinutes(List<String> reminders) {
    final result = <int>[];
    for (final r in reminders) {
      if (r.contains('1 hafta')) {
        result.add(7 * 24 * 60);
      } else if (r.contains('1 gün')) {
        result.add(24 * 60);
      } else if (r.contains('2 saat')) {
        result.add(2 * 60);
      }
    }
    return result;
  }

  /// Randevuyu cihaz takvimine ekler; daha önce eklendiyse mevcut etkinliği günceller.
  static Future<CalendarSyncResult> upsertAppointmentInCalendar(
    DentalAppointment appointment,
  ) async {
    try {
      final existingEventId = await _getStoredEventId(appointment.id);

      final title =
          '🦷 ${appointment.memberName} - ${appointment.appointmentType}';
      final locationParts = [
        if (appointment.clinicName.trim().isNotEmpty)
          appointment.clinicName.trim(),
        if (appointment.address.trim().isNotEmpty) appointment.address.trim(),
      ];
      final location = locationParts.join(', ');

      final notesBuffer = StringBuffer();
      if (appointment.doctorName.trim().isNotEmpty) {
        notesBuffer.writeln('Diş Hekimi: ${appointment.doctorName.trim()}');
      }
      if (appointment.clinicName.trim().isNotEmpty) {
        notesBuffer.writeln('Klinik: ${appointment.clinicName.trim()}');
      }
      if (appointment.notes.trim().isNotEmpty) {
        notesBuffer.writeln('Notlar: ${appointment.notes.trim()}');
      }

      final startMillis = appointment.dateTime.millisecondsSinceEpoch;
      final endMillis = appointment.dateTime
          .add(const Duration(minutes: 45))
          .millisecondsSinceEpoch;

      final response = await _channel.invokeMethod<dynamic>('upsertEvent', {
        'eventId': existingEventId ?? '',
        'title': title,
        'notes': notesBuffer.toString().trim(),
        'location': location,
        'startMillis': startMillis,
        'endMillis': endMillis,
        'alarmMinutes': _reminderLabelsToMinutes(appointment.reminders),
      });

      if (response is Map) {
        final ok = response['success'] == true;
        final updated = response['updated'] == true;
        final newEventId = response['eventId']?.toString() ?? '';
        final err = response['error']?.toString() ?? '';

        if (ok) {
          if (newEventId.isNotEmpty) {
            await _saveStoredEventId(appointment.id, newEventId);
          }
          return CalendarSyncResult(
            success: true,
            message: updated
                ? 'Cihaz takvimindeki randevu güncellendi!'
                : 'Randevu cihaz takvimine eklendi!',
          );
        }
        if (err == 'permission_denied') {
          return const CalendarSyncResult(
            success: false,
            message:
                'Takvim izni reddedildi. Ayarlar > FunBrushBoxApp > Takvimler kısmından Tam Erişim verebilirsiniz.',
          );
        }
        return CalendarSyncResult(
          success: false,
          message: 'Takvim güncellenemedi: $err',
        );
      }

      return const CalendarSyncResult(
        success: false,
        message: 'Cihaz takviminden yanıt alınamadı.',
      );
    } on MissingPluginException {
      return const CalendarSyncResult(
        success: false,
        message: 'Bu platformda cihaz takvimi entegrasyonu desteklenmiyor.',
      );
    } catch (e) {
      debugPrint('DeviceCalendarService upsert error: $e');
      return CalendarSyncResult(
        success: false,
        message: 'Takvim güncellenirken hata oluştu: $e',
      );
    }
  }

  /// Randevuya bağlı cihaz takvimi etkinliğini siler.
  static Future<CalendarSyncResult> deleteAppointmentFromCalendar(
    String appointmentId,
  ) async {
    try {
      final existingEventId = await _getStoredEventId(appointmentId);
      if (existingEventId == null || existingEventId.isEmpty) {
        return const CalendarSyncResult(
          success: true,
          message: '',
        );
      }

      final response = await _channel.invokeMethod<dynamic>('deleteEvent', {
        'eventId': existingEventId,
      });

      await _removeStoredEventId(appointmentId);

      if (response is Map) {
        final ok = response['success'] == true;
        final deleted = response['deleted'] == true;
        if (ok && deleted) {
          return const CalendarSyncResult(
            success: true,
            message: 'Randevu cihaz takviminden de silindi.',
          );
        }
      }
      return const CalendarSyncResult(success: true, message: '');
    } catch (e) {
      debugPrint('DeviceCalendarService delete error: $e');
      return CalendarSyncResult(
        success: false,
        message: 'Takvimden silinirken hata oluştu: $e',
      );
    }
  }

  /// Geriye dönük uyumluluk alias'ı.
  static Future<CalendarSyncResult> addAppointmentToCalendar(
    DentalAppointment appointment,
  ) =>
      upsertAppointmentInCalendar(appointment);
}
