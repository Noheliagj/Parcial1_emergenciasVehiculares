import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Emergencia {
  id: number;
  cliente_id?: number;
  vehiculo_id?: number;
  taller_id?: number;
  tecnico_id?: number;
  direccion: string;
  descripcion: string;
  estado: string;
  observaciones?: string;
  transcripcion?: string;
  fecha_creacion?: string;
}

@Injectable({
  providedIn: 'root'
})
export class EmergenciaService { // La CLASE se llama así, pero el ARCHIVO es emergencia.ts
  private apiUrl = 'http://127.0.0.1:8000'; 

  constructor(private http: HttpClient) { }

  obtenerPendientes(): Observable<Emergencia[]> {
    return this.http.get<Emergencia[]>(`${this.apiUrl}/emergencias-taller/`);
  }

  obtenerPorTaller(tallerId: number): Observable<Emergencia[]> {
    return this.http.get<Emergencia[]>(`${this.apiUrl}/api/talleres/${tallerId}/emergencias`);
  }

  aceptarSolicitud(emergenciaId: number, tallerId?: number, tecnicoId?: number): Observable<any> {
    let params = new HttpParams();

    if (tallerId !== undefined && tallerId !== null) {
      params = params.set('taller_id', tallerId);
    }

    if (tecnicoId !== undefined && tecnicoId !== null) {
      params = params.set('tecnico_id', tecnicoId);
    }

    return this.http.put(`${this.apiUrl}/api/emergencias/${emergenciaId}/aceptar`, null, { params });
  }

  rechazarSolicitud(emergenciaId: number, motivo?: string): Observable<any> {
    const params = motivo ? new HttpParams().set('motivo', motivo) : new HttpParams();
    return this.http.put(`${this.apiUrl}/api/emergencias/${emergenciaId}/rechazar`, null, { params });
  }

  actualizarEstado(
    emergenciaId: number,
    estado: string,
    observaciones?: string,
    tecnicoId?: number
  ): Observable<any> {
    return this.http.put(`${this.apiUrl}/api/emergencias/${emergenciaId}/estado`, {
      estado,
      observaciones,
      tecnico_id: tecnicoId
    });
  }
}