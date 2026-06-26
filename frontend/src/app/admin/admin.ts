import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
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
  activeTab: 'clients' | 'office' | 'services' | 'categories' | 'logs' = 'clients';
  
  logs: any[] = [];
  users: any[] = [];
  services: any[] = [];
  categories: any[] = [];

  newOfficeEmail = '';
  newOfficePassword = '';

  newCategoryCode = '';
  newCategoryName = '';

  newService = {
    name: '',
    description: '',
    estimated_duration_hours: '1.0'
  };

  // Dropdown Master Source
  dropdownCategories: any[] = [];

  // Temporary local variables for Category and Price selections inside the single creation form
  formCategorySelection = '';
  formPriceSelection: number | null = null;

  // Collection representing the configured matrix inside the creation form before submission
  stagedPrices: any[] = [];

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router,
     private cdr: ChangeDetectorRef
  ) {}

  ngOnInit() {
    this.loadMasterCategories();
    this.refreshData();
  }

  setTab(tab: 'clients' | 'office' | 'services' | 'categories' | 'logs') {
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
          this.dropdownCategories = res.categories;
          this.cdr.detectChanges();
        },
        error: (err) => console.error('Meta lookup initialization failed', err)
      });
  }

  refreshData() {
    if (this.activeTab === 'services') {
      this.fetchServices();
    } else if (this.activeTab === 'categories') {
      this.fetchCategories();
    } else if (this.activeTab === 'logs') {
      this.fetchAuditLogs();
    } else {
      this.fetchUsers();
    }
  }

  // Helper getters to clean label tracking inside form matrix view loops
  getCategoryLabel(code: string): string {
    const found = this.dropdownCategories.find(c => c.code === code);
    return found ? found.name : code;
  }

  // Add category-price parameters directly into the internal form container array list
  addPriceToFormMatrix() {
    if (!this.formCategorySelection || this.formPriceSelection === null) {
      alert('Please select a valid Vehicle Category and type a Price rule first.');
      return;
    }

    // Overwrite duplicates if the same category is assigned twice inside the form
    this.stagedPrices = this.stagedPrices.filter(p => p.category !== this.formCategorySelection);

    this.stagedPrices.push({
      category: this.formCategorySelection,
      price_in_rupees: this.formPriceSelection
    });

    // Reset loop placeholders
    this.formCategorySelection = '';
    this.formPriceSelection = null;
  }

  removePriceFromFormMatrix(index: number) {
    this.stagedPrices.splice(index, 1);
  }

  fetchUsers() {
    const roleMap = this.activeTab === 'clients' ? 'USER' : 'OFFICE';
    this.http.get(`http://localhost:8000/api/admin/users/?role=${roleMap}`, { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.users = data;
        this.cdr.detectChanges();
      });
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
      .subscribe((data: any) => {
        this.services = data;
        this.cdr.detectChanges();
      });
  }

  createServiceType() {
    if (!this.newService.name) return;

    const payload = {
      name: this.newService.name,
      description: this.newService.description,
      estimated_duration_hours: this.newService.estimated_duration_hours,
      prices: this.stagedPrices // Sends the complete matrix map parameters built inside the form
    };

    this.http.post('http://localhost:8000/api/services/', payload, { headers: this.getHeaders() })
      .subscribe({
        next: () => {
          this.fetchServices();
          // Wipe form bindings clean
          this.newService = { name: '', description: '', estimated_duration_hours: '1.0' };
          this.stagedPrices = [];
          this.formCategorySelection = '';
          this.formPriceSelection = null;
        },
        error: (err) => console.error('Failed to register service matrix', err)
      });
  }

  deleteService(serviceId: number) {
    if (!confirm('Are you sure you want to completely delete this service element?')) return;
    this.http.delete(`http://localhost:8000/api/services/${serviceId}/`, { headers: this.getHeaders() })
      .subscribe(() => this.fetchServices());
  }

  fetchCategories() {
    this.http.get('http://localhost:8000/api/categories/', { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.categories = data;
        this.cdr.detectChanges();
      });
  }

  createVehicleCategory() {
    if (!this.newCategoryCode || !this.newCategoryName) return;
    
    const payload = {
      code: this.newCategoryCode.toUpperCase().replace(/\s+/g, '_'),
      name: this.newCategoryName
    };

    this.http.post('http://localhost:8000/api/categories/', payload, { headers: this.getHeaders() })
      .subscribe(() => {
        this.fetchCategories();
        this.loadMasterCategories();
        this.newCategoryCode = '';
        this.newCategoryName = '';
      });
  }

  deleteVehicleCategory(code: string) {
    if (!confirm(`Are you sure you want to delete vehicle category: ${code}?`)) return;
    this.http.delete(`http://localhost:8000/api/categories/${code}/`, { headers: this.getHeaders() })
      .subscribe(() => {
        this.fetchCategories();
        this.loadMasterCategories();
      });
  }

  fetchAuditLogs() {
    this.http.get('http://localhost:8000/api/admin/logs/', { headers: this.getHeaders() })
      .subscribe((data: any) => {
        this.logs = data;
        this.cdr.detectChanges();
      });
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}