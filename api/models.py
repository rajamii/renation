from django.contrib.auth.models import AbstractUser
from django.db import models
from django.contrib.auth import get_user_model

class User(AbstractUser):
    class Roles(models.TextChoices):
        USER = 'USER', 'User'
        OFFICE = 'OFFICE', 'Office'
        ADMIN = 'ADMIN', 'Admin'
        
    username = None
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=10, choices=Roles.choices, default=Roles.USER)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    def __str__(self):
        return f"{self.email} ({self.role})"
    

User = get_user_model()

class Service(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    estimated_duration_hours = models.DecimalField(max_digits=4, decimal_places=1, default=1.0)

    def __str__(self):
        return self.name

class AppointmentSlot(models.Model):
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_capacity = models.PositiveIntegerField(default=1, help_text="Number of cars that can be detailed in this slot")
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['date', 'start_time']

    def __str__(self):
        return f"{self.date} ({self.start_time} - {self.end_time})"

class Booking(models.Model):
    class BookingStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        CONFIRMED = 'CONFIRMED', 'Confirmed'
        IN_PROGRESS = 'IN_PROGRESS', 'In Progress'
        READY = 'READY', 'Ready for Delivery'
        COMPLETED = 'COMPLETED', 'Completed'
        CANCELLED = 'CANCELLED', 'Cancelled'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    service = models.ForeignKey(Service, on_delete=models.PROTECT)
    slot = models.ForeignKey(AppointmentSlot, on_delete=models.PROTECT, related_name='bookings')
    status = models.CharField(max_length=20, choices=BookingStatus.choices, default=BookingStatus.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.email} - {self.service.name} - {self.status}"