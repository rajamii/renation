import uuid
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone
from .utils import generate_referral_code

# ==========================================
# 1. DATABASE CONFIGURATION MASTER TABLES
# ==========================================

class RoleMaster(models.Model):
    """Tracks application tier privileges (USER, OFFICE, ADMIN)"""
    code = models.CharField(max_length=20, unique=True, primary_key=True)
    name = models.CharField(max_length=50)

    def __str__(self):
        return self.name


class VehicleCategoryMaster(models.Model):
    """Tracks shop pricing tiers (HATCHBACK, SEDAN, SUV, etc.)"""
    code = models.CharField(max_length=30, unique=True, primary_key=True)
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name


class BookingStatusMaster(models.Model):
    """Tracks workflow pipelines (PENDING, CONFIRMED, etc.)"""
    code = models.CharField(max_length=30, unique=True, primary_key=True)
    name = models.CharField(max_length=100)
    ui_color_class = models.CharField(max_length=100, default='neutral')

    def __str__(self):
        return self.name

# ==========================================
# 2. CORE IDENTITY ENGINE MANAGERS & MODALS
# ==========================================

class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        
        user_role, _ = RoleMaster.objects.get_or_create(code='USER', defaults={'name': 'User'})
        extra_fields.setdefault('role', user_role)
        
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        
        admin_role, _ = RoleMaster.objects.get_or_create(code='ADMIN', defaults={'name': 'Admin'})
        extra_fields.setdefault('role', admin_role)

        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    role = models.ForeignKey(RoleMaster, on_delete=models.PROTECT, related_name='assigned_users')

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    def __str__(self):
        return f"{self.email} ({self.role_id})"

    
class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    referral_code = models.CharField(max_length=10, unique=True, default=generate_referral_code)

# ==========================================
# 3. WORKSHOP SCHEDULING & PRICE MODELS
# ==========================================

class Service(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    estimated_duration_hours = models.DecimalField(max_digits=4, decimal_places=1, default=1.0)

    def __str__(self):
        return self.name


class ServicePriceMatrix(models.Model):
    """Links service pricing explicitly to vehicle categories (in ₹)"""
    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name='prices')
    category = models.ForeignKey(VehicleCategoryMaster, on_delete=models.CASCADE, related_name='pricing_set')
    price_in_rupees = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        unique_together = ('service', 'category')

    def __str__(self):
        return f"{self.service.name} - {self.category.name}: ₹{self.price_in_rupees}"


class AppointmentSlot(models.Model):
    """Operational booking windows managed by staff users"""
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_capacity = models.PositiveIntegerField(default=1)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['date', 'start_time']

    def __str__(self):
        return f"{self.date} ({self.start_time} - {self.end_time})"


class Booking(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    service = models.ForeignKey(Service, on_delete=models.PROTECT)
    vehicle_category = models.ForeignKey(VehicleCategoryMaster, on_delete=models.PROTECT, related_name='bookings')
    vehicle_make_model = models.CharField(max_length=255)
    vehicle_license_plate = models.CharField(max_length=50, blank=True, null=True)
    requested_date = models.DateField()
    
    slot = models.ForeignKey(AppointmentSlot, on_delete=models.PROTECT, related_name='bookings', blank=True, null=True)
    status = models.ForeignKey(BookingStatusMaster, on_delete=models.PROTECT, related_name='bookings')
    estimated_delivery_timeline = models.CharField(max_length=100, blank=True, null=True)
    final_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class BookingLog(models.Model):
    """System-wide historical workflow audit log engine"""
    booking_id = models.IntegerField()
    client_email = models.EmailField()
    service_name = models.CharField(max_length=100)
    action_by = models.CharField(max_length=255)
    status_changed_to = models.CharField(max_length=50)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']

 # ==========================================
 # 4. REFERRAL & LOYALTY MODELS
 # ==========================================       

class Referral(models.Model):
    STATUS_CHOICES = [
        ('signed_up', 'Signed Up'),
        ('booking_completed', 'Booking Completed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    referrer = models.ForeignKey(User, related_name='referrals_sent', on_delete=models.CASCADE)
    referee = models.OneToOneField(User, related_name='referral_received', on_delete=models.CASCADE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='signed_up')
    booking_id = models.CharField(max_length=100, null=True, blank=True) # First booking ID
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.referrer.username} -> {self.referee.username} ({self.status})"


class UnlockedDiscount(models.Model):
    TYPE_CHOICES = [
        ('direct', 'Direct Referral Reward'),
        ('indirect', 'Indirect Referral Reward'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, related_name='unlocked_discounts', on_delete=models.CASCADE)
    referral_type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    milestone_count = models.IntegerField()  # 3, 5 for direct | 10, 25, 50 for indirect
    discount_percentage = models.IntegerField()  # 10, 20, 30
    is_used = models.BooleanField(default=False)
    unlocked_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'referral_type', 'milestone_count')


class LoyaltyMilestone(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, related_name='loyalty_milestones', on_delete=models.CASCADE)
    year = models.IntegerField(default=timezone.now().year)
    milestone_tier = models.IntegerField(default=10)  # 10 bookings milestone
    coupon_code = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'year', 'milestone_tier')       