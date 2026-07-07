import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent, HttpErrorResponse, HttpBackend, HttpClient } from '@angular/common/http';
import { Observable, throwError, BehaviorSubject } from 'rxjs';
import { catchError, switchMap, filter, take } from 'rxjs/operators';
import { AuthService } from './services/auth.service';
import { environment } from '../environments/environments';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  private isRefreshing = false;
  private refreshTokenSubject: BehaviorSubject<string | null> = new BehaviorSubject<string | null>(null);
  private http: HttpClient;

  constructor(private authService: AuthService, private handler: HttpBackend) {
    this.http = new HttpClient(handler);
  }

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const token = localStorage.getItem('access');

    // Only add headers if the token exists
    let authReq = req;
    if (token) {
      authReq = req.clone({
        setHeaders: { Authorization: `Bearer ${token}` }
      });
    }

    return next.handle(authReq).pipe(
      catchError(error => {
        if (error instanceof HttpErrorResponse && error.status === 401 && !req.url.includes('auth/login')) {
          return this.handle401Error(authReq, next);
        }
        return throwError(error);
      })
    );
  }

  private handle401Error(req: HttpRequest<any>, next: HttpHandler) {
    if (!this.isRefreshing) {
      this.isRefreshing = true;
      this.refreshTokenSubject.next(null);

      const refreshToken = localStorage.getItem('refresh');
      return this.http.post(`${environment.apiUrl}/auth/refresh/`, { refresh: refreshToken }).pipe(
        switchMap((res: any) => {
          this.isRefreshing = false;
          localStorage.setItem('access', res.access);
          this.refreshTokenSubject.next(res.access);
          return next.handle(req.clone({
            setHeaders: { Authorization: `Bearer ${res.access}` }
          }));
        }),
        catchError(err => {
          this.isRefreshing = false;
          this.authService.logout();
          return throwError(err);
        })
      );
    }
    return this.refreshTokenSubject.pipe(
      filter(token => token !== null),
      take(1),
      switchMap(token => next.handle(req.clone({
        setHeaders: { Authorization: `Bearer ${token}` }
      })))
    );
  }
}