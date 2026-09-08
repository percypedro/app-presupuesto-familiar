import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

/// Pantalla sencilla de "Acerca de": nombre de la app, versión y datos de
/// contacto del desarrollador. No depende de ningún paquete extra (usa
/// Clipboard, que ya viene incluido en Flutter) para no arriesgar otro
/// problema de compilación como el que tuvimos con file_picker/share_plus.
class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({super.key});

  static const _correoDesarrollador = 'devpercypedrofuentesramos@gmail.com';
  static const _version = '1.3.0';

  Future<void> _copiarCorreo(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _correoDesarrollador));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado')),
    );
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
          'Acerca de',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
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
                    color: esquema.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: esquema.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Mis Finanzas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Versión $_version',
              style: TextStyle(fontSize: 13, color: esquema.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESARROLLADOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Percy Pedro Fuentes Ramos',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _copiarCorreo(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: esquema.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.email_outlined,
                              size: 17,
                              color: esquema.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _correoDesarrollador,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Icon(
                            Icons.copy_rounded,
                            size: 17,
                            color: esquema.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Toca el correo para copiarlo',
              style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
