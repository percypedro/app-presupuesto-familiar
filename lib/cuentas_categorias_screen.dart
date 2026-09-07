import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'models/categoria.dart';
import 'models/cuenta.dart';
import 'models/subcategoria.dart';
import 'tema.dart';

/// Pantalla para administrar las cuentas y las categorías/subcategorías:
/// renombrarlas o borrarlas. Crearlas ya se podía hacer desde el diálogo de
/// "nuevo movimiento"; aquí se completa el resto del mantenimiento.
class CuentasCategoriasScreen extends StatefulWidget {
  const CuentasCategoriasScreen({super.key});

  @override
  State<CuentasCategoriasScreen> createState() => _CuentasCategoriasScreenState();
}

class _CuentasCategoriasScreenState extends State<CuentasCategoriasScreen> {
  final _db = DatabaseHelper.instancia;

  bool _cargando = true;
  List<Cuenta> _cuentas = [];
  List<Categoria> _categoriasIngreso = [];
  List<Categoria> _categoriasEgreso = [];
  Map<int, List<Subcategoria>> _subcategoriasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final cuentas = await _db.obtenerCuentas();
    final ingreso = await _db.obtenerCategorias(tipo: 'ingreso');
    final egreso = await _db.obtenerCategorias(tipo: 'egreso');

    final subcategorias = <int, List<Subcategoria>>{};
    for (final categoria in [...ingreso, ...egreso]) {
      subcategorias[categoria.id!] = await _db.obtenerSubcategorias(categoria.id!);
    }

