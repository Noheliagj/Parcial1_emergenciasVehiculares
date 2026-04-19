import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart'; // Para formatear la fecha y hora

class FichaResumenPage extends StatelessWidget {
  final Map<String, dynamic> datosIA;
  final Uint8List imagenBytes;

  const FichaResumenPage({super.key, required this.datosIA, required this.imagenBytes});

  @override
  Widget build(BuildContext context) {
    // Generamos datos automáticos del sistema
    final String fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String folioSistema = "INC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    
    // Extraemos la info de la IA
    final String tipo = datosIA['tipo_incidente']?.toString().toUpperCase() ?? 'DESCONOCIDO';
    final String severidad = datosIA['nivel_severidad']?.toString().toUpperCase() ?? 'NO DEFINIDA';
    final bool requiereGrua = datosIA['sugiere_grua'] ?? false;
    final String confianza = datosIA['confianza_ia'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha del Incidente', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de la Ficha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("REPORTE OFICIAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Text(folioSistema, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                    const Divider(thickness: 2, height: 30),

                    // Evidencia Fotográfica
                    const Text("Evidencia Fotográfica:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(imagenBytes, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 20),

                    // Datos generados por el Sistema
                    _construirFilaDato(Icons.calendar_today, "Fecha y Hora", fechaActual),
                    const SizedBox(height: 15),

                    // Análisis de la IA
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade200)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("🤖 Diagnóstico Automático (IA)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 10),
                          _construirFilaDato(Icons.car_crash, "Clasificación", tipo),
                          const SizedBox(height: 8),
                          _construirFilaDato(Icons.warning_amber_rounded, "Severidad", severidad, 
                            colorValor: severidad == 'CRÍTICO' || severidad == 'GRAVE' ? Colors.red : Colors.orange.shade700),
                          const SizedBox(height: 8),
                          _construirFilaDato(Icons.analytics, "Confianza del Modelo", confianza),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Alerta de Grúa
                    if (requiereGrua)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.fire_truck, color: Colors.red, size: 30),
                            SizedBox(width: 10),
                            Expanded(child: Text("SE REQUIERE GRÚA OBLIGATORIA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.build_circle, color: Colors.green, size: 30),
                            SizedBox(width: 10),
                            Expanded(child: Text("Asistencia en el lugar (No requiere grúa)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Botón Final
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 15)),
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text("Confirmar y Enviar a Taller", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          // Aquí irá el código para guardar en tu base de datos después
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ficha guardada exitosamente")));
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Pequeño widget auxiliar para que el código quede limpio
  Widget _construirFilaDato(IconData icono, String etiqueta, String valor, {Color? colorValor}) {
    return Row(
      children: [
        Icon(icono, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text("$etiqueta: ", style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: colorValor ?? Colors.black87))),
      ],
    );
  }
}