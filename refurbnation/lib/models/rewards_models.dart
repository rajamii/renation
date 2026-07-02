class UnlockedDiscount {
  final String id;
  final String referralType;
  final int milestoneCount;
  final int discountPercentage;
  final bool isUsed;
  final DateTime unlockedAt;

  UnlockedDiscount({
    required this.id,
    required this.referralType,
    required this.milestoneCount,
    required this.discountPercentage,
    required this.isUsed,
    required this.unlockedAt,
  });

  factory UnlockedDiscount.fromJson(Map<String, dynamic> json) {
    return UnlockedDiscount(
      id: json['id'],
      referralType: json['referral_type'],
      milestoneCount: json['milestone_count'],
      discountPercentage: json['discount_percentage'],
      isUsed: json['is_used'],
      unlockedAt: DateTime.parse(json['unlocked_at']),
    );
  }
}
