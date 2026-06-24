import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';

@Component({
  selector: 'app-admin',
  templateUrl: './admin.html',
  standalone: true,
  imports: [FormsModule, CommonModule]
})
export class AdminComponent implements OnInit {
  activeTab: 'clients' | 'office' = 'clients';
  users: any[] = [];
  newOfficeEmail = '';
  newOfficePassword = '';

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.fetchUsers();
  }

  setTab(tab: 'clients' | 'office') {
    this.activeTab = tab;
    this.fetchUsers();
  }

  getHeaders() {
    return new HttpHeaders().set('Authorization', `Bearer ${localStorage.getItem('access')}`);
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
}