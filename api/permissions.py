from rest_framework import permissions

class IsAdminUserRole(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role_id == 'ADMIN')

class IsAdminOrOffice(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role_id in ['ADMIN', 'OFFICE'])

class IsAdminOfficeOrReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return bool(request.user and request.user.is_authenticated and request.user.role_id in ['ADMIN', 'OFFICE'])