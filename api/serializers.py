from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import Service, AppointmentSlot, Booking

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'email', 'role', 'date_joined')
        read_only_fields = ('id', 'role', 'date_joined')

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    
    class Meta:
        model = User
        fields = ('email', 'password')

    def create(self, validated_data):
        # Default registration is for standard 'USER'
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            role=User.Roles.USER
        )
        return user

class AdminCreateOfficeUserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    
    class Meta:
        model = User
        fields = ('email', 'password')

    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            role=User.Roles.OFFICE
        )
        return user
    
class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Service
        fields = '__all__'

class AppointmentSlotSerializer(serializers.ModelSerializer):
    current_bookings = serializers.SerializerMethodField()

    class Meta:
        model = AppointmentSlot
        fields = ['id', 'date', 'start_time', 'end_time', 'max_capacity', 'is_active', 'current_bookings']

    def get_current_bookings(self, obj):
        # Exclude cancelled bookings from the capacity count
        return obj.bookings.exclude(status='CANCELLED').count()

class BookingSerializer(serializers.ModelSerializer):
    service_details = ServiceSerializer(source='service', read_only=True)
    slot_details = AppointmentSlotSerializer(source='slot', read_only=True)

    class Meta:
        model = Booking
        fields = ['id', 'user', 'service', 'slot', 'status', 'created_at', 'updated_at', 'service_details', 'slot_details']
        read_only_fields = ['user', 'status'] # Users shouldn't set their own status directly here