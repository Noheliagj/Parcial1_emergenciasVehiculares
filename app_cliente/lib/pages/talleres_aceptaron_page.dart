

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../pages/pago_page.dart';



double calcularDistanciaKm(
  double lat1, double lon1,
  double lat2, double lon2,
) {
  const R = 6371.0; // Radio de la Tierra en km
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _rad(double deg) => deg * math.pi / 180;

// ════════════════════════════════════════════════════════════════
// PÁGINA: Lista de talleres que aceptaron + ranking inteligente
// ════════════════════════════════════════════════════════════════
class TalleresAceptaronPage extends StatefulWidget {
  final int emergenciaId;
  final Map<String, dynamic>? datosFicha;
  // Coordenadas del cliente (para calcular distancia real)
  final double? clienteLat;
  final double? clienteLon;

  const TalleresAceptaronPage({
    super.key,
    required this.emergenciaId,
    this.datosFicha,
    this.clienteLat,
    this.clienteLon,
  });

  @override
  State<TalleresAceptaronPage> createState() =>
      _TalleresAceptaronPageState();
}

class _TalleresAceptaronPageState extends State<TalleresAceptaronPage> {
  bool _cargando   = true;
  bool _confirmando = false;
  List<Map<String, dynamic>> _talleres = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTalleres();
  }

  Future<void> _cargarTalleres() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/api/emergencias/${widget.emergenciaId}/talleres-aceptaron',
      ));
      if (res.statusCode == 200) {
        final datos = jsonDecode(res.body) as Map<String, dynamic>;
        List<Map<String, dynamic>> talleres =
            List<Map<String, dynamic>>.from(datos['talleres'] as List);

        // ── CU-17: Calcular distancia y score para cada taller ──
        talleres = _calcularDistanciasYOrdenar(talleres);

        setState(() {
          _talleres = talleres;
          _cargando = false;
        });
      } else {
        setState(() {
          _error    = 'Error al cargar talleres (${res.statusCode})';
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error    = 'Sin conexión con el servidor';
        _cargando = false;
      });
    }
  }

  // ── CU-17: Algoritmo de ordenamiento inteligente ──────────
  
  
  List<Map<String, dynamic>> _calcularDistanciasYOrdenar(
    List<Map<String, dynamic>> talleres,
  ) {
    final bool tenemoGPS =
        widget.clienteLat != null && widget.clienteLon != null;

    for (final t in talleres) {
      double distanciaKm = 0;
      bool tieneDistancia = false;

      // Calcular distancia real si el taller tiene coordenadas
      // y el cliente tiene GPS
      final tallerLat = t['latitud'] as double?;
      final tallerLon = t['longitud'] as double?;

      if (tenemoGPS && tallerLat != null && tallerLon != null) {
        distanciaKm = calcularDistanciaKm(
          widget.clienteLat!,
          widget.clienteLon!,
          tallerLat,
          tallerLon,
        );
        tieneDistancia = true;
      }

      t['distancia_km']    = tieneDistancia ? distanciaKm : null;
      t['tiene_distancia'] = tieneDistancia;

      // Score: tiempo tiene más peso (0.7) que distancia (0.3)
      // Si no tenemos distancia, usamos solo tiempo
      final tiempo = (t['tiempo_estimado_minutos'] as int? ?? 30).toDouble();
      if (tieneDistancia) {
        t['score'] = (tiempo * 0.7) + (distanciaKm * 5 * 0.3);
        // multiplicamos distanciaKm * 5 para ponerla en escala similar a minutos
      } else {
        t['score'] = tiempo;
      }
    }

    // Ordenar de menor score a mayor (primero el mejor)
    talleres.sort((a, b) =>
        (a['score'] as double).compareTo(b['score'] as double));

    return talleres;
  }

  // ── El cliente confirma un taller ─────────────────────────
  Future<void> _confirmarTaller(Map<String, dynamic> tallerElegido) async {
    setState(() => _confirmando = true);
    try {
      final aceptacionId = tallerElegido['aceptacion_id'] as int;
      final res = await http.post(Uri.parse(
        '${ApiConfig.baseUrl}/api/emergencias/${widget.emergenciaId}'
        '/confirmar-taller?aceptacion_id=$aceptacionId',
      ));

      if (res.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingTallerPage(
              emergenciaId:   widget.emergenciaId,
              nombreTaller:   tallerElegido['nombre_taller'],
              tiempoEstimado: tallerElegido['tiempo_estimado_minutos'] ?? 15,
              datosFicha:     widget.datosFicha,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al confirmar: ${res.body}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error de conexión'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talleres disponibles',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _cargarTalleres)
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Buscando talleres disponibles...',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _cargarTalleres, child: const Text('Reintentar')),
        ]),
      );
    }
    if (_talleres.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Esperando respuesta de talleres...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Los talleres cercanos están revisando tu solicitud.',
              style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _cargarTalleres,
            icon: const Icon(Icons.refresh),
            label: const Text('Verificar ahora'),
          ),
        ]),
      );
    }

    return Column(children: [
      // Banner con ficha IA
      if (widget.datosFicha != null) _bannerFichaIA(),

      // Instrucción con info del criterio de ordenamiento
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: Colors.indigo.shade50,
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.indigo, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_talleres.length} taller(es) disponible(s). '
              'Ordenados por tiempo + distancia (IA).',
              style: const TextStyle(color: Colors.indigo, fontSize: 13),
            ),
          ),
        ]),
      ),

      // Lista de talleres
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _talleres.length,
          itemBuilder: (context, i) =>
              _tarjetaTaller(_talleres[i], esRecomendado: i == 0),
        ),
      ),
    ]);
  }

  Widget _bannerFichaIA() {
    final tipo  = widget.datosFicha?['tipo_ia']?.toString() ?? '—';
    final sev   = widget.datosFicha?['severidad_ia']?.toString() ?? '—';
    final grua  = widget.datosFicha?['sugiere_grua'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.psychology, color: Colors.purple, size: 16),
          SizedBox(width: 6),
          Text('Diagnóstico IA enviado al taller',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _chip('🔧 $tipo', Colors.blue),
          _chip('⚠️ $sev', Colors.orange),
          if (grua) _chip('🚛 Grúa sugerida', Colors.red),
        ]),
      ]),
    );
  }

  Widget _chip(String texto, Color color) {
    return Chip(
      label: Text(texto,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _tarjetaTaller(Map<String, dynamic> taller, {bool esRecomendado = false}) {
    final nombre     = taller['nombre_taller']          as String? ?? 'Taller';
    final direccion  = taller['direccion_taller']        as String? ?? '';
    final telefono   = taller['telefono']                as String? ?? '';
    final minutos    = taller['tiempo_estimado_minutos'] as int?    ?? 15;
    final mensaje    = taller['mensaje']                 as String?;
    final distanciaKm = taller['distancia_km']           as double?;
    final tieneGPS   = taller['tiene_distancia']         as bool?   ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: esRecomendado ? Colors.amber.shade600 : Colors.grey.shade300,
          width: esRecomendado ? 2.5 : 1,
        ),
      ),
      elevation: esRecomendado ? 6 : 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + badge recomendado
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: esRecomendado
                      ? Colors.amber.shade50
                      : Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.store,
                    color: esRecomendado
                        ? Colors.amber.shade700
                        : Colors.indigo,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    if (esRecomendado)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade600),
                        ),
                        child: Text('⭐ Recomendado',
                            style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  if (direccion.isNotEmpty)
                    Text(direccion,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),

            // ── CU-17: Tiempo + distancia en la misma fila ──
            Row(children: [
              // Tiempo estimado
              Row(children: [
                const Icon(Icons.timer_outlined,
                    size: 16, color: Colors.teal),
                const SizedBox(width: 4),
                Text('$minutos min',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal)),
              ]),
              const SizedBox(width: 16),
              // Distancia real (si disponible)
              if (tieneGPS && distanciaKm != null)
                Row(children: [
                  const Icon(Icons.straighten, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('${distanciaKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue)),
                ]),
              if (!tieneGPS)
                const Text('Distancia no calculada',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),

            if (mensaje != null && mensaje.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 14, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('"$mensaje"',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic)),
                ),
              ]),
            ],

            if (telefono.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(telefono,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ],

            const SizedBox(height: 14),

            // Botón elegir
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: esRecomendado
                      ? Colors.amber.shade600
                      : Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _confirmando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                label: Text(
                  _confirmando ? 'Confirmando...' : 'Elegir este taller',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                onPressed:
                    _confirmando ? null : () => _confirmarTaller(taller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PÁGINA: Tracking con redirección a PagoPage al finalizar
// ════════════════════════════════════════════════════════════════
class TrackingTallerPage extends StatefulWidget {
  final int emergenciaId;
  final String nombreTaller;
  final int tiempoEstimado;
  final Map<String, dynamic>? datosFicha;
  
  // Variables declaradas
  final double? clienteLat;
  final double? clienteLon;

  // Constructor con el 'this.' agregado correctamente
  const TrackingTallerPage({
    super.key,
    required this.emergenciaId,
    required this.nombreTaller,
    required this.tiempoEstimado,
    this.datosFicha,
    this.clienteLat, 
    this.clienteLon,
  });

  @override
  State<TrackingTallerPage> createState() => _TrackingTallerPageState();
}

class _TrackingTallerPageState extends State<TrackingTallerPage>
    with TickerProviderStateMixin {
  late AnimationController _autoController;
  late Animation<double>   _autoPosition;
  late AnimationController _pulsoController;
  late Animation<double>   _pulsoEscala;
  
  // Tu plugin listo
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  String _estadoActual = 'Confirmada';
  bool   _haLlegado    = false;
  Timer? _pollingTimer;
  int    _minutosRestantes = 0;

  @override
  void initState() {
    super.initState();

    // ── 1. INICIALIZAR NOTIFICACIONES AL ABRIR LA PANTALLA ──
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // ── 2. TU CÓDIGO ORIGINAL DE ANIMACIONES Y TIMER ──
    _minutosRestantes = widget.tiempoEstimado;

    _autoController = AnimationController(
      vsync: this,
      duration: Duration(
          minutes: widget.tiempoEstimado > 0 ? widget.tiempoEstimado : 1),
    );
    _autoPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _autoController, curve: Curves.easeInOut),
    );
    _autoController.forward();

    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulsoEscala = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.elasticOut),
    );

    Timer.periodic(const Duration(minutes: 1), (t) {
      if (_minutosRestantes > 0) setState(() => _minutosRestantes--);
      else t.cancel();
    });

    _pollingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _verificarEstado());
  }

  // ── 3. LA FUNCIÓN QUE HACE SONAR EL CELULAR ──
  // Pégala justo debajo de tu initState
  Future<void> _notificarLlegada() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'canal_emergencias_01', // ID del canal
      'Avisos de Llegada',    // Nombre del canal
      channelDescription: 'Notificaciones cuando el técnico llega a la ubicación',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      0, 
      '🚨 ¡El técnico ha llegado!', 
      '${widget.nombreTaller} ya está en tu ubicación para asistirte.', 
      platformChannelSpecifics,
    );
  }


