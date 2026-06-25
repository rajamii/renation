import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { AuthService } from '../services/auth.service';
import { AdminComponent } from '../admin/admin';
import { OfficeComponent } from '../office/office';
import { environment } from '../../environments/environments';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule, AdminComponent, OfficeComponent],
  templateUrl: './dashboard.html'
})
export class DashboardComponent implements OnInit {
  private apiUrl = environment.apiUrl;
  
  userRole: 'ADMIN' | 'OFFICE' | 'USER' | null = null;
  userEmail: string = '';

  servicesList: any[] = [];
  categoriesList: any[] = [];
  userBookings: any[] = [];
  availableSlots: any[] = []; // <-- Holds the slots filtered by date

  bookingForm = {
    service: '',
    vehicle_category: '',
    vehicle_make_model: '',
    vehicle_license_plate: '',
    requested_date: '',
    slot: '' // <-- Added slot property to the submission payload
  };

  successMessage = '';
  errorMessage = '';

  constructor(
    private authService: AuthService,
    private router: Router,
    private http: HttpClient
  ) {}

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
    }
  }

  loadFormMetadata() {
    const headers = new HttpHeaders({
      'Authorization': `Bearer ${localStorage.getItem('access')}`
    });

    this.http.get<any>(`${this.apiUrl}/config/meta_lookup/`, { headers }).subscribe({
      next: (data) => { this.categoriesList = data.categories || []; },
      error: (err) => console.error('Failed to load categories', err)
    });

    this.http.get<any[]>(`${this.apiUrl}/services/`, { headers }).subscribe({
      next: (data) => { this.servicesList = data || []; },
      error: (err) => console.error('Failed to load services', err)
    });
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

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}