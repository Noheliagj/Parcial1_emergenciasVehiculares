// ================================================================
// ARCHIVO: src/app/dashboard/tecnicos/tecnicos.component.ts
// REEMPLAZA tu tecnicos.component.ts actual
//
// CAMBIOS:
// 1. Se SEPARÓ el template y styles a tecnicos.html y tecnicos.scss
//    (antes todo estaba inline en el .ts con template: `` y styles: ``)
// 2. Se agregó la columna "Disponibilidad" en la tabla de técnicos
//    con un toggle para que el taller pueda ver quién está disponible
// 3. Se agregó un botón "Marcar disponible" para cada técnico en la tabla
// ================================================================

import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpClientModule } from '@angular/common/http';

const API = 'http://localhost:8000';

@Component({
  selector: 'app-tecnicos',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule],
  // ─── CORRECCIÓN: Template movido a tecnicos.html y styles a tecnicos.scss
  templateUrl: './tecnicos.html',
  styleUrls: ['./tecnicos.scss']
})
export class TecnicosComponent implements OnInit {

  nuevoTecnico = {
    nombre_completo: '',
    especialidad: '',
    usuario: '',
    contrasena: '',
    taller_id: 0
  };

  listaTecnicos: any[] = [];
  mensaje = '';
  mensajeError = '';
  tallerId = 0;

  constructor(private http: HttpClient) { }

  ngOnInit() {
    if (typeof window !== 'undefined' && typeof localStorage !== 'undefined') {
      const tallerInfo = JSON.parse(localStorage.getItem('taller') || '{}');
      if (tallerInfo?.id) {
        this.tallerId = tallerInfo.id;
        this.nuevoTecnico.taller_id = tallerInfo.id;
        this.cargarTecnicos();
      }
    }
  }

  cargarTecnicos() {
    this.http.get<any[]>(`${API}/api/talleres/${this.tallerId}/tecnicos`)
      .subscribe({
        next: (res) => { this.listaTecnicos = res; },
        error: () => { this.mensajeError = 'No se pudieron cargar los técnicos.'; }
      });
  }

  registrarTecnico() {
    if (this.nuevoTecnico.taller_id === 0) {
      alert('Error de sesión: cierra sesión y vuelve a entrar.');
      return;
    }
    this.http.post(`${API}/tecnicos/`, this.nuevoTecnico).subscribe({
      next: () => {
        this.mensaje = '¡Técnico registrado con éxito!';
        this.cargarTecnicos();
        this.nuevoTecnico.nombre_completo = '';
        this.nuevoTecnico.especialidad = '';
        this.nuevoTecnico.usuario = '';
        this.nuevoTecnico.contrasena = '';
        setTimeout(() => this.mensaje = '', 3000);
      },
      error: (err) => {
        alert('Error al registrar: ' + (err.error?.detail || 'Fallo de conexión'));
      }
    });
  }

  // ── CU-14: Marcar un técnico como disponible desde el panel del taller
  marcarDisponible(tecnicoId: number) {
    this.http.patch(
      `${API}/api/tecnicos/${tecnicoId}/disponibilidad?disponible=true`,
      {}
    ).subscribe({
      next: () => {
        this.mensaje = '✅ Técnico marcado como disponible';
        this.cargarTecnicos();
        setTimeout(() => this.mensaje = '', 3000);
      },
      error: () => alert('Error al actualizar disponibilidad')
    });
  }

  // ── CU-14: Marcar un técnico como NO disponible desde el panel del taller
  marcarNoDisponible(tecnicoId: number) {
    const motivo = window.prompt(
      '¿Motivo de no disponibilidad?\n(Ej: Fuera de horario, En otra emergencia, Descanso)'
    )?.trim();
    if (motivo === null) return; // Canceló

    this.http.patch(
      `${API}/api/tecnicos/${tecnicoId}/disponibilidad?disponible=false&motivo=${encodeURIComponent(motivo || '')}`,
      {}
    ).subscribe({
      next: () => {
        this.mensaje = '🔴 Técnico marcado como no disponible';
        this.cargarTecnicos();
        setTimeout(() => this.mensaje = '', 3000);
      },
      error: () => alert('Error al actualizar disponibilidad')
    });
  }
}