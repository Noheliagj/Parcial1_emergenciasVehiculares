import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { forkJoin, of } from 'rxjs';
import { EmergenciaService, Emergencia } from '../../services/emergencia';
import { AuthService } from '../../services/auth.service';

const API = 'http://localhost:8000';

@Component({
  selector: 'app-emergencia-vista',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './emergencia-vista.html',
  styleUrls: ['./emergencia-vista.scss']
})
export class EmergenciaVistaComponent implements OnInit {

  // ── Listas de emergencias ──────────────────────────────────
  listaPendientes: Emergencia[] = [];
  listaActivas: Emergencia[] = [];

  // ── Datos del taller logueado ──────────────────────────────
  datosTaller: any = null;

  // ── Estado de la UI ────────────────────────────────────────
  cargando = false;
  mensajeError = '';
  accionEnCursoId: number | null = null;
  imagenAmpliada: string | null = null;

  // Variables para la Ficha de IA
  emergenciaFichaSeleccionada: any = null;
  cargandoIA = false;

  abrirFichaIA(em: any) {
    console.log("🟢 1. Abriendo modal para la solicitud...");
    this.emergenciaFichaSeleccionada = em;
    this.cargandoIA = true;

    // Si ya tenía datos, los mostramos al instante
    if (em.diagnostico_ia && em.diagnostico_ia.trim() !== '') {
      this.cargandoIA = false;
      this.cdr.detectChanges();
      return;
    }

    this.http.post(`${API}/api/emergencias/${em.id}/generar-ficha-ia`, {}, { responseType: 'text' }).subscribe({
      next: (resText: any) => {
        console.log("🟢 2. Datos recibidos de la IA.");

        let data: any = {};
        try {
          let textoLimpio = resText.replace(/```json/g, '').replace(/```/g, '').trim();
          data = JSON.parse(textoLimpio);
        } catch (e) {
          data = { diagnostico_ia: resText };
        }

        const info = data.ficha || data.datos || data.emergencia || data;
        let herramientas = Array.isArray(info.herramientas_sugeridas)
          ? info.herramientas_sugeridas.join(', ')
          : info.herramientas_sugeridas;

        // Inyectamos la información directo en la tarjeta
        em.diagnostico_ia = info.diagnostico_ia || 'Diagnóstico listo.';
        em.severidad_ia = info.severidad_ia || 'No especificada';
        em.herramientas_sugeridas = herramientas || 'No especificadas';

        // 💣 HACK DE DESTRUCCIÓN 💣
        // 1. Matamos la ventana congelada
        this.emergenciaFichaSeleccionada = null;
        this.cdr.detectChanges();

        // 2. La revivimos 50 milisegundos después con los datos nuevos
        setTimeout(() => {
          this.cargandoIA = false; // Relojito apagado
          this.emergenciaFichaSeleccionada = em; // Inyectamos la tarjeta actualizada
          this.cdr.detectChanges(); // Angular está OBLIGADO a redibujar esto
          console.log("🟢 3. ¡Hack aplicado! Pantalla redibujada a la fuerza.");
        }, 50);
      },
      error: (err: any) => {
        this.cargandoIA = false;
        this.cdr.detectChanges();
        alert('Error de conexión.');
      }
    });
  }

  cerrarFichaIA() {
    this.emergenciaFichaSeleccionada = null;
  }

  // ── Control del formulario de aceptación (CU-13) ──────────
  // Cada emergencia tiene su propio estado de formulario
  mostrarFormTiempo: { [key: number]: boolean } = {};
  tiemposEstimados: { [key: number]: number } = {};
  mensajesAceptacion: { [key: number]: string } = {};

  // ── Técnicos disponibles para asignar ─────────────────────
  // Se cargan cuando el taller abre el formulario de aceptación
  tecnicosDisponibles: { id: number; nombre_completo: string; especialidad: string }[] = [];
  tecnicoSeleccionado: { [key: number]: number } = {}; // emergenciaId → tecnicoId
  cargandoTecnicos = false;

