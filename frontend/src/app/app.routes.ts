import { Routes } from '@angular/router';
import { roleGuard } from './services/auth.guard';
import { AdminComponent } from './admin/admin';
import { LoginComponent } from './login/login';
import { LandingComponent } from './landing/landing';
import { OfficeComponent } from './office/office'; 

export const routes: Routes = [
  { path: '', component: LandingComponent },
  { path: 'login', component: LoginComponent },
  
  // Protected Admin & Office Staff Routes Only
  { 
    path: 'admin', 
    component: AdminComponent, 
    canActivate: [roleGuard(['ADMIN'])] 
  },
  { 
    path: 'office', 
    component: OfficeComponent, 
    canActivate: [roleGuard(['ADMIN', 'OFFICE'])] 
  },

  // Fallback route
  { path: '**', redirectTo: '' }
];