Future<void> _verificarEstado() async {
  try {
    // 1. Consultamos el estado al servidor
    final res = await http.get(Uri.parse(
      '${ApiConfig.baseUrl}/api/emergencias/${widget.emergenciaId}/estado',
    ));

    if (res.statusCode == 200 && mounted) {
      final datos = jsonDecode(res.body);
      final nuevoEstado = datos['emergencia']['estado']?.toString() ?? '';
      
      // Coordenadas del taller (que vienen del backend)
      final tallerLat = datos['emergencia']['taller_lat'] as double?;
      final tallerLon = datos['emergencia']['taller_lon'] as double?;

      // 2. LÓGICA DE DISTANCIA REAL (Comparación de coordenadas)
      if (widget.clienteLat != null && widget.clienteLon != null && tallerLat != null && tallerLon != null) {
        double distanciaRestante = calcularDistanciaKm(
          widget.clienteLat!, 
          widget.clienteLon!, 
          tallerLat, 
          tallerLon
        );

        print("Distancia real: $distanciaRestante km");

        // Si el taller está a menos de 100 metros (0.1 km)
        if (distanciaRestante <= 0.1 && !_haLlegado) {
          _marcarLlegadaReal();
        }
      }

      // 3. Lógica por cambio de estado manual (desde el dashboard del taller)
      if (nuevoEstado != _estadoActual) {
        setState(() => _estadoActual = nuevoEstado);
      }

      if ((nuevoEstado == 'En Proceso' || nuevoEstado == 'Finalizado') && !_haLlegado) {
        _marcarLlegadaReal();
      }
    }
  } catch (e) {
    print("Error en polling: $e");
  }
}

