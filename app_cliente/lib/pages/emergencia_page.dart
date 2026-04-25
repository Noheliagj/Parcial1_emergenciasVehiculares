
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // NUEVO: para abrir Google Maps
import 'dart:convert';
import 'dart:typed_data';
import '../api_config.dart';
import '../theme.dart';
import 'dart:html' as html;
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


class EmergenciaPage extends StatefulWidget {
  final int clienteId;
  const EmergenciaPage({super.key, required this.clienteId});
  @override
  State<EmergenciaPage> createState() => _EmergenciaPageState();
}

class _EmergenciaPageState extends State<EmergenciaPage> {
  // ── Controladores de texto ──────────────────────────────────
  final ubicacionCtrl  = TextEditingController();
  final descripcionCtrl = TextEditingController();
  late stt.SpeechToText _speech;
  // ── Estado de la UI ─────────────────────────────────────────
  bool _enviando       = false;
  bool _cargandoGPS    = false;
  bool _cargandoVehiculos = true;
  bool _isListening = false;
  String _textoPrevio = '';
  String? _errorVehiculos;

  // ── Vehículos ────────────────────────────────────────────────
  List<Map<String, dynamic>> _vehiculos = [];
  int? _vehiculoSeleccionadoId;

  // ── GPS ──────────────────────────────────────────────────────
  double? _latitud;
  double? _longitud;

  // ── Foto de evidencia (NO va a la IA aquí) ───────────────────
  XFile?     _fotoEvidencia;
  Uint8List? _fotoBytes;

  // ── Audio ────────────────────────────────────────────────────
  PlatformFile? _archivoAudio;  // Audio subido desde galería/archivos
  // Nota: si quieres grabar audio desde micrófono agrega el package 'record'

  // ── ImagePicker ──────────────────────────────────────────────
  final _picker = ImagePicker();

  // ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    super.initState();
    _cargarVehiculos();
  }

  @override
  void dispose() {
    ubicacionCtrl.dispose();
    descripcionCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // 1. CARGAR VEHÍCULOS DEL CLIENTE
  // ══════════════════════════════════════════════════════════════
  Future<void> _cargarVehiculos() async {
    try {
      final respuesta = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vehiculos/cliente/${widget.clienteId}'),
      );
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as List<dynamic>;
        setState(() {
          _vehiculos = datos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _vehiculoSeleccionadoId = _vehiculos.isNotEmpty ? _vehiculos.first['id'] as int? : null;
          _cargandoVehiculos = false;
        });
      } else {
        setState(() {
          _errorVehiculos = 'No se pudieron cargar los vehículos.';
          _cargandoVehiculos = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorVehiculos = 'Error de conexión al cargar vehículos.';
        _cargandoVehiculos = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 2. OBTENER UBICACIÓN GPS + BOTÓN GOOGLE MAPS
  //    - Pide permisos, obtiene lat/lon
  //    - Muestra las coordenadas con un botón para abrir Maps
  // ══════════════════════════════════════════════════════════════
  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _cargandoGPS = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _mostrarError('Permisos de ubicación denegados permanentemente. Ve a Configuración.');
        return;
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latitud  = pos.latitude;
          _longitud = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Ubicación GPS obtenida'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      _mostrarError('No se pudo obtener el GPS. Ingresa la dirección manualmente.');
    } finally {
      setState(() => _cargandoGPS = false);
    }
  }

  // Abre Google Maps con las coordenadas obtenidas
  // IMPORTANTE: agrega url_launcher en pubspec.yaml para que esto funcione
  Future<void> _abrirGoogleMaps() async {
    if (_latitud == null || _longitud == null) return;
    // Formato de URL que abre Google Maps en la ubicación exacta
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_latitud,$_longitud'
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarError('No se pudo abrir Google Maps');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 3. SELECCIONAR FOTO DE EVIDENCIA (sin IA)
  //    El usuario toma o sube la foto. Se guarda con la emergencia.
  //    El análisis IA solo está disponible en "Mis Emergencias"
  // ══════════════════════════════════════════════════════════════
  Future<void> _seleccionarFotoEvidencia(ImageSource origen) async {
    final foto = await _picker.pickImage(source: origen, imageQuality: 80);
    if (foto != null) {
      final bytes = await foto.readAsBytes();
      setState(() {
        _fotoEvidencia = foto;
        _fotoBytes     = bytes;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 4. SELECCIONAR AUDIO
  //    Permite al usuario seleccionar un archivo de audio existente
  // ══════════════════════════════════════════════════════════════
  Future<void> _seleccionarAudio() async {
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.wav,.mp3,.m4a,.aac,.ogg';
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final file = uploadInput.files?.first;
    if (file == null) return;

    final reader = html.FileReader();

    reader.readAsArrayBuffer(file);

    reader.onLoadEnd.listen((event) {
      setState(() {
        _archivoAudio = PlatformFile(
          name: file.name,
          size: file.size,
          bytes: reader.result as Uint8List,
        );
      });
    });
  });
}

  // ══════════════════════════════════════════════════════════════
  // 5. ENVIAR EMERGENCIA
  //    Paso 1: Crear la emergencia en el backend
  //    Paso 2: Subir la foto de evidencia (si hay)
  //    Paso 3: Subir y transcribir el audio (si hay)
  // ══════════════════════════════════════════════════════════════
Future<void> enviar() async {
    if (ubicacionCtrl.text.isEmpty || descripcionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, completa todos los campos obligatorios'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_vehiculoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Primero registra o selecciona un vehículo'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _enviando = true);

    try {
      // ── PASO 0: Capturar el GPS en tiempo real ──
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
        );
        
        // ¡Magia! Sobrescribimos tus variables con los datos reales del satélite
        _latitud = position.latitude;
        _longitud = position.longitude;
        print("📍 Coordenadas capturadas: $_latitud, $_longitud");
      } else {
        // Si el usuario no dio permiso, cancelamos el envío
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Necesitas dar permiso de GPS para enviar la emergencia.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // ── PASO 1: Crear la emergencia base con los datos del GPS ──
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergencias/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id'  : widget.clienteId,
          'vehiculo_id' : _vehiculoSeleccionadoId,
          'direccion'   : ubicacionCtrl.text,
          'descripcion' : descripcionCtrl.text,
          'latitud'     : _latitud,   // 👈 Ahora esto enviará el número exacto
          'longitud'    : _longitud,  // 👈 Y esto también
        }),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        // Asegúrate de que esta función _mostrarError exista en tu código
        _mostrarError('Error al crear emergencia: ${res.body}');
        setState(() => _enviando = false);
        return;
      }
      
      // ... (El resto de tu código para subir la foto, etc.)

      // Obtener el ID de la emergencia recién creada
      final emergenciaData = jsonDecode(res.body);
      final int emergenciaId = emergenciaData['datos']['id'];

      // ── PASO 2: Subir foto de evidencia (si el usuario adjuntó una) ──
      // ¡OJO! Esta foto NO activa la IA. Solo se guarda para que el taller la vea.
      if (_fotoEvidencia != null && _fotoBytes != null) {
        var requestFoto = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/api/emergencias/$emergenciaId/subir-evidencia'),
        );
        requestFoto.files.add(
          http.MultipartFile.fromBytes('imagen', _fotoBytes!, filename: _fotoEvidencia!.name),
        );
        await requestFoto.send(); // Si falla no bloqueamos el flujo principal
      }

      // ── PASO 3: Subir y transcribir audio (si el usuario adjuntó uno) ──
      if (_archivoAudio != null) {
        final audioBytes = _archivoAudio!.bytes;
        if (audioBytes != null) {
          var requestAudio = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}/api/emergencias/transcribir-audio?emergencia_id=$emergenciaId'),
          );
          requestAudio.files.add(
            http.MultipartFile.fromBytes('audio', audioBytes, filename: _archivoAudio!.name),
          );
          await requestAudio.send(); // Si falla no bloqueamos el flujo principal
        }
      }

      // ── ÉXITO ──
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Emergencia reportada. Un taller te contactará pronto.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));

    } catch (e) {
      _mostrarError('Error de conexión con el servidor.');
      print('Error: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }


  void _escucharVoz() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Estado: $val'),
        onError: (val) => print('Error: $val'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          // 👇 AHORA USA TU NOMBRE REAL 👇
          _textoPrevio = descripcionCtrl.text; 
        });

        _speech.listen(
          onResult: (val) => setState(() {
            // 👇 AHORA USA TU NOMBRE REAL 👇
            descripcionCtrl.text = '$_textoPrevio ${val.recognizedWords}'.trim();
          }),
          localeId: 'es_ES',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }
  
  // ══════════════════════════════════════════════════════════════
  // 6. BUILD — Interfaz de usuario
  // ══════════════════════════════════════════════════════════════
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

            // ── BANNER DE ALERTA ──────────────────────────────
            _bannerAlerta(),
            const SizedBox(height: 28),

            const Text('Detalles del incidente',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
            const SizedBox(height: 20),

            // ── SELECTOR DE VEHÍCULO ─────────────────────────
            _selectorVehiculo(),
            const SizedBox(height: 16),

            // ── CAMPO DIRECCIÓN / REFERENCIA ─────────────────
            TextField(
              controller: ubicacionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección o referencia *',
                hintText: 'Ej: Av. Villazon frente al semáforo',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.danger),
              ),
            ),
            const SizedBox(height: 12),

            // ── BOTÓN GPS + MOSTRAR COORDENADAS + ABRIR MAPS ─
            _seccionUbicacionGPS(),
            const SizedBox(height: 16),

            // ── DESCRIPCIÓN ──────────────────────────────────
            TextField(
              controller: descripcionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '¿Qué ocurrió con el vehículo? *',
                hintText: 'Ej: Se pinchó la llanta delantera derecha...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.build_outlined, color: AppTheme.textMuted),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── SECCIÓN: FOTO DE EVIDENCIA ───────────────────
            _seccionFotoEvidencia(),
            const SizedBox(height: 20),

            // ── SECCIÓN: AUDIO ───────────────────────────────
            TextField(
              controller: descripcionCtrl,
              maxLines: 4,
              // OJO: Le quitamos el "const" a InputDecoration porque _isListening cambia
              decoration: InputDecoration( 
                labelText: '¿Qué ocurrió con el vehículo? *',
                hintText: 'Escribe o presiona el micrófono para hablar...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.build_outlined, color: AppTheme.textMuted),
                ),
                alignLabelWithHint: true,
                // 👇 AQUÍ ENTRA LA MAGIA DEL MICRÓFONO 👇
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 60), // Lo alineamos arriba
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? AppTheme.danger : Colors.deepPurple,
                      size: 28,
                    ),
                    onPressed: _escucharVoz, // Llama a la función que creamos antes
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── BOTÓN ENVIAR ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _enviando
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(_enviando ? 'Enviando...' : 'Enviar emergencia',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                onPressed: _enviando ? null : enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ════════════════════════════════════════════════════════════

  Widget _bannerAlerta() {
    return Container(
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
          'Describe tu situación. Puedes adjuntar foto y audio como evidencia.',
          style: TextStyle(color: AppTheme.danger, fontSize: 13, height: 1.4),
        )),
      ]),
    );
  }

  Widget _selectorVehiculo() {
    if (_cargandoVehiculos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorVehiculos != null) {
      return Text(_errorVehiculos!, style: const TextStyle(color: Colors.red));
    }
    if (_vehiculos.isEmpty) {
      return const Text(
        'No tienes vehículos registrados.',
        style: TextStyle(color: Colors.orange),
      );
    }
    return DropdownButtonFormField<int>(
      value: _vehiculoSeleccionadoId,
      decoration: const InputDecoration(
        labelText: 'Vehículo asociado *',
        prefixIcon: Icon(Icons.directions_car_outlined, color: AppTheme.textMuted),
      ),
      items: _vehiculos.map((v) => DropdownMenuItem<int>(
        value: v['id'] as int,
        child: Text('${v['marca']} ${v['modelo']} - ${v['placa']}'),
      )).toList(),
      onChanged: (val) => setState(() => _vehiculoSeleccionadoId = val),
    );
  }

  // ── GPS: Botón para obtener coordenadas + chip con coords + botón Maps ──
  Widget _seccionUbicacionGPS() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón para obtener GPS
        OutlinedButton.icon(
          onPressed: _cargandoGPS ? null : _obtenerUbicacionGPS,
          icon: _cargandoGPS
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.gps_fixed, color: Colors.teal),
          label: Text(
            _cargandoGPS ? 'Obteniendo GPS...' : 'Obtener mi ubicación GPS',
            style: const TextStyle(color: Colors.teal),
          ),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.teal)),
        ),

        // Si ya se obtuvo la ubicación, mostrar coordenadas + botón Maps
        if (_latitud != null && _longitud != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // Mostramos las coordenadas con 5 decimales de precisión
                    'Lat: ${_latitud!.toStringAsFixed(5)}\nLon: ${_longitud!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 13, color: Colors.teal, height: 1.4),
                  ),
                ),
                // Botón para abrir Google Maps — requiere url_launcher
                TextButton.icon(
                  onPressed: _abrirGoogleMaps,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Ver en Maps', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Sección para adjuntar FOTO DE EVIDENCIA ──
  // Importante: esta foto NO va a la IA aquí. El análisis IA
  // solo está en "Mis Emergencias" → dentro de cada emergencia.
  Widget _seccionFotoEvidencia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.camera_alt_outlined, color: Colors.blueGrey, size: 20),
          SizedBox(width: 8),
          Text('Foto de evidencia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(width: 8),
          Text('(opcional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 4),
        // Aclaración: la foto se manda al taller, no a la IA aquí
        const Text(
          'La foto se enviará al taller. Podrás analizarla con IA desde "Mis Emergencias".',
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
        ),
        const SizedBox(height: 10),

        // Preview de la foto si ya se seleccionó
        if (_fotoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(_fotoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
        if (_fotoBytes != null) const SizedBox(height: 10),

        // Botones para tomar foto o elegir de galería
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _seleccionarFotoEvidencia(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Cámara', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _seleccionarFotoEvidencia(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Galería', style: TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      ],
    );
  }
}