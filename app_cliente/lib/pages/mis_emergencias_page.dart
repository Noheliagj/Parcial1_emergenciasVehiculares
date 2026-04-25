import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../api_config.dart';

class MisEmergenciasPage extends StatefulWidget {
  final int clienteId;
  const MisEmergenciasPage({super.key, required this.clienteId});

  @override
  State<MisEmergenciasPage> createState() => _MisEmergenciasPageState();
}

class _MisEmergenciasPageState extends State<MisEmergenciasPage> {
  bool _cargando = true;
  List<Map<String, dynamic>> _emergencias = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarEmergencias();
  }

  Future<void> _cargarEmergencias() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/clientes/${widget.clienteId}/emergencias'),
      );
      if (res.statusCode == 200) {
        final datos = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _emergencias = datos
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar emergencias (${res.statusCode})';
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Sin conexión con el servidor';
        _cargando = false;
      });
    }
  }

  bool _estaCompletada(String estado) => estado == 'Finalizado';

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Finalizado':
        return Colors.green;
      case 'En Proceso':
        return Colors.blue;
      case 'En Camino':
        return Colors.orange;
      case 'Aceptada':
        return Colors.teal;
      case 'Cancelado':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  Future<void> _abrirMaps(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Emergencias',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEmergencias,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _cargarEmergencias,
                child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_emergencias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No tienes emergencias registradas',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarEmergencias,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emergencias.length,
        itemBuilder: (context, i) => _tarjetaEmergencia(_emergencias[i]),
      ),
    );
  }

  Widget _tarjetaEmergencia(Map<String, dynamic> em) {
    final estado = em['estado'] as String? ?? 'Pendiente';
    final completada = _estaCompletada(estado);
    final colorBorde = completada ? Colors.green : Colors.red;

    final urlImagen = em['foto_url'] as String?;
    final tieneImagen = urlImagen != null && urlImagen.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorBorde, width: 2),
      ),
      elevation: 3,
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorBorde.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completada ? Icons.check_circle : Icons.error_outline,
              color: colorBorde,
              size: 24,
            ),
          ),
          title: Text(
            'Emergencia #${em['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _colorEstado(estado).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _colorEstado(estado)),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: _colorEstado(estado),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                em['direccion'] ?? 'Sin dirección',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          children: [
            const Divider(),

            _filaDetalle(Icons.description_outlined, 'Descripción',
                em['descripcion'] ?? 'Sin descripción'),

            if (em['taller_asignado'] != null)
              _filaDetalle(Icons.store_outlined, 'Taller asignado',
                  em['taller_asignado']),

            if (em['tecnico_asignado'] != null)
              _filaDetalle(Icons.person_outlined, 'Técnico',
                  em['tecnico_asignado']),

            if (em['transcripcion'] != null)
              _filaDetalle(Icons.mic_outlined, 'Transcripción',
                  em['transcripcion']),

            if (em['latitud'] != null && em['longitud'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(children: [
                  const Icon(Icons.map_outlined, size: 16, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${(em['latitud'] as num).toStringAsFixed(5)}, '
                      '${(em['longitud'] as num).toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _abrirMaps(
                      (em['latitud'] as num).toDouble(),
                      (em['longitud'] as num).toDouble(),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Maps', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal),
                  ),
                ]),
              ),

            // Mostrar la foto del cliente (con clic para agrandar)
            if (tieneImagen) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Foto adjunta (Toca para agrandar):',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: () =>
                    _mostrarImagenPantallaCompleta(context, urlImagen!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        urlImagen!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                      // Ícono de lupa sobre la imagen
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(IconData icono, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
            Text(valor, style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Muestra la imagen a pantalla completa con opción de Zoom
  // ════════════════════════════════════════════════════════════
  void _mostrarImagenPantallaCompleta(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}