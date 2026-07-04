import random, string
from django.db import transaction
from django.utils import timezone
    
def generate_referral_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

def handle_booking_completion(user, current_booking_id, user_bookings_queryset):
    """
    Executes reward evaluations upon completing a detailing job.
    user_bookings_queryset should represent the completed bookings of this user.
    """
    from api.models import Referral, UnlockedDiscount, LoyaltyMilestone
    
    current_year = timezone.now().year

    with transaction.atomic():
        completed_this_year = user_bookings_queryset.filter(
            status__code='DELIVERED', 
            created_at__year=current_year 
        ).count()

        if completed_this_year == 10:
            already_awarded = LoyaltyMilestone.objects.filter(user=user, year=current_year, milestone_tier=10).exists()
            if not already_awarded:
                LoyaltyMilestone.objects.create(
                    user=user,
                    year=current_year,
                    milestone_tier=10,
                    coupon_code=f"ELITE10X-{user.id.hex[:4].upper()}-{current_year}"
                )

        referral_record = Referral.objects.filter(referee=user, status='signed_up').first()
        
        if not referral_record:
            return  

        referral_record.status = 'booking_completed'
        referral_record.booking_id = str(current_booking_id)
        referral_record.save()

        parent = referral_record.referrer
        direct_count = Referral.objects.filter(referrer=parent, status='booking_completed').count()

        if direct_count == 3:
            UnlockedDiscount.objects.get_or_create(user=parent, referral_type='direct', milestone_count=3, defaults={'discount_percentage': 20})
        elif direct_count == 5:
            UnlockedDiscount.objects.get_or_create(user=parent, referral_type='direct', milestone_count=5, defaults={'discount_percentage': 30})

        grandparent_referral = Referral.objects.filter(referee=parent).first()
    if grandparent_referral:
        grandparent = grandparent_referral.referrer
        
        parent_referee_ids = Referral.objects.filter(
            referrer=parent
        ).values_list('referee_id', flat=True)
        
        indirect_count = Referral.objects.filter(
            referrer__in=parent_referee_ids,
            status='booking_completed'
        ).values('referee').distinct().count()

        if indirect_count >= 50:
            UnlockedDiscount.objects.get_or_create(user=grandparent, referral_type='indirect', milestone_count=50, defaults={'discount_percentage': 30})
        elif indirect_count >= 25:
            UnlockedDiscount.objects.get_or_create(user=grandparent, referral_type='indirect', milestone_count=25, defaults={'discount_percentage': 20})
        elif indirect_count >= 10:
            UnlockedDiscount.objects.get_or_create(user=grandparent, referral_type='indirect', milestone_count=10, defaults={'discount_percentage': 10})