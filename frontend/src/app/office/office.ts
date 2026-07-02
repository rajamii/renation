import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { environment } from '../../environments/environment.prod';

@Component({
  selector: 'app-office',
  templateUrl: './office.html',
  standalone: true,
  imports: [FormsModule, CommonModule]
})
export class OfficeComponent implements OnInit {
  bookings: any[] = [];
  slots: any[] = [];
  statuses: any[] = [];
  
  // Slot Creation Form Bindings matching Django models configuration fields
  newSlot = {
    date: '',
    start_time: '',
    end_time: '',
    max_capacity: 1,
    is_active: true
  };

  // State handles tracking active status change overlays
  selectedBooking: any = null;
  updatingStatus = '';
  updatingTimeline = '';
  updatingSlotId: number | null = null;

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit() {
    this.fetchBookings();
    this.fetchSlots();
    this.loadMetaLookups();
  }

  getHeaders() {
    return new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
  }

  fetchBookings() {
    this.http.get(`${environment.apiUrl}/api/bookings/`, { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.bookings = data;
        this.cdr.detectChanges();
      });
  }

  fetchSlots() {
    this.http.get(`${environment.apiUrl}/api/slots/`, { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.slots = data;
        this.cdr.detectChanges();
      });
  }

  loadMetaLookups() {
    this.http.get(`${environment.apiUrl}/api/config/meta_lookup/`, { headers: this.getHeaders() })
      .subscribe((res: any) => {
        this.statuses = res.statuses;
        this.cdr.detectChanges();
      });
  }

  createSlot() {
    if (!this.newSlot.date || !this.newSlot.start_time || !this.newSlot.end_time) return;

    // Standardize time formatting inputs cleanly for Django's TimeField parser validation
    const payload = {
      date: this.newSlot.date,
      start_time: this.newSlot.start_time.length === 5 ? `${this.newSlot.start_time}:00` : this.newSlot.start_time,
      end_time: this.newSlot.end_time.length === 5 ? `${this.newSlot.end_time}:00` : this.newSlot.end_time,
      max_capacity: this.newSlot.max_capacity,
      is_active: true
    };

    this.http.post(`${environment.apiUrl}/api/slots/`, payload, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.fetchSlots();
          // Clear inputs upon execution success
          this.newSlot = { date: '', start_time: '', end_time: '', max_capacity: 1, is_active: true };
        },
        error: (err) => console.error('Failed to provision scheduling slot', err)
      });
  }

  openUpdateModal(booking: any) {
    this.selectedBooking = booking;
    this.updatingStatus = booking.status;
    this.updatingTimeline = booking.estimated_delivery_timeline || '';
    this.updatingSlotId = booking.slot;
  }

  closeModal() {
    this.selectedBooking = null;
  }

  submitStatusUpdate() {
    if (!this.selectedBooking) return;

    const payload = {
      status: this.updatingStatus,
      estimated_delivery_timeline: this.updatingTimeline,
      slot: this.updatingSlotId
    };

    this.http.patch(`${environment.apiUrl}/api/bookings/${this.selectedBooking.id}/update_status/`, payload, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.fetchBookings();
          this.closeModal();
        },
        error: (err) => console.error('Failed to commit operational tracking variables', err)
      });
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}