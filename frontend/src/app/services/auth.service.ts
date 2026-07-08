import { Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { tap } from 'rxjs';
import { environment } from '../../environments/environments';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  
  currentUser = signal<{role: string, email?: string} | null>(null);

  constructor(private http: HttpClient) {
    const role = localStorage.getItem('role');
    if (role) {
      this.currentUser.set({ role });
    }
  }

  login(credentials: any) {
    return this.http.post(`${this.apiUrl}/auth/login/`, credentials).pipe(
      tap((res: any) => {
        localStorage.setItem('access', res.access);
        localStorage.setItem('refresh', res.refresh);
        localStorage.setItem('role', res.role);
        
        this.currentUser.set({ role: res.role, email: res.email });
      })
    );
  }

  register(userData: Record<string, any>) {
    return this.http.post(`${this.apiUrl}/auth/register/`, userData);
  }

  updateProfile(profileData: {email: string, phone_number: string}) {
    return this.http.patch(`${this.apiUrl}/auth/profile/`, profileData);
  }

  logout() {
    localStorage.clear();
    this.currentUser.set(null);
  }
}