    if (!mounted) return;
    setState(() {
      _cuentas = cuentas;
      _categoriasIngreso = ingreso;
      _categoriasEgreso = egreso;
      _subcategoriasPorCategoria = subcategorias;
      _cargando = false;
    });
  }

  // -------------------------------------------------------------- Cuentas

  Future<void> _crearCuenta() async {
    final nombre = await _pedirNombre(titulo: 'Nueva cuenta');
    if (nombre == null) return;
    await _db.insertarCuenta(nombre);
    await _cargarDatos();
  }

  Future<void> _editarCuenta(Cuenta cuenta) async {
    final nombre = await _pedirNombre(titulo: 'Renombrar cuenta', valorInicial: cuenta.nombre);
    if (nombre == null) return;
    await _db.actualizarCuenta(cuenta.id!, nombre);
    await _cargarDatos();
  }

  Future<void> _eliminarCuenta(Cuenta cuenta) async {
    final usos = await _db.contarMovimientosPorCuenta(cuenta.id!);
    if (!mounted) return;
    if (usos > 0) {
      await _avisoNoSePuedeBorrar(
        'No puedes borrar "${cuenta.nombre}"',
        'Tiene $usos movimiento${usos == 1 ? '' : 's'} registrado${usos == 1 ? '' : 's'} con esta cuenta. '
            'Cambia esos movimientos a otra cuenta (o bórralos) antes de eliminarla.',
      );
      return;
    }
    final confirmar = await _confirmarBorrado('¿Eliminar la cuenta "${cuenta.nombre}"?');
    if (confirmar != true) return;
    await _db.eliminarCuenta(cuenta.id!);
    await _cargarDatos();
  }

  // ---------------------------------------------------------- Categorías

  Future<void> _crearCategoria(String tipo) async {
    final nombre = await _pedirNombre(
      titulo: tipo == 'ingreso' ? 'Nueva categoría de ingreso' : 'Nueva categoría de egreso',
    );
    if (nombre == null) return;
    await _db.insertarCategoria(nombre, tipo);
    await _cargarDatos();
  }

  Future<void> _editarCategoria(Categoria categoria) async {
    final nombre = await _pedirNombre(titulo: 'Renombrar categoría', valorInicial: categoria.nombre);
    if (nombre == null) return;
    await _db.actualizarCategoria(categoria.id!, nombre);
    await _cargarDatos();
  }

  Future<void> _eliminarCategoria(Categoria categoria) async {
    final usos = await _db.contarMovimientosPorCategoria(categoria.id!);
    final subcategorias = await _db.contarSubcategoriasPorCategoria(categoria.id!);
    if (!mounted) return;

    if (usos > 0 || subcategorias > 0) {
      final partes = <String>[];
      if (subcategorias > 0) {
        partes.add('$subcategorias subcategoría${subcategorias == 1 ? '' : 's'}');
      }
      if (usos > 0) {
        partes.add('$usos movimiento${usos == 1 ? '' : 's'}');
      }
      await _avisoNoSePuedeBorrar(
        'No puedes borrar "${categoria.nombre}"',
        'Todavía tiene ${partes.join(' y ')}. Bórralos o reasígnalos primero.',
      );
      return;
    }

    final confirmar = await _confirmarBorrado('¿Eliminar la categoría "${categoria.nombre}"?');
    if (confirmar != true) return;
    await _db.eliminarCategoria(categoria.id!);
    await _cargarDatos();
  }

  // ------------------------------------------------------- Subcategorías

  Future<void> _crearSubcategoria(Categoria categoria) async {
    final nombre = await _pedirNombre(titulo: 'Nueva subcategoría de "${categoria.nombre}"');
    if (nombre == null) return;
    await _db.insertarSubcategoria(nombre, categoria.id!);
    await _cargarDatos();
  }

  Future<void> _editarSubcategoria(Subcategoria subcategoria) async {
    final nombre =
        await _pedirNombre(titulo: 'Renombrar subcategoría', valorInicial: subcategoria.nombre);
    if (nombre == null) return;
    await _db.actualizarSubcategoria(subcategoria.id!, nombre);
    await _cargarDatos();
  }

  Future<void> _eliminarSubcategoria(Subcategoria subcategoria) async {
    final usos = await _db.contarMovimientosPorSubcategoria(subcategoria.id!);
    if (!mounted) return;
    if (usos > 0) {
      await _avisoNoSePuedeBorrar(
        'No puedes borrar "${subcategoria.nombre}"',
        'Tiene $usos movimiento${usos == 1 ? '' : 's'} registrado${usos == 1 ? '' : 's'} con esta subcategoría. '
            'Cambia esos movimientos a otra subcategoría (o bórralos) antes de eliminarla.',
      );
      return;
    }
    final confirmar = await _confirmarBorrado('¿Eliminar la subcategoría "${subcategoria.nombre}"?');
    if (confirmar != true) return;
    await _db.eliminarSubcategoria(subcategoria.id!);
    await _cargarDatos();
  }

  // ------------------------------------------------------------- Diálogos

  Future<String?> _pedirNombre({required String titulo, String? valorInicial}) async {
    final controlador = TextEditingController(text: valorInicial);
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(titulo),
          content: TextField(
            controller: controlador,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
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
              child: Text(valorInicial == null ? 'Crear' : 'Guardar'),
            ),
          ],
        );
      },
    );
    if (nombre == null || nombre.isEmpty) return null;
    return nombre;
  }

  Future<bool?> _confirmarBorrado(String pregunta) {
    final esquema = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(pregunta),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: esquema.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _avisoNoSePuedeBorrar(String titulo, String mensaje) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
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
          'Cuentas y categorías',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Seccion(
                  titulo: 'CUENTAS',
                  colorIcono: esquema.primary,
                  onAgregar: _crearCuenta,
                  etiquetaAgregar: 'Nueva cuenta',
                  hijos: [
                    for (final cuenta in _cuentas)
                      _FilaEditable(
                        nombre: cuenta.nombre,
                        onEditar: () => _editarCuenta(cuenta),
                        onEliminar: () => _eliminarCuenta(cuenta),
                      ),
                    if (_cuentas.isEmpty) const _FilaVacia(texto: 'No tienes cuentas todavía'),
                  ],
                ),
                const SizedBox(height: 22),
                _Seccion(
                  titulo: 'CATEGORÍAS DE INGRESO',
                  colorIcono: ColoresFinanzas.de(context).ingreso,
                  onAgregar: () => _crearCategoria('ingreso'),
                  etiquetaAgregar: 'Nueva categoría',
                  hijos: [
                    for (final categoria in _categoriasIngreso)
                      _BloqueCategoria(
                        categoria: categoria,
                        subcategorias: _subcategoriasPorCategoria[categoria.id!] ?? [],
                        onEditarCategoria: () => _editarCategoria(categoria),
                        onEliminarCategoria: () => _eliminarCategoria(categoria),
                        onAgregarSubcategoria: () => _crearSubcategoria(categoria),
                        onEditarSubcategoria: _editarSubcategoria,
                        onEliminarSubcategoria: _eliminarSubcategoria,
                      ),
                    if (_categoriasIngreso.isEmpty)
                      const _FilaVacia(texto: 'No tienes categorías de ingreso todavía'),
                  ],
                ),
                const SizedBox(height: 22),
                _Seccion(
                  titulo: 'CATEGORÍAS DE EGRESO',
                  colorIcono: ColoresFinanzas.de(context).egreso,
                  onAgregar: () => _crearCategoria('egreso'),
                  etiquetaAgregar: 'Nueva categoría',
                  hijos: [
                    for (final categoria in _categoriasEgreso)
                      _BloqueCategoria(
                        categoria: categoria,
                        subcategorias: _subcategoriasPorCategoria[categoria.id!] ?? [],
                        onEditarCategoria: () => _editarCategoria(categoria),
                        onEliminarCategoria: () => _eliminarCategoria(categoria),
                        onAgregarSubcategoria: () => _crearSubcategoria(categoria),
                        onEditarSubcategoria: _editarSubcategoria,
                        onEliminarSubcategoria: _eliminarSubcategoria,
                      ),
                    if (_categoriasEgreso.isEmpty)
                      const _FilaVacia(texto: 'No tienes categorías de egreso todavía'),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Encabezado de sección ("CUENTAS", "CATEGORÍAS DE...") con su botón de
/// "+ agregar" y una tarjeta que envuelve a todos sus hijos.
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.colorIcono,
    required this.onAgregar,
    required this.etiquetaAgregar,
    required this.hijos,
  });

  final String titulo;
  final Color colorIcono;
  final VoidCallback onAgregar;
  final String etiquetaAgregar;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: esquema.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(etiquetaAgregar),
              style: TextButton.styleFrom(
                foregroundColor: colorIcono,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Column(children: hijos),
        ),
      ],
    );
  }
}

