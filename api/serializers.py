from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    Service, 
    ServicePriceMatrix, 
    VehicleMaster,
    Garage,
    Booking, 
    BookingLog, 
    VehicleCategoryMaster, 
    BookingStatusMaster,
    UnlockedDiscount,
    Referral,
    UserProfile,
    DigitalVoucher
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
    referral_code = serializers.CharField(write_only=True, required=False, allow_blank=True, allow_null=True)
    phone_number = serializers.CharField(write_only=True, required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = User
        fields = ['email', 'password', 'username', 'first_name', 'last_name', 'referral_code', 'phone_number']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        
        referral_code = validated_data.pop('referral_code', None)
        phone_number = validated_data.pop('phone_number', None)
        user = User.objects.create_user(**validated_data)
        
        UserProfile.objects.create(user=user, phone_number=phone_number)

        if referral_code:
            try:
                parent_profile = UserProfile.objects.get(referral_code=referral_code)
                Referral.objects.create(
                    referrer=parent_profile.user,
                    referee=user,
                    status='signed_up'
                )
            except UserProfile.DoesNotExist:
                pass

        return user

class UserProfileSerializer(serializers.ModelSerializer):
    referral_code = serializers.CharField(source='profile.referral_code', read_only=True)
    phone_number = serializers.CharField(source='profile.phone_number', required=False, allow_null=True, allow_blank=True)

    class Meta:
        model = User
        fields = ['email', 'username', 'first_name', 'last_name', 'referral_code', 'phone_number']
        read_only_fields = ['first_name', 'last_name', 'referral_code', 'username']
        
    def update(self, instance, validated_data):
        profile_data = validated_data.pop('profile', {})
        
        instance.email = validated_data.get('email', instance.email)
        instance.save()

        if 'phone_number' in profile_data:
            instance.profile.phone_number = profile_data['phone_number']
            instance.profile.save()

        return instance

# ==========================================
# SYSTEM LOOKUP & MASTER TRACKING SERIALIZERS
# ==========================================

class VehicleMasterSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = VehicleMaster
        fields = ['id', 'brand', 'name', 'category', 'category_name']


class GarageSerializer(serializers.ModelSerializer):
    vehicle_details = VehicleMasterSerializer(source='vehicle', read_only=True)

    class Meta:
        model = Garage
        fields = ['id', 'vehicle', 'vehicle_details', 'license_plate', 'created_at']
        read_only_fields = ['id', 'created_at']

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

class DigitalVoucherSerializer(serializers.ModelSerializer):
    class Meta:
        model = DigitalVoucher
        fields = ['id', 'perk_description', 'is_redeemed', 'created_at']

class BookingSerializer(serializers.ModelSerializer):
    status = serializers.SlugRelatedField(slug_field='code', queryset=BookingStatusMaster.objects.all(), required=False)
    voucher = DigitalVoucherSerializer(read_only=True, allow_null=True)
    garage_vehicle = serializers.PrimaryKeyRelatedField(queryset=Garage.objects.all(), required=True)
    status_name = serializers.CharField(source='status.name', read_only=True)
    service_name = serializers.CharField(source='service.name', read_only=True)
    slot_start = serializers.TimeField(source='slot.start_time', read_only=True)
    slot_end = serializers.TimeField(source='slot.end_time', read_only=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        if request and request.user and not request.user.role_id in ['ADMIN', 'OFFICE']:
            self.fields['garage_vehicle'].queryset = Garage.objects.filter(user=request.user)

    class Meta:
        model = Booking
        fields = '__all__'
        read_only_fields = ['user', 'status', 'final_price', 'payment_window_start']

# ==========================================
# REFERRAL & LOYALTY SERIALIZERS
# ==========================================

class UnlockedDiscountSerializer(serializers.ModelSerializer):
    class Meta:
        model = UnlockedDiscount
        fields = ['referral_type', 'milestone_count', 'discount_percentage', 'is_used', 'unlocked_at']

class RewardSummarySerializer(serializers.Serializer):
    referral_code = serializers.CharField()
    direct_referrals_count = serializers.IntegerField()
    indirect_referrals_count = serializers.IntegerField()
    yearly_bookings_count = serializers.IntegerField()
    unlocked_discounts = UnlockedDiscountSerializer(many=True)
    loyalty_milestones_unlocked = serializers.IntegerField()