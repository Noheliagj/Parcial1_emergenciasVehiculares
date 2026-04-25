import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms'; 
import { Router, RouterModule } from '@angular/router'; // <--- Añade RouterModule aquí
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-login-taller',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule], // <--- ¡AQUÍ ES CLAVE AGREGARLO!
  templateUrl: './login-taller.html',
  styleUrls: ['./login-taller.scss']
})
export class LoginTaller {
  credenciales = {
    email: '',
    contrasena: ''
  };

  constructor(private router: Router, private authService: AuthService) {}

  ingresar() {
    if (this.credenciales.email !== '' && this.credenciales.contrasena !== '') {

      this.authService.login(this.credenciales.email, this.credenciales.contrasena).subscribe({
        next: (datosReales: any) => { // <-- Le añadimos ": any" por si acaso
          console.log('¡Bienvenida!', datosReales);

          // 1. ✨ ¡AQUÍ ESTÁ LA MAGIA! Guardamos los datos del taller en el navegador
          // Usamos datosReales.datos porque así lo manda tu FastAPI
          if (datosReales && datosReales.datos) {
            localStorage.setItem('taller', JSON.stringify(datosReales.datos));
          }

          // 2. Le decimos a Angular que cambie de pantalla
          this.router.navigate(['/dashboard']);
        },
        error: (err: any) => {
          alert('Ups! Usuario o clave incorrectos');
          console.error(err);
        }
      });

    } else {
      alert('Rellena los campos primero');
    }
  }

  // Opcional: Si prefieres usar (click)="irARegistro()" en vez de routerLink
  irARegistro() {
    this.router.navigate(['/registro']);
  }
}