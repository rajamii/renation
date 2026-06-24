import { Component, inject, OnInit, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './admin.html',
  styleUrl: './admin.scss'
})
export class AdminComponent implements OnInit {
  private http = inject(HttpClient);
  
  activeTab = signal<'clients' | 'create-office'>('clients');
  clients = signal<any[]>([]);
  officeData = { email: '', password: '', first_name: '', last_name: '' };

  ngOnInit() {
    this.loadClients();
  }

  loadClients() {
    this.http.get<any[]>('http://localhost:8000/api/admin/clients/').subscribe(data => this.clients.set(data));
  }

  onCreateOffice() {
    this.http.post('http://localhost:8000/api/admin/create-office/', this.officeData).subscribe({
      next: () => {
        alert('Office personnel configured successfully.');
        this.officeData = { email: '', password: '', first_name: '', last_name: '' };
        this.activeTab.set('clients');
      }
    });
  }
}