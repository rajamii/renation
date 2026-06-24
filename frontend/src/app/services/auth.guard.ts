import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { AuthService } from './auth.service';

export const roleGuard = (allowedRoles: string[]): CanActivateFn => {
  return () => {
    const authService = inject(AuthService);
    const router = inject(Router);
    const user = authService.currentUser(); // Reads the signal synchronously

    if (user && allowedRoles.includes(user.role)) {
      return true;
    }
    
    router.navigate(['/login']);
    return false;
  };
};