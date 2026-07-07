import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import * as QRCode from 'qrcode';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';
import { AdminComponent } from '../admin/admin';
import { OfficeComponent } from '../office/office';
import { RewardSummary } from '../shared/rewards.model';
import { Observable } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule, AdminComponent, OfficeComponent],
  templateUrl: './dashboard.html'
})
export class DashboardComponent implements OnInit {
  rewardSummary: RewardSummary | null = null;
  isLoading = true;
  userRole: 'ADMIN' | 'OFFICE' | 'USER' | null = null;
  userEmail: string = '';

  servicesList: any[] = [];
  userBookings: any[] = [];
  availableSlots: any[] = [];

  userGarage: any[] = [];
  lookupVehiclesCatalog: any[] = [];
  uniqueBrands: string[] = [];
  filteredModels: any[] = [];

  selectedStatusFilter: string = 'CONFIRMED';

  activeTab: 'bookings' | 'garage' | 'rewards' = 'bookings';

  bookingForm = {
    service: '',
    garage_vehicle: '',
    requested_date: '',
    slot: ''
  };

  garagePayload = { brand: '', vehicle: '', license_plate: '' };
  selectedDiscountId: string | null = null;
  selectedDiscountPercentage: number = 0;

  showQrModal = false;
  selectedBookingId: string | null = null;
  qrCodeDataUrl: string = '';

  successMessage = '';
  errorMessage = '';

