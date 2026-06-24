from django.shortcuts import render

# Create your views here.
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import get_user_model
from .serializers import RegisterSerializer, UserSerializer, CreateOfficeUserSerializer
from .permissions import IsAdminUserRole

User = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

class AdminCreateOfficeUserView(generics.CreateAPIView):
    permission_classes = [IsAuthenticated, IsAdminUserRole]
    serializer_class = CreateOfficeUserSerializer

class AdminListClientUsersView(generics.ListAPIView):
    permission_classes = [IsAuthenticated, IsAdminUserRole]
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(role=User.Roles.USER)