class Toothbrush {
  static const int defaultRenewalPeriodDays = 120; // 4 ay

  final String id;
  final String name; // Keeping for backward compatibility if needed, or can be derived
  final String fircaId;
  final String? cihazId;
  final String userName;
  final int renewalPeriodDays;
  final DateTime startDate;
  final DateTime? renewalDate;
  final DateTime? expirationDate;
  final String? avatar;
  final String? mascotName;
  final bool isActive;

  Toothbrush({
    required this.id,
    required this.name,
    required this.fircaId,
    this.cihazId,
    required this.userName,
    required this.renewalPeriodDays,
    required this.startDate,
    this.renewalDate,
    this.expirationDate,
    this.avatar,
    this.mascotName,
    this.isActive = true,
  });

  Toothbrush copyWith({
    String? id,
    String? name,
    String? fircaId,
    String? cihazId,
    String? userName,
    int? renewalPeriodDays,
    DateTime? startDate,
    DateTime? renewalDate,
    DateTime? expirationDate,
    String? avatar,
    String? mascotName,
    bool? isActive,
  }) {
    return Toothbrush(
      id: id ?? this.id,
      name: name ?? this.name,
      fircaId: fircaId ?? this.fircaId,
      cihazId: cihazId ?? this.cihazId,
      userName: userName ?? this.userName,
      renewalPeriodDays: renewalPeriodDays ?? this.renewalPeriodDays,
      startDate: startDate ?? this.startDate,
      renewalDate: renewalDate ?? this.renewalDate,
      expirationDate: expirationDate ?? this.expirationDate,
      avatar: avatar ?? this.avatar,
      mascotName: mascotName ?? this.mascotName,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Toothbrush.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        try {
          // Try parsing DD.MM.YYYY
          final parts = dateStr.split('.');
          if (parts.length == 3) {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
        return DateTime.now();
      }
    }

    DateTime? parseOptionalDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        try {
           // Try parsing DD.MM.YYYY
          final parts = dateStr.split('.');
          if (parts.length == 3) {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
        return null;
      }
    }

    final fircaId = json['firca_id']?.toString() ?? '';
    final userName = json['kullanici_adi'] ?? 'Unknown User';
    final parsedRenewalPeriod = json['yenilenme_zamani'] is int
        ? json['yenilenme_zamani'] as int
        : int.tryParse(json['yenilenme_zamani']?.toString() ?? '') ??
            defaultRenewalPeriodDays;
    // Eski 6 aylık (180 gün) varsayılanı 4 aya (120 gün) çek
    final renewalPeriod =
        parsedRenewalPeriod == 180 ? defaultRenewalPeriodDays : parsedRenewalPeriod;

    return Toothbrush(
      id: json['id'].toString(),
      name: '$fircaId - $userName', // Default display name logic
      fircaId: fircaId,
      cihazId: json['cihaz_id']?.toString(),
      userName: userName,
      renewalPeriodDays: renewalPeriod,
      startDate: json['baslangic_tarihi'] != null 
          ? parseDate(json['baslangic_tarihi']) 
          : parseDate(json['created_at']), 
      renewalDate: parseOptionalDate(json['yenillenme_tarihi'] ?? json['yenilenme_tarihi']),
      expirationDate: parseOptionalDate(json['son_kullanma_tarihi']),
      avatar: json['avatar']?.toString(),
      mascotName: json['maskot_adi']?.toString(),
    );
  }
}
