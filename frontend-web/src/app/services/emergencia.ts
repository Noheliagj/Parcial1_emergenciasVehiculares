import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Emergencia {
  id: number;
  direccion: string;
  descripcion: string;
  estado: string;
}

@Injectable({
  providedIn: 'root'
})
export class EmergenciaService { // La CLASE se llama así, pero el ARCHIVO es emergencia.ts
  private apiUrl = 'http://127.0.0.1:8000/emergencias-taller/'; 

  constructor(private http: HttpClient) { }

  obtenerPendientes(): Observable<Emergencia[]> {
    return this.http.get<Emergencia[]>(this.apiUrl);
  }
}