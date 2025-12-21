class BrushingRecord {
  final String id;
  final String? brushId;
  final DateTime createdAt;
  final int durationSeconds;
  final String? userId;

  BrushingRecord({
    required this.id,
    this.brushId,
    required this.createdAt,
    required this.durationSeconds,
    this.userId,
  });

  factory BrushingRecord.fromJson(Map<String, dynamic> json) {
    return BrushingRecord(
      id: json['id'].toString(),
      brushId: json['firca_id']?.toString(), // Changed from brush_id
      createdAt: DateTime.parse(json['created_at']),
      durationSeconds: json['sure'] is int ? json['sure'] : int.tryParse(json['sure']?.toString() ?? '0') ?? 0, 
      userId: null, // Not in DB
    );
  }
}