  constructor(
    private service: EmergenciaService,
    private authService: AuthService,
    private router: Router,
    private http: HttpClient,  // ← Inyectado directamente para las llamadas nuevas
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit(): void {
    this.datosTaller = this.authService.getUsuario();
    if (!this.datosTaller) {
      this.router.navigate(['/login']);
      return;
    }
    this.cargar();
    // 🛑 TIMER DE 5 SEGUNDOS ELIMINADO AQUÍ
  }

  cargar(): void {
    const tallerId = this.obtenerTallerId();
    this.cargando = true;

    const activas$ = tallerId !== null
      ? this.service.obtenerPorTaller(tallerId)
      : of([] as Emergencia[]);

    forkJoin({
      pendientes: this.service.obtenerPendientes(),
      activas: activas$
    }).subscribe({
      next: ({ pendientes, activas }) => {
        this.listaPendientes = pendientes;
        // Incluir "Confirmada" y "AceptadaPorTaller" además de los estados activos
        this.listaActivas = activas.filter(em =>
          ['Aceptada', 'Confirmada', 'En Camino', 'En Proceso'].includes(em.estado)
        );
        this.mensajeError = '';
        this.cargando = false;
      },
      error: (e: any) => {
        this.mensajeError = 'No se pudo cargar. Intenta de nuevo.';
        this.cargando = false;
        console.error('Error FastAPI:', e);
      }
    });
    // 🛑 RADAR INTERVAL SILENCIOSO ELIMINADO AQUÍ
  }

  obtenerTallerId(): number | null {
    const id = Number(this.datosTaller?.id);
    return Number.isFinite(id) ? id : null;
  }
  // ── CÁLCULO AUTOMÁTICO DE TIEMPO POR COORDENADAS GPS ──
  calcularTiempoAutomatico(latCliente: any, lonCliente: any): number {    // 1. Obtenemos las coordenadas del taller
    // Si tu taller no tiene lat/lon en la base de datos aún, usamos unas coordenadas centrales por defecto
    const latTaller = this.datosTaller?.latitud || -17.7833;
    const lonTaller = this.datosTaller?.longitud || -63.1821;

    // Si el cliente no envió su GPS, devolvemos 15 minutos por defecto para que no falle
    if (!latCliente || !lonCliente) return 15;

    // 2. Fórmula de Haversine para sacar la distancia real en kilómetros
    const R = 6371; // Radio de la tierra en km
    const dLat = (latCliente - latTaller) * (Math.PI / 180);
    const dLon = (lonCliente - lonTaller) * (Math.PI / 180);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(latTaller * (Math.PI / 180)) * Math.cos(latCliente * (Math.PI / 180)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distanciaKm = R * c;

    // 3. Calcular tiempo: Asumimos tráfico de ciudad (aprox 30 km/h -> 2 minutos por kilómetro)
    // Le sumamos 5 minutos base que tarda el mecánico en preparar sus herramientas y arrancar.
    const minutosCalculados = Math.round((distanciaKm * 2) + 5);

    return minutosCalculados;
  }

  // ── CU-13: Mostrar formulario de aceptación + cargar técnicos disponibles
  async abrirFormularioAceptacion(emergenciaId: number): Promise<void> {
    this.mostrarFormTiempo[emergenciaId] = true;
    this.cargandoTecnicos = true;

    // Inicializar valores por defecto
    if (!this.tiemposEstimados[emergenciaId]) {
      this.tiemposEstimados[emergenciaId] = 15;
    }

    const tallerId = this.obtenerTallerId();
    if (!tallerId) {
      this.cargandoTecnicos = false;
      return;
    }

    // Cargar técnicos del taller y filtrar solo los disponibles
    this.http.get<any[]>(`${API}/api/talleres/${tallerId}/tecnicos`).subscribe({
      next: (tecnicos) => {
        // ─── Solo mostramos técnicos con disponible = true
        this.tecnicosDisponibles = tecnicos.filter(t => t.disponible === true);
        this.cargandoTecnicos = false;
      },
      error: () => {
        this.tecnicosDisponibles = [];
        this.cargandoTecnicos = false;
      }
    });
  }

  // ── CU-13: Enviar aceptación con tiempo + técnico elegido
  // ── CU-13 Corregido: Enviar propuesta (Postulación) ──
  aceptarConTiempo(em: any): void {
    const tallerId = this.obtenerTallerId();
    if (!tallerId) {
      alert('Error de sesión. Por favor vuelve a iniciar sesión.');
      return;
    }
    const tiempo = this.calcularTiempoAutomatico(em.latitud, em.longitud);
    const mensaje = this.mensajesAceptacion[em.id] || '';
    const tecnico = this.tecnicoSeleccionado[em.id];

    // Cambiamos la lógica: Ahora enviamos una OFERTA
    // Revisa si tu ruta en Python es /aceptar-con-tiempo o /postular
    let url = `${API}/api/emergencias/${em.id}/aceptar-con-tiempo`
      + `?taller_id=${tallerId}`
      + `&tiempo_estimado_minutos=${tiempo}`;

    if (mensaje) url += `&mensaje=${encodeURIComponent(mensaje)}`;
    if (tecnico) url += `&tecnico_id=${tecnico}`;

    this.accionEnCursoId = em.id;

    this.http.put(url, {}).subscribe({
      next: () => {
        // ¡IMPORTANTE! Mensaje de feedback para la defensa
        alert(`✅ Propuesta enviada. El cliente ahora verá que llegas en ${tiempo} min.`);

        this.mostrarFormTiempo[em.id] = false;
        this.accionEnCursoId = null;

        // Marcamos localmente que ya respondimos para que no aparezca el formulario de nuevo
        em.yaRespondido = true;

        //this.cargar();
      },
      error: (err: any) => {
        this.accionEnCursoId = null;
        alert('Error: ' + (err.error?.detail || 'No se pudo enviar la propuesta'));
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
        alert(err?.error?.detail || 'Error.');
      },
      complete: () => { this.accionEnCursoId = null; }
    });
  }

  cambiarEstado(emergencia: Emergencia, estado: string): void {
    const observaciones = window.prompt('Observaciones opcionales:')?.trim();
    this.accionEnCursoId = emergencia.id;
    this.service.actualizarEstado(
      emergencia.id, estado, observaciones || undefined
    ).subscribe({
      next: () => this.cargar(),
      error: (err: any) => {
        this.accionEnCursoId = null;
        alert(err?.error?.detail || 'Error.');
      },
      complete: () => { this.accionEnCursoId = null; }
    });
  }

  abrirImagen(url: string): void { this.imagenAmpliada = url; }
  cerrarImagen(): void { this.imagenAmpliada = null; }

  // 🛑 Función ngOnDestroy ELIMINADA por completo
  // 🛑 Función cargarEmergenciasSilencioso ELIMINADA por completo
}