  constructor(
    private authService: AuthService,
    private apiService: ApiService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit() {
    const role = localStorage.getItem('role');
    const email = localStorage.getItem('email');

    if (!role) {
      this.authService.logout();
      this.router.navigate(['/login']);
      return;
    }

    this.userRole = role as 'ADMIN' | 'OFFICE' | 'USER';
    this.userEmail = email || 'Client Account';

    if (this.userRole === 'USER') {
      this.loadFormMetadata();
      this.loadUserBookings();
      this.fetchRewards();
      this.fetchUserGarage();
      this.fetchCatalogLookups();
    }
  }

  setTab(tabName: 'bookings' | 'garage' | 'rewards') {
    this.activeTab = tabName;
    this.selectedStatusFilter = 'CONFIRMED';
    this.cdr.detectChanges();
  }

  getFilteredBookings(): any[] {
    if (this.selectedStatusFilter === 'ALL') {
      return this.userBookings;
    }
    return this.userBookings.filter(booking => booking.status === this.selectedStatusFilter);
  }

  loadFormMetadata() {
    this.apiService.get<any[]>('/services/').subscribe({
      next: (data) => {
        this.servicesList = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load services index menu', err)
    });
  }

  fetchUserGarage() {
    this.apiService.get<any[]>('/garage/').subscribe({
      next: (data) => {
        this.userGarage = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to fetch user garage references', err)
    });
  }

  fetchCatalogLookups() {
    this.apiService.get<any[]>('/vehicles/').subscribe({
      next: (data) => {
        this.lookupVehiclesCatalog = data || [];
        const brandsSet = new Set(this.lookupVehiclesCatalog.map(car => car.brand));
        this.uniqueBrands = Array.from(brandsSet).sort();
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to pull master car models', err)
    });
  }

  onBrandChange() {
    this.filteredModels = [];
    this.garagePayload.vehicle = '';
    if (!this.garagePayload.brand) return;

    this.filteredModels = this.lookupVehiclesCatalog
      .filter(car => car.brand === this.garagePayload.brand)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  onFilterChange() {
    this.cdr.detectChanges();
  }

  addCarToGarage() {
    if (!this.garagePayload.vehicle || !this.garagePayload.license_plate) return;

    const formattedPayload = {
      vehicle: this.garagePayload.vehicle,
      license_plate: this.garagePayload.license_plate.toUpperCase().replace(/\s+/g, '')
    };

    this.apiService.post('/garage/', formattedPayload).subscribe({
      next: () => {
        this.fetchUserGarage();
        this.garagePayload = { brand: '', vehicle: '', license_plate: '' };
        this.filteredModels = [];
        this.successMessage = 'Vehicle added to your garage successfully!';
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: (err) => {
        alert(err.error?.license_plate?.[0] || 'This license plate identifier is already taken.');
      }
    });
  }

  getRewardSummary(): Observable<RewardSummary> {
    return this.apiService.get<RewardSummary>('/rewards/dashboard/');
  }

  fetchRewards(): void {
    this.getRewardSummary().subscribe({
      next: (data) => {
        this.rewardSummary = data;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load rewards dashboard payload', err);
        this.isLoading = false;
      }
    });
  }

  toggleDiscount(discount: any): void {
    if (this.selectedDiscountId === discount.id) {
      this.selectedDiscountId = null;
      this.selectedDiscountPercentage = 0;
    } else {
      this.selectedDiscountId = discount.id;
      this.selectedDiscountPercentage = discount.discount_percentage;
    }
  }

  onDateChange() {
    this.availableSlots = [];
    this.bookingForm.slot = '';

    if (!this.bookingForm.requested_date) return;

    this.apiService.get<any[]>(`/slots/?date=${this.bookingForm.requested_date}`).subscribe({
      next: (data) => {
        this.availableSlots = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load slots for selected date line context', err)
    });
  }

  loadUserBookings() {
    this.apiService.get<any[]>('/bookings/').subscribe({
      next: (data) => {
        this.userBookings = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load user tracking bookings stream', err)
    });
  }

  submitBooking() {
    this.successMessage = '';
    this.errorMessage = '';

    const payload = {
      ...this.bookingForm,
      discount_id: this.selectedDiscountId
    };

    this.apiService.post('/bookings/', payload).subscribe({
      next: () => {
        this.successMessage = 'Your workshop booking was requested successfully!';
        this.bookingForm = { service: '', garage_vehicle: '', requested_date: '', slot: '' };
        this.selectedDiscountId = null;
        this.selectedDiscountPercentage = 0;
        this.availableSlots = [];
        this.loadUserBookings();
        this.fetchRewards();
      },
      error: (err: any) => {
        this.errorMessage = err.error?.error || err.error?.[0] || 'Validation error occurred processing booking parameters.';
      }
    });
  }

  getDirectProgress(): number {
    if (!this.rewardSummary) return 0;
    return Math.min((this.rewardSummary.direct_referrals_count / 5) * 100, 100);
  }

  getIndirectProgress(): number {
    if (!this.rewardSummary) return 0;
    return Math.min((this.rewardSummary.indirect_referrals_count / 50) * 100, 100);
  }

  getLoyaltyProgress(): number {
    if (!this.rewardSummary) return 0;
    return Math.min((this.rewardSummary.yearly_bookings_count / 10) * 100, 100);
  }

  openQrModal(booking: any) {
    const details = booking.garage_vehicle_details?.vehicle_details;
    const plate = booking.garage_vehicle_details?.license_plate || 'N/A';

    const qrTextPayload =
      `Booking ID: #${booking.id}\nVehicle: ${details?.brand || ''} ${details?.name || 'Unknown'}\nLicense Plate: ${plate.toUpperCase()}\nCategory: ${details?.category_name || 'Standard Tier'}\nDate: ${booking.requested_date}\nSlot Reference: Window #${booking.slot}`;

    this.selectedBookingId = String(booking.id);
    this.showQrModal = true;

    QRCode.toDataURL(qrTextPayload, { width: 280, margin: 2 })
      .then(url => {
        this.qrCodeDataUrl = url;
        this.cdr.detectChanges();
      })
      .catch(err => console.error('Error generating barcode string payload mapping', err));
  }

  closeQrModal() {
    this.showQrModal = false;
    this.selectedBookingId = null;
    this.qrCodeDataUrl = '';
    this.cdr.detectChanges();
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}