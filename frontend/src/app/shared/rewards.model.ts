export interface UnlockedDiscount {
    referral_type: 'direct' | 'indirect';
    milestone_count: number;
    discount_percentage: number;
    is_used: boolean;
    unlocked_at: string;
}

export interface RewardSummary {
    referral_code: string;
    direct_referrals_count: number;
    indirect_referrals_count: number;
    yearly_bookings_count: number;
    unlocked_discounts: UnlockedDiscount[];
    loyalty_milestones_unlocked: number;
}