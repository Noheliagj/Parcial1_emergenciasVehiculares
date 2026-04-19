import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

import 'solicitud_detalle_page.dart';

class MisSolicitudesPage extends StatefulWidget {
  final int clienteId;

  const MisSolicitudesPage({super.key, required this.clienteId});

  @override
  State<MisSolicitudesPage> createState() => _MisSolicitudesPageState();
}

class _MisSolicitudesPageState extends State<MisSolicitudesPage> {
  List<Map<String, dynamic>> solicitudes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    cargarSolicitudes();
  }

  Future<void> cargarSolicitudes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final respuesta = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/clientes/${widget.clienteId}/emergencias'),
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as List<dynamic>;
        setState(() {
          solicitudes = datos
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'No se pudieron cargar tus solicitudes.';
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión con el servidor.';
        _cargando = false;
      });
    }
  }

  Color _colorEstado(String estado) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarSolicitudes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: cargarSolicitudes,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : solicitudes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'Aún no tienes solicitudes registradas.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: cargarSolicitudes,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: solicitudes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final solicitud = solicitudes[index];
                          final estado = (solicitud['estado'] ?? 'Pendiente').toString();
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Solicitud #${solicitud['id']}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _colorEstado(estado).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          estado,
                                          style: TextStyle(
                                            color: _colorEstado(estado),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Dirección: ${solicitud['direccion'] ?? 'No disponible'}'),
                                  const SizedBox(height: 6),
                                  Text('Descripción: ${solicitud['descripcion'] ?? 'Sin descripción'}'),
                                  const SizedBox(height: 6),
                                  Text('Taller: ${solicitud['taller_asignado'] ?? 'Pendiente de asignación'}'),
                                  const SizedBox(height: 6),
                                  Text('Técnico: ${solicitud['tecnico_asignado'] ?? 'Pendiente'}'),
                                  if (solicitud['transcripcion'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text('Audio: ${solicitud['transcripcion']}'),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SolicitudDetallePage(
                                              solicitudId: solicitud['id'] as int,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.visibility_outlined),
                                      label: const Text('Ver detalle'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}