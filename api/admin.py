from django.contrib import admin
from .models import User, Service, ServicePriceMatrix, Booking, BookingLog

class ServicePriceMatrixInline(admin.TabularInline):
    model = ServicePriceMatrix
    extra = 6
    max_num = 6

@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = ('name', 'estimated_duration_hours')
    search_fields = ('name',)
    inlines = [ServicePriceMatrixInline]

@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'garage_vehicle', 'get_vehicle_category', 'final_price', 'status', 'requested_date')
    list_filter = ('status', 'garage_vehicle__vehicle__category', 'requested_date')
    search_fields = ('user__email', 'garage_vehicle__vehicle__brand', 'garage_vehicle__vehicle__name', 'garage_vehicle__license_plate')

    @admin.display(description='Vehicle Category')
    def get_vehicle_category(self, obj):
        return obj.garage_vehicle.vehicle.category.name

admin.site.register(User)
admin.site.register(BookingLog)