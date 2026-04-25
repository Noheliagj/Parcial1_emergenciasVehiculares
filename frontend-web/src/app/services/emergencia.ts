// ============================================================
// ARCHIVO: app/services/emergencia.ts
//
// CAMBIOS vs versión original:
// 1. Se agrega imagen_evidencia_url al modelo Emergencia
// 2. Se agrega latitud y longitud para el enlace de Maps
// 3. Los métodos del servicio se mantienen igual
// ============================================================

import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

// Modelo de Emergencia actualizado
export interface Emergencia {
  id: number;
  cliente_id: number;
  vehiculo_id: number;
  direccion: string;
  descripcion: string;
  estado: string;
  latitud?: number;               // Para el enlace a Google Maps
  longitud?: number;              // Para el enlace a Google Maps
  tipo_ia?: string;               // Resultado del análisis IA (CU-11)
  severidad_ia?: string;          // Severidad del análisis IA
  audio_url?: string;
  transcripcion?: string;         // Transcripción del audio (CU-10)
  foto_url?: string;  // URL de la foto de evidencia (NUEVO)
  observaciones?: string;
  taller_id?: number;
  tecnico_id?: number;
  fecha_creacion?: string;
  fecha_actualizacion?: string;
}

// IMPORTANTE: Asegúrate de que esta URL sea la de tu backend FastAPI
const API_URL = 'http://localhost:8000';

@Injectable({ providedIn: 'root' })
export class EmergenciaService {

  constructor(private http: HttpClient) { }

  // Obtener todas las emergencias pendientes (para el taller)
  obtenerPendientes(): Observable<Emergencia[]> {
    return this.http.get<Emergencia[]>(`${API_URL}/emergencias-taller/`);
  }

  // Obtener emergencias de un taller específico
  obtenerPorTaller(tallerId: number, estado?: string): Observable<Emergencia[]> {
    let params = new HttpParams();
    if (estado) params = params.set('estado', estado);
    return this.http.get<Emergencia[]>(`${API_URL}/api/talleres/${tallerId}/emergencias`, { params });
  }

  // CU-08: Aceptar solicitud
  aceptarSolicitud(emergenciaId: number, tallerId: number, tecnicoId?: number): Observable<any> {
    let params = new HttpParams().set('taller_id', tallerId.toString());
    if (tecnicoId) params = params.set('tecnico_id', tecnicoId.toString());
    return this.http.put(`${API_URL}/api/emergencias/${emergenciaId}/aceptar`, {}, { params });
  }

  // CU-08: Rechazar solicitud
  rechazarSolicitud(emergenciaId: number, motivo?: string): Observable<any> {
    let params = new HttpParams();
    if (motivo) params = params.set('motivo', motivo);
    return this.http.put(`${API_URL}/api/emergencias/${emergenciaId}/rechazar`, {}, { params });
  }

  // CU-09: Actualizar estado del servicio
  actualizarEstado(
    emergenciaId: number,
    estado: string,
    observaciones?: string,
    tecnicoId?: number
  ): Observable<any> {
    const body: any = { estado };
    if (observaciones) body.observaciones = observaciones;
    if (tecnicoId) body.tecnico_id = tecnicoId;
    return this.http.put(`${API_URL}/api/emergencias/${emergenciaId}/estado`, body);
  }

  // Obtener detalle completo de una emergencia (incluyendo foto e IA)
  obtenerDetalle(emergenciaId: number): Observable<any> {
    return this.http.get(`${API_URL}/api/emergencias/${emergenciaId}/detalle-completo`);
  }

  // Obtener historial de estados de una emergencia
  obtenerHistorial(emergenciaId: number): Observable<any[]> {
    return this.http.get<any[]>(`${API_URL}/api/emergencias/${emergenciaId}/historial`);
  }
}