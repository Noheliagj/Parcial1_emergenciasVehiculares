import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme.dart';

class EmergenciaPage extends StatefulWidget {
  final int clienteId;
  const EmergenciaPage({super.key, required this.clienteId});
  @override
  State<EmergenciaPage> createState() => _EmergenciaPageState();
}

class _EmergenciaPageState extends State<EmergenciaPage> {
  final ubicacionCtrl  = TextEditingController();
  final descripcionCtrl = TextEditingController();
  bool _enviando = false;

  Future<void> enviar() async {
    // 1. Validación de campos vacíos
    if (ubicacionCtrl.text.isEmpty || descripcionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, completa todos los campos'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _enviando = true);
    
    try {
      final res = await http.post(
        // 2. IP CORREGIDA PARA WEB
        Uri.parse('http://localhost:8000/emergencias/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id': widget.clienteId,
          // ⚠️ OJO: Asegúrate de tener un vehículo con ID 1 en tu BD, 
          // o FastAPI lo rechazará por error de llave foránea.
          'vehiculo_id': 1, 
          'direccion': ubicacionCtrl.text,
          'descripcion': descripcionCtrl.text,
        }),
      );

      // 3. MANEJO DE RESPUESTAS
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Se envió con éxito
        Navigator.pop(context); // Cierra la pantalla
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Emergencia reportada. Un taller te contactará pronto.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        // El servidor rechazó la petición (ej. no existe el vehiculo_id)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar: ${res.body}'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
        print('Error de FastAPI: ${res.body}');
      }
    } catch (e) {
      // 4. ERROR DE CONEXIÓN
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error de conexión con el servidor.'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
      print('Excepción: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Emergencia'),
        backgroundColor: AppTheme.danger,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de alerta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Describe tu situación con el mayor detalle posible para recibir ayuda rápida.',
                  style: TextStyle(color: AppTheme.danger, fontSize: 13, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 28),

            const Text('Detalles del incidente',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
            const SizedBox(height: 20),

            TextField(
              controller: ubicacionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección o referencia',
                hintText: 'Ej: Av. Villazon frente al semáforo',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.danger),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descripcionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '¿Qué ocurrió con el vehículo?',
                hintText: 'Ej: Se pinchó la llanta delantera derecha...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.build_outlined, color: AppTheme.textMuted),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // Botón enviar
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _enviando
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(_enviando ? 'Enviando...' : 'Enviar emergencia',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                onPressed: _enviando ? null : enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}