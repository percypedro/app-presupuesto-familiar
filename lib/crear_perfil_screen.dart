import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'home_page.dart';
import 'services/perfil_service.dart';
import 'tema.dart';

/// Se muestra la primera vez que se abre la app (todavía no hay ningún
/// perfil creado). Pide un nombre y arranca con ese perfil.
class CrearPerfilScreen extends StatefulWidget {
  const CrearPerfilScreen({super.key});

  @override
  State<CrearPerfilScreen> createState() => _CrearPerfilScreenState();
}

class _CrearPerfilScreenState extends State<CrearPerfilScreen> {
  final _controlador = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final nombre = _controlador.text.trim();
    if (nombre.isEmpty) return;

    setState(() => _guardando = true);

    final servicio = PerfilService();
    await servicio.agregarPerfil(nombre);
    await servicio.establecerPerfilActivo(nombre);
    await DatabaseHelper.instancia.abrirPerfil(nombre);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          esquema.primary,
                          Color.lerp(esquema.primary, Colors.black, 0.22)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: esquema.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 44,
                      color: esquema.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '¿Cómo te llamas?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Este será tu perfil: tus cuentas, categorías y movimientos '
                    'se guardan por separado de los de cualquier otra persona.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: esquema.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controlador,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: decoracionCampo(context, 'Tu nombre'),
                    onSubmitted: (_) => _crear(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _guardando ? null : _crear,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _guardando
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: esquema.onPrimary,
                              ),
                            )
                          : const Text('Comenzar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
