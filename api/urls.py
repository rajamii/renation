from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    ServiceViewSet,
    CafeItemViewSet,
    GamingStationViewSet,
    MasterInvoiceViewSet, 
    BookingViewSet, 
    ConfigurationViewSet, 
    AdminDashboardViewSet,
    VehicleCategoryViewSet,
    RegisterView,
    CustomTokenObtainPairView,
    UserProfileView,
    ApplyDiscountView,
    RewardDashboardView,
    VehicleMasterViewSet,
    GarageViewSet,
    ClientSelfServiceViewSet
)

router = DefaultRouter()

# Operational pipelines mapping
router.register(r'services', ServiceViewSet, basename='services')
router.register(r'bookings', BookingViewSet, basename='bookings')

# System Configuration lookup mappings
router.register(r'config', ConfigurationViewSet, basename='config')
router.register(r'categories', VehicleCategoryViewSet, basename='categories')
router.register(r'vehicles', VehicleMasterViewSet, basename='vehicles')
router.register(r'garage', GarageViewSet, basename='garage')
router.register(r'cafe', CafeItemViewSet, basename='cafe')
router.register(r'gaming', GamingStationViewSet, basename='gaming')
router.register(r'invoices', MasterInvoiceViewSet, basename='invoices')
router.register(r'client-services', ClientSelfServiceViewSet, basename='client-services')

# Custom Admin command console endpoint mappings
router.register(r'admin', AdminDashboardViewSet, basename='admin-dashboard')

urlpatterns = [
    path('', include(router.urls)),
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
    path('auth/profile/', UserProfileView.as_view(), name='auth_profile'),
    path('rewards/dashboard/', RewardDashboardView.as_view(), name='rewards-dashboard'),
    path('rewards/apply-discount/', ApplyDiscountView.as_view(), name='apply-discount'),
]