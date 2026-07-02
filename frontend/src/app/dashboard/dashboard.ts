import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import * as QRCode from 'qrcode';
import { AuthService } from '../services/auth.service';
import { AdminComponent } from '../admin/admin';
import { OfficeComponent } from '../office/office';
import { environment } from '../../environments/environments';
import { RewardSummary } from '../shared/rewards.model';
import { Observable } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule, AdminComponent, OfficeComponent],
  templateUrl: './dashboard.html'
})
export class DashboardComponent implements OnInit {
  private apiUrl = environment.apiUrl;

  rewardSummary: RewardSummary | null = null;
  isLoading = true;
  userRole: 'ADMIN' | 'OFFICE' | 'USER' | null = null;
  userEmail: string = '';

  servicesList: any[] = [];
  categoriesList: any[] = [];
  userBookings: any[] = [];
  availableSlots: any[] = [];

  bookingForm = {
    service: '',
    vehicle_category: '',
    vehicle_make_model: '',
    vehicle_license_plate: '',
    requested_date: '',
    slot: ''
  };

  selectedDiscountId: string | null = null;
  selectedDiscountPercentage: number = 0;

  showQrModal = false;
  selectedBookingId: string | null = null;
  qrCodeDataUrl: string = '';

  successMessage = '';
  errorMessage = '';

  constructor(
    private authService: AuthService,
    private router: Router,
    private http: HttpClient,
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
    }
  }

  loadFormMetadata() {
    const headers = new HttpHeaders({
      'Authorization': `Bearer ${localStorage.getItem('access')}`
    });

    this.http.get<any>(`${this.apiUrl}/config/meta_lookup/`, { headers }).subscribe({
      next: (data) => {
        this.categoriesList = data.categories || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load categories', err)
    });

    this.http.get<any[]>(`${this.apiUrl}/services/`, { headers }).subscribe({
      next: (data) => {
        this.servicesList = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load services', err)
    });
  }

  getRewardSummary(): Observable<RewardSummary> {
    return this.http.get<RewardSummary>(`${this.apiUrl}/rewards/summary/`, {
      headers: new HttpHeaders({
        'Authorization': `Bearer ${localStorage.getItem('access')}`
      })
    });
  }

  fetchRewards(): void {
    this.getRewardSummary().subscribe({
      next: (data) => {
        this.rewardSummary = data;
        this.isLoading = false;
      },
      error: (err) => {
        console.error('Failed to load rewards', err);
        this.isLoading = false;
      }
    });
  }

  toggleDiscount(discount: any): void {
    if (this.selectedDiscountId === discount.id) {
      // If clicking the already selected discount, unselect it
      this.selectedDiscountId = null;
      this.selectedDiscountPercentage = 0;
    } else {
      // Select the new discount
      this.selectedDiscountId = discount.id;
      this.selectedDiscountPercentage = discount.discount_percentage;
    }
  }

  // Listens for date changes to query slots from the backend matching that day
  onDateChange() {
    this.availableSlots = [];
    this.bookingForm.slot = ''; // Reset slot whenever date shifts

    if (!this.bookingForm.requested_date) return;

    const headers = new HttpHeaders({
      'Authorization': `Bearer ${localStorage.getItem('access')}`
    });

    // Uses the custom list-filtering capability we added to your AppointmentSlotViewSet
    this.http.get<any[]>(`${this.apiUrl}/slots/?date=${this.bookingForm.requested_date}`, { headers }).subscribe({
      next: (data) => {
        this.availableSlots = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load slots for selected date', err)
    });
  }

  loadUserBookings() {
    const headers = new HttpHeaders({
      'Authorization': `Bearer ${localStorage.getItem('access')}`
    });

    this.http.get<any[]>(`${this.apiUrl}/bookings/`, { headers }).subscribe({
      next: (data) => {
        this.userBookings = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => console.error('Failed to load user tracking bookings', err)
    });
  }

  submitBooking() {
    this.successMessage = '';
    this.errorMessage = '';

    const headers = new HttpHeaders({
      'Authorization': `Bearer ${localStorage.getItem('access')}`
    });

    this.http.post(`${this.apiUrl}/bookings/`, this.bookingForm, { headers }).subscribe({
      next: () => {
        this.successMessage = 'Your workshop booking was requested successfully!';
        this.bookingForm = {
          service: '',
          vehicle_category: '',
          vehicle_make_model: '',
          vehicle_license_plate: '',
          requested_date: '',
          slot: ''
        };
        this.availableSlots = [];
        this.loadUserBookings();
      },
      error: (err) => {
        console.error('Booking generation failed', err);
        this.errorMessage = err.error?.error || err.error?.[0] || 'Validation error occurred.';
      }
    });
  }

  // Helper methods to calculate progress bar percentages (capped at 100%)
  getDirectProgress(): number {
    if (!this.rewardSummary) return 0;
    // Max milestone for direct is 5
    return Math.min((this.rewardSummary.direct_referrals_count / 5) * 100, 100);
  }

  getIndirectProgress(): number {
    if (!this.rewardSummary) return 0;
    // Max milestone for indirect is 50
    return Math.min((this.rewardSummary.indirect_referrals_count / 50) * 100, 100);
  }

  getLoyaltyProgress(): number {
    if (!this.rewardSummary) return 0;
    // Loyalty milestone is 10 bookings
    return Math.min((this.rewardSummary.yearly_bookings_count / 10) * 100, 100);
  }


  openQrModal(booking: any) {
    const qrTextPayload =
      `Booking ID: #${booking.id}
      Vehicle: ${booking.vehicle_make_model}
      License Plate: ${booking.vehicle_license_plate}
      Category: ${booking.vehicle_category}
      Date: ${booking.requested_date}
      Slot Reference: Slot #${booking.slot}`;

    this.selectedBookingId = String(booking.id);
    this.showQrModal = true;

    QRCode.toDataURL(qrTextPayload, { width: 280, margin: 2 })
      .then(url => {
        this.qrCodeDataUrl = url;
        this.cdr.detectChanges();
      })
      .catch(err => {
        console.error('Error generating detailed QR code text payload', err);
      });
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