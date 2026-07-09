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

  // Generic GET request
  get<T>(path: string, params?: HttpParams): Observable<T> {
    return this.http.get<T>(`${this.apiUrl}${path}`, { params });
  }

  // Generic POST request
  post<T>(path: string, body: any = {}): Observable<T> {
    return this.http.post<T>(`${this.apiUrl}${path}`, body);
  }

  // Generic PATCH request
  patch<T>(endpoint: string, payload: any): Observable<T> {
    return this.http.patch<T>(`${this.apiUrl}${endpoint}`, payload);
  }
}