from rest_framework import viewsets, permissions, generics, status
from rest_framework.decorators import APIView, action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model

from .models import (
    Service, 
    Booking, 
    BookingLog, 
    VehicleCategoryMaster, 
    BookingStatusMaster, 
    RoleMaster, 
    ServicePriceMatrix,
    Referral,
    UnlockedDiscount,
    LoyaltyMilestone,
    VehicleMaster,
    Garage,
    DigitalVoucher,
)
from .serializers import (
    ServiceSerializer, 
    BookingSerializer, 
    VehicleCategoryMasterSerializer, 
    BookingStatusMasterSerializer, 
    UserSerializer,
    RegisterSerializer,
    BookingLogSerializer,
    UserProfileSerializer,
    RewardSummarySerializer,
    VehicleMasterSerializer,
    GarageSerializer
)
from .permissions import IsAdminUserRole, IsAdminOrOffice, IsAdminOfficeOrReadOnly

User = get_user_model()

# ==========================================
# 1. AUTHENTICATION VIEWS
# ==========================================

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role.code 
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data['role'] = self.user.role.code
        data['email'] = self.user.email
        return data

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = RegisterSerializer

class UserProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = UserProfileSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ==========================================
# 2. MASTER REPOSITORIES & METADATA CRUD
# ==========================================

class VehicleCategoryViewSet(viewsets.ModelViewSet):
    """Allows full CRUD operations on size/pricing category master records (Admin Only)"""
    queryset = VehicleCategoryMaster.objects.all()
    serializer_class = VehicleCategoryMasterSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

class VehicleMasterViewSet(viewsets.ModelViewSet):
    """
    Allows Admin to Add/Edit/Delete vehicles.
    Allows Users to GET the list of vehicles for their garage selection.
    """
    queryset = VehicleMaster.objects.all()
    serializer_class = VehicleMasterSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.IsAuthenticated()]
        return [permissions.IsAuthenticated(), IsAdminUserRole()]


class GarageViewSet(viewsets.ModelViewSet):
    """
    Allows Users to manage their personal garage.
    """
    serializer_class = GarageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Garage.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class ConfigurationViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get'])
    def meta_lookup(self, request):
        categories = VehicleCategoryMaster.objects.all()
        statuses = BookingStatusMaster.objects.all()
        return Response({
            'categories': VehicleCategoryMasterSerializer(categories, many=True).data,
            'statuses': BookingStatusMasterSerializer(statuses, many=True).data
        })


# ==========================================
# 3. WORKSHOP CORE BUSINESS WORKFLOW VIEWS
# ==========================================

class ServiceViewSet(viewsets.ModelViewSet):
    """
    Provides complete multi-role menu listing and unified administrative 
    CRUD for treatment models along with tiered price parameters.
    """
    queryset = Service.objects.prefetch_related('prices').all()
    serializer_class = ServiceSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOfficeOrReadOnly]



class BookingViewSet(viewsets.ModelViewSet):
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        two_hours_ago = timezone.now() - timezone.timedelta(hours=2)
        
        expired_bookings = Booking.objects.filter(
            status__code='AWAITING PAYMENT',
            payment_window_start__isnull=False,
            payment_window_start__lt=two_hours_ago
        )
        if expired_bookings.exists():
            cancelled_status = BookingStatusMaster.objects.get(code='CANCELLED')
            expired_bookings.update(status=cancelled_status)

        if user.role_id in ['ADMIN', 'OFFICE']:
            return Booking.objects.select_related('voucher').all().order_by('-created_at')
        return Booking.objects.select_related('voucher').filter(user=user).order_by('-created_at')

    def _log_action(self, booking, actor):
        from .models import BookingLog
        BookingLog.objects.create(
            booking_id=booking.id,
            client_email=booking.user.email,
            service_name=booking.service.name,
            action_by=actor.email,
            status_changed_to=booking.status.name
        )

    def perform_create(self, serializer):
        service = serializer.validated_data.get('service')
        garage_vehicle = serializer.validated_data.get('garage_vehicle')

        try:
            vehicle_category = garage_vehicle.vehicle.category
            matrix_entry = ServicePriceMatrix.objects.get(service=service, category=vehicle_category)
            calculated_price = float(matrix_entry.price_in_rupees)
        except Exception:
            calculated_price = 0.00

        discount_id = self.request.data.get('discount_id')
        if discount_id:
            try:
                discount = UnlockedDiscount.objects.get(id=discount_id, user=self.request.user, is_used=False)
                deduction = (discount.discount_percentage / 100.0) * calculated_price
                calculated_price = calculated_price - deduction
                discount.is_used = True
                discount.save()
            except UnlockedDiscount.DoesNotExist:
                pass

        initial_status = BookingStatusMaster.objects.get(code='PENDING')
        booking = serializer.save(user=self.request.user, status=initial_status, final_price=calculated_price)
        self._log_action(booking, self.request.user)

    @action(detail=True, methods=['patch'], permission_classes=[IsAdminOrOffice])
    def update_status(self, request, pk=None):
        """
        Strict state machine pipeline controller preventing manual status skipping.
        Advances bookings through context-aware sequence mappings cleanly.
        """
        booking = self.get_object()
        current_stage = booking.status.code
        is_cash_payment = request.data.get('cash_payment', False)

        assigned_date = request.data.get('assigned_date')
        assigned_time = request.data.get('assigned_time')
        new_timeline = request.data.get('estimated_delivery_timeline')

        WORKFLOW_MAP = {
            'PENDING': 'AWAITING PAYMENT',
            'AWAITING PAYMENT': 'CONFIRMED',
            'CONFIRMED': 'ARRIVED',
            'ARRIVED': 'WORK IN PROGRESS',
            'WORK IN PROGRESS': 'AWAITING PAYMENT'
        }

        if current_stage == 'AWAITING PAYMENT':
    
            if booking.assigned_date and booking.payment_window_start is None:
                next_stage_code = 'DELIVERED'
            else:
                next_stage_code = 'CONFIRMED' # Initial deposit stage
        else:
            next_stage_code = WORKFLOW_MAP.get(current_stage)

        if not next_stage_code:
            return Response({'error': 'This booking has already reached its final terminal lifecycle state.'}, status=status.HTTP_400_BAD_REQUEST)

        if next_stage_code == 'AWAITING PAYMENT' and current_stage == 'PENDING':
            final_date = assigned_date or booking.assigned_date
            final_time = assigned_time or booking.assigned_time
            if not final_date or not final_time:
                return Response({'error': 'You must assign both a Date and Time block before proceeding.'}, status=status.HTTP_400_BAD_REQUEST)
            
            booking.assigned_date = final_date
            booking.assigned_time = final_time
            booking.payment_window_start = timezone.now()

        elif current_stage == 'AWAITING PAYMENT':
            if not is_cash_payment:
                return Response({'error': 'Online billing steps must be triggered via client application hubs.'}, status=status.HTTP_400_BAD_REQUEST)
            
            if next_stage_code == 'CONFIRMED':
                DigitalVoucher.objects.get_or_create(booking=booking, user=booking.user)

        elif current_stage == 'ARRIVED' and next_stage_code == 'WORK IN PROGRESS':
            booking.payment_window_start = None

        if new_timeline:
            booking.estimated_delivery_timeline = new_timeline

        booking.status = BookingStatusMaster.objects.get(code=next_stage_code)
        booking.save()
        self._log_action(booking, request.user)
        
        return Response({
            'status': 'Workflow advanced successfully',
            'previous_stage': current_stage,
            'current_state': booking.status.code,
            'assigned_date': booking.assigned_date,
            'assigned_time': booking.assigned_time
        }, status=status.HTTP_200_OK)


