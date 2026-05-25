class SeasonalRecommendation {
  final String id;
  final int month;
  final String eventName;
  final String productName;
  final String category;
  final String reason;
  final int urgency;
  final int weeksBefore;

  SeasonalRecommendation({
    required this.id,
    required this.month,
    required this.eventName,
    required this.productName,
    required this.category,
    required this.reason,
    required this.urgency,
    required this.weeksBefore,
  });

  factory SeasonalRecommendation.fromMap(Map<String, dynamic> map) {
    return SeasonalRecommendation(
      id: map['id'],
      month: map['month'],
      eventName: map['event_name'],
      productName: map['product_name'],
      category: map['category'],
      reason: map['reason'],
      urgency: map['urgency'],
      weeksBefore: map['weeks_before'],
    );
  }
}