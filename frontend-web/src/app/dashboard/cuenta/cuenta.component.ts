import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AuthService } from '../../services/auth.service';

@Component({
    selector: 'app-cuenta',
    standalone: true,
    imports: [CommonModule],
    template: `
    <div class="section-fade">
      <div class="page-header">
        <div>
          <h1>Mi Cuenta</h1>
          <p>Información registrada de tu taller.</p>
        </div>
      </div>

      <div class="account-card">
        <div class="account-avatar">
          {{ datosTaller?.nombre_taller ? datosTaller.nombre_taller.charAt(0).toUpperCase() : 'T' }}
        </div>
        
        <div class="account-fields">
          <div class="account-field">
            <label>NOMBRE DEL TALLER</label>
            <p>{{ datosTaller?.nombre_taller || '—' }}</p>
          </div>
          
          <div class="account-field">
            <label>CORREO ELECTRÓNICO</label>
            <p>{{ datosTaller?.email || '—' }}</p>
          </div>
          
          <div class="account-field">
            <label>TELÉFONO</label>
            <p>{{ datosTaller?.telefono || '—' }}</p>
          </div>
          
          <div class="account-field">
            <label>DIRECCIÓN</label>
            <p>{{ datosTaller?.direccion || '—' }}</p>
          </div>
        </div>
      </div>
    </div>
  `,
    styles: [`
    .section-fade { animation: fadeIn 0.3s ease; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    
    .page-header { margin-bottom: 30px; }
    .page-header h1 { font-size: 28px; font-weight: 700; color: #111827; margin-bottom: 4px; }
    .page-header p { color: #6b7280; font-size: 15px; margin: 0; }
    
    .account-card {
      background: white;
      border-radius: 16px;
      padding: 40px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.04);
      max-width: 600px;
    }
    
    .account-avatar {
      width: 80px;
      height: 80px;
      background-color: #6366f1; /* Morado estilo dashboard */
      color: white;
      font-size: 32px;
      font-weight: bold;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      margin-bottom: 30px;
    }
    
    .account-fields {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    
    .account-field {
      border-bottom: 1px solid #f3f4f6;
      padding-bottom: 16px;
    }
    
    .account-field:last-child {
      border-bottom: none;
      padding-bottom: 0;
    }
    
    .account-field label {
      display: block;
      font-size: 12px;
      font-weight: 600;
      color: #9ca3af;
      margin-bottom: 8px;
      letter-spacing: 0.5px;
    }
    
    .account-field p {
      margin: 0;
      font-size: 16px;
      color: #1f2937;
      font-weight: 500;
    }
  `]
})
export class CuentaComponent implements OnInit {
    datosTaller: any = null;

    constructor(private authService: AuthService) { }

    ngOnInit(): void {
        this.datosTaller = this.authService.getUsuario();
    }
}