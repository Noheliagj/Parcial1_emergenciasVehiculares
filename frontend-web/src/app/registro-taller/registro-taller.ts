import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-registro-taller',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './registro-taller.html',
  styleUrl: './registro-taller.scss'
})
export class RegistroTallerComponent {

  taller = {
    nombre_taller: '',
    direccion: '',
    telefono: '',
    email: '',
    contrasena: '',
    latitud: 0,   // <-- NUEVO: Listo para recibir el GPS
    longitud: 0   // <-- NUEVO: Listo para recibir el GPS
  };

  // Variable para saber si ya le dio clic al botón del mapa
  ubicacionDetectada: boolean = false;

  // Le decimos al componente que usaremos al cartero
  constructor(private http: HttpClient) { }

  // --- NUEVA FUNCIÓN MÁGICA DE GPS ---
  detectarUbicacion() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          // Guardamos las coordenadas directo en nuestro objeto taller
          this.taller.latitud = position.coords.latitude;
          this.taller.longitud = position.coords.longitude;
          this.ubicacionDetectada = true;

          console.log('📍 Ubicación capturada:', this.taller.latitud, this.taller.longitud);
        },
        (error) => {
          alert("Por favor, acepta los permisos de ubicación en tu navegador para poder registrar el taller.");
        }
      );
    } else {
      alert("Tu navegador no soporta GPS.");
    }
  }

  guardarTaller() {
    // Validación obligatoria: No dejar guardar si no hay GPS
    // (Esto asegura que el CU-17 de asignación inteligente nunca falle por falta de datos)
    if (!this.ubicacionDetectada) {
      alert("⚠️ Por favor, haz clic en 'Detectar mi Ubicación GPS' antes de registrarte.");
      return;
    }

    // El cartero viaja a la ventanilla de FastAPI (puerto 8000)
    this.http.post('http://localhost:8000/talleres/', this.taller).subscribe({

      // Si el Backend responde que todo salió bien:
      next: (respuesta: any) => {
        alert('🎉 ' + respuesta.mensaje);

        // Limpiamos las cajitas y reseteamos el GPS después de guardar
        this.taller = { nombre_taller: '', direccion: '', telefono: '', email: '', contrasena: '', latitud: 0, longitud: 0 };
        this.ubicacionDetectada = false;
      },

      // Si hay un error (ej. el backend está apagado o correo repetido):
      error: (error) => {
        alert('Ups, hubo un problema. ¿Está encendido el Backend o el correo ya existe?');
        console.error(error);
      }
    });
  }
}