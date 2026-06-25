from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from .models import (
    Service, 
    ServicePriceMatrix, 
    AppointmentSlot, 
    Booking, 
    BookingLog, 
    VehicleCategoryMaster, 
    BookingStatusMaster
)

User = get_user_model()

# ==========================================
# IDENTITY & AUTHENTICATION SERIALIZERS
# ==========================================

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'role_id']

class RegisterSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['email', 'password']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


# ==========================================
# SYSTEM LOOKUP & MASTER TRACKING SERIALIZERS
# ==========================================

class VehicleCategoryMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleCategoryMaster
        fields = ['code', 'name']

class BookingStatusMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingStatusMaster
        fields = ['code', 'name', 'ui_color_class']

class BookingLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingLog
        fields = '__all__'


# ==========================================
# SERVICE MATRIX WRITABLE NESTED SERIALIZERS
# ==========================================

class ServicePriceMatrixSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = ServicePriceMatrix
        fields = ['id', 'category', 'category_name', 'price_in_rupees']

class ServiceSerializer(serializers.ModelSerializer):
    # 'prices' matches your frontend loops (*ngFor="let p of s.prices")
    prices = ServicePriceMatrixSerializer(many=True, required=False)

    class Meta:
        model = Service
        fields = ['id', 'name', 'description', 'estimated_duration_hours', 'prices']

    def create(self, validated_data):
        prices_data = validated_data.pop('prices', [])
        service = Service.objects.create(**validated_data)
        
        for price_item in prices_data:
            ServicePriceMatrix.objects.create(service=service, **price_item)
        return service

    def update(self, instance, validated_data):
        prices_data = validated_data.pop('prices', None)
        
        # Save flat details
        instance.name = validated_data.get('name', instance.name)
        instance.description = validated_data.get('description', instance.description)
        instance.estimated_duration_hours = validated_data.get('estimated_duration_hours', instance.estimated_duration_hours)
        instance.save()

        # Synchronize pricing matrices safely if explicitly passed
        if prices_data is not None:
            instance.prices.all().delete()
            for price_item in prices_data:
                ServicePriceMatrix.objects.create(service=instance, **price_item)
                
        return instance


# ==========================================
# WORKSHOP CORE OPERATIONAL SERIALIZERS
# ==========================================

class AppointmentSlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppointmentSlot
        fields = '__all__'

class BookingSerializer(serializers.ModelSerializer):
    status_name = serializers.CharField(source='status.name', read_only=True)
    service_name = serializers.CharField(source='service.name', read_only=True)

    class Meta:
        model = Booking
        fields = [
            'id', 'user', 'service', 'service_name', 'vehicle_category', 
            'vehicle_make_model', 'vehicle_license_plate', 'requested_date', 
            'slot', 'status', 'status_name', 'estimated_delivery_timeline', 
            'final_price', 'created_at', 'updated_at'
        ]
        read_only_fields = ['user', 'status', 'final_price']