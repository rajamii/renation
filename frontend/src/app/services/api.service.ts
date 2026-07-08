import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environments';

@Injectable({
  providedIn: 'root'
})
export class ApiService {

  private apiUrl: string = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /**
   * Generic GET request
   * @param path The endpoint path (e.g., '/bookings/')
   * @param params Optional query parameters
   */
  get<T>(path: string, params?: HttpParams): Observable<T> {
    return this.http.get<T>(`${this.apiUrl}${path}`, { params });
  }

  /**
   * Generic POST request
   * @param path The endpoint path (e.g., '/bookings/')
   * @param body The data to send
   */
  post<T>(path: string, body: any = {}): Observable<T> {
    return this.http.post<T>(`${this.apiUrl}${path}`, body);
  }

  patch<T>(endpoint: string, payload: any): Observable<T> {
    return this.http.patch<T>(`${this.apiUrl}${endpoint}`, payload);
  }
}