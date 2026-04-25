import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';

const API = 'http://localhost:8000';

@Component({
  selector: 'app-tecnico-vista',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './tecnico-vista.html',
  styleUrls: ['./tecnico-vista.scss']
})
export class TecnicoVistaComponent implements OnInit, OnDestroy {
  datosTecnico: any = null;
  asignacionActual: any = null;
  tieneAsignacion = false;
  historial: any[] = [];

  seccion: 'inicio' | 'historial' = 'inicio';
  cargando = false;
  accionando = false;
  timer: any;

  // Toggle de disponibilidad
  disponible = true;
  motivoNoDisponible = '';
  mostrarMotivoInput = false;

  constructor(private http: HttpClient, private router: Router) { }

  ngOnInit(): void {
    // 🛡️ PARCHE SSR: Verificamos que estamos en el navegador
    if (typeof window !== 'undefined' && typeof localStorage !== 'undefined') {

      // 🔑 CORRECCIÓN: Buscar la llave 'tecnico' (Igual que en tu login)
      const sesion = localStorage.getItem('tecnico');
      if (!sesion) {
        this.router.navigate(['/login-tecnico']);
        return;
      }
      this.datosTecnico = JSON.parse(sesion);
      this.disponible = this.datosTecnico.disponible ?? true;

      this.cargarAsignacion();
      // Polling cada 8 segundos para ver si le asignan una emergencia
      this.timer = setInterval(() => this.cargarAsignacion(), 8000);
    }
  }

  cargarAsignacion(): void {
    if (!this.datosTecnico) return;
    this.http.get<any>(
      API + '/api/tecnicos/' + this.datosTecnico.id + '/asignacion-actual'
    ).subscribe({
      next: (res) => {
        this.tieneAsignacion = res.tiene_asignacion;
        this.asignacionActual = res.emergencia;
      },
      error: () => { }
    });
  }

  cargarHistorial(): void {
    this.http.get<any[]>(
      API + '/api/tecnicos/' + this.datosTecnico.id + '/historial'
    ).subscribe({
      next: (res) => this.historial = res,
      error: () => { }
    });
  }

  // Actualizar estado de la emergencia
  cambiarEstado(nuevoEstado: string): void {
    if (!this.asignacionActual) return;
    this.accionando = true;
    this.http.put(
      API + '/api/emergencias/' + this.asignacionActual.id + '/estado',
      { estado: nuevoEstado }
    ).subscribe({
      next: () => {
        this.accionando = false;
        this.cargarAsignacion();
        if (nuevoEstado === 'Finalizado') {
          this.tieneAsignacion = false;
          this.asignacionActual = null;
        }
      },
      error: () => { this.accionando = false; }
    });
  }

  // Cambiar disponibilidad
  toggleDisponibilidad(): void {
    if (this.disponible) {
      // Va a ponerse no disponible → pedir motivo
      this.mostrarMotivoInput = true;
    } else {
      // Va a ponerse disponible
      this.disponible = true;
      this.mostrarMotivoInput = false;
      this.guardarDisponibilidad();
    }
  }

  guardarDisponibilidad(): void {
    this.disponible = !this.disponible || !this.mostrarMotivoInput;
    if (this.mostrarMotivoInput) this.disponible = false;

    const params = new URLSearchParams({
      disponible: String(this.disponible),
      motivo: this.motivoNoDisponible
    });
    this.http.patch(
      API + '/api/tecnicos/' + this.datosTecnico.id + '/disponibilidad?' + params.toString(),
      {}
    ).subscribe(() => { this.mostrarMotivoInput = false; });
  }

  cambiarSeccion(s: 'inicio' | 'historial'): void {
    this.seccion = s;
    if (s === 'historial') this.cargarHistorial();
  }

  abrirGoogleMaps(): void {
    if (!this.asignacionActual) return;
    const { latitud, longitud } = this.asignacionActual;
    if (latitud && longitud) {
      // 🗺️ CORRECCIÓN: Formato oficial de Google Maps
      window.open(
        `https://www.google.com/maps/search/?api=1&query=${latitud},${longitud}`,
        '_blank'
      );
    }
  }

  salir(): void {
    if (typeof localStorage !== 'undefined') {
      localStorage.removeItem('tecnico');
    }
    this.router.navigate(['/login-tecnico']);
  }

  ngOnDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }
} 