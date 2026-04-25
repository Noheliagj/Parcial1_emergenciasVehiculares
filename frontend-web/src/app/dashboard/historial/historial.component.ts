import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../../services/auth.service';

const API = 'http://localhost:8000';

@Component({
    selector: 'app-historial',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './historial.html',
    styleUrls: ['./historial.scss']
})
export class HistorialComponent implements OnInit {

    // Lista completa de atenciones finalizadas del taller
    historial: any[] = [];

    // Lista filtrada (la que se muestra en pantalla)
    historialFiltrado: any[] = [];

    // Lista de técnicos para el filtro desplegable
    listaTecnicos: any[] = [];

    // Filtros activos
    filtroTecnico: string = 'todos';
    filtroBusqueda: string = '';

    // Estado de la UI
    cargando = false;
    error: string | null = null;

    // Estadísticas rápidas
    totalAtenciones = 0;
    promedioTiempo = 0; // futuro
    tallerId: number | null = null;

    constructor(
        private http: HttpClient,
        private authService: AuthService
    ) { }

    ngOnInit(): void {
        const taller = this.authService.getUsuario();
        if (!taller?.id) return;
        this.tallerId = Number(taller.id);
        this.cargarHistorial();
        this.cargarTecnicos();
    }

    // ── Carga el historial completo del taller desde el backend ──
    // Endpoint: GET /api/talleres/{id}/historial  (ya existe en main.py)
    cargarHistorial(): void {
        this.cargando = true;
        this.error = null;

        this.http.get<any[]>(`${API}/api/talleres/${this.tallerId}/historial`)
            .subscribe({
                next: (datos) => {
                    this.historial = datos;
                    this.historialFiltrado = datos;
                    this.totalAtenciones = datos.length;
                    this.cargando = false;
                    this.aplicarFiltros();
                },
                error: () => {
                    this.error = 'No se pudo cargar el historial. Verifica tu conexión.';
                    this.cargando = false;
                }
            });
    }

    // ── Carga los técnicos del taller para el filtro ──────────
    cargarTecnicos(): void {
        this.http.get<any[]>(`${API}/api/talleres/${this.tallerId}/tecnicos`)
            .subscribe({
                next: (data) => { this.listaTecnicos = data; },
                error: () => { }
            });
    }

    // ── Aplica los filtros activos sobre el historial completo ──
    // Se llama cada vez que cambia el filtro de técnico o la búsqueda
    aplicarFiltros(): void {
        let resultado = [...this.historial];

        // Filtro por técnico
        if (this.filtroTecnico !== 'todos') {
            resultado = resultado.filter(
                item => item.tecnico_nombre === this.filtroTecnico
            );
        }

        // Filtro por búsqueda (busca en dirección, cliente, tipo)
        if (this.filtroBusqueda.trim()) {
            const texto = this.filtroBusqueda.toLowerCase().trim();
            resultado = resultado.filter(
                item =>
                    item.cliente_nombre?.toLowerCase().includes(texto) ||
                    item.direccion?.toLowerCase().includes(texto) ||
                    item.tipo_incidente?.toLowerCase().includes(texto)
            );
        }

        this.historialFiltrado = resultado;
    }

    // ── Helper: devuelve color según severidad del incidente ──
    colorSeveridad(sev: string | null): string {
        if (!sev) return '#9ca3af';
        const mapa: { [k: string]: string } = {
            'leve': '#10b981',
            'moderado': '#f59e0b',
            'grave': '#ef4444',
            'crítico': '#7f1d1d',
        };
        return mapa[sev.toLowerCase()] || '#9ca3af';
    }

    // ── Helper: ícono según tipo de incidente ────────────────
    iconoTipo(tipo: string | null): string {
        if (!tipo) return '🔧';
        const mapa: { [k: string]: string } = {
            'batería': '🔋',
            'llanta': '🛞',
            'choque': '💥',
            'motor': '⚙️',
            'otros': '🔧',
        };
        return mapa[tipo.toLowerCase()] || '🔧';
    }
}