import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class TranscripcionAudioPage extends StatefulWidget {
  const TranscripcionAudioPage({super.key});

  @override
  State<TranscripcionAudioPage> createState() => _TranscripcionAudioPageState();
}

class _TranscripcionAudioPageState extends State<TranscripcionAudioPage> {
  final emergenciaIdCtrl = TextEditingController();
  PlatformFile? archivoSeleccionado;
  bool _enviando = false;
  String? _resultado;
  String? _error;

  Future<void> seleccionarAudio() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg'],
      withData: true,
    );

    if (resultado != null && resultado.files.isNotEmpty) {
      setState(() {
        archivoSeleccionado = resultado.files.first;
        _resultado = null;
        _error = null;
      });
    }
  }

  Future<void> transcribir() async {
    final emergenciaId = int.tryParse(emergenciaIdCtrl.text.trim());
    if (emergenciaId == null) {
      setState(() {
        _error = 'Ingresa un ID de emergencia válido.';
      });
      return;
    }

    if (archivoSeleccionado == null || (archivoSeleccionado!.bytes == null && archivoSeleccionado!.path == null)) {
      setState(() {
        _error = 'Selecciona un archivo de audio primero.';
      });
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
      _resultado = null;
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/emergencias/transcribir-audio?emergencia_id=$emergenciaId');
      final request = http.MultipartRequest('POST', uri);

      if (archivoSeleccionado!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            archivoSeleccionado!.bytes!,
            filename: archivoSeleccionado!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            archivoSeleccionado!.path!,
            filename: archivoSeleccionado!.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final datos = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _resultado = datos['transcripcion']?.toString();
        });
      } else {
        setState(() {
          _error = 'El servidor respondió con error: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudo conectar con el backend.';
      });
    } finally {
      setState(() {
        _enviando = false;
      });
    }
  }

  @override
  void dispose() {
    emergenciaIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcribir audio'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecciona el audio del incidente y envíalo al motor de IA para generar la transcripción.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emergenciaIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID de emergencia',
                hintText: 'Ej: 15',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: seleccionarAudio,
              icon: const Icon(Icons.audiotrack_rounded),
              label: const Text('Seleccionar audio'),
            ),
            const SizedBox(height: 12),
            if (archivoSeleccionado != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(archivoSeleccionado!.name),
                  subtitle: Text('${archivoSeleccionado!.size} bytes'),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _enviando ? null : transcribir,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: _enviando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Transcribir audio'),
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ),
              ),
            if (_resultado != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _resultado!,
                    style: TextStyle(color: Colors.green.shade900, height: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}