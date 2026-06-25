from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ServiceMatrixViewSet, 
    AppointmentSlotViewSet, 
    BookingViewSet, 
    ConfigurationViewSet, 
    AdminDashboardViewSet,
    RegisterView,
    CustomTokenObtainPairView,
    VehicleCategoryMasterViewSet,
    BookingStatusMasterViewSet
)
from rest_framework_simplejwt.views import TokenRefreshView

# Initialize DRF Router Engine
router = DefaultRouter()

# 1. Main Operation Business Pipeline Endpoints
router.register(r'services', ServiceMatrixViewSet, basename='services')
router.register(r'slots', AppointmentSlotViewSet, basename='slots')
router.register(r'bookings', BookingViewSet, basename='bookings')

# 2. Dynamic Configurations Master Lookup Endpoint
router.register(r'config', ConfigurationViewSet, basename='config')

# 3. Custom Admin Command Console Workspace Router Endpoint
router.register(r'admin', AdminDashboardViewSet, basename='admin-dashboard')

router.register(r'services', ServiceMatrixViewSet, basename='service-matrix')
router.register(r'master/vehicle-categories', VehicleCategoryMasterViewSet, basename='master-vehicle-category')
router.register(r'master/booking-statuses', BookingStatusMasterViewSet, basename='master-booking-status')

urlpatterns = [
    # Router endpoints interface mapping
    path('', include(router.urls)),
    
    # Consolidated Token Security Gateway Core Mappings
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
]