// ============================================================
// ARCHIVO: app/dashboard/inicio/inicio.component.ts
//
// Componente para la sección "Inicio" del dashboard.
// Muestra estadísticas: pendientes, activas, finalizadas.
// Es el componente que se ve al hacer login.
// ============================================================

import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { EmergenciaService } from '../../services/emergencia';
import { AuthService } from '../../services/auth.service';

@Component({
    selector: 'app-inicio',
    standalone: true,
    imports: [CommonModule],
    template: `
    <div class="section-fade">
      <div class="page-header">
        <div>
          <h1>¡Bienvenido, {{ nombreTaller }}!</h1>
          <p>Aquí tienes un resumen de la actividad de tu taller.</p>
        </div>
      </div>
 
      <div class="stats-grid">
        <div class="stat-card red">
          <div class="stat-icon">🚨</div>
          <div class="stat-info">
            <span class="stat-num">{{ totalPendientes }}</span>
            <span class="stat-label">Emergencias pendientes</span>
          </div>
        </div>
 
        <div class="stat-card blue">
          <div class="stat-icon">🔧</div>
          <div class="stat-info">
            <span class="stat-num">{{ totalActivas }}</span>
            <span class="stat-label">Servicios activos</span>
          </div>
        </div>
 
        <div class="stat-card green">
          <div class="stat-icon">✅</div>
          <div class="stat-info">
            <span class="stat-num">{{ totalFinalizados }}</span>
            <span class="stat-label">Servicios finalizados hoy</span>
          </div>
        </div>
      </div>
    </div>
  `,
    styles: [`
    .section-fade { animation: fadeIn 0.25s ease; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
    .page-header { margin-bottom: 32px; }
    .page-header h1 { font-size: 26px; font-weight: 700; color: #111827; margin-bottom: 4px; }
    .page-header p { color: #6b7280; font-size: 14px; }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 20px; }
    .stat-card {
      background: white; border-radius: 16px; padding: 24px;
      display: flex; align-items: center; gap: 18px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06); border-left: 5px solid transparent;
    }
    .stat-card.red   { border-color: #ef4444; .stat-num { color: #ef4444; } }
    .stat-card.blue  { border-color: #3b82f6; .stat-num { color: #3b82f6; } }
    .stat-card.green { border-color: #10b981; .stat-num { color: #10b981; } }
    .stat-icon  { font-size: 32px; }
    .stat-info  { display: flex; flex-direction: column; }
    .stat-num   { font-size: 34px; font-weight: 700; line-height: 1; }
    .stat-label { font-size: 13px; color: #6b7280; margin-top: 4px; }
  `]
})
export class InicioComponent implements OnInit, OnDestroy {
    totalPendientes = 0;
    totalActivas = 0;
    totalFinalizados = 0;
    nombreTaller = '';
    timer: any;

    constructor(
        private service: EmergenciaService,
        private authService: AuthService
    ) { }

    ngOnInit(): void {
        const taller = this.authService.getUsuario();
        this.nombreTaller = taller?.nombre_taller || 'Taller';
        this.cargarEstadisticas();
        // Actualizar estadísticas cada 10 segundos
        this.timer = setInterval(() => this.cargarEstadisticas(), 10000);
    }

    cargarEstadisticas(): void {
        const taller = this.authService.getUsuario();
        const tallerId = Number(taller?.id);

        // Pendientes: todas las emergencias sin taller asignado
        this.service.obtenerPendientes().subscribe({
            next: (pendientes) => this.totalPendientes = pendientes.length,
            error: () => { }
        });

        // Activas y finalizadas: las del taller
        if (Number.isFinite(tallerId)) {
            this.service.obtenerPorTaller(tallerId).subscribe({
                next: (todas) => {
                    this.totalActivas = todas.filter(e =>
                        ['Aceptada', 'En Camino', 'En Proceso'].includes(e.estado)
                    ).length;
                    this.totalFinalizados = todas.filter(e => e.estado === 'Finalizado').length;
                },
                error: () => { }
            });
        }
    }

    ngOnDestroy(): void {
        if (this.timer) clearInterval(this.timer);
    }
}