class _FilaVacia extends StatelessWidget {
  const _FilaVacia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(texto, style: TextStyle(color: esquema.onSurfaceVariant, fontSize: 13.5)),
    );
  }
}

/// Una fila simple con nombre + botones de editar/borrar. Se usa para
/// cuentas y, dentro de cada categoría, para sus subcategorías.
class _FilaEditable extends StatelessWidget {
  const _FilaEditable({
    required this.nombre,
    required this.onEditar,
    required this.onEliminar,
    this.indentado = false,
  });

  final String nombre;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final bool indentado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(indentado ? 44 : 16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(
                fontSize: indentado ? 14 : 15,
                fontWeight: indentado ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined),
            iconSize: 19,
            color: esquema.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            tooltip: 'Renombrar',
          ),
          IconButton(
            onPressed: onEliminar,
            icon: const Icon(Icons.delete_outline_rounded),
            iconSize: 19,
            color: esquema.error,
            visualDensity: VisualDensity.compact,
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }
}

/// Una categoría con su lista de subcategorías anidada, plegable.
class _BloqueCategoria extends StatefulWidget {
  const _BloqueCategoria({
    required this.categoria,
    required this.subcategorias,
    required this.onEditarCategoria,
    required this.onEliminarCategoria,
    required this.onAgregarSubcategoria,
    required this.onEditarSubcategoria,
    required this.onEliminarSubcategoria,
  });

  final Categoria categoria;
  final List<Subcategoria> subcategorias;
  final VoidCallback onEditarCategoria;
  final VoidCallback onEliminarCategoria;
  final VoidCallback onAgregarSubcategoria;
  final void Function(Subcategoria) onEditarSubcategoria;
  final void Function(Subcategoria) onEliminarSubcategoria;

  @override
  State<_BloqueCategoria> createState() => _BloqueCategoriaState();
}

class _BloqueCategoriaState extends State<_BloqueCategoria> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final haySubcategorias = widget.subcategorias.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: haySubcategorias ? () => setState(() => _expandido = !_expandido) : null,
                icon: Icon(
                  _expandido ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                ),
                color: haySubcategorias ? esquema.onSurfaceVariant : Colors.transparent,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: haySubcategorias ? () => setState(() => _expandido = !_expandido) : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.categoria.nombre,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (haySubcategorias) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${widget.subcategorias.length})',
                          style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onEditarCategoria,
                icon: const Icon(Icons.edit_outlined),
                iconSize: 19,
                color: esquema.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                tooltip: 'Renombrar',
              ),
              IconButton(
                onPressed: widget.onEliminarCategoria,
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 19,
                color: esquema.error,
                visualDensity: VisualDensity.compact,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
        if (_expandido) ...[
          for (final subcategoria in widget.subcategorias)
            _FilaEditable(
              nombre: subcategoria.nombre,
              indentado: true,
              onEditar: () => widget.onEditarSubcategoria(subcategoria),
              onEliminar: () => widget.onEliminarSubcategoria(subcategoria),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAgregarSubcategoria,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Subcategoría'),
                style: TextButton.styleFrom(
                  foregroundColor: esquema.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
        ] else if (!haySubcategorias)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAgregarSubcategoria,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Subcategoría'),
                style: TextButton.styleFrom(
                  foregroundColor: esquema.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
