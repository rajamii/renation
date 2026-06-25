# api/views.py
from rest_framework import viewsets, permissions, generics, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model

from .models import Service, AppointmentSlot, Booking, BookingLog, VehicleCategoryMaster, BookingStatusMaster, RoleMaster, ServicePriceMatrix
from .serializers import (
    ServiceMatrixSerializer, 
    AppointmentSlotSerializer, 
    BookingSerializer, 
    VehicleCategoryMasterSerializer, 
    BookingStatusMasterSerializer, 
    UserSerializer,
    RegisterSerializer,
    BookingLogSerializer
)
from .permissions import IsAdminUserRole, IsAdminOrOffice, IsAdminOfficeOrReadOnly

User = get_user_model()

# ==========================================
# 1. AUTHENTICATION & IDENTITY VIEWS
# ==========================================

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Pull role code directly from the master relationship
        token['role'] = user.role.code 
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data['role'] = self.user.role.code
        data['email'] = self.user.email
        return data

class CustomTokenObtainPairView(TokenObtainPairView):
    """Exposes custom JWT payload tokens matching your login interface routing"""
    serializer_class = CustomTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    """Handles new client registration requests across your web app forms"""
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = RegisterSerializer


# ==========================================
# 2. DYNAMIC LOOKUP META ENDPOINTS
# ==========================================

class ConfigurationViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get'])
    def meta_lookup(self, request):
        """Feeds master list parameters direct to frontend form options dynamically"""
        categories = VehicleCategoryMaster.objects.all()
        statuses = BookingStatusMaster.objects.all()
        return Response({
            'categories': VehicleCategoryMasterSerializer(categories, many=True).data,
            'statuses': BookingStatusMasterSerializer(statuses, many=True).data
        })


# ==========================================
# 3. CORE MANAGEMENT CORE BUSINESS VIEWS
# ==========================================

class ServiceMatrixViewSet(viewsets.ModelViewSet):
    queryset = Service.objects.prefetch_related('price_matrix').all()
    serializer_class = ServiceMatrixSerializer

    def get_permissions(self):
        # Allow client roles to view services, but reserve changes for Admin/Office
        if self.action in ['list', 'retrieve']:
            permission_classes = [permissions.IsAuthenticated]
        else:
            permission_classes = [permissions.IsAuthenticated, IsAdminOrOffice]
        return [permission() for permission in permission_classes]

class VehicleCategoryMasterViewSet(viewsets.ModelViewSet):
    queryset = VehicleCategoryMaster.objects.all()
    serializer_class = VehicleCategoryMasterSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOrOffice]

class BookingStatusMasterViewSet(viewsets.ModelViewSet):
    queryset = BookingStatusMaster.objects.all()
    serializer_class = BookingStatusMasterSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOrOffice]

class AppointmentSlotViewSet(viewsets.ModelViewSet):
    queryset = AppointmentSlot.objects.filter(is_active=True)
    serializer_class = AppointmentSlotSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOfficeOrReadOnly]


class BookingViewSet(viewsets.ModelViewSet):
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role_id in ['ADMIN', 'OFFICE']:
            return Booking.objects.all().order_by('-created_at')
        return Booking.objects.filter(user=user).order_by('-created_at')

    def _log_action(self, booking, actor):
        BookingLog.objects.create(
            booking_id=booking.id,
            client_email=booking.user.email,
            service_name=booking.service.name,
            action_by=actor.email,
            status_changed_to=booking.status.name
        )

    def perform_create(self, serializer):
        service = serializer.validated_data.get('service')
        vehicle_category = serializer.validated_data.get('vehicle_category')
        
        try:
            matrix_entry = ServicePriceMatrix.objects.get(service=service, category=vehicle_category)
            calculated_price = matrix_entry.price_in_rupees
        except Exception:
            calculated_price = 0.00

        initial_status = BookingStatusMaster.objects.get(code='PENDING')
        booking = serializer.save(user=self.request.user, status=initial_status, final_price=calculated_price)
        self._log_action(booking, self.request.user)

    @action(detail=True, methods=['patch'], permission_classes=[IsAdminOrOffice])
    def update_status(self, request, pk=None):
        booking = self.get_object()
        new_status_code = request.data.get('status')
        new_timeline = request.data.get('estimated_delivery_timeline')
        slot_id = request.data.get('slot')

        if new_status_code:
            try:
                booking.status = BookingStatusMaster.objects.get(code=new_status_code)
            except BookingStatusMaster.DoesNotExist:
                return Response({'error': 'Invalid Master Status Selection Code'}, status=status.HTTP_400_BAD_REQUEST)
                
        if new_timeline:
            booking.estimated_delivery_timeline = new_timeline
            
        if slot_id:
            booking.slot_id = slot_id
            
        booking.save()
        self._log_action(booking, request.user)
        return Response({'status': 'Tracking data committed successfully'})


# ==========================================
# 4. CUSTOM MANAGEMENT CONSOLE APP ENDPOINTS
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