import { Routes } from '@angular/router';
import { LoginTaller } from './login-taller/login-taller'; // Ajusta la ruta si es necesario
import { EmergenciaVista } from './dashboard/emergencia-vista/emergencia-vista';
import { RegistroTallerComponent } from './registro-taller/registro-taller';


export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' }, // Si entras a la web, te manda al login
  { path: 'login', component: LoginTaller },           // Pantalla de inicio de sesión
  { path: 'dashboard', component: EmergenciaVista },   // Tu panel de emergencias
  { path: 'registro', component: RegistroTallerComponent }, // <--- Agrega esta línea
];