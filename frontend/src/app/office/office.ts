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
  }

  getHeaders() {
    return new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
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
    this.updatingAssignedDate = booking.assigned_date || booking.requested_date; // Default to preferred date
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