# ==========================================
# 4. CUSTOM HQ MANAGEMENT CONSOLE APP VIEW
# ==========================================

class AdminDashboardViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated, IsAdminUserRole]

    @action(detail=False, methods=['get'], url_path='users')
    def get_users_by_role(self, request):
        target_role = request.query_params.get('role', 'USER')
        users = User.objects.filter(role__code=target_role)
        return Response(UserSerializer(users, many=True).data)

    @action(detail=False, methods=['post'], url_path='users/office')
    def provision_office_user(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        if not email or not password:
            return Response({'error': 'Missing credentials parameters'}, status=400)
            
        office_role = RoleMaster.objects.get(code='OFFICE')
        user = User.objects.create_user(email=email, password=password, role=office_role)
        return Response(UserSerializer(user).data)

    @action(detail=False, methods=['get'], url_path='logs')
    def view_audit_logs(self, request):
        logs = BookingLog.objects.all()
        return Response(BookingLogSerializer(logs, many=True).data)
    
# ==========================================
# 5. REWARD & LOYALTY TRACKING VIEWS
# ==========================================

class RewardDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        current_year = timezone.now().year

        direct_count = Referral.objects.filter(referrer=user, status='booking_completed').count()
        
        indirect_count = Referral.objects.filter(
            status='booking_completed',
            referrer__in=Referral.objects.filter(referrer=user).values_list('referee_id', flat=True)
        ).count()

        yearly_bookings = Booking.objects.filter(
            user=user, 
            status__code='DELIVERED', 
            created_at__year=current_year
        ).count()

        unlocked = UnlockedDiscount.objects.filter(user=user)
        loyalty_count = LoyaltyMilestone.objects.filter(user=user, year=current_year).count()

        data = {
            'referral_code': user.profile.referral_code,
            'direct_referrals_count': direct_count,
            'indirect_referrals_count': indirect_count,
            'yearly_bookings_count': yearly_bookings,
            'unlocked_discounts': unlocked,
            'loyalty_milestones_unlocked': loyalty_count
        }

        serializer = RewardSummarySerializer(data)
        return Response(serializer.data)


class ApplyDiscountView(APIView):
    """Consumes an UnlockedDiscount during checkout"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        discount_id = request.data.get('discount_id')
        cart_total = request.data.get('cart_total')
        
        if not discount_id or not cart_total:
            return Response({"error": "Missing parameters"}, status=status.HTTP_400_BAD_REQUEST)

        discount = get_object_or_404(UnlockedDiscount, id=discount_id, user=request.user, is_used=False)

        deduction_amount = (discount.discount_percentage / 100.0) * float(cart_total)
        new_total = float(cart_total) - deduction_amount

        discount.is_used = True
        discount.save()

        return Response({
            "message": "Discount applied successfully!",
            "discount_percentage": discount.discount_percentage,
            "deduction_amount": deduction_amount,
            "new_total": new_total
        })