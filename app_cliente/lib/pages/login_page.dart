import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../theme.dart';
import 'registro_page.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  final http.Client? client;

  const LoginPage({super.key, this.client});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _ocultarPass = true;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarCuentaDemo();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _cargarCuentaDemo() {
    if (emailCtrl.text.isEmpty && passCtrl.text.isEmpty) {
      emailCtrl.text = 'demo.cliente@si2.local';
      passCtrl.text = '1234';
    }
  }

  Future<void> iniciarSesion() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      _snack('Por favor ingresa todos los campos', Colors.orange);
      return;
    }
    setState(() => _cargando = true);
    try {
      final clienteHttp = widget.client;
      final res = clienteHttp != null
          ? await clienteHttp.post(
              Uri.parse('${ApiConfig.baseUrl}/login-cliente/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': emailCtrl.text, 'contrasena': passCtrl.text}),
            )
          : await http.post(
              Uri.parse('${ApiConfig.baseUrl}/login-cliente/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': emailCtrl.text, 'contrasena': passCtrl.text}),
            );
      if (res.statusCode == 200) {
        final datos = jsonDecode(res.body);
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => DashboardPage(clienteId: datos['usuario_id']),
        ));
      } else {
        final detalle = _extraerDetalleError(res.body);
        _snack(detalle ?? 'Correo o contraseña incorrectos', AppTheme.danger);
      }
    } catch (e) {
      _snack('Error de conexión con el servidor', AppTheme.danger);
    } finally {
      setState(() => _cargando = false);
    }
  }

  String? _extraerDetalleError(String body) {
    try {
      final datos = jsonDecode(body);
      if (datos is Map<String, dynamic>) {
        final detalle = datos['detail'];
        if (detalle is String && detalle.isNotEmpty) {
          return detalle;
        }
      }
    } catch (_) {}
    return null;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // --- AQUÍ EMPIEZA LA PANTALLA VISUAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.build_circle_rounded, size: 60, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text('Bienvenida', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
                const SizedBox(height: 6),
                const Text('Inicia sesión en tu cuenta', style: TextStyle(fontSize: 15, color: AppTheme.textMuted)),
                const SizedBox(height: 40),

                TextButton.icon(
                  onPressed: _cargarCuentaDemo,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Usar cuenta demo'),
                ),

                const SizedBox(height: 12),

                // Campos
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: _ocultarPass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted),
                      onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Botón
                ElevatedButton(
                  onPressed: _cargando ? null : iniciarSesion,
                  child: _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 20),

                // Link registro
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroPage())),
                    child: RichText(
                      text: const TextSpan(
                        text: '¿No tienes cuenta? ',
                        style: TextStyle(color: AppTheme.textMuted),
                        children: [TextSpan(text: 'Regístrate', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}