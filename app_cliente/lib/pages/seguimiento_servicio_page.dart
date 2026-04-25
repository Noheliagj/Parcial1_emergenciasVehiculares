import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'pago_page.dart';

class SeguimientoServicioPage extends StatefulWidget {
  final Map<String, dynamic> emergencia;

  const SeguimientoServicioPage({super.key, required this.emergencia});

  @override
  State<SeguimientoServicioPage> createState() =>
      _SeguimientoServicioPageState();
}

class _SeguimientoServicioPageState extends State<SeguimientoServicioPage>
    with TickerProviderStateMixin {

  // ── Estado actual del servicio ─────────────────────────────
  String _estadoActual = '';
  String _tallerNombre = '';
  String _tecnicoNombre = '';
  bool _yaNavegoPago = false;        // Para no navegar dos veces a PagoPage
  bool _mostraronLlegada = false;    // Para no mostrar el dialog dos veces

  // ── Progreso del auto animado ──────────────────────────────
  // Viene del endpoint /ubicacion-tecnico-vivo
  double _progreso = 0.0;           // 0.0 a 1.0
  int _minutosRestantes = 0;

  // ── Polling ────────────────────────────────────────────────
  Timer? _pollingTimer;
  bool _verificandoAhora = false;

  // ── Animación del auto ─────────────────────────────────────
  late AnimationController _autoController;
  late Animation<double> _autoAnimacion;

  // ── Animación de pulso al llegar ──────────────────────────
  late AnimationController _pulsoController;
  late Animation<double> _pulsoEscala;

  @override
  void initState() {
    super.initState();

    // Inicializar datos del widget
    _estadoActual  = widget.emergencia['estado'] ?? '';
    _tallerNombre  = widget.emergencia['taller_asignado'] ?? 'Taller';
    _tecnicoNombre = widget.emergencia['tecnico_asignado'] ?? 'Por definir';

    // Animación del auto: controlada manualmente con _progreso
    _autoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _autoAnimacion = Tween<double>(begin: 0.0, end: 1.0).animate(_autoController);

    // Animación de pulso
    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulsoEscala = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.elasticOut),
    );

    // Iniciar polling inmediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificar());
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _verificar());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _autoController.dispose();
    _pulsoController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // POLLING: Consulta estado + ubicación en vivo del técnico
  // ══════════════════════════════════════════════════════════
  Future<void> _verificar() async {
    if (_verificandoAhora || !mounted) return;
    _verificandoAhora = true;

    try {
      final emergenciaId = widget.emergencia['id'] as int;

      // 1. Obtener estado actual de la emergencia
      final resEstado = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/api/emergencias/$emergenciaId/estado',
      ));

      if (!mounted || resEstado.statusCode != 200) return;

      final datosEstado = jsonDecode(resEstado.body);
      final nuevoEstado =
          datosEstado['emergencia']['estado']?.toString() ?? '';
      final tallerNombre =
          datosEstado['nombre_taller']?.toString() ?? _tallerNombre;
      final tecnicoNombre =
          datosEstado['nombre_tecnico']?.toString() ?? _tecnicoNombre;

      if (mounted) {
        setState(() {
          _estadoActual  = nuevoEstado;
          _tallerNombre  = tallerNombre;
          _tecnicoNombre = tecnicoNombre;
        });
      }

      // 2. Obtener progreso GPS del técnico (simulado por el backend)
      if (nuevoEstado == 'En Camino') {
        final resUbicacion = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/emergencias/$emergenciaId/ubicacion-tecnico-vivo',
        ));
        if (mounted && resUbicacion.statusCode == 200) {
          final datosUbicacion = jsonDecode(resUbicacion.body);
          if (datosUbicacion['moviendose'] == true) {
            final nuevoProg =
                (datosUbicacion['progreso_porcentaje'] as num).toDouble() /
                    100.0;
            setState(() => _progreso = nuevoProg.clamp(0.0, 1.0));
            // Animar el auto hasta el nuevo progreso
            _autoController.animateTo(_progreso,
                duration: const Duration(milliseconds: 500));
          }
        }
      }

      // 3. Detectar llegada del técnico
      if (nuevoEstado == 'En Proceso' && !_mostraronLlegada) {
        _mostraronLlegada = true;
        _pulsoController.repeat(reverse: true);
        setState(() => _progreso = 1.0);
        _autoController.animateTo(1.0,
            duration: const Duration(milliseconds: 800));
        // Mostrar dialog de llegada después de un frame
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _mostrarDialogLlegada();
      }

      // 4. Detectar finalización → navegar a PagoPage (CU-16)
      if (nuevoEstado == 'Finalizado' && !_yaNavegoPago) {
        _yaNavegoPago = true;
        _pollingTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PagoPage(emergenciaId: emergenciaId),
            ),
          );
        }
      }
    } catch (_) {
      // Ignorar errores de red
    } finally {
      _verificandoAhora = false;
    }
  }

  // ── Dialog cuando el técnico llega (estado = "En Proceso") ──
  void _mostrarDialogLlegada() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _pulsoEscala,
              child: const Text('🎉',
                  style: TextStyle(fontSize: 72)),
            ),
            const SizedBox(height: 16),
            Text('¡$_tallerNombre ha llegado!',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'El técnico está en tu ubicación.\nEn breve finalizará el servicio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('¡Entendido!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento en Vivo',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verificar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Banner de estado ────────────────────────────
          _bannerEstado(),
          const SizedBox(height: 20),

          // ── Datos del taller y técnico ─────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.store,
                        color: Colors.indigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Taller asignado',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      Text(_tallerNombre,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  )),
                ]),
                if (_tecnicoNombre != 'Por definir') ...[
                  const Divider(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.person,
                          color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Técnico asignado',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 11)),
                        Text(_tecnicoNombre,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    )),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Animación del auto ─────────────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(
                  _estadoActual == 'En Proceso' || _estadoActual == 'Finalizado'
                      ? '¡El técnico ha llegado!'
                      : _estadoActual == 'En Camino'
                          ? 'Técnico en camino... 🚗'
                          : 'Preparando salida...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _estadoActual == 'En Proceso'
                        ? Colors.green
                        : Colors.indigo,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Pista de animación ──
                _pistaDeTecnico(),
                const SizedBox(height: 16),

                // ── Nota informativa ──
                if (_estadoActual == 'Finalizado')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.payment, color: Colors.teal),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Servicio completado. Redirigiendo al pago...',
                              style: TextStyle(
                                  color: Colors.teal, fontSize: 13))),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Botón volver ────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al menú principal'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.indigo),
                foregroundColor: Colors.indigo,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Banner de estado con colores dinámicos ─────────────────
  Widget _bannerEstado() {
    Color color;
    IconData icono;
    String texto;

    switch (_estadoActual) {
      case 'Confirmada':
        color = Colors.blue;
        icono = Icons.check_circle_outline;
        texto = 'Taller confirmado — preparando salida';
        break;
      case 'En Camino':
        color = Colors.orange;
        icono = Icons.directions_car;
        texto = '¡El técnico está en camino a tu ubicación!';
        break;
      case 'En Proceso':
        color = Colors.green;
        icono = Icons.handyman;
        texto = '¡El técnico ha llegado y está trabajando!';
        break;
      case 'Finalizado':
        color = Colors.teal;
        icono = Icons.task_alt;
        texto = 'Servicio completado ✅ — Preparando cobro...';
        break;
      default:
        color = Colors.indigo;
        icono = Icons.info_outline;
        texto = 'Estado: $_estadoActual';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icono, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
        ),
      ]),
    );
  }

  // ── Pista visual con el auto animado ──────────────────────
  Widget _pistaDeTecnico() {
    final haLlegado = _estadoActual == 'En Proceso' ||
        _estadoActual == 'Finalizado';

    return AnimatedBuilder(
      animation: _autoAnimacion,
      builder: (context, child) {
        // Usamos _progreso directamente (actualizado por el polling)
        final progreso = _progreso;

        return SizedBox(
          height: 90,
          child: Stack(alignment: Alignment.center, children: [
            // Línea de pista gris
            Positioned(
              left: 30,
              right: 30,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Línea de progreso
            Positioned(
              left: 30,
              child: LayoutBuilder(builder: (ctx, _) {
                final ancho = MediaQuery.of(context).size.width - 40 - 60;
                return Container(
                  width: ancho * progreso,
                  height: 5,
                  decoration: BoxDecoration(
                    color: haLlegado ? Colors.green : Colors.indigo,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            // Punto origen (cliente)
            const Positioned(
              left: 10,
              child: Column(children: [
                Icon(Icons.my_location, color: Colors.red, size: 22),
                SizedBox(height: 4),
                Text('Tú', style: TextStyle(fontSize: 10, color: Colors.red)),
              ]),
            ),

            // Punto destino (taller)
            const Positioned(
              right: 10,
              child: Column(children: [
                Icon(Icons.home_repair_service,
                    color: Colors.indigo, size: 22),
                SizedBox(height: 4),
                Text('Taller',
                    style: TextStyle(fontSize: 10, color: Colors.indigo)),
              ]),
            ),

            // El auto que se mueve
            Positioned(
              left: (() {
                final ancho = MediaQuery.of(context).size.width - 40 - 60;
                // El auto va de x=30 hasta el 85% del ancho disponible
                return 30.0 + (ancho * 0.85) * progreso;
              })(),
              child: Text(
                haLlegado ? '✅' : '🚗',
                style: const TextStyle(fontSize: 30),
              ),
            ),

            // Porcentaje de progreso
            if (_estadoActual == 'En Camino' && _progreso > 0)
              Positioned(
                bottom: 0,
                child: Text(
                  '${(_progreso * 100).round()}% del camino',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey),
                ),
              ),
          ]),
        );
      },
    );
  }
}