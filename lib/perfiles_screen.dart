import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'home_page.dart';
import 'services/perfil_service.dart';
import 'tema.dart';

class PerfilesScreen extends StatefulWidget {
  const PerfilesScreen({super.key});

  @override
  State<PerfilesScreen> createState() => _PerfilesScreenState();
}

class _PerfilesScreenState extends State<PerfilesScreen> {
  final _servicio = PerfilService();
  List<String> _perfiles = [];
  String? _perfilActivo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfiles = await _servicio.obtenerPerfiles();
    final activo = await _servicio.obtenerPerfilActivo();
    setState(() {
      _perfiles = perfiles;
      _perfilActivo = activo;
      _cargando = false;
    });
  }

  Future<void> _seleccionar(String nombre) async {
    if (nombre == _perfilActivo) {
      Navigator.of(context).pop();
      return;
    }
    await DatabaseHelper.instancia.abrirPerfil(nombre);
    await _servicio.establecerPerfilActivo(nombre);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _mostrarDialogoNuevoPerfil() async {
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Nuevo perfil'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: decoracionCampo(context, 'Nombre'),
            onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controlador.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (nombre == null || nombre.isEmpty) return;

    await _servicio.agregarPerfil(nombre);
    await _seleccionar(nombre);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Perfiles',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final nombre in _perfiles)
                  _FilaPerfil(
                    nombre: nombre,
                    esActivo: nombre == _perfilActivo,
                    onTap: () => _seleccionar(nombre),
                  ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: esquema.outlineVariant,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _mostrarDialogoNuevoPerfil,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: esquema.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add_rounded, color: esquema.onSurfaceVariant),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Crear otro perfil',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: esquema.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilaPerfil extends StatelessWidget {
  const _FilaPerfil({
    required this.nombre,
    required this.esActivo,
    required this.onTap,
  });

  final String nombre;
  final bool esActivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: esActivo ? esquema.primaryContainer : esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esActivo
              ? esquema.primary.withValues(alpha: 0.4)
              : esquema.outlineVariant.withValues(alpha: 0.55),
          width: esActivo ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: esActivo ? esquema.primary : esquema.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: esActivo ? esquema.onPrimary : esquema.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                      if (esActivo)
                        Text(
                          'Perfil en uso',
                          style: TextStyle(
                            fontSize: 12,
                            color: esquema.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                if (esActivo)
                  Icon(Icons.check_circle_rounded, color: esquema.primary)
                else
                  Icon(Icons.chevron_right_rounded, color: esquema.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
