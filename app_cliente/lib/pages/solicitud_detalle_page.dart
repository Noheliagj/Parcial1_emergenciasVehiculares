import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class SolicitudDetallePage extends StatefulWidget {
  final int solicitudId;

  const SolicitudDetallePage({super.key, required this.solicitudId});

  @override
  State<SolicitudDetallePage> createState() => _SolicitudDetallePageState();
}

class _SolicitudDetallePageState extends State<SolicitudDetallePage> {
  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? emergencia;
  List<Map<String, dynamic>> historial = [];
  String? nombreTaller;
  String? nombreTecnico;

  @override
  void initState() {
    super.initState();
    cargarDetalle();
  }

  Future<void> cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final respuesta = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/emergencias/${widget.solicitudId}/estado'),
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        setState(() {
          emergencia = Map<String, dynamic>.from(datos['emergencia'] as Map);
          historial = (datos['historial_estados'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          nombreTaller = datos['nombre_taller']?.toString();
          nombreTecnico = datos['nombre_tecnico']?.toString();
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'No se pudo obtener el detalle de la solicitud.';
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión al consultar el estado.';
        _cargando = false;
      });
    }
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'Aceptada':
        return Colors.green;
      case 'En Camino':
        return Colors.orange;
      case 'En Proceso':
        return Colors.blue;
      case 'Finalizado':
        return Colors.teal;
      case 'Rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = emergencia?['estado']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitud #${widget.solicitudId}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: cargarDetalle,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _colorEstado(estado).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _colorEstado(estado).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado actual: ${estado ?? 'No disponible'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _colorEstado(estado),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Dirección: ${emergencia?['direccion'] ?? 'No disponible'}'),
                            const SizedBox(height: 6),
                            Text('Descripción: ${emergencia?['descripcion'] ?? 'Sin descripción'}'),
                            const SizedBox(height: 6),
                            Text('Taller asignado: ${nombreTaller ?? 'Pendiente'}'),
                            const SizedBox(height: 6),
                            Text('Técnico asignado: ${nombreTecnico ?? 'Pendiente'}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Historial de actualizaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (historial.isEmpty)
                        const Text('Aún no hay movimientos registrados para esta solicitud.')
                      else
                        ...historial.map(
                          (evento) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Icon(Icons.update, color: _colorEstado(evento['estado_nuevo']?.toString())),
                              title: Text('${evento['estado_anterior']} → ${evento['estado_nuevo']}'),
                              subtitle: Text(
                                evento['descripcion']?.toString() ?? 'Sin observaciones',
                              ),
                              trailing: Text(
                                evento['fecha_cambio']?.toString().substring(0, 16) ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}