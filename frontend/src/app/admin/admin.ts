import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-admin',
  templateUrl: './admin.html',
  standalone: true,
  imports: [FormsModule, CommonModule]
})
export class AdminComponent implements OnInit {
  activeTab: 'clients' | 'office' | 'services' | 'logs' = 'clients';
  logs: any[] = [];
  users: any[] = [];
  services: any[] = [];

  newOfficeEmail = '';
  newOfficePassword = '';

  newService = {
    name: '',
    description: '',
    estimated_duration_hours: '1.0'
  };

  categoryPricesForm: any[] = [];

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit() {
    this.loadMasterCategories();
    this.refreshData();
  }

  setTab(tab: 'clients' | 'office' | 'services' | 'logs') {
    this.activeTab = tab;
    this.refreshData();
  }

  getHeaders() {
    return new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
  }

  loadMasterCategories() {
    this.http.get('http://localhost:8000/api/config/meta_lookup/', { headers: this.getHeaders() })
      .subscribe({
        next: (res: any) => {
          this.categoryPricesForm = res.categories.map((c: any) => ({
            category: c.code,
            label: c.name,
            price_in_rupees: null
          }));
        }
      });
  }

  refreshData() {
    if (this.activeTab === 'services') {
      this.fetchServices();
    } else if (this.activeTab === 'logs') {
      this.fetchAuditLogs();
    } else {
      this.fetchUsers();
    }
  }

  fetchUsers() {
    const roleMap = this.activeTab === 'clients' ? 'USER' : 'OFFICE';
    this.http.get(`http://localhost:8000/api/admin/users/?role=${roleMap}`, { headers: this.getHeaders() })
      .subscribe((data: any) => this.users = data);
  }

  createOfficeUser() {
    const payload = { email: this.newOfficeEmail, password: this.newOfficePassword };
    this.http.post('http://localhost:8000/api/admin/users/office/', payload, { headers: this.getHeaders() })
      .subscribe(() => {
        this.fetchUsers();
        this.newOfficeEmail = '';
        this.newOfficePassword = '';
      });
  }

  fetchServices() {
    this.http.get('http://localhost:8000/api/services/', { headers: this.getHeaders() })
      .subscribe((data: any) => this.services = data);
  }

  createServiceType() {
  if (!this.newService.name) return;

  // Gather only categories where a price has been explicitly inserted
  const filteredMatrix = this.categoryPricesForm
    .filter(item => item.price_in_rupees !== null && item.price_in_rupees !== '')
    .map(item => ({
      category: item.category, // e.g., 'HATCHBACK'
      price_in_rupees: item.price_in_rupees
    }));

  // Build the nested matrix payload structure
  const payload = {
    name: this.newService.name,
    description: this.newService.description,
    estimated_duration_hours: this.newService.estimated_duration_hours,
    price_matrix: filteredMatrix // <-- Swapped from 'prices' to match backend field
  };

  this.http.post('http://localhost:8000/api/services/', payload, { headers: this.getHeaders() })
    .subscribe({
      next: () => {
        this.fetchServices(); // Refresh list view
        // Reset primary form properties
        this.newService = { name: '', description: '', estimated_duration_hours: '1.0' };
        // Empty out category value fields
        this.categoryPricesForm.forEach(item => item.price_in_rupees = null);
      },
      error: (err) => console.error('Failed to register service matrix', err)
    });
}

  fetchAuditLogs() {
    this.http.get('http://localhost:8000/api/admin/logs/', { headers: this.getHeaders() })
      .subscribe((data: any) => this.logs = data);
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}