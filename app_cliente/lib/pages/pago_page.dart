

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class PagoPage extends StatefulWidget {
  final int emergenciaId;
  const PagoPage({super.key, required this.emergenciaId});

  @override
  State<PagoPage> createState() => _PagoPageState();
}

class _PagoPageState extends State<PagoPage>
    with SingleTickerProviderStateMixin {

  String _etapa = 'seleccion'; // 'seleccion' | 'procesando' | 'exito'
  String _metodoPago = 'efectivo';
  final _montoCtrl = TextEditingController(text: '150.00');
  Map<String, dynamic>? _datosServicio;
  bool _cargandoDatos = true;
  int? _pagoId;

  late AnimationController _exitoController;
  late Animation<double> _exitoEscala;

  @override
  void initState() {
    super.initState();
    _exitoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitoEscala = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _exitoController, curve: Curves.elasticOut),
    );
    _cargarDatosServicio();
  }

  @override
  void dispose() {
    _exitoController.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosServicio() async {
    try {
      final res = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/api/emergencias/${widget.emergenciaId}/detalle-completo',
      ));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _datosServicio = jsonDecode(res.body);
          _cargandoDatos = false;
        });
      } else {
        setState(() => _cargandoDatos = false);
      }
    } catch (_) {
      setState(() => _cargandoDatos = false);
    }
  }

  Future<void> _procesarPago() async {
    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _etapa = 'procesando');

    try {
      // PASO 1: Crear orden de pago
      final res = await http.post(Uri.parse(
        '${ApiConfig.baseUrl}/api/pagos/crear'
        '?emergencia_id=${widget.emergenciaId}'
        '&monto=$monto'
        '&metodo=${Uri.encodeComponent(_metodoPago)}',
      ));

      if (res.statusCode != 200) {
        setState(() => _etapa = 'seleccion');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${jsonDecode(res.body)['detail'] ?? res.body}'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      final datosPago = jsonDecode(res.body);
      final pagoId = datosPago['pago_id'] as int;

      // PASO 2: Simular procesamiento del pago (2 segundos)
      await Future.delayed(const Duration(seconds: 2));

      // PASO 3: Confirmar el pago
      final res2 = await http.patch(Uri.parse(
        '${ApiConfig.baseUrl}/api/pagos/$pagoId/confirmar'
        '?referencia=SIM_${DateTime.now().millisecondsSinceEpoch}',
      ));

      if (res2.statusCode == 200 && mounted) {
        setState(() {
          _pagoId = pagoId;
          _etapa = 'exito';
        });
        _exitoController.forward();
      } else {
        setState(() => _etapa = 'seleccion');
      }
    } catch (e) {
      setState(() => _etapa = 'seleccion');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evitar que el usuario vuelva atrás durante el procesamiento
      canPop: _etapa != 'procesando',
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        appBar: AppBar(
          title: const Text('Realizar Pago',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.indigo,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: _etapa != 'procesando',
        ),
        body: _etapa == 'exito' ? _pantallaExito() : _pantallaSeleccion(),
      ),
    );
  }

  Widget _pantallaSeleccion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen del servicio
          if (_cargandoDatos)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator())),
          if (_datosServicio != null) _resumenServicio(),
          const SizedBox(height: 24),

          // Monto
          _seccionTitulo('💰 Monto del servicio', Colors.indigo),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Text('Bs.',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: '0.00'),
                    enabled: _etapa != 'procesando',
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // Método de pago
          _seccionTitulo('💳 Método de pago', Colors.indigo),
          const SizedBox(height: 12),
          _opcionMetodoPago(
            valor: 'tarjeta',
            icono: Icons.credit_card,
            titulo: 'Tarjeta de débito/crédito',
            subtitulo: 'Visa, Mastercard, American Express',
            color: Colors.blue,
          ),
          const SizedBox(height: 10),
          _opcionMetodoPago(
            valor: 'qr',
            icono: Icons.qr_code_scanner,
            titulo: 'Código QR / Transferencia',
            subtitulo: 'Bancos bolivianos (Simple, BCP, BNB...)',
            color: Colors.teal,
          ),
          const SizedBox(height: 10),
          _opcionMetodoPago(
            valor: 'efectivo',
            icono: Icons.money,
            titulo: 'Efectivo en mano',
            subtitulo: 'Paga directamente al técnico',
            color: Colors.green,
          ),
          const SizedBox(height: 32),

          // Botón confirmar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _etapa == 'procesando' ? null : _procesarPago,
              child: _etapa == 'procesando'
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Procesando pago...',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    )
                  : const Text('Confirmar pago',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('🔒 Tu pago está protegido',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _resumenServicio() {
    final taller = _datosServicio?['taller_asignado'] ?? 'Taller';
    final tipo = _datosServicio?['tipo_ia'] ?? 'Servicio vehicular';
    final dir = _datosServicio?['direccion'] ?? '';

    return Card(
      color: Colors.indigo.shade50,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.receipt_long_outlined, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Resumen del servicio',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.indigo)),
          ]),
          const SizedBox(height: 12),
          _filaDato('Taller:', taller),
          _filaDato('Tipo:', tipo),
          if (dir.isNotEmpty) _filaDato('Lugar:', dir),
          _filaDato('Estado:', '✅ Finalizado'),
        ]),
      ),
    );
  }

  Widget _filaDato(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text('$titulo ',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.indigo)),
        Expanded(
            child: Text(valor,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _opcionMetodoPago({
    required String valor,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Color color,
  }) {
    final seleccionado = _metodoPago == valor;
    return GestureDetector(
      onTap: () => setState(() => _metodoPago = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: seleccionado ? color : Colors.grey.shade200,
              width: seleccionado ? 2 : 1),
          boxShadow: seleccionado
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)]
              : [],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: seleccionado
                  ? color.withOpacity(0.15)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: seleccionado ? color : Colors.grey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: seleccionado ? color : Colors.black87)),
              Text(subtitulo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          if (seleccionado) Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }

  Widget _seccionTitulo(String texto, Color color) {
    return Text(texto,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: color));
  }

  Widget _pantallaExito() {
    final iconos = {
      'tarjeta': Icons.credit_card,
      'qr': Icons.qr_code,
      'efectivo': Icons.money,
    };
    final nombres = {
      'tarjeta': 'Tarjeta',
      'qr': 'Código QR',
      'efectivo': 'Efectivo',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
            scale: _exitoEscala,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade300, width: 3),
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 72),
            ),
          ),
          const SizedBox(height: 28),
          const Text('¡Pago realizado!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 10),
          const Text(
            'Tu pago fue procesado exitosamente.\nGracias por usar Auxilio Vial.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (_pagoId != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Referencia de pago: #$_pagoId',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(iconos[_metodoPago], color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Pagado con ${nombres[_metodoPago]}  ·  '
              'Bs. ${double.tryParse(_montoCtrl.text)?.toStringAsFixed(2) ?? "—"}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ]),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Volver al inicio',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}