void _marcarLlegadaReal() async {
  setState(() {
    _haLlegado = true;
    _minutosRestantes = 0; // Forzamos el contador a cero
  });
  
  _pollingTimer?.cancel();
  _autoController.stop();
  _pulsoController.repeat(reverse: true);

  if (mounted) {
    if (_estadoActual == 'Finalizado') {
      _irAPagar();
    } else {
      _mostrarDialogLlegada();
    }
  }
}

  void _mostrarDialogLlegada() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _pulsoEscala,
              child: const Text('🎉', style: TextStyle(fontSize: 72)),
            ),
            const SizedBox(height: 16),
            Text('¡${widget.nombreTaller} ha llegado!',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'El técnico está en tu ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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

  void _irAPagar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PagoPage(emergenciaId: widget.emergenciaId),
      ),
    );
  }

  @override
  void dispose() {
    _autoController.dispose();
    _pulsoController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Técnico en camino',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Taller asignado
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.indigo.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.store,
                      color: Colors.indigo, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Taller asignado',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(widget.nombreTaller,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Banner de estado
          _bannerEstado(),
          const SizedBox(height: 20),

          // Animación del auto
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(
                  _haLlegado ? '¡El técnico llegó!' : 'Técnico en camino...',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _haLlegado ? Colors.green : Colors.indigo),
                ),
                const SizedBox(height: 20),
                _AnimacionAuto(
                    positionAnimation: _autoPosition, haLlegado: _haLlegado),
                const SizedBox(height: 16),
                if (!_haLlegado)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.teal, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _minutosRestantes > 0
                          ? 'Llega en aprox. $_minutosRestantes min'
                          : 'Llegando en cualquier momento...',
                      style: const TextStyle(
                          color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bannerEstado() {
    Color   color;
    IconData icono;
    String  texto;
    switch (_estadoActual) {
      case 'Confirmada':
        color = Colors.blue;
        icono = Icons.check_circle_outline;
        texto = 'Taller confirmado — preparando salida';
        break;
      case 'En Camino':
        color = Colors.orange;
        icono = Icons.directions_car;
        texto = '¡El técnico está en camino!';
        break;
      case 'En Proceso':
        color = Colors.green;
        icono = Icons.handyman;
        texto = '¡El técnico ha llegado y está trabajando!';
        break;
      case 'Finalizado':
        color = Colors.teal;
        icono = Icons.task_alt;
        texto = 'Servicio completado ✅';
        break;
      default:
        color = Colors.grey;
        icono = Icons.info_outline;
        texto = 'Estado: $_estadoActual';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icono, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Widget de animación del auto (sin cambios)
// ═══════════════════════════════════════════════════════════════
class _AnimacionAuto extends StatelessWidget {
  final Animation<double> positionAnimation;
  final bool haLlegado;
  const _AnimacionAuto(
      {required this.positionAnimation, required this.haLlegado});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: positionAnimation,
      builder: (context, child) {
        return SizedBox(
          height: 80,
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              left: 20,
              right: 20,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: 20,
              child: LayoutBuilder(builder: (ctx, _) {
                final totalWidth = MediaQuery.of(context).size.width - 48 - 40;
                return Container(
                  width: totalWidth * positionAnimation.value,
                  height: 4,
                  decoration: BoxDecoration(
                    color: haLlegado ? Colors.green : Colors.indigo,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const Positioned(
              left: 10,
              child: Column(children: [
                Icon(Icons.my_location, color: Colors.red, size: 20),
                Text('Tú', style: TextStyle(fontSize: 9)),
              ]),
            ),
            const Positioned(
              right: 10,
              child: Column(children: [
                Icon(Icons.home_repair_service, color: Colors.indigo, size: 20),
                Text('Taller', style: TextStyle(fontSize: 9)),
              ]),
            ),
            Positioned(
              left: (() {
                final w = MediaQuery.of(context).size.width - 48 - 40;
                return 20 + w * 0.85 * positionAnimation.value;
              })(),
              child: Text(haLlegado ? '✅' : '🚗',
                  style: const TextStyle(fontSize: 28)),
            ),
          ]),
        );
      },
    );
  }
}

// ── Helper para el popup automático (sin cambios) ──────────────
void mostrarAlertaTalleresAceptaron(
  BuildContext context, {
  required int emergenciaId,
  required int cantidadTalleres,
  Map<String, dynamic>? datosFicha,
  double? clienteLat,
  double? clienteLon,
}) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.green.shade50, shape: BoxShape.circle),
          child: const Text('🏪', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 16),
        Text('$cantidadTalleres taller(es) respondieron',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Elige el que más te convenga.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.store, color: Colors.white),
            label: const Text('Ver talleres disponibles',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TalleresAceptaronPage(
                    emergenciaId: emergenciaId,
                    datosFicha:   datosFicha,
                    clienteLat:   clienteLat,
                    clienteLon:   clienteLon,
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    ),
  );
}