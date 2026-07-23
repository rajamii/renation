import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-login',
  templateUrl: './login.html',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink]
})
export class LoginComponent {
  // This defines the toggle state for the view
  isLogin = true;

  // Form input bindings
  email = '';
  password = '';
  firstName = '';
  lastName = '';
  username = '';
  phoneNumber = '';
  referralCode = '';

  constructor(
    private authService: AuthService,
    private router: Router
  ) { }

  onSubmit() {
    const credentials = { email: this.email, password: this.password };
    this.authService.login(credentials).subscribe({
      next: () => {
        const role = localStorage.getItem('role');
        if (role === 'ADMIN') {
          this.router.navigate(['/admin']);
        } else if (role === 'OFFICE') {
          this.router.navigate(['/office']);
        } else {
          // If a regular user tries to log into the internal portal:
          alert('This portal is restricted to internal staff. Please use the mobile app or PWA.');
          this.authService.logout();
        }
      },
      error: (err) => console.error('Authentication failed', err)
    });
  }
}