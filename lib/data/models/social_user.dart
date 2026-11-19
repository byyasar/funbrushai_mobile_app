class SocialUser {
  final String id;
  final String name;
  final String avatarUrl;
  final String brushId;
  final int currentStreak;
  final String? mascotName;

  SocialUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.brushId,
    this.currentStreak = 0,
    this.mascotName,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      id: json['id'].toString(),
      name: json['kullanici_adi'] ?? json['ad_soyad'] ?? 'Unknown User',
      // Prioritize 'avatar' field, fall back to 'resim_url', then default placeholder
      avatarUrl: json['avatar'] ?? json['resim_url'] ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuB9boV4AD7YahFfWVFOK84uR5qISeHoJc5pD7nfaePwE-w6ha3pdVOVBrvC-hQeWYXh-_IjhzzfpHehLsjxjfX0U_j57_4lkVt_rhiA0LAt9KEax12d_McNlezQQgh6XsWU_Qan4-7gdrZCrVd-_1m_ZvUwCd_2xgBgzT2n74v8Qeo8eFKjUyZY-s-rKucYB5E6CeWntC6L_s68cAVJ43cff41Dcj3hi-UOZTNvXe3yNn2ScDLNlbtLV8lTJFQVaZcj6M_68-deed0',
      brushId: json['firca_id']?.toString() ?? '',
      currentStreak: json['seri_gun'] ?? 0, // Assuming there might be a pre-calculated streak, or we calculate it
      mascotName: json['maskot_adi']?.toString(),
    );
  }
}
