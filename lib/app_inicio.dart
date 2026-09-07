import 'package:flutter/material.dart';

import 'crear_perfil_screen.dart';
import 'db/database_helper.dart';
import 'home_page.dart';
import 'services/perfil_service.dart';

/// Primera pantalla que se muestra al abrir la app. Decide, sin que el
/// usuario tenga que hacer nada, a dónde ir:
/// - Si no hay ningún perfil creado todavía -> pide crear el primero.
/// - Si ya hay uno activo -> entra directo a él.
class AppInicio extends StatefulWidget {
  const AppInicio({super.key});

  @override
  State<AppInicio> createState() => _AppInicioState();
}

class _AppInicioState extends State<AppInicio> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    final servicio = PerfilService();
    final perfiles = await servicio.obtenerPerfiles();

    if (perfiles.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CrearPerfilScreen()),
      );
      return;
    }

    final activo = await servicio.obtenerPerfilActivo();
    final nombreAAbrir = (activo != null && perfiles.contains(activo)) ? activo : perfiles.first;

    await DatabaseHelper.instancia.abrirPerfil(nombreAAbrir);
    await servicio.establecerPerfilActivo(nombreAAbrir);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
