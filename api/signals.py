from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Booking
from .utils import handle_booking_completion

@receiver(post_save, sender=Booking)
def check_booking_milestones(sender, instance, created, **kwargs):
    if instance.status.code == 'DELIVERED':
        user_bookings = Booking.objects.filter(user=instance.user)
        handle_booking_completion(
            user=instance.user, 
            current_booking_id=instance.id, 
            user_bookings_queryset=user_bookings
        )