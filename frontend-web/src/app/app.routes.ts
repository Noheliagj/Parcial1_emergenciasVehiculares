import { Routes } from '@angular/router';

export const routes: Routes = [
  // 1. LA LANDING PAGE (Ruta raíz principal)
  {
    path: '',
    loadComponent: () => import('./landing/landing.component').then(m => m.LandingComponent),
    pathMatch: 'full'
  },

  // 2. Login de talleres (Jefe)
  {
    path: 'login',
    loadComponent: () => import('./login-taller/login-taller').then(m => m.LoginTaller)
  },

  // 3. Registro de talleres
  {
    path: 'registro',
    loadComponent: () => import('./registro-taller/registro-taller').then(m => m.RegistroTallerComponent)
  },

  // 4. Login ESPECÍFICO para el técnico (¡Afuera del dashboard!)
  {
    path: 'login-tecnico',
    loadComponent: () => import('./login-tecnico/login-tecnico.component').then(m => m.LoginTecnicoComponent)
  },

  // 5. La pantalla de trabajo del técnico (Punto 3 - ¡Afuera del dashboard!)
  {
    path: 'tecnico-vista',
    loadComponent: () => import('./tecnico-vista/tecnico-vista.component').then(m => m.TecnicoVistaComponent)
  },

  // 6. DASHBOARD PRINCIPAL (Solo las pantallas del menú del Jefe van en 'children')
  {
    path: 'dashboard',
    loadComponent: () => import('./dashboard/dashboard').then(m => m.DashboardComponent),
    children: [
      // Cuando entre a /dashboard, mandarlo directo a /dashboard/inicio
      { path: '', redirectTo: 'inicio', pathMatch: 'full' },

      // Sección inicio: estadísticas rápidas
      {
        path: 'inicio',
        loadComponent: () => import('./dashboard/inicio/inicio.component').then(m => m.InicioComponent)
      },

      // Sección emergencias: gestión de solicitudes
      {
        path: 'emergencias',
        loadComponent: () => import('./dashboard/emergencia-vista/emergencia-vista').then(m => m.EmergenciaVistaComponent)
      },

      {
        path: 'historial',
        loadComponent: () =>
          import('./dashboard/historial/historial.component')
            .then(m => m.HistorialComponent)
      },

      // Sección técnicos: registrar y ver trabajadores
      {
        path: 'tecnicos',
        loadComponent: () => import('./dashboard/tecnicos/tecnicos.component').then(m => m.TecnicosComponent)
      },

      // Sección cuenta: perfil del taller
      {
        path: 'cuenta',
        loadComponent: () => import('./dashboard/cuenta/cuenta.component').then(m => m.CuentaComponent)
      }
    ]
  },

  // 7. Catch-all: cualquier ruta mal escrita te devuelve al inicio (Landing)
  { path: '**', redirectTo: '' }
];