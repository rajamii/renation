from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ServiceViewSet, 
    AppointmentSlotViewSet, 
    BookingViewSet, 
    ConfigurationViewSet, 
    AdminDashboardViewSet,
    VehicleCategoryViewSet,
    RegisterView,
    CustomTokenObtainPairView
)
from rest_framework_simplejwt.views import TokenRefreshView

router = DefaultRouter()

# Operational pipelines mapping
router.register(r'services', ServiceViewSet, basename='services')
router.register(r'slots', AppointmentSlotViewSet, basename='slots')
router.register(r'bookings', BookingViewSet, basename='bookings')

# System Configuration lookup mappings
router.register(r'config', ConfigurationViewSet, basename='config')
router.register(r'categories', VehicleCategoryViewSet, basename='categories')

# Custom Admin command console endpoint mappings
router.register(r'admin', AdminDashboardViewSet, basename='admin-dashboard')

urlpatterns = [
    path('', include(router.urls)),
    
    # Token Security Gateway Core Mappings
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
]