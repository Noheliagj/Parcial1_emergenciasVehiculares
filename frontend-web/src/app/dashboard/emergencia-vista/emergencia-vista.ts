import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router'; 
import { EmergenciaService, Emergencia } from '../../services/emergencia';
import { AuthService } from '../../services/auth.service'; // <--- Asegúrate de que este archivo exista

@Component({
  selector: 'app-emergencia-vista',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './emergencia-vista.html',
  styleUrls: ['./emergencia-vista.scss']
})
export class EmergenciaVista implements OnInit, OnDestroy {
  // 1. Variables de datos
  lista: Emergencia[] = [];
  datosTaller: any = null;
  
  // 2. Variables de control
  timer: any;
  seccion: string = 'inicio'; 

  constructor(
    private service: EmergenciaService, 
    private authService: AuthService, 
    private router: Router
  ) {}

  ngOnInit(): void {
  // Le pedimos al mensajero los datos que guardó en el Paso 1
  this.datosTaller = this.authService.getUsuario();
  
  // Si la mochila está vacía (nadie se logueó), lo sacamos de aquí
  if (!this.datosTaller) {
    this.router.navigate(['/login']);
    return;
  }

  this.cargar(); // Carga las emergencias de la tabla
}

  cargar(): void {
    this.service.obtenerPendientes().subscribe({
      next: (res: Emergencia[]) => {
        this.lista = res;
      },
      error: (e: any) => {
        console.error("Error al conectar con FastAPI:", e);
      }
    });
  }

  // Función para el botón de cerrar sesión
  salir(): void {
    this.authService.cerrarSesion(); // limpia localStorage
    this.router.navigate(['/login']);
}

  ngOnDestroy(): void {
    // Muy importante limpiar el timer cuando el usuario se va del dashboard
    if (this.timer) {
      clearInterval(this.timer);
    }
  }
}

