from rest_framework import viewsets, permissions, generics, status
from rest_framework.decorators import APIView, action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db.models import Q, Sum
from django.shortcuts import get_object_or_404
from django.contrib.auth.models import BaseUserManager
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model

from .models import (
    UserProfile,
    Service, 
    Booking, 
    BookingLog, 
    VehicleCategoryMaster, 
    MasterInvoice,
    InvoiceLineItem,
    CafeItem,
    GamingStation,
    GamingSession,
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
    CafeItemSerializer,
    GamingStationSerializer,
    MasterInvoiceSerializer, 
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

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            print("--- REGISTRATION ERRORS ---", serializer.errors)
        return super().post(request, *args, **kwargs)

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
    Allows Admins/Office to retrieve existing vehicles or assign them to clients.
    """
    serializer_class = GarageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role.code in ['ADMIN', 'OFFICE']:
            return Garage.objects.all().order_by('-created_at')
        return Garage.objects.filter(user=self.request.user).order_by('-created_at')

    def create(self, request, *args, **kwargs):
        license_plate = request.data.get('license_plate', '').upper().replace(" ", "")
        if license_plate:
            existing_garage = Garage.objects.filter(license_plate=license_plate).first()
            if existing_garage:
                serializer = self.get_serializer(existing_garage)
                return Response(serializer.data, status=status.HTTP_200_OK)
        
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        user = self.request.user
        
        if user.role.code in ['ADMIN', 'OFFICE']:
            client_id = self.request.data.get('user')
            is_guest = self.request.data.get('is_guest', False)
            
            if is_guest or (not client_id):
                user, _ = User.objects.get_or_create(
                    email='anonymous@refurbnation.com', 
                    defaults={'first_name': 'Anonymous', 'role': RoleMaster.objects.get(code='USER')}
                )
            elif client_id:
                user = User.objects.get(id=client_id)

        serializer.save(user=user)

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
        booking_source = serializer.validated_data.get('booking_source', 'ONLINE')
        
        is_guest = serializer.validated_data.pop('is_guest', False)
        client_id = serializer.validated_data.pop('client_id', None)
        
        assigned_user = self.request.user
        
        if booking_source == 'OFFLINE':
            if is_guest:
                assigned_user, _ = User.objects.get_or_create(
                    email='anonymous@refurbnation.com',
                    defaults={'first_name': 'Anonymous', 'role': RoleMaster.objects.get(code='USER')}
                )
            elif client_id:
                assigned_user = User.objects.get(id=client_id)

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

        master_invoice_id = self.request.data.get('master_invoice_id')
        
        if master_invoice_id:
            master_invoice = MasterInvoice.objects.get(id=master_invoice_id)
        else:
            if assigned_user.email == 'anonymous@refurbnation.com':
                # Create a completely isolated tab for this guest
                master_invoice = MasterInvoice.objects.create(user=None, status='OPEN')
            else:
                # Retrieve the user's existing open tab or create one
                master_invoice, _ = MasterInvoice.objects.get_or_create(user=assigned_user, status='OPEN')

        initial_status = BookingStatusMaster.objects.get(code='PENDING')
        booking = serializer.save(
            user=assigned_user, 
            status=initial_status, 
            final_price=calculated_price,
            booking_source=booking_source,
            master_invoice=master_invoice
        )
        
        InvoiceLineItem.objects.create(
            invoice=master_invoice,
            category='DETAILING',
            description=f"Booking #{booking.id}: {service.name}",
            amount=calculated_price
        )

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
            
            if next_stage_code == 'CONFIRMED' and booking.booking_source == 'ONLINE':
                DigitalVoucher.objects.get_or_create(
                    booking=booking, 
                    user=booking.user,
                    defaults={
                        'cafe_discount_percentage': 10,
                        'free_gaming_minutes': 30
                    }
                )

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

    @action(detail=False, methods=['get'], url_path='users', permission_classes=[IsAdminOrOffice])
    def get_users_by_role(self, request):
        target_role = request.query_params.get('role', 'USER')
        search_query = request.query_params.get('search', '').strip()
        users = User.objects.filter(role__code=target_role)
        
        if search_query:
            users = users.filter(
                Q(email__icontains=search_query) |
                Q(username__icontains=search_query) |
                Q(profile__phone_number__icontains=search_query)
            )
            
        return Response(UserSerializer(users, many=True).data)

    @action(detail=False, methods=['post'], url_path='users/rapid-profile', permission_classes=[IsAdminOrOffice])
    def create_rapid_profile(self, request):
        """Allows Office staff to instantly create a customer profile at the counter."""
        first_name = request.data.get('first_name', 'Guest')
        phone_number = request.data.get('phone_number')
        
        if not phone_number:
            return Response({'error': 'Phone number is required for a rapid profile.'}, status=400)

        # Auto-generate a secure dummy email and random password
        dummy_email = f"{phone_number}@guest.refurbnation.com"
        random_password = BaseUserManager().make_random_password()
        
        user_role = RoleMaster.objects.get(code='USER')
        
        try:
            user = User.objects.create_user(
                email=dummy_email, 
                password=random_password, 
                first_name=first_name, 
                role=user_role
            )
            UserProfile.objects.create(user=user, phone_number=phone_number)
            
            return Response({
                'id': user.id, 
                'email': user.email, 
                'first_name': user.first_name,
                'phone_number': phone_number
            }, status=201)
            
        except Exception as e:
            return Response({'error': str(e)}, status=400)

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

# ==========================================
# CAFE & GAMING DIRECTORY VIEWS
# ==========================================
class CafeItemViewSet(viewsets.ModelViewSet):
    serializer_class = CafeItemSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOfficeOrReadOnly]

    def get_queryset(self):
        if self.request.user.role.code in ['ADMIN', 'OFFICE']:
            return CafeItem.objects.all().order_by('category', 'name')
        return CafeItem.objects.filter(is_available=True).order_by('category', 'name')

class GamingStationViewSet(viewsets.ModelViewSet):
    serializer_class = GamingStationSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOfficeOrReadOnly]

    def get_queryset(self):
        if self.request.user.role.code in ['ADMIN', 'OFFICE']:
            return GamingStation.objects.all().order_by('name')
        return GamingStation.objects.filter(is_active=True).order_by('name')
    
# ==========================================
# MASTER INVOICE & POS ACTION CONTROLLER
# ==========================================
class MasterInvoiceViewSet(viewsets.ModelViewSet):
    queryset = MasterInvoice.objects.all()
    serializer_class = MasterInvoiceSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOrOffice]

    @action(detail=False, methods=['post'])
    def get_or_create_tab(self, request):
        """Fetches an open tab for the client, or creates a new one."""
        client_id = request.data.get('client_id')
        is_guest = request.data.get('is_guest', False)
        
        if is_guest:
            invoice = MasterInvoice.objects.create(user=None, status='OPEN')
        else:
            user = User.objects.get(id=client_id)
            invoice, _ = MasterInvoice.objects.get_or_create(user=user, status='OPEN')
            
        return Response(MasterInvoiceSerializer(invoice).data)

    @action(detail=True, methods=['post'])
    def add_cafe_item(self, request, pk=None):
        """Adds a cafe item and auto-calculates voucher discounts."""
        invoice = self.get_object()
        item = CafeItem.objects.get(id=request.data.get('item_id'))
        quantity = int(request.data.get('quantity', 1))
        
        total_price = float(item.price) * quantity
        applied_discount = False
        
        if invoice.user:
            voucher = DigitalVoucher.objects.filter(user=invoice.user, is_cafe_discount_used=False).first()
            if voucher:
                deduction = total_price * (voucher.cafe_discount_percentage / 100.0)
                total_price -= deduction
                voucher.is_cafe_discount_used = True
                voucher.save()
                applied_discount = True
                
        InvoiceLineItem.objects.create(
            invoice=invoice,
            category='CAFE',
            description=f"{quantity}x {item.name} {'(-10% Voucher)' if applied_discount else ''}",
            amount=total_price
        )
        return Response({'status': 'Item added to tab', 'final_price': total_price})

    @action(detail=True, methods=['post'])
    def start_gaming_session(self, request, pk=None):
        """Assigns a console and auto-applies free voucher minutes."""
        invoice = self.get_object()
        station = GamingStation.objects.get(id=request.data.get('station_id'))
        
        free_minutes = 0
        if invoice.user:
            voucher = DigitalVoucher.objects.filter(user=invoice.user, is_gaming_perk_used=False).first()
            if voucher:
                free_minutes = voucher.free_gaming_minutes
                voucher.is_gaming_perk_used = True
                voucher.save()
                
        GamingSession.objects.create(
            invoice=invoice,
            station=station,
            complimentary_minutes_applied=free_minutes
        )
        
        InvoiceLineItem.objects.create(
            invoice=invoice,
            category='GAMING',
            description=f"Console Access: {station.name} ({free_minutes} free mins applied)",
            amount=0.00
        )
        return Response({'status': 'Console assigned', 'free_minutes': free_minutes})

    @action(detail=True, methods=['post'])
    def remove_line_item(self, request, pk=None):
        """Removes a line item from the tab and reverts associated perks or records."""
        invoice = self.get_object()
        item_id = request.data.get('item_id')
        
        try:
            line_item = InvoiceLineItem.objects.get(id=item_id, invoice=invoice)
            
            if line_item.category == 'CAFE' and '(-10% Voucher)' in line_item.description and invoice.user:
                voucher = DigitalVoucher.objects.filter(user=invoice.user).first()
                if voucher:
                    voucher.is_cafe_discount_used = False
                    voucher.save()
                    
            elif line_item.category == 'GAMING':
                session = invoice.gaming_sessions.filter(end_time__isnull=True).first()
                if session:
                    if session.complimentary_minutes_applied > 0 and invoice.user:
                        voucher = DigitalVoucher.objects.filter(user=invoice.user).first()
                        if voucher:
                            voucher.is_gaming_perk_used = False
                            voucher.save()
                    session.delete()
                    
            elif line_item.category == 'DETAILING':
                booking = invoice.bookings.filter(status__code__in=['PENDING', 'AWAITING PAYMENT']).first()
                if booking:
                    booking.delete()
                    
            line_item.delete()
            return Response({'status': 'Item removed successfully'}, status=status.HTTP_200_OK)
            
        except InvoiceLineItem.DoesNotExist:
            return Response({'error': 'Line item not found.'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def finalize_invoice(self, request, pk=None):
        """Stops active gaming sessions, calculates final costs, and locks the bill for payment."""
        invoice = self.get_object()
        
        if invoice.status != 'OPEN':
            return Response({'error': 'Only open tabs can be finalized.'}, status=status.HTTP_400_BAD_REQUEST)

        active_sessions = invoice.gaming_sessions.filter(end_time__isnull=True)
        for session in active_sessions:
            session.end_time = timezone.now()
            session.save()
            
            duration_seconds = (session.end_time - session.start_time).total_seconds()
            billable_minutes = max(0, (duration_seconds / 60.0) - session.complimentary_minutes_applied)
            
            if billable_minutes > 0:
                cost = (float(billable_minutes) / 60.0) * float(session.station.hourly_rate)
                InvoiceLineItem.objects.create(
                    invoice=invoice, category='GAMING',
                    description=f"Gaming Billed: {session.station.name} ({int(billable_minutes)} mins)", amount=round(cost, 2)
                )

        invoice.status = 'AWAITING_PAYMENT'
        invoice.save()
        
        grand_total = invoice.line_items.aggregate(total=Sum('amount'))['total'] or 0.00
        return Response({'status': 'Invoice Finalized', 'grand_total': grand_total})

    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        """Allows office staff to mark the finalized bill as paid via Cash/POS."""
        invoice = self.get_object()
        invoice.status = 'PAID'
        invoice.save()

        associated_booking = invoice.bookings.first()
        if associated_booking and associated_booking.status.code != 'DELIVERED':
            associated_booking.status = BookingStatusMaster.objects.get(code='DELIVERED')
            associated_booking.save()

        return Response({'status': 'Payment complete.'})

class ClientSelfServiceViewSet(viewsets.ViewSet):
    """Secure endpoints for clients to manage their own open tabs and orders."""
    permission_classes = [permissions.IsAuthenticated]

    def _get_active_tab(self, user):
        invoice, _ = MasterInvoice.objects.get_or_create(user=user, status='OPEN')
        return invoice

    @action(detail=False, methods=['get'])
    def my_tab(self, request):
        invoice = self._get_active_tab(request.user)
        return Response(MasterInvoiceSerializer(invoice).data)

    @action(detail=False, methods=['post'])
    def order_cafe_item(self, request):
        invoice = self._get_active_tab(request.user)
        item = CafeItem.objects.get(id=request.data.get('item_id'))
        quantity = int(request.data.get('quantity', 1))
        
        total_price = float(item.price) * quantity
        applied_discount = False
        
        # Check and apply Digital Voucher (10% Off)
        voucher = DigitalVoucher.objects.filter(user=request.user, is_cafe_discount_used=False).first()
        if voucher:
            deduction = total_price * (voucher.cafe_discount_percentage / 100.0)
            total_price -= deduction
            voucher.is_cafe_discount_used = True
            voucher.save()
            applied_discount = True
                
        InvoiceLineItem.objects.create(
            invoice=invoice,
            category='CAFE',
            description=f"App Order: {quantity}x {item.name} {'(-10% Voucher)' if applied_discount else ''}",
            amount=total_price
        )
        return Response({'status': 'Order placed', 'final_price': total_price})

    @action(detail=False, methods=['post'])
    def book_console(self, request):
        invoice = self._get_active_tab(request.user)
        station = GamingStation.objects.get(id=request.data.get('station_id'))
        
        free_minutes = 0
        voucher = DigitalVoucher.objects.filter(user=request.user, is_gaming_perk_used=False).first()
        if voucher:
            free_minutes = voucher.free_gaming_minutes
            voucher.is_gaming_perk_used = True
            voucher.save()
                
        GamingSession.objects.create(
            invoice=invoice,
            station=station,
            complimentary_minutes_applied=free_minutes
        )
        
        InvoiceLineItem.objects.create(
            invoice=invoice,
            category='GAMING',
            description=f"App Reservation: {station.name} ({free_minutes} free mins applied)",
            amount=0.00
        )
        return Response({'status': 'Console reserved', 'free_minutes': free_minutes})

    @action(detail=False, methods=['post'])
    def pay_online(self, request):
        """Allows customers to pay their finalized bill via the app."""
        invoice, _ = MasterInvoice.objects.get_or_create(user=request.user, status__in=['OPEN', 'AWAITING_PAYMENT'])
        
        if invoice.status != 'AWAITING_PAYMENT':
            return Response({'error': 'Bill must be finalized by staff before online payment.'}, status=400)

        invoice.status = 'PAID'
        invoice.save()

        associated_booking = invoice.bookings.first()
        if associated_booking and associated_booking.status.code != 'DELIVERED':
            associated_booking.status = BookingStatusMaster.objects.get(code='DELIVERED')
            associated_booking.save()

        return Response({'status': 'Online Payment Successful'})