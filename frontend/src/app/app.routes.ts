import { Routes } from '@angular/router';
import { roleGuard } from './services/auth.guard';
import { AdminComponent } from './admin/admin';
import { LoginComponent } from './login/login';
import { LandingComponent } from './landing/landing';
import { OfficeComponent } from './office/office'; 
import { DashboardComponent } from './dashboard/dashboard';

export const routes: Routes = [
  { path: '', component: LandingComponent }, // Public
  { path: 'login', component: LoginComponent }, // Public
  
  // Protected Routes
  { 
    path: 'admin', 
    component: AdminComponent,
    canActivate: [roleGuard(['ADMIN'])] // Only Admin can access
  },
  { 
    path: 'office', 
    component: OfficeComponent, // Replace with your actual office component
    canActivate: [roleGuard(['ADMIN', 'OFFICE'])] // Admins and Office staff can access
  },
  { 
    path: 'dashboard', 
    component: DashboardComponent, // Replace with your actual user dashboard
    canActivate: [roleGuard(['ADMIN', 'OFFICE', 'USER'])] // Any authenticated user
  },
  
  // Fallback route
  { path: '**', redirectTo: '' }
];