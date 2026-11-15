enum MascotMood {
  sparkling, // 2x/gün, yüksek enerji, etrafta yıldızlar
  happy,     // Son 8 saatte fırçalanmış, mutlu
  sleepy,    // 12-20 saattir fırçalanmamış, yorgun/uykulu
  dirtyMicrobes, // 24+ saattir fırçalanmamış, mikroplar belirdi!
}

class MascotModel {
  final String customName;
  final int happiness; // 0 - 100
  final int hygiene;   // 0 - 100
  final int xp;
  final int streakDays;
  final String equippedHatId;
  final String equippedCostumeId;
  final String equippedToolId;
  final List<String> unlockedItemIds;
  final DateTime? lastBrushedAt;

  const MascotModel({
    this.customName = 'Pırıl Diş',
    this.happiness = 100,
    this.hygiene = 100,
    this.xp = 120,
    this.streakDays = 1,
    this.equippedHatId = 'hat_cap',
    this.equippedCostumeId = 'costume_cape',
    this.equippedToolId = 'tool_sparkle_brush',
    this.unlockedItemIds = const ['hat_none', 'hat_cap', 'costume_none', 'costume_cape', 'tool_none', 'tool_sparkle_brush'],
    this.lastBrushedAt,
  });

  int get level => (xp / 200).floor() + 1;
  int get xpInCurrentLevel => xp % 200;
  double get levelProgress => (xp % 200) / 200.0;

  MascotMood get mood {
    if (lastBrushedAt == null) {
      return MascotMood.happy;
    }
    final diffHours = DateTime.now().difference(lastBrushedAt!).inHours;

    if (diffHours >= 24 || hygiene <= 30) {
      return MascotMood.dirtyMicrobes;
    } else if (diffHours >= 12 || happiness <= 50) {
      return MascotMood.sleepy;
    } else if (streakDays >= 2 && happiness >= 80) {
      return MascotMood.sparkling;
    } else {
      return MascotMood.happy;
    }
  }

  String get moodMessage {
    switch (mood) {
      case MascotMood.sparkling:
        return 'Işıl ışıl parlıyorum! Dişlerin harika!';
      case MascotMood.happy:
        return 'Bugün kendimi çok zinde hissediyorum!';
      case MascotMood.sleepy:
        return 'Biraz enerjim düştü.. Diş fırçalama vakti mi?';
      case MascotMood.dirtyMicrobes:
        return 'İmdat! Küçük mikroplar geldi, hemen fırçalayalım!';
    }
  }

  MascotModel copyWith({
    String? customName,
    int? happiness,
    int? hygiene,
    int? xp,
    int? streakDays,
    String? equippedHatId,
    String? equippedCostumeId,
    String? equippedToolId,
    List<String>? unlockedItemIds,
    DateTime? lastBrushedAt,
  }) {
    return MascotModel(
      customName: customName ?? this.customName,
      happiness: happiness ?? this.happiness,
      hygiene: hygiene ?? this.hygiene,
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      equippedHatId: equippedHatId ?? this.equippedHatId,
      equippedCostumeId: equippedCostumeId ?? this.equippedCostumeId,
      equippedToolId: equippedToolId ?? this.equippedToolId,
      unlockedItemIds: unlockedItemIds ?? this.unlockedItemIds,
      lastBrushedAt: lastBrushedAt ?? this.lastBrushedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'customName': customName,
        'happiness': happiness,
        'hygiene': hygiene,
        'xp': xp,
        'streakDays': streakDays,
        'equippedHatId': equippedHatId,
        'equippedCostumeId': equippedCostumeId,
        'equippedToolId': equippedToolId,
        'unlockedItemIds': unlockedItemIds,
        'lastBrushedAt': lastBrushedAt?.toIso8601String(),
      };

  factory MascotModel.fromJson(Map<String, dynamic> json) => MascotModel(
        customName: json['customName'] as String? ?? 'Pırıl Diş',
        happiness: json['happiness'] as int? ?? 100,
        hygiene: json['hygiene'] as int? ?? 100,
        xp: json['xp'] as int? ?? 120,
        streakDays: json['streakDays'] as int? ?? 1,
        equippedHatId: json['equippedHatId'] as String? ?? 'hat_cap',
        equippedCostumeId: json['equippedCostumeId'] as String? ?? 'costume_cape',
        equippedToolId: json['equippedToolId'] as String? ?? 'tool_sparkle_brush',
        unlockedItemIds: (json['unlockedItemIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            const ['hat_none', 'hat_cap', 'costume_none', 'costume_cape', 'tool_none', 'tool_sparkle_brush'],
        lastBrushedAt: json['lastBrushedAt'] != null
            ? DateTime.tryParse(json['lastBrushedAt'] as String)
            : DateTime.now().subtract(const Duration(hours: 3)),
      );
}
