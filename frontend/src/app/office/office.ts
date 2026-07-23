import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { environment } from '../../environments/environments';

@Component({
  selector: 'app-office',
  templateUrl: './office.html',
  standalone: true,
  imports: [FormsModule, CommonModule]
})
export class OfficeComponent implements OnInit {
  bookings: any[] = [];
  statuses: any[] = [];

  isCashOverrideActive: boolean = false;

  selectedBooking: any = null;
  updatingStatus = '';
  updatingTimeline = '';
  updatingAssignedDate = '';
  updatingAssignedTime = '';

  activeTab: string = 'bookings';

  posSearchQuery: string = '';
  posSearchResults: any[] = [];
  selectedPosClient: any = null;
  isGuestCheckout: boolean = false;
  posServices: any[] = [];
  posVehiclesCatalog: any[] = [];
  uniquePosBrands: string[] = [];
  filteredPosModels: any[] = [];

  posCafeMenu: any[] = [];
  posGamingStations: any[] = [];
  activeInvoice: any = null;

  showCafeForm: boolean = false;
  showGamingForm: boolean = false;

  cafePayload = { item_id: '', quantity: 1 };
  gamingPayload = { station_id: '' };

  showOfflineBookingForm: boolean = false;

  offlineBookingPayload = {
    service: '',
    brand: '',
    vehicle: '',
    license_plate: '',
    requested_date: new Date().toISOString().split('T')[0],
    assigned_time: ''
  };

  rapidProfileForm = {
    first_name: '',
    phone_number: ''
  };

  selectedStatusFilter: string = 'PENDING';
  isSyncing: boolean = false;

  newSlot = {
    date: '',
    start_time: '',
    end_time: '',
    max_capacity: 1,
    is_active: true
  };

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit() {
    this.fetchBookings();
    this.loadMetaLookups();
    this.loadPosMasterData();
  }

  getHeaders() {
    return new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
  }

  searchPosClient() {
    if (!this.posSearchQuery.trim()) return;
    this.http.get(`${environment.apiUrl}/admin/users/?role=USER&search=${this.posSearchQuery}`, { headers: this.getHeaders() })
      .subscribe({
        next: (results: any) => {
          this.posSearchResults = results;
          this.cdr.detectChanges();
        },
        error: (err) => alert('Search failed.')
      });
  }

  selectPosClient(client: any) {
    this.selectedPosClient = client;
    this.isGuestCheckout = false;
    this.posSearchResults = [];
    this.fetchActiveTab();
  }

  submitRapidProfile() {
    if (!this.rapidProfileForm.phone_number) {
      alert("Phone number is required for a rapid profile.");
      return;
    }

    this.http.post(`${environment.apiUrl}/admin/users/rapid-profile/`, this.rapidProfileForm, { headers: this.getHeaders() })
      .subscribe({
        next: (newClient: any) => {
          this.selectedPosClient = newClient;
          this.isGuestCheckout = false;
          this.rapidProfileForm = { first_name: '', phone_number: '' };
          this.cdr.detectChanges();
        },
        error: (err: any) => alert('Failed to create rapid profile: ' + (err.error?.error || 'Unknown error'))
      });
  }

  enableGuestCheckout() {
    this.selectedPosClient = { first_name: 'Anonymous', email: 'Walk-In Guest' };
    this.isGuestCheckout = true;
    this.fetchActiveTab();
  }

  resetPos() {
    this.selectedPosClient = null;
    this.isGuestCheckout = false;
    this.posSearchQuery = '';
    this.posSearchResults = [];
  }

  loadPosMasterData() {
    this.http.get(`${environment.apiUrl}/services/`, { headers: this.getHeaders() })
      .subscribe((data: any) => this.posServices = data);

    this.http.get(`${environment.apiUrl}/vehicles/`, { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.posVehiclesCatalog = data;
        const brands = new Set(this.posVehiclesCatalog.map(v => v.brand));
        this.uniquePosBrands = Array.from(brands).sort() as string[];
      });

    this.http.get(`${environment.apiUrl}/cafe/`, { headers: this.getHeaders() }).subscribe((data: any) => this.posCafeMenu = data);

    this.http.get(`${environment.apiUrl}/gaming/`, { headers: this.getHeaders() }).subscribe((data: any) => this.posGamingStations = data);
  }

