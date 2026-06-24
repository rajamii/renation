from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView, RegisterView, 
    AdminUserListView, AdminCreateOfficeUserView,
    ServiceViewSet, AppointmentSlotViewSet, BookingViewSet
)

# Initialize the router
router = DefaultRouter()
router.register(r'services', ServiceViewSet, basename='service')
router.register(r'slots', AppointmentSlotViewSet, basename='slot')
router.register(r'bookings', BookingViewSet, basename='booking')

urlpatterns = [
    # Auth & Admin URLs from Phase 1
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/login/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
    path('admin/users/', AdminUserListView.as_view(), name='admin_user_list'),
    path('admin/users/office/', AdminCreateOfficeUserView.as_view(), name='admin_create_office_user'),
    
    # Core Application URLs
    path('', include(router.urls)),
]