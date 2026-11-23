class AppointmentChecklistItem {
  final String text;
  final bool done;

  const AppointmentChecklistItem({
    required this.text,
    this.done = false,
  });

  AppointmentChecklistItem copyWith({
    String? text,
    bool? done,
  }) {
    return AppointmentChecklistItem(
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'done': done,
      };

  factory AppointmentChecklistItem.fromJson(Map<String, dynamic> json) {
    return AppointmentChecklistItem(
      text: json['text']?.toString() ?? '',
      done: json['done'] == true,
    );
  }
}

class DentalAppointment {
  final String id;
  final String memberName;
  final String? brushId;
  final String appointmentType;
  final DateTime dateTime;
  final String doctorName;
  final String clinicName;
  final String address;
  final String notes;
  final List<String> reminders;
  final bool syncWithCalendar;
  final bool isCompleted;
  final List<AppointmentChecklistItem> checklist;

  const DentalAppointment({
    required this.id,
    required this.memberName,
    this.brushId,
    required this.appointmentType,
    required this.dateTime,
    required this.doctorName,
    required this.clinicName,
    this.address = '',
    this.notes = '',
    this.reminders = const ['1 gün önce', '2 saat önce'],
    this.syncWithCalendar = true,
    this.isCompleted = false,
    this.checklist = const [],
  });

  bool get isUpcoming {
    if (isCompleted) return false;
    final now = DateTime.now();
    return dateTime.isAfter(now.subtract(const Duration(hours: 2)));
  }

  bool get isPast => !isUpcoming;

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return target.difference(today).inDays;
  }

  String get countdownLabel {
    if (isCompleted) return 'Tamamlandı';
    final diff = daysLeft;
    if (diff < 0) return 'Geçmiş';
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '$diff gün kaldı';
  }

  String get typeEmoji {
    switch (appointmentType) {
      case 'Rutin Kontrol':
        return '🩺';
      case 'Diş Taşı Temizliği':
      case 'Temizlik':
        return '✨';
      case 'Dolgu':
        return '🦷';
      case 'Ortodonti':
        return '😁';
      case 'Florür Uygulaması':
        return '🛡️';
      case 'Acil':
        return '🚨';
      default:
        return '🦷';
    }
  }

  static List<AppointmentChecklistItem> defaultChecklistFor(String type) {
    return [
      const AppointmentChecklistItem(
        text: 'Randevudan önce dişleri fırçala',
        done: false,
      ),
      const AppointmentChecklistItem(
        text: 'Son 30 günlük fırçalama PDF raporunu hazırla',
        done: false,
      ),
      if (type == 'Ortodonti')
        const AppointmentChecklistItem(
          text: 'Braket temizliğini kontrol et ve yedek mum iste',
          done: false,
        )
      else
        const AppointmentChecklistItem(
          text: 'Önceki röntgen veya hekim notlarını yanına al',
          done: false,
        ),
    ];
  }

  DentalAppointment copyWith({
    String? id,
    String? memberName,
    String? brushId,
    String? appointmentType,
    DateTime? dateTime,
    String? doctorName,
    String? clinicName,
    String? address,
    String? notes,
    List<String>? reminders,
    bool? syncWithCalendar,
    bool? isCompleted,
    List<AppointmentChecklistItem>? checklist,
  }) {
    return DentalAppointment(
      id: id ?? this.id,
      memberName: memberName ?? this.memberName,
      brushId: brushId ?? this.brushId,
      appointmentType: appointmentType ?? this.appointmentType,
      dateTime: dateTime ?? this.dateTime,
      doctorName: doctorName ?? this.doctorName,
      clinicName: clinicName ?? this.clinicName,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      reminders: reminders ?? this.reminders,
      syncWithCalendar: syncWithCalendar ?? this.syncWithCalendar,
      isCompleted: isCompleted ?? this.isCompleted,
      checklist: checklist ?? this.checklist,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_name': memberName,
        'brush_id': brushId,
        'appointment_type': appointmentType,
        'date_time': dateTime.toIso8601String(),
        'doctor_name': doctorName,
        'clinic_name': clinicName,
        'address': address,
        'notes': notes,
        'reminders': reminders,
        'sync_with_calendar': syncWithCalendar,
        'is_completed': isCompleted,
        'checklist': checklist.map((e) => e.toJson()).toList(),
      };

  factory DentalAppointment.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'] as List<dynamic>? ?? [];
    final rawReminders = json['reminders'] as List<dynamic>? ?? [];
    return DentalAppointment(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      memberName: json['member_name']?.toString() ?? 'Kullanıcı',
      brushId: json['brush_id']?.toString(),
      appointmentType: json['appointment_type']?.toString() ?? 'Rutin Kontrol',
      dateTime: DateTime.tryParse(json['date_time']?.toString() ?? '') ?? DateTime.now(),
      doctorName: json['doctor_name']?.toString() ?? '',
      clinicName: json['clinic_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      reminders: rawReminders.map((e) => e.toString()).toList(),
      syncWithCalendar: json['sync_with_calendar'] == true,
      isCompleted: json['is_completed'] == true,
      checklist: rawChecklist
          .whereType<Map<String, dynamic>>()
          .map(AppointmentChecklistItem.fromJson)
          .toList(),
    );
  }
}
