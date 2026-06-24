import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.scss'
})
export class LoginComponent {
  private authService = inject(AuthService);
  private router = inject(Router);

  email = '';
  password = '';

  onSubmit() {
    this.authService.login({ email: this.email, password: this.password }).subscribe({
      next: (user) => {
        if (user.role === 'ADMIN') this.router.navigate(['/admin']);
        else if (user.role === 'OFFICE') this.router.navigate(['/office']);
        else this.router.navigate(['/dashboard']);
      }
    });
  }
}