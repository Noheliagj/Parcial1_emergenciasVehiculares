import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../theme.dart';
import 'vehiculos_page.dart';
import 'emergencia_page.dart';
import 'mis_emergencias_page.dart';
import 'talleres_aceptaron_page.dart';
import 'transcripcion_audio_page.dart';
import 'pago_page.dart';
import 'seguimiento_servicio_page.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardPage extends StatefulWidget {
  final int clienteId;
  const DashboardPage({super.key, required this.clienteId});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Auxilio Vial', 'Talleres', 'Mi Perfil'][_tab]),
        automaticallyImplyLeading: false,
        actions: [
          if (_tab == 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.circle, size: 8, color: AppTheme.danger),
                SizedBox(width: 5),
                Text('En vivo',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
      body: [
        _TabSOS(clienteId: widget.clienteId),
        // ─── CORRECCIÓN: Tab Talleres ahora es StatefulWidget
        //     que carga datos reales del backend
        const _TabTalleres(),
        _TabPerfil(clienteId: widget.clienteId),
      ][_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
          color: Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textMuted,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.emergency_share_outlined),
                activeIcon: Icon(Icons.emergency_share),
                label: 'SOS'),
            BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                activeIcon: Icon(Icons.store),
                label: 'Talleres'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB SOS — Polling automático corregido
// ═══════════════════════════════════════════════════════════════
class _TabSOS extends StatefulWidget {
  final int clienteId;
  const _TabSOS({required this.clienteId});
  @override
  State<_TabSOS> createState() => _TabSOSState();
}

class _TabSOSState extends State<_TabSOS> {
  Timer? _pollingTimer;
  int? _emergenciaNotificadaId; // Para saber a cuál ya le mostramos el PopUp
  bool _verificandoAhora = false;
  
  // NUEVO: Aquí guardamos la info del servicio mientras no esté finalizado
  Map<String, dynamic>? _servicioEnCurso;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificar();
    });
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _verificar(),
    );
  }

  Future<void> _verificar() async {
    if (_verificandoAhora || !mounted) return;
    _verificandoAhora = true;

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/clientes/${widget.clienteId}/emergencias'),
      );
      if (!mounted || res.statusCode != 200) return;

      final lista = jsonDecode(res.body) as List<dynamic>;
      Map<String, dynamic>? servicioActivoDetectado;

      for (final item in lista) {
        final em = item as Map<String, dynamic>;
        final estado = em['estado'] as String? ?? '';
        final emergenciaId = em['id'] as int;

        // 1. Detectar si hay un servicio vivo (Cualquier estado menos Pendiente/Finalizado/Cancelado)
        if (estado != 'Pendiente' && estado != 'Finalizado' && estado != 'Cancelado') {
          servicioActivoDetectado = em;
        }

        // 2. Lógica del POPUP (Solo mostrar si los talleres aceptaron y no lo hemos mostrado)
        if (estado == 'AceptadaPorTaller' && _emergenciaNotificadaId != emergenciaId) {
          final res2 = await http.get(Uri.parse(
            '${ApiConfig.baseUrl}/api/emergencias/$emergenciaId/talleres-aceptaron',
          ));

          if (!mounted || res2.statusCode != 200) continue;

          final datos2 = jsonDecode(res2.body) as Map<String, dynamic>;
          final talleres = datos2['talleres'] as List;

          if (talleres.isNotEmpty) {
            _emergenciaNotificadaId = emergenciaId; // Marcar como notificada
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                mostrarAlertaTalleresAceptaron(
                  context,
                  emergenciaId: emergenciaId,
                  cantidadTalleres: talleres.length,
                );
              }
            });
          }
        }

        // 3. Resetear la memoria del popup si el servicio ya terminó
        if (estado == 'Finalizado' && emergenciaId == _emergenciaNotificadaId) {
          _emergenciaNotificadaId = null;
        }
      }

      // Actualizar la interfaz con el servicio en curso (si lo hay)
      if (mounted) {
        setState(() {
          _servicioEnCurso = servicioActivoDetectado;
        });
      }

    } catch (_) {
      // Ignorar errores de red en el polling
    } finally {
      _verificandoAhora = false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 👇 ESTA ES LA NUEVA TARJETA QUE NO DESAPARECE 👇
                _buildTarjetaSeguimiento(context),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.car_crash_outlined,
                      size: 64, color: Colors.redAccent),
                ),
                const SizedBox(height: 28),

                const Text('¿Necesitas asistencia?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text(
                  'Presiona SOS para reportar.\nPuedes adjuntar foto y audio.',
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Botón SOS
                SizedBox(
                  width: 180,
                  height: 180,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: const CircleBorder(),
                      elevation: 10,
                      shadowColor: Colors.redAccent.withOpacity(0.5),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                EmergenciaPage(clienteId: widget.clienteId)),
                      );
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new_rounded,
                            size: 56, color: Colors.white),
                        SizedBox(height: 8),
                        Text('SOS',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Mis Emergencias
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo, width: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MisEmergenciasPage(clienteId: widget.clienteId)),
                  ),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Mis Emergencias',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

 // ─── NUEVO WIDGET: TARJETA DE SEGUIMIENTO (Banner Inteligente) ───
  Widget _buildTarjetaSeguimiento(BuildContext context) {
    // Si no hay servicio en curso, no mostramos nada
    if (_servicioEnCurso == null) return const SizedBox.shrink();

    final estado = _servicioEnCurso!['estado'] ?? '';
    final taller = _servicioEnCurso!['taller_asignado'] ?? 'Asignando...';
    final tecnico = _servicioEnCurso!['tecnico_asignado'] ?? 'Por definir';

    // CASO A: Taller aceptó, pero cliente aún no confirma (Banner Naranja)
    if (estado == 'AceptadaPorTaller') {
      return InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TalleresAceptaronPage(
                  emergenciaId: _servicioEnCurso!['id'])),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 30),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.shade400, width: 1.5),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.airport_shuttle,
                  color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('¡Talleres respondieron!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepOrange)),
                SizedBox(height: 4),
                Text('Toca para ver quién puede ayudarte.',
                    style: TextStyle(color: Colors.black87, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 16),
          ]),
        ),
      );
    }

    // CASO B: Ya fue confirmada y está en progreso (Tarjeta de seguimiento)
    // 👇 AQUÍ ESTÁN LAS VARIABLES QUE SE HABÍAN BORRADO 👇
    Color colorEstado = Colors.indigo;
    IconData iconoEstado = Icons.handyman;
    
    if (estado == 'En Camino') {
      colorEstado = Colors.blue;
      iconoEstado = Icons.directions_car;
    } else if (estado == 'En Proceso') {
      colorEstado = Colors.green;
      iconoEstado = Icons.build_circle;
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeguimientoServicioPage(emergencia: _servicioEnCurso!),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 30),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: colorEstado.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4)
            )
          ],
          border: Border.all(color: colorEstado.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconoEstado, color: colorEstado, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Servicio $estado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorEstado),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Taller: $taller', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Técnico: $tecnico', style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            const Text('Toca aquí para ver el mapa y tiempo de llegada 📍', 
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════
// TAB TALLERES — Carga TODOS los talleres registrados del sistema
// ═══════════════════════════════════════════════════════════════
// CORRECCIÓN 3: Antes mostraba 3 tarjetas hardcodeadas.
// Ahora llama a GET /talleres/ para traer los reales.
// Necesitas agregar ese endpoint en main.py (ver abajo).
class _TabTalleres extends StatefulWidget {
  const _TabTalleres();
  @override
  State<_TabTalleres> createState() => _TabTalleresState();
}

class _TabTalleresState extends State<_TabTalleres> {
  bool _cargando = true;
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
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/talleres/'));
      if (res.statusCode == 200) {
        final datos = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _talleres = datos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _cargando = false;
        });
      } else {
        setState(() { _error = 'Error al cargar talleres'; _cargando = false; });
      }
    } catch (e) {
      setState(() { _error = 'Sin conexión con el servidor'; _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
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
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No hay talleres registrados aún.',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTalleres,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _talleres.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = _talleres[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home_repair_service_outlined,
                      color: Colors.indigo),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['nombre_taller'] ?? 'Taller',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      if (t['direccion'] != null)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(t['direccion'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      if (t['telefono'] != null)
                        Row(children: [
                          const Icon(Icons.phone_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(t['telefono'],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                    ],
                  ),
                ),
                // Indicador verde de "registrado en el sistema"
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text('Activo',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB PERFIL — sin cambios
// ═══════════════════════════════════════════════════════════════
class _TabPerfil extends StatelessWidget {
  final int clienteId;
  const _TabPerfil({required this.clienteId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('Mi cuenta',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain)),
            const SizedBox(height: 4),
            Text('ID: $clienteId',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 32),

        Card(
          child: Column(children: [
            _opcion(
              icon: Icons.directions_car_outlined,
              color: AppTheme.primary,
              titulo: 'Mis Vehículos',
              subtitulo: 'Gestiona tus autos registrados',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          VehiculosPage(clienteId: clienteId))),
            ),
            const Divider(height: 1, indent: 60),
            _opcion(
              icon: Icons.history_outlined,
              color: const Color(0xFF10B981),
              titulo: 'Mis Emergencias',
              subtitulo: 'Historial con análisis IA',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MisEmergenciasPage(clienteId: clienteId))),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        Card(
          child: _opcion(
            icon: Icons.logout_rounded,
            color: AppTheme.danger,
            titulo: 'Cerrar sesión',
            subtitulo: 'Salir de tu cuenta',
            onTap: () => Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false),
            textoRojo: true,
          ),
        ),
      ],
    );
  }

  Widget _opcion({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    bool textoRojo = false,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(titulo,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textoRojo ? AppTheme.danger : AppTheme.textMain,
              fontSize: 14)),
      subtitle: Text(subtitulo,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 13, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }
}