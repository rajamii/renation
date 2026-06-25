import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { AdminComponent } from '../admin/admin';
import { OfficeComponent } from '../office/office';

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.html',
  standalone: true,
  imports: [CommonModule, RouterModule, AdminComponent, OfficeComponent]
})
export class DashboardComponent implements OnInit {
  userRole: 'ADMIN' | 'OFFICE' | 'USER' | null = null;
  userEmail: string = '';

  constructor(
    private authService: AuthService,
    private router: Router
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
    this.userEmail = email || 'Staff Account';

    // If a standard client somehow hits the /dashboard route directly, 
    // seamlessly route them back to their consumer booking platform view
    if (this.userRole === 'USER') {
      this.router.navigate(['/bookings']);
    }
  }

  logout() {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}