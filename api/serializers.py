from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import Service, ServicePriceMatrix, AppointmentSlot, Booking, BookingLog, VehicleCategoryMaster, BookingStatusMaster

User = get_user_model()

# ==========================================
# 1. IDENTITY & PRIVILEGE SERIALIZERS
# ==========================================

class UserSerializer(serializers.ModelSerializer):
    role_code = serializers.CharField(source='role.code', read_only=True)
    role_name = serializers.CharField(source='role.name', read_only=True)

    class Meta:
        model = User
        fields = ('id', 'email', 'role_code', 'role_name', 'date_joined')


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])

    class Meta:
        model = User
        fields = ('email', 'password')

    def create(self, validated_data):
        # Relies on CustomUserManager to bind the default 'USER' role object
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user

# ==========================================
# 2. MASTER TABLE DEFINITION SERIALIZERS
# ==========================================

class VehicleCategoryMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleCategoryMaster
        fields = ['code', 'name']

class BookingStatusMasterSerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingStatusMaster
        fields = ['code', 'name', 'ui_color_class']

# ==========================================
# 3. WORKSHOP TREATMENT MATRIX SERIALIZERS
# ==========================================

class ServicePriceMatrixSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServicePriceMatrix
        fields = ['id', 'category', 'price_in_rupees']

class ServiceMatrixSerializer(serializers.ModelSerializer):
    # This embeds the category-specific pricing array directly inside the Service object
    price_matrix = ServicePriceMatrixSerializer(many=True, required=False)

    class Meta:
        model = Service
        fields = ['id', 'name', 'estimated_duration_hours', 'price_matrix']

    def create(self, validated_data):
        # Extract the price matrix data out of the payload
        matrix_data = validated_data.pop('price_matrix', [])
        # Save the primary Service record
        service = Service.objects.create(**validated_data)
        
        # Iteratively attach the pricing matrix metadata rows
        for item in matrix_data:
            ServicePriceMatrix.objects.create(service=service, **item)
        return service

    def update(self, instance, validated_data):
        matrix_data = validated_data.pop('price_matrix', None)
        
        # Update core service attributes
        instance.name = validated_data.get('name', instance.name)
        instance.estimated_duration_hours = validated_data.get('estimated_duration_hours', instance.estimated_duration_hours)
        instance.save()

        # If a new matrix map is provided, update or overwrite the existing configurations
        if matrix_data is not None:
            # Simple approach: clear out old prices and rebuild the pricing structure
            instance.price_matrix.all().delete()
            for item in matrix_data:
                ServicePriceMatrix.objects.create(service=instance, **item)
                
        return instance


class AppointmentSlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppointmentSlot
        fields = '__all__'

# ==========================================
# 4. INTAKE TRACKING & AUDIT LOG SERIALIZERS
# ==========================================

class BookingSerializer(serializers.ModelSerializer):
    service_name = serializers.CharField(source='service.name', read_only=True)
    vehicle_category_name = serializers.CharField(source='vehicle_category.name', read_only=True)
    status_name = serializers.CharField(source='status.name', read_only=True)
    status_ui_color = serializers.CharField(source='status.ui_color_class', read_only=True)
    
    # Nested inline appointment properties exposed upon office confirmation
    slot_date = serializers.CharField(source='slot.date', read_only=True)
    slot_start_time = serializers.CharField(source='slot.start_time', read_only=True)
    slot_end_time = serializers.CharField(source='slot.end_time', read_only=True)
    
    class Meta:
        model = Booking
        fields = '__all__'
        read_only_fields = ('user', 'status', 'slot', 'estimated_delivery_timeline', 'final_price')


class BookingLogSerializer(serializers.ModelSerializer):
    """Serializes core audit trail metrics direct to custom admin workspace logs view"""
    class Meta:
        model = BookingLog
        fields = '__all__'