  onPosBrandChange() {
    this.offlineBookingPayload.vehicle = '';
    if (!this.offlineBookingPayload.brand) return;
    this.filteredPosModels = this.posVehiclesCatalog
      .filter(v => v.brand === this.offlineBookingPayload.brand)
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  fetchActiveTab() {
    const payload = {
      client_id: this.selectedPosClient?.id,
      is_guest: this.isGuestCheckout
    };
    this.http.post(`${environment.apiUrl}/invoices/get_or_create_tab/`, payload, { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.activeInvoice = data;
        this.cdr.detectChanges();
      });
  }

  addCafeItem() {
    if (!this.cafePayload.item_id || !this.activeInvoice) return;

    this.http.post(`${environment.apiUrl}/invoices/${this.activeInvoice.id}/add_cafe_item/`, this.cafePayload, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          alert('Added to Tab! System checked for discounts automatically.');
          this.showCafeForm = false;
          this.cafePayload = { item_id: '', quantity: 1 };
          this.fetchActiveTab();
        },
        error: (err) => alert('Failed to add item.')
      });
  }

  assignConsole() {
    if (!this.gamingPayload.station_id || !this.activeInvoice) return;

    this.http.post(`${environment.apiUrl}/invoices/${this.activeInvoice.id}/start_gaming_session/`, this.gamingPayload, { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          alert(`Console Assigned! ${res.free_minutes} free minutes applied from voucher if applicable.`);
          this.showGamingForm = false;
          this.gamingPayload.station_id = '';
          this.fetchActiveTab();
        },
        error: (err) => alert('Failed to assign console.')
      });
  }

  get invoiceTotal(): number {
    if (!this.activeInvoice || !this.activeInvoice.line_items) return 0;
    return this.activeInvoice.line_items.reduce((sum: number, item: any) => sum + parseFloat(item.amount), 0);
  }

  removeLineItem(itemId: number) {
    if (!confirm('Are you sure you want to remove this item from the tab?')) return;

    this.http.post(`${environment.apiUrl}/invoices/${this.activeInvoice.id}/remove_line_item/`, { item_id: itemId }, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.fetchActiveTab();
          this.fetchBookings();
        },
        error: (err) => alert('Failed to remove item: ' + (err.error?.error || 'Unknown error'))
      });
  }

  finalizeTab() {
    if (!this.activeInvoice) return;
    this.http.post(`${environment.apiUrl}/invoices/${this.activeInvoice.id}/finalize_invoice/`, {}, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          alert('Bill Finalized! Timers stopped. Waiting for payment.');
          this.fetchActiveTab();
        },
        error: (err) => alert('Failed to finalize: ' + (err.error?.error || 'Unknown error'))
      });
  }

  markPaidCash() {
    if (!this.activeInvoice) return;
    this.http.post(`${environment.apiUrl}/invoices/${this.activeInvoice.id}/mark_paid/`, {}, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          alert('Payment Collected & Tab Closed!');
          this.resetPos();
          this.fetchBookings();
        },
        error: (err) => alert('Failed to process payment.')
      });
  }

  submitOfflineBooking() {
    if (!this.selectedPosClient) return;

    const garagePayload = {
      vehicle: this.offlineBookingPayload.vehicle,
      license_plate: this.offlineBookingPayload.license_plate.toUpperCase().replace(/\s+/g, ''),
      user: this.selectedPosClient.id,
      is_guest: this.isGuestCheckout
    };

    this.http.post(`${environment.apiUrl}/garage/`, garagePayload, { headers: this.getHeaders() })
      .subscribe({
        next: (garageResponse: any) => {
          const bookingPayload = {
            service: this.offlineBookingPayload.service,
            garage_vehicle: garageResponse.id,
            requested_date: this.offlineBookingPayload.requested_date,
            assigned_date: this.offlineBookingPayload.requested_date,
            assigned_time: this.offlineBookingPayload.assigned_time,
            booking_source: 'OFFLINE',
            is_guest: this.isGuestCheckout,
            client_id: this.selectedPosClient.id,
            master_invoice_id: this.activeInvoice ? this.activeInvoice.id : null // FIX: Pass the running tab ID
          };

          this.http.post(`${environment.apiUrl}/bookings/`, bookingPayload, { headers: this.getHeaders() })
            .subscribe({
              next: () => {
                alert('Offline Booking Added to Invoice!');
                this.showOfflineBookingForm = false;
                this.fetchBookings();
                this.fetchActiveTab();
              },
              error: (err) => alert('Booking Failed: ' + (err.error?.error || 'Validation error'))
            });
        },
        error: (err) => alert('Failed to register vehicle plate. Please check your network.')
      });
  }

  fetchBookings() {
    this.isSyncing = true;
    this.cdr.detectChanges();

    this.http.get(`${environment.apiUrl}/bookings/`, { headers: this.getHeaders() })
      .subscribe({
        next: (data: any) => {
          this.bookings = data;
          this.isSyncing = false;
          this.cdr.detectChanges();
        },
        error: (err) => {
          console.error('Failed to sync workflow logs', err);
          this.isSyncing = false;
          this.cdr.detectChanges();
        }
      });
  }

  getFilteredBookings(): any[] {
    if (this.selectedStatusFilter === 'ALL') {
      return this.bookings;
    }
    return this.bookings.filter(b => b.status === this.selectedStatusFilter);
  }


  loadMetaLookups() {
    this.http.get(`${environment.apiUrl}/config/meta_lookup/`, { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.statuses = res.statuses;
        this.cdr.detectChanges();
      });
  }

  openUpdateModal(booking: any) {
    this.selectedBooking = booking;
    this.updatingStatus = booking.status;
    this.isCashOverrideActive = false;
    this.updatingTimeline = booking.estimated_delivery_timeline || '';
    this.updatingAssignedDate = booking.assigned_date || booking.requested_date;
    this.updatingAssignedTime = booking.assigned_time || booking.requested_time || '';
  }

  closeModal() {
    this.selectedBooking = null;
  }

  submitStatusUpdate() {
    if (!this.selectedBooking) return;

    // Frontend pre-validation tracking checks
    if (this.selectedBooking.status === 'PENDING' && (!this.updatingAssignedDate || !this.updatingAssignedTime)) {
      alert('You must provide explicit scheduling coordinates to advance a new request.');
      return;
    }

    if (this.selectedBooking.status === 'AWAITING PAYMENT' && !this.isCashOverrideActive) {
      alert('Please check the Bypass confirmation toggle box to manually log over-the-counter physical cash settlements.');
      return;
    }

    const payload = {
      cash_payment: this.isCashOverrideActive,
      estimated_delivery_timeline: this.updatingTimeline,
      assigned_date: this.updatingAssignedDate,
      assigned_time: this.updatingAssignedTime
    };

    this.http.patch(`${environment.apiUrl}/bookings/${this.selectedBooking.id}/update_status/`, payload, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.fetchBookings();
          this.closeModal();
        },
        error: (err) => alert('Transition blocked: ' + (err.error?.error || 'Server validation error'))
      });
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}