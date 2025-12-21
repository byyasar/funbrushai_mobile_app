class Toothbrush {
  final String id;
  final String name; // Keeping for backward compatibility if needed, or can be derived
  final String fircaId;
  final String userName;
  final int renewalPeriodDays;
  final DateTime startDate;
  final DateTime? renewalDate;
  final DateTime? expirationDate;
  final String? avatar;

  Toothbrush({
    required this.id,
    required this.name,
    required this.fircaId,
    required this.userName,
    required this.renewalPeriodDays,
    required this.startDate,
    this.renewalDate,
    this.expirationDate,
    this.avatar,
  });

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
    final renewalPeriod = json['yenilenme_zamani'] is int 
        ? json['yenilenme_zamani'] 
        : int.tryParse(json['yenilenme_zamani']?.toString() ?? '90') ?? 90;

    return Toothbrush(
      id: json['id'].toString(),
      name: '$fircaId - $userName', // Default display name logic
      fircaId: fircaId,
      userName: userName,
      renewalPeriodDays: renewalPeriod,
      startDate: json['baslangic_tarihi'] != null 
          ? parseDate(json['baslangic_tarihi']) 
          : parseDate(json['created_at']), 
      renewalDate: parseOptionalDate(json['yenillenme_tarihi'] ?? json['yenilenme_tarihi']),
      expirationDate: parseOptionalDate(json['son_kullanma_tarihi']),
      avatar: json['avatar']?.toString(),
    );
  }
}
