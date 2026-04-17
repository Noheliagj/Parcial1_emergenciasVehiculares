import 'package:flutter/material.dart';
import '../theme.dart';
import 'vehiculos_page.dart';
import 'emergencia_page.dart';
import 'login_page.dart'; // Asegúrate de que la ruta sea correcta según tus carpetas

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
                Text('En vivo', style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
      body: [
        _TabSOS(clienteId: widget.clienteId),
        _TabTalleres(),
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
            BottomNavigationBarItem(icon: Icon(Icons.emergency_share_outlined), activeIcon: Icon(Icons.emergency_share), label: 'SOS'),
            BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Talleres'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ── TAB SOS ──────────────────────────────────────────────
class _TabSOS extends StatelessWidget {
  final int clienteId;
  const _TabSOS({required this.clienteId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono decorativo
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.car_crash_outlined, size: 64, color: AppTheme.danger),
          ),
          const SizedBox(height: 28),
          const Text('¿Necesitas asistencia?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textMain),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text(
            'Presiona el botón SOS para reportar una emergencia y que un taller te asista.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 56),

          // Botón SOS
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EmergenciaPage(clienteId: clienteId),
            )),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.danger,
                boxShadow: [
                  BoxShadow(color: AppTheme.danger.withOpacity(0.35), blurRadius: 30, spreadRadius: 8),
                  BoxShadow(color: AppTheme.danger.withOpacity(0.15), blurRadius: 60, spreadRadius: 20),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power_settings_new_rounded, size: 56, color: Colors.white),
                  SizedBox(height: 8),
                  Text('SOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TAB TALLERES ─────────────────────────────────────────
class _TabTalleres extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_repair_service_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taller Mecánico Pro', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                SizedBox(height: 3),
                Text('A 2.5 km · Abierto ahora', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ],
            )),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
          ]),
        ),
      ),
    );
  }
}

// ── TAB PERFIL ───────────────────────────────────────────
class _TabPerfil extends StatelessWidget {
  final int clienteId;
  const _TabPerfil({required this.clienteId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar
        Center(
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('Mi cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
            const SizedBox(height: 4),
            Text('ID: $clienteId', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 32),

        // Opciones
        Card(
          child: Column(children: [
            _opcion(
              icon: Icons.directions_car_outlined,
              color: AppTheme.primary,
              titulo: 'Mis Vehículos',
              subtitulo: 'Gestiona tus autos registrados',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VehiculosPage(clienteId: clienteId),
              )),
            ),
            const Divider(height: 1, indent: 60),
            _opcion(
              icon: Icons.history_outlined,
              color: const Color(0xFF10B981),
              titulo: 'Mis Emergencias',
              subtitulo: 'Historial de reportes',
              onTap: () {},
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
                  context, 
                 '/', // Esta es la ruta de tu LoginPage que configuramos en main.dart
                 (route) => false, // Esto destruye el historial para que no puedan volver atrás
               ),
           textoRojo: true,
         ),
       )
      ],
    );
  }

  Widget _opcion({required IconData icon, required Color color, required String titulo, required String subtitulo, required VoidCallback onTap, bool textoRojo = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, color: textoRojo ? AppTheme.danger : AppTheme.textMain, fontSize: 14)),
      subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }
}