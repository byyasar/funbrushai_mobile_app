enum MascotItemCategory { hat, costume, tool }

class MascotItem {
  final String id;
  final String name;
  final String description;
  final MascotItemCategory category;
  final String icon; // Emoji or asset symbol
  final int requiredStreak; // Streak requirement to unlock
  final int requiredXp; // XP requirement to unlock
  final bool isDefaultUnlocked;

  const MascotItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.requiredStreak = 0,
    this.requiredXp = 0,
    this.isDefaultUnlocked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'icon': icon,
        'requiredStreak': requiredStreak,
        'requiredXp': requiredXp,
        'isDefaultUnlocked': isDefaultUnlocked,
      };

  factory MascotItem.fromJson(Map<String, dynamic> json) => MascotItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        category: MascotItemCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => MascotItemCategory.hat,
        ),
        icon: json['icon'] as String,
        requiredStreak: json['requiredStreak'] as int? ?? 0,
        requiredXp: json['requiredXp'] as int? ?? 0,
        isDefaultUnlocked: json['isDefaultUnlocked'] as bool? ?? false,
      );

  // Predefined game catalog of items
  static const List<MascotItem> allItems = [
    // Şapkalar
    MascotItem(
      id: 'hat_none',
      name: 'Şapkasız',
      description: 'Doğal ve sade görünüm.',
      category: MascotItemCategory.hat,
      icon: '🚫',
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'hat_cap',
      name: 'Spor Şapka',
      description: 'Enerjik bir fırçalayıcı stili!',
      category: MascotItemCategory.hat,
      icon: '🧢',
      requiredXp: 100,
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'hat_crown',
      name: 'Altın Taç',
      description: '7 günlük fırçalama serisi kralına özel.',
      category: MascotItemCategory.hat,
      icon: '👑',
      requiredStreak: 7,
      requiredXp: 500,
    ),
    MascotItem(
      id: 'hat_grad',
      name: 'Mezuniyet Kepi',
      description: 'Diş sağlığı ustası rozeti!',
      category: MascotItemCategory.hat,
      icon: '🎓',
      requiredStreak: 3,
      requiredXp: 300,
    ),
    MascotItem(
      id: 'hat_pirate',
      name: 'Korsan Şapkası',
      description: 'Çürük avcısı cesur korsan!',
      category: MascotItemCategory.hat,
      icon: '🏴‍☠️',
      requiredXp: 800,
    ),

    // Kıyafetler / Zırh
    MascotItem(
      id: 'costume_none',
      name: 'Kostümsüz',
      description: 'Bembeyaz parlak diş dokusu.',
      category: MascotItemCategory.costume,
      icon: '🚫',
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'costume_cape',
      name: 'Kahraman Pelerini',
      description: 'Mikroplara karşı uçan kahraman!',
      category: MascotItemCategory.costume,
      icon: '🦸‍♂️',
      requiredStreak: 3,
      requiredXp: 250,
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'costume_armor',
      name: 'Köpük Zırhı',
      description: 'Çürük geçirmeyen parlak titanyum kalkan.',
      category: MascotItemCategory.costume,
      icon: '🛡️',
      requiredStreak: 5,
      requiredXp: 600,
    ),
    MascotItem(
      id: 'costume_doctor',
      name: 'Doktor Önlüğü',
      description: 'Minik profesör diş hekimi stili.',
      category: MascotItemCategory.costume,
      icon: '🥼',
      requiredXp: 1000,
    ),

    // Araçlar / Fırçalar
    MascotItem(
      id: 'tool_none',
      name: 'Elde Alet Yok',
      description: 'Serbest eller.',
      category: MascotItemCategory.tool,
      icon: '🚫',
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'tool_sparkle_brush',
      name: 'Yıldızlı Fırça',
      description: 'Işıltı saçan süper fırça!',
      category: MascotItemCategory.tool,
      icon: '🪥',
      isDefaultUnlocked: true,
    ),
    MascotItem(
      id: 'tool_magic_wand',
      name: 'Sihirli Asa',
      description: 'Mikropları anında buharlaştıran sihirli değnek.',
      category: MascotItemCategory.tool,
      icon: '🪄',
      requiredStreak: 10,
      requiredXp: 1200,
    ),
  ];
}
