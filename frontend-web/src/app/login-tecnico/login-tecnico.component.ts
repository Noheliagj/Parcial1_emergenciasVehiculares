import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { HttpClient, HttpClientModule } from '@angular/common/http';

@Component({
  selector: 'app-login-tecnico',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule, HttpClientModule],
  template: `
    <div class="login-container">
      <div class="login-box">
        
        <div style="margin-bottom: 15px; text-align: left;">
          <a routerLink="/" style="text-decoration: none; color: #6366f1; font-weight: 600; cursor: pointer; font-size: 14px;">
            ⬅️ Volver al Inicio
          </a>
        </div>

        <div class="header">
          <span class="icon">👷‍♂️</span>
          <h2>Portal del Técnico</h2>
          <p>Ingresa tus credenciales de acceso</p>
        </div>

        <form (ngSubmit)="ingresar()">
          <div class="form-group">
            <label>Usuario</label>
            <input type="text" name="usuario" [(ngModel)]="credenciales.usuario" placeholder="Ej. Alejandro_1" required>
          </div>

          <div class="form-group">
            <label>Contraseña</label>
            <input type="password" name="contrasena" [(ngModel)]="credenciales.contrasena" placeholder="Tu clave" required>
          </div>

          <button type="submit" class="btn-primary">Entrar a mi turno</button>
        </form>

        <div class="footer-link">
          <a routerLink="/login">¿Eres el administrador del Taller? Entra aquí</a>
        </div>
      </div>
    </div>
  `
  ,  styles: [`
    .login-container { display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f2f5; }
    .login-box { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
    .header { text-align: center; margin-bottom: 30px; }
    .icon { font-size: 40px; }
    h2 { color: #1e1e38; margin: 10px 0 5px; }
    p { color: #6b7280; font-size: 14px; margin: 0; }
    .form-group { margin-bottom: 20px; }
    label { display: block; margin-bottom: 8px; font-weight: bold; color: #374151; font-size: 14px; }
    input { width: 100%; padding: 12px; border: 1px solid #d1d5db; border-radius: 8px; box-sizing: border-box; }
    .btn-primary { width: 100%; padding: 14px; background: #10b981; color: white; border: none; border-radius: 8px; font-weight: bold; font-size: 16px; cursor: pointer; transition: 0.3s; }
    .btn-primary:hover { background: #059669; }
    .footer-link { text-align: center; margin-top: 20px; }
    .footer-link a { color: #6366f1; text-decoration: none; font-size: 14px; font-weight: 500; }
  `]
})
export class LoginTecnicoComponent {
  credenciales = {
    usuario: '',
    contrasena: ''
  };

  constructor(private router: Router, private http: HttpClient) { }

  ingresar() {
    if (this.credenciales.usuario !== '' && this.credenciales.contrasena !== '') {
      // Llamamos directo a la ruta del backend para técnicos
      this.http.post('http://localhost:8000/login-tecnico/', this.credenciales)
        .subscribe({
          next: (res: any) => {
            console.log('Técnico logueado:', res);
            // Guardamos la info del técnico en la memoria
            localStorage.setItem('tecnico', JSON.stringify(res.tecnico));

            // Lo mandamos a su pantalla de trabajo (que armaremos en un momento)
            this.router.navigate(['/tecnico-vista']);
          },
          error: (err: any) => {
            alert('Ups! Usuario o clave incorrectos. Revisa bien cómo te registró tu jefe.');
            console.error(err);
          }
        });
    } else {
      alert('Rellena usuario y contraseña');
    }
  }
}