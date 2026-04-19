import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { EmergenciaService, Emergencia } from '../../services/emergencia';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-emergencia-vista',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './emergencia-vista.html',
  styleUrls: ['./emergencia-vista.scss']
})
export class EmergenciaVista implements OnInit, OnDestroy {
  // 1. Variables de datos
  listaPendientes: Emergencia[] = [];
  listaActivas: Emergencia[] = [];
  datosTaller: any = null;
  
  // 2. Variables de control
  timer: any;
  seccion: string = 'inicio'; 
  cargando = false;
  mensajeError = '';
  accionEnCursoId: number | null = null;

  constructor(
    private service: EmergenciaService, 
    private authService: AuthService, 
    private router: Router
  ) {}

  ngOnInit(): void {
    this.datosTaller = this.authService.getUsuario();

    if (!this.datosTaller) {
      this.router.navigate(['/login']);
      return;
    }

    this.cargar();
    this.timer = setInterval(() => this.cargar(), 5000);
  }

  cargar(): void {
    const tallerId = this.obtenerTallerId();
    this.cargando = true;

    const emergenciasActivas$ = tallerId !== null
      ? this.service.obtenerPorTaller(tallerId)
      : of([] as Emergencia[]);

    forkJoin({
      pendientes: this.service.obtenerPendientes(),
      activas: emergenciasActivas$
    }).subscribe({
      next: ({ pendientes, activas }) => {
        this.listaPendientes = pendientes;
        this.listaActivas = activas.filter((emergencia) =>
          ['Aceptada', 'En Camino', 'En Proceso'].includes(emergencia.estado)
        );
        this.mensajeError = '';
        this.cargando = false;
      },
      error: (e: any) => {
        this.mensajeError = 'No se pudo cargar la información. Intenta nuevamente.';
        this.cargando = false;
        console.error("Error al conectar con FastAPI:", e);
      }
    });
  }

  obtenerTallerId(): number | null {
    const id = Number(this.datosTaller?.id);
    return Number.isFinite(id) ? id : null;
  }

  aceptar(emergencia: Emergencia): void {
    const tallerId = this.obtenerTallerId();
    if (tallerId === null) {
      alert('No se pudo identificar el taller logueado.');
      return;
    }

    const tecnicoTexto = window.prompt('ID del técnico asignado (opcional):')?.trim();
    const tecnicoId = tecnicoTexto ? Number(tecnicoTexto) : undefined;

    this.accionEnCursoId = emergencia.id;
    this.service.aceptarSolicitud(
      emergencia.id,
      tallerId,
      tecnicoId !== undefined && Number.isFinite(tecnicoId) ? tecnicoId : undefined
    ).subscribe({
      next: () => this.cargar(),
      error: (err: any) => {
        this.accionEnCursoId = null;
        alert(err?.error?.detail || 'No se pudo aceptar la solicitud.');
      },
      complete: () => {
        this.accionEnCursoId = null;
      }
    });
  }

  rechazar(emergencia: Emergencia): void {
    const motivo = window.prompt('Motivo del rechazo (opcional):')?.trim();
    this.accionEnCursoId = emergencia.id;
    this.service.rechazarSolicitud(emergencia.id, motivo || undefined).subscribe({
      next: () => this.cargar(),
      error: (err: any) => {
        this.accionEnCursoId = null;
        alert(err?.error?.detail || 'No se pudo rechazar la solicitud.');
      },
      complete: () => {
        this.accionEnCursoId = null;
      }
    });
  }

  cambiarEstado(emergencia: Emergencia, estado: string): void {
    const observaciones = window.prompt('Observaciones opcionales:')?.trim();
    const tecnicoTexto = window.prompt('ID del técnico responsable (opcional):')?.trim();
    const tecnicoId = tecnicoTexto ? Number(tecnicoTexto) : undefined;

    this.accionEnCursoId = emergencia.id;
    this.service.actualizarEstado(
      emergencia.id,
      estado,
      observaciones || undefined,
      tecnicoId !== undefined && Number.isFinite(tecnicoId) ? tecnicoId : undefined
    ).subscribe({
      next: () => this.cargar(),
      error: (err: any) => {
        this.accionEnCursoId = null;
        alert(err?.error?.detail || 'No se pudo actualizar el estado.');
      },
      complete: () => {
        this.accionEnCursoId = null;
      }
    });
  }

  // Función para el botón de cerrar sesión
  salir(): void {
    this.authService.cerrarSesion(); // limpia localStorage
    this.router.navigate(['/login']);
}

  ngOnDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }
}

