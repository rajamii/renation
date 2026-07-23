import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { QRCodeComponent } from 'angularx-qrcode';
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';
import { AdminComponent } from '../admin/admin';
import { OfficeComponent } from '../office/office';
import { RewardSummary } from '../shared/rewards.model';
import { Observable } from 'rxjs';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../environments/environments';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule, AdminComponent, OfficeComponent, QRCodeComponent],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit, OnDestroy {
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
  cafeMenu: any[] = [];
  gamingStations: any[] = [];
  myTab: any = null;
  selectedStatusFilter: string = 'PENDING';
  activeTab: 'bookings' | 'garage' | 'rewards' | 'profile'| 'cafe' | 'gaming' = 'bookings'; 

  profileData = {
    email: '',
    username: '',
    first_name: '',
    last_name: '',
    phone_number: '',
    referral_code: ''
  };
  isEditingProfile = false;
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

  // NEW FEATURES: Global State tracking models
  countdowns: { [key: number]: string } = {};
  timerInterval: any;
  selectedVoucherId: string | null = null; // Used to feed inline QR value tracking cleanly

  constructor(
    private http: HttpClient, // Added for standalone tracking updates
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
      this.fetchUserProfile();

      // NEW: Initialize background window loop to compute payment window countdowns every second
      this.timerInterval = setInterval(() => {
        this.calculateAllCountdowns();
      }, 1000);
    }
  }

  ngOnDestroy() {
    // NEW: Guard memory leaks cleanly
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
    }
  }

  // NEW: Calculate active payment windows
  calculateAllCountdowns() {
    let changesDetected = false;
    this.userBookings.forEach(booking => {
      if (booking.status === 'AWAITING PAYMENT' && booking.payment_window_start) {
        const startTime = new Date(booking.payment_window_start).getTime();
        const expirationTime = startTime + (2 * 60 * 60 * 1000);
        const now = new Date().getTime();
        const difference = expirationTime - now;

        if (difference <= 0) {
          this.countdowns[booking.id] = 'EXPIRED';
          booking.status = 'CANCELLED';
          changesDetected = true;
        } else {
          const minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
          const seconds = Math.floor((difference % (1000 * 60)) / 1000);
          const displayMinutes = minutes < 10 ? `0${minutes}` : `${minutes}`;
          const displaySeconds = seconds < 10 ? `0${seconds}` : `${seconds}`;
          const newString = `${displayMinutes}:${displaySeconds}`;

          if (this.countdowns[booking.id] !== newString) {
            this.countdowns[booking.id] = newString;
            changesDetected = true;
          }
        }
      }
    });
    if (changesDetected) {
      this.cdr.detectChanges();
    }
  }

  executeTokenPayment(bookingId: number) {
    const headers = new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
    this.http.patch(`${environment.apiUrl}/bookings/${bookingId}/update_status/`, { status: 'CONFIRMED' }, { headers })
      .subscribe({
        next: () => {
          this.successMessage = 'Payment successful! Your tracking block has updated to confirmed.';
          this.loadUserBookings();
          this.fetchRewards();
          setTimeout(() => this.successMessage = '', 4000);
        },
        error: (err) => {
          this.errorMessage = 'Payment processing failed: ' + (err.error?.error || 'Gateway Timeout');
          setTimeout(() => this.errorMessage = '', 4000);
        }
      });
  }

  payTabOnline() {
    this.apiService.post('/client-services/pay_online/').subscribe({
      next: () => {
        this.successMessage = 'Payment successful! Tab settled.';
        this.fetchMyTab();
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: () => this.errorMessage = 'Payment failed.'
    });
  }

  
  setTab(tabName: 'bookings' | 'garage' | 'profile' | 'rewards' | 'cafe' | 'gaming') {
    this.activeTab = tabName;
    if (tabName === 'cafe') this.loadCafeMenu();
    if (tabName === 'gaming') this.loadGamingStations();
    this.fetchMyTab();
    this.cdr.detectChanges();
  }

  fetchMyTab() {
    this.apiService.get<any>('/client-services/my_tab/').subscribe(data => this.myTab = data);
  }

  loadCafeMenu() {
    this.apiService.get<any[]>('/cafe/').subscribe(data => {
      this.cafeMenu = data;
      this.cdr.detectChanges();
    });
  }

  loadGamingStations() {
    this.apiService.get<any[]>('/gaming/').subscribe(data => {
      this.gamingStations = data;
      this.cdr.detectChanges();
    });
  }

  orderCafeItem(itemId: string) {
    this.apiService.post('/client-services/order_cafe_item/', { item_id: itemId, quantity: 1 }).subscribe({
      next: () => {
        this.successMessage = 'Order placed and added to your tab!';
        this.fetchMyTab();
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: () => this.errorMessage = 'Failed to place order.'
    });
  }

  reserveConsole(stationId: string) {
    this.apiService.post('/client-services/book_console/', { station_id: stationId }).subscribe({
      next: (res: any) => {
        this.successMessage = `Console reserved! ${res.free_minutes} free minutes applied.`;
        this.fetchMyTab();
        setTimeout(() => this.successMessage = '', 4000);
      },
      error: () => this.errorMessage = 'Failed to reserve console.'
    });
  }

  getFilteredBookings(): any[] {
    if (this.selectedStatusFilter === 'ALL') { return this.userBookings; }
    return this.userBookings.filter(booking => booking.status === this.selectedStatusFilter);
  }

  loadFormMetadata() {
    this.apiService.get<any[]>('/services/').subscribe({
      next: (data) => { this.servicesList = data || []; this.cdr.detectChanges(); },
      error: (err) => console.error('Failed to load services index menu', err)
    });
  }

  fetchUserProfile() {
    this.apiService.get<any>('/auth/profile/').subscribe({
      next: (data) => { if (data) { this.profileData = data; this.userEmail = data.email; localStorage.setItem('email', data.email); } },
      error: (err) => console.error('Failed to resolve profile fields', err)
    });
  }

  saveProfileChanges() {
    this.successMessage = ''; this.errorMessage = '';
    const patchPayload = { email: this.profileData.email, phone_number: this.profileData.phone_number };
    this.apiService.patch<any>('/auth/profile/', patchPayload).subscribe({
      next: (updatedData: any) => {
        this.successMessage = 'Profile data committed successfully!';
        this.profileData = updatedData; this.userEmail = updatedData.email;
        localStorage.setItem('email', updatedData.email); this.isEditingProfile = false;
        this.cdr.detectChanges(); setTimeout(() => this.successMessage = '', 4000);
      },
      error: (err: any) => { this.errorMessage = err.error?.error || 'Failed to update account information profile layers.'; this.cdr.detectChanges(); }
    });
  }

  cancelProfileEditing() { this.isEditingProfile = false; this.fetchUserProfile(); }
  fetchUserGarage() {
    this.apiService.get<any[]>('/garage/').subscribe({
      next: (data) => { this.userGarage = data || []; this.cdr.detectChanges(); },
      error: (err) => console.error('Failed to fetch user garage references', err)
    });
  }

  fetchCatalogLookups() {
    this.apiService.get<any[]>('/vehicles/').subscribe({
      next: (data) => {
        this.lookupVehiclesCatalog = data || [];
        const brandsSet = new Set(this.lookupVehiclesCatalog.map(car => car.brand));
        this.uniqueBrands = Array.from(brandsSet).sort(); this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to pull master car models', err)
    });
  }

  onBrandChange() {
    this.filteredModels = []; this.garagePayload.vehicle = ''; if (!this.garagePayload.brand) return;
    this.filteredModels = this.lookupVehiclesCatalog.filter(car => car.brand === this.garagePayload.brand).sort((a, b) => a.name.localeCompare(b.name));
  }

  onFilterChange() { this.cdr.detectChanges(); }
  addCarToGarage() {
    if (!this.garagePayload.vehicle || !this.garagePayload.license_plate) return;
    const formattedPayload = { vehicle: this.garagePayload.vehicle, license_plate: this.garagePayload.license_plate.toUpperCase().replace(/\s+/g, '') };
    this.apiService.post('/garage/', formattedPayload).subscribe({
      next: () => {
        this.fetchUserGarage(); this.garagePayload = { brand: '', vehicle: '', license_plate: '' }; this.filteredModels = [];
        this.successMessage = 'Vehicle added to your garage successfully!'; setTimeout(() => this.successMessage = '', 4000);
      },
      error: (err) => { alert(err.error?.license_plate?.[0] || 'This license plate identifier is already taken.'); }
    });
  }

  getRewardSummary(): Observable<RewardSummary> { return this.apiService.get<RewardSummary>('/rewards/dashboard/'); }
  fetchRewards(): void {
    this.getRewardSummary().subscribe({
      next: (data) => { this.rewardSummary = data; this.isLoading = false; this.cdr.detectChanges(); },
      error: (err) => { console.error('Failed to load rewards dashboard payload', err); this.isLoading = false; }
    });
  }

  toggleDiscount(discount: any): void {
    if (this.selectedDiscountId === discount.id) { this.selectedDiscountId = null; this.selectedDiscountPercentage = 0; }
    else { this.selectedDiscountId = discount.id; this.selectedDiscountPercentage = discount.discount_percentage; }
  }

  onDateChange() {
    this.availableSlots = []; this.bookingForm.slot = ''; if (!this.bookingForm.requested_date) return;
    this.apiService.get<any[]>(`/slots/?date=${this.bookingForm.requested_date}`).subscribe({
      next: (data) => { this.availableSlots = data || []; this.cdr.detectChanges(); },
      error: (err) => console.error('Failed to load slots for selected date line context', err)
    });
  }

  loadUserBookings() {
    this.apiService.get<any[]>('/bookings/').subscribe({
      next: (data) => { this.userBookings = data || []; this.cdr.detectChanges(); },
      error: (err) => console.error('Failed to load user tracking bookings stream', err)
    });
  }

  submitBooking() {
    this.successMessage = ''; this.errorMessage = '';
    const payload = { ...this.bookingForm, discount_id: this.selectedDiscountId };
    this.apiService.post('/bookings/', payload).subscribe({
      next: () => {
        this.successMessage = 'Your workshop booking was requested successfully!';
        this.bookingForm = { service: '', garage_vehicle: '', requested_date: '', slot: '' };
        this.selectedDiscountId = null; this.selectedDiscountPercentage = 0; this.availableSlots = [];
        this.loadUserBookings(); this.fetchRewards();
      },
      error: (err: any) => { this.errorMessage = err.error?.error || err.error?.[0] || 'Validation error occurred processing booking parameters.'; }
    });
  }

  getDirectProgress(): number { if (!this.rewardSummary) return 0; return Math.min((this.rewardSummary.direct_referrals_count / 5) * 100, 100); }

  getIndirectProgress(): number { if (!this.rewardSummary) return 0; return Math.min((this.rewardSummary.indirect_referrals_count / 50) * 100, 100); }

  getLoyaltyProgress(): number { if (!this.rewardSummary) return 0; return Math.min((this.rewardSummary.yearly_bookings_count / 10) * 100, 100); }

  getVehicleDetails(garageVehicleId: any): any {
    if (!this.userGarage || !garageVehicleId) return null;
    return this.userGarage.find(car => car.id === Number(garageVehicleId));
  }

  openQrModal(booking: any) {
    const matchedVehicle = this.getVehicleDetails(booking.garage_vehicle);

    const details = matchedVehicle?.vehicle_details;
    const plate = matchedVehicle?.license_plate || 'N/A';
    const vehicleName = details ? `${details.brand} ${details.name}` : 'Unknown Vehicle';

    let masterPayload: any = {
      manifest_type: 'STUDIO_PASS',
      booking_id: booking.id,
      service: booking.service_name || 'Workshop Treatment',
      vehicle: vehicleName,
      license_plate: plate.toUpperCase(),
      vehicle_category: details?.category_name || 'Standard Tier',
      schedule: booking.assigned_date ? `${booking.assigned_date} @ ${booking.assigned_time}` : 'PENDING'
    };

    if (booking.voucher) {
      const isFullyRedeemed = booking.voucher.is_cafe_discount_used && booking.voucher.is_gaming_perk_used;
      
      masterPayload.lounge_access = {
        voucher_id: booking.voucher.id,
        perk: `${booking.voucher.cafe_discount_percentage}% Cafe & ${booking.voucher.free_gaming_minutes}m Gaming`,
        status: isFullyRedeemed ? 'REDEEMED' : 'ACTIVE_VALID'
      };
    } else {
      masterPayload.lounge_access = { status: 'NO_VOUCHER_ATTACHED' };
    }

    this.selectedBookingId = JSON.stringify(masterPayload);
    this.showQrModal = true;
    this.cdr.detectChanges();
  }

  closeQrModal() { this.showQrModal = false; this.selectedBookingId = null; this.qrCodeDataUrl = ''; this.cdr.detectChanges(); }

  logout() { this.authService.logout(); this.router.navigate(['/login']); }
}