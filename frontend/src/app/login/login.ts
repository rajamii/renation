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
  referralCode = '';

  constructor(
    private authService: AuthService, 
    private router: Router
  ) {}

  onSubmit() {
    const credentials = { email: this.email, password: this.password };

    if (this.isLogin) {
      // Execute login sequence using your Signals-based AuthService
      this.authService.login(credentials).subscribe({
        next: () => {
          // Redirect dynamically based on the role your backend sent back
          const role = localStorage.getItem('role');
          if (role === 'ADMIN') this.router.navigate(['/admin']);
          else if (role === 'OFFICE') this.router.navigate(['/office']);
          else this.router.navigate(['/dashboard']);
        },
        error: (err) => console.error('Authentication failed', err)
      });
    } else {
      // Execute signup/registration sequence
      this.authService.register({ ...credentials, referralCode: this.referralCode }).subscribe({
        next: () => {
          // Switch to login view smoothly upon successful registration
          this.isLogin = true;
          this.password = '';
          this.referralCode = '';
        },
        error: (err) => console.error('Registration failed', err)
      });
    }
  }
}