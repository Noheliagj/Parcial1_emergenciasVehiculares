import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule],
  template: `
    <div class="dashboard-layout">
      
      <aside class="sidebar">
        <div class="brand">
          <h2>TallerPro</h2>
          <p>Gestión de Auxilios</p>
        </div>

        <nav class="menu">
          <a routerLink="inicio" routerLinkActive="active" class="menu-item">
            <span class="icon">🏠</span> Inicio
          </a>
          <a routerLink="emergencias" routerLinkActive="active" class="menu-item">
            <span class="icon">🚨</span> Emergencias
          </a>
          <a routerLink="tecnicos" routerLinkActive="active" class="menu-item">
            <span class="icon">👷‍♂️</span> Mis Técnicos
          </a>
          <a routerLink="/dashboard/historial" routerLinkActive="active" class="menu-item">
        📋 Historial
          </a>
          <a routerLink="cuenta" routerLinkActive="active" class="menu-item">
            <span class="icon">👤</span> Mi Cuenta
          </a>
        </nav>

        <div class="footer-menu">
          <button (click)="logout()" class="logout-btn">
            <span class="icon">🚪</span> Cerrar Sesión
          </button>
        </div>
      </aside>

      <main class="main-content">
        <div class="container">
          <router-outlet></router-outlet>
        </div>
      </main>

    </div>
  `,
  styles: [`
    :host { display: block; height: 100vh; font-family: 'Segoe UI', Roboto, sans-serif; }
    
    .dashboard-layout {
      display: flex;
      height: 100vh;
      background-color: #f0f2f5;
    }

    /* SIDEBAR MEJORADO */
    .sidebar {
      width: 280px;
      background: linear-gradient(180deg, #1e1e38 0%, #111122 100%);
      color: white;
      display: flex;
      flex-direction: column;
      box-shadow: 4px 0 10px rgba(0,0,0,0.2);
    }

    .brand {
      padding: 40px 24px;
      text-align: center;
      border-bottom: 1px solid rgba(255,255,255,0.1);
    }

    .brand h2 { 
      margin: 0; 
      font-size: 28px; /* Letras más grandes */
      letter-spacing: 1px;
      color: #6366f1;
    }

    .brand p { margin: 5px 0 0; font-size: 14px; color: #8e8ea0; }

    /* MENÚ MÁS LLAMATIVO */
    .menu {
      flex: 1;
      padding: 30px 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .menu-item {
      padding: 16px 20px;
      border-radius: 12px;
      color: #d1d1e0;
      text-decoration: none;
      font-size: 18px; /* Letras más grandes */
      font-weight: 600;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
    }

    .menu-item:hover {
      background: rgba(255,255,255,0.05);
      color: white;
      transform: translateX(5px);
    }

    .menu-item.active {
      background: #6366f1;
      color: white;
      box-shadow: 0 4px 15px rgba(99, 102, 241, 0.4);
    }

    .icon { margin-right: 15px; font-size: 20px; }

    /* BOTÓN DE CERRAR SESIÓN */
    .footer-menu {
      padding: 20px;
      border-top: 1px solid rgba(255,255,255,0.1);
    }

    .logout-btn {
      width: 100%;
      padding: 14px;
      border-radius: 10px;
      border: none;
      background: rgba(239, 68, 68, 0.1);
      color: #ef4444;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.3s;
    }

    .logout-btn:hover {
      background: #ef4444;
      color: white;
    }

    /* CONTENIDO */
    .main-content {
      flex: 1;
      overflow-y: auto;
      padding: 40px;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
  `]
})
export class DashboardComponent {
  constructor(private router: Router) { }

  logout() {
    // Aquí borramos cualquier rastro de la sesión
    localStorage.clear();
    sessionStorage.clear();

    // Mandamos al usuario de vuelta al login
    this.router.navigate(['/login']);
  }
}