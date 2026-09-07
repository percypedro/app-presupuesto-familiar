import 'package:flutter/material.dart';

import 'acerca_de_screen.dart';
import 'cuentas_categorias_screen.dart';
import 'db/database_helper.dart';
import 'filtro_screen.dart';
import 'models/categoria.dart';
import 'models/cuenta.dart';
import 'models/movimiento.dart';
import 'models/subcategoria.dart';
import 'perfiles_screen.dart';
import 'services/exportar_importar_service.dart';
import 'services/perfil_service.dart';
import 'tema.dart';
import 'utils/fechas.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Movimiento> _movimientos = [];
  List<Cuenta> _cuentas = [];
  bool _cargando = true;
  String? _perfilActivo;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final perfilActivo = await PerfilService().obtenerPerfilActivo();
    final cuentas = await DatabaseHelper.instancia.obtenerCuentas();
    final movimientos = await DatabaseHelper.instancia.obtenerMovimientos();
    setState(() {
      _perfilActivo = perfilActivo;
      _cuentas = cuentas;
      _movimientos = movimientos;
      _cargando = false;
    });
  }

  Future<void> _exportar() async {
    final perfil = _perfilActivo;
    if (perfil == null || _exportando) return;
    setState(() => _exportando = true);
    try {
      await ExportarImportarService().exportarPerfilActivo(perfil);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _importar() async {
    String? nombreImportado;
    try {
      nombreImportado = await ExportarImportarService().importarDesdeArchivo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar: $e')),
      );
      return;
    }

    if (nombreImportado == null || !mounted) return; // el usuario canceló

    await PerfilService().agregarPerfil(nombreImportado);
    if (!mounted) return;

    final cambiarAhora = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importación completa'),
        content: Text(
          'Se importaron los datos del perfil "$nombreImportado". '
          '¿Quieres cambiar a ese perfil ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quedarme aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cambiar ahora'),
          ),
        ],
      ),
    );

    if (cambiarAhora != true) return;

    await PerfilService().establecerPerfilActivo(nombreImportado);
    await DatabaseHelper.instancia.abrirPerfil(nombreImportado);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  List<Movimiento> get _movimientosDelMes {
    final ahora = DateTime.now();
    return _movimientos
        .where((m) => m.fecha.year == ahora.year && m.fecha.month == ahora.month)
        .toList();
  }

  double get _ingresosMes => _movimientosDelMes
      .where((m) => m.esIngreso)
      .fold(0.0, (suma, m) => suma + m.monto);

  double get _egresosMes => _movimientosDelMes
      .where((m) => !m.esIngreso)
      .fold(0.0, (suma, m) => suma + m.monto);

  double get _balanceMes => _ingresosMes - _egresosMes;

  Future<void> _eliminarMovimiento(Movimiento movimiento) async {
    await DatabaseHelper.instancia.eliminarMovimiento(movimiento.id!);
    await _cargarDatos();
  }

  Future<void> _mostrarDialogoMovimiento({Movimiento? existente}) async {
    if (_cuentas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cuentas disponibles todavía')),
      );
      return;
    }

    final resultado = await showDialog<_NuevoMovimientoData>(
      context: context,
      builder: (context) => _DialogoNuevoMovimiento(
        cuentas: _cuentas,
        existente: existente,
      ),
    );

    if (resultado != null) {
      final movimiento = Movimiento(
        id: existente?.id,
        tipo: resultado.tipo,
        descripcion: resultado.descripcion,
        monto: resultado.monto,
        fecha: resultado.fecha,
        cuentaId: resultado.cuentaId,
        categoriaId: resultado.categoriaId,
        subcategoriaId: resultado.subcategoriaId,
      );
      if (existente != null) {
        await DatabaseHelper.instancia.actualizarMovimiento(movimiento);
      } else {
        await DatabaseHelper.instancia.insertarMovimiento(movimiento);
      }
    }

    // Siempre recargamos: puede que se haya creado una cuenta/categoría
    // nueva desde el diálogo aunque el usuario haya cancelado el movimiento.
    await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mis Finanzas',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            if (_perfilActivo != null)
              Text(
                _perfilActivo!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: esquema.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Filtrar y agrupar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FiltroScreen()),
              );
            },
          ),
          if (_exportando)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: esquema.primary),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (valor) {
                switch (valor) {
                  case 'exportar':
                    _exportar();
                    break;
                  case 'importar':
                    _importar();
                    break;
                  case 'perfiles':
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => const PerfilesScreen()));
                    break;
                  case 'cuentas_categorias':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CuentasCategoriasScreen()),
                    );
                    break;
                  case 'acerca_de':
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => const AcercaDeScreen()));
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'exportar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.ios_share_rounded),
                    title: Text('Exportar mis datos'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'importar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.download_rounded),
                    title: Text('Importar datos'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'perfiles',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.switch_account_rounded),
                    title: Text('Cambiar de perfil'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'cuentas_categorias',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.category_outlined),
                    title: Text('Cuentas y categorías'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'acerca_de',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Acerca de'),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TarjetaBalance(
                  balance: _balanceMes,
                  ingresos: _ingresosMes,
                  egresos: _egresosMes,
                ),
                if (_movimientos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: Row(
                      children: [
                        Text(
                          'MOVIMIENTOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_movimientos.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _movimientos.isEmpty
                      ? const _EstadoVacio()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _movimientos.length,
                          itemBuilder: (context, index) {
                            final movimiento = _movimientos[index];
                            return _FilaMovimiento(
                              movimiento: movimiento,
                              onTap: () => _mostrarDialogoMovimiento(existente: movimiento),
                              onEliminar: () => _eliminarMovimiento(movimiento),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoMovimiento(),
        backgroundColor: esquema.primary,
        foregroundColor: esquema.onPrimary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

String _subtituloMovimiento(Movimiento movimiento) {
  final partes = <String>[
    movimiento.cuentaNombre ?? '',
    formatearFechaCorta(movimiento.fecha),
  ];
  if (movimiento.subcategoriaNombre != null) {
    partes.add(movimiento.subcategoriaNombre!);
  } else if (movimiento.categoriaNombre != null) {
    partes.add(movimiento.categoriaNombre!);
  }
  return partes.where((p) => p.isNotEmpty).join(' · ');
}

/// Una fila de la lista de movimientos. Se ve como una tarjeta y se puede
/// deslizar hacia la izquierda para borrar.
class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.movimiento,
    required this.onTap,
    required this.onEliminar,
  });

  final Movimiento movimiento;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final finanzas = ColoresFinanzas.de(context);
    final esIngreso = movimiento.esIngreso;

    const margen = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    final radio = BorderRadius.circular(16);

    return Dismissible(
      key: ValueKey(movimiento.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: margen,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: finanzas.egreso, borderRadius: radio),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onEliminar(),
      child: Container(
        margin: margen,
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLowest,
          borderRadius: radio,
          border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radio,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: finanzas.colorSuave(esIngreso),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esIngreso ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 20,
                      color: finanzas.color(esIngreso),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          movimiento.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtituloMovimiento(movimiento),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${esIngreso ? '+' : '−'} ${formatearBs(movimiento.monto)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: finanzas.color(esIngreso),
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

/// La tarjeta verde de arriba: es lo primero que se ve al abrir la app, así
/// que carga el color fuerte de la paleta y el número más grande.
class _TarjetaBalance extends StatelessWidget {
  const _TarjetaBalance({
    required this.balance,
    required this.ingresos,
    required this.egresos,
  });

  final double balance;
  final double ingresos;
  final double egresos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final mes = nombresMeses[DateTime.now().month - 1].toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALANCE DE $mes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: esquema.onPrimary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatearBs(balance),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: esquema.onPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MiniResumen(
                  etiqueta: 'Ingresos',
                  monto: ingresos,
                  icono: Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: esquema.onPrimary.withValues(alpha: 0.18),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _MiniResumen(
                    etiqueta: 'Egresos',
                    monto: egresos,
                    icono: Icons.arrow_downward_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniResumen extends StatelessWidget {
  const _MiniResumen({
    required this.etiqueta,
    required this.monto,
    required this.icono,
  });

  final String etiqueta;
  final double monto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final suave = esquema.onPrimary.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icono, size: 13, color: suave),
            const SizedBox(width: 4),
            Text(etiqueta, style: TextStyle(fontSize: 12, color: suave)),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatearBs(monto),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: esquema.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: esquema.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: esquema.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Todavía no hay movimientos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: esquema.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toca el botón "Agregar" para registrar tu primer ingreso o gasto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: esquema.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos que devuelve el diálogo de "nuevo movimiento" cuando el usuario
/// presiona Guardar. HomePage se encarga de guardarlos en la base de datos.
class _NuevoMovimientoData {
  final String tipo;
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final int cuentaId;
  final int? categoriaId;
  final int? subcategoriaId;

  _NuevoMovimientoData({
    required this.tipo,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.cuentaId,
    this.categoriaId,
    this.subcategoriaId,
  });
}

class _DialogoNuevoMovimiento extends StatefulWidget {
  const _DialogoNuevoMovimiento({
    required this.cuentas,
    this.existente,
  });

  final List<Cuenta> cuentas;

  /// Si no es null, el diálogo abre en modo edición con estos datos
  /// precargados, en vez de crear un movimiento nuevo.
  final Movimiento? existente;

  @override
  State<_DialogoNuevoMovimiento> createState() => _DialogoNuevoMovimientoState();
}

/// Valores especiales usados en los desplegables para representar la
/// opción "crear uno nuevo" (no son ids reales de ninguna fila).
const int _idNuevaCuenta = -1;
const int _idNuevaCategoria = -1;
const int _idNuevaSubcategoria = -1;

class _DialogoNuevoMovimientoState extends State<_DialogoNuevoMovimiento> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();

  String _tipo = 'egreso';
  DateTime _fecha = DateTime.now();
  int? _cuentaId;
  late List<Cuenta> _cuentasDisponibles;

  int? _categoriaId;
  List<Categoria> _categoriasDisponibles = [];
  bool _cargandoCategorias = true;

  int? _subcategoriaId;
  List<Subcategoria> _subcategoriasDisponibles = [];
  bool _cargandoSubcategorias = false;

  @override
  void initState() {
    super.initState();
    _cuentasDisponibles = List.of(widget.cuentas);

    final existente = widget.existente;
    if (existente != null) {
      _tipo = existente.tipo;
      _fecha = existente.fecha;
      _descripcionController.text = existente.descripcion;
      _montoController.text = existente.monto.toStringAsFixed(2);
      _cuentaId = existente.cuentaId;
      _categoriaId = existente.categoriaId;
      _subcategoriaId = existente.subcategoriaId;
      if (existente.categoriaId != null) {
        _cargarSubcategorias(existente.categoriaId!);
      }
    } else {
      _cuentaId = _cuentasDisponibles.first.id;
    }

    _cargarCategorias(_tipo);
  }

  /// Vuelve a cargar la lista de categorías disponibles según el tipo
  /// (ingreso/egreso) seleccionado, para no mezclar categorías de un tipo
  /// con movimientos del otro.
  Future<void> _cargarCategorias(String tipo) async {
    final categorias = await DatabaseHelper.instancia.obtenerCategorias(tipo: tipo);
    if (!mounted) return;
    setState(() {
      _categoriasDisponibles = categorias;
      _cargandoCategorias = false;
      // Si la categoría que tenía este movimiento (por ejemplo, uno viejo
      // guardado antes de separar categorías por tipo) ya no aparece en
      // esta lista, la quitamos para no romper el desplegable.
      if (_categoriaId != null && !categorias.any((c) => c.id == _categoriaId)) {
        _categoriaId = null;
        _subcategoriaId = null;
        _subcategoriasDisponibles = [];
      }
    });
  }

  Future<void> _cargarSubcategorias(int categoriaId) async {
    setState(() => _cargandoSubcategorias = true);
    final subcategorias = await DatabaseHelper.instancia.obtenerSubcategorias(categoriaId);
    if (!mounted) return;
    setState(() {
      _subcategoriasDisponibles = subcategorias;
      _cargandoSubcategorias = false;
      if (_subcategoriaId != null && !subcategorias.any((s) => s.id == _subcategoriaId)) {
        _subcategoriaId = null;
      }
    });
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _mostrarDialogoNuevaCuenta() async {
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva cuenta'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo(
              context,
              'Nombre de la cuenta',
              ayuda: 'Ej. Tarjeta, Ahorros...',
            ),
            onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controlador.text.trim()),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (nombre == null || nombre.isEmpty) return;

    final nuevoId = await DatabaseHelper.instancia.insertarCuenta(nombre);
    setState(() {
      _cuentasDisponibles = [
        ..._cuentasDisponibles,
        Cuenta(id: nuevoId, nombre: nombre),
      ];
      _cuentaId = nuevoId;
    });
  }

  Future<void> _mostrarDialogoNuevaCategoria() async {
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controlador,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracionCampo(
                  context,
                  'Nombre de la categoría',
                  ayuda: 'Ej. Educación, Mascotas...',
                ),
                onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
              ),
              const SizedBox(height: 10),
              Text(
                _tipo == 'ingreso'
                    ? 'Se guardará como categoría de Ingreso'
                    : 'Se guardará como categoría de Egreso',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controlador.text.trim()),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (nombre == null || nombre.isEmpty) return;

    final nuevoId = await DatabaseHelper.instancia.insertarCategoria(nombre, _tipo);
    setState(() {
      _categoriasDisponibles = [
        ..._categoriasDisponibles,
        Categoria(id: nuevoId, nombre: nombre, tipo: _tipo),
      ];
      _categoriaId = nuevoId;
      _subcategoriaId = null;
      _subcategoriasDisponibles = [];
    });
  }

  Future<void> _seleccionarCategoria(int? valor) async {
    if (valor == _idNuevaCategoria) {
      await _mostrarDialogoNuevaCategoria();
      return;
    }
    setState(() {
      _categoriaId = valor;
      _subcategoriaId = null;
      _subcategoriasDisponibles = [];
    });
    if (valor != null) {
      await _cargarSubcategorias(valor);
    }
  }

  Future<void> _mostrarDialogoNuevaSubcategoria() async {
    if (_categoriaId == null) return;
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva subcategoría'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo(
              context,
              'Nombre de la subcategoría',
              ayuda: 'Ej. Hamburguesas, Pizza...',
            ),
            onSubmitted: (valor) => Navigator.of(context).pop(valor.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controlador.text.trim()),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (nombre == null || nombre.isEmpty) return;

    final nuevoId = await DatabaseHelper.instancia.insertarSubcategoria(
      nombre,
      _categoriaId!,
    );
    setState(() {
      _subcategoriasDisponibles = [
        ..._subcategoriasDisponibles,
        Subcategoria(id: nuevoId, nombre: nombre, categoriaId: _categoriaId!),
      ];
      _subcategoriaId = nuevoId;
    });
  }

  Future<void> _elegirFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  void _guardar() {
    if (_formKey.currentState!.validate() && _cuentaId != null) {
      Navigator.of(context).pop(
        _NuevoMovimientoData(
          tipo: _tipo,
          descripcion: _descripcionController.text.trim(),
          monto: double.parse(_montoController.text.replaceAll(',', '.')),
          fecha: _fecha,
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId,
          subcategoriaId: _subcategoriaId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.existente != null;
    final esquema = Theme.of(context).colorScheme;
    final finanzas = ColoresFinanzas.de(context);
    final esIngreso = _tipo == 'ingreso';

    return AlertDialog(
      backgroundColor: esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        esEdicion ? 'Editar movimiento' : 'Nuevo movimiento',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: finanzas.colorSuave(esIngreso),
                  selectedForegroundColor: finanzas.color(esIngreso),
                  side: BorderSide(color: esquema.outlineVariant),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'ingreso',
                    label: Text('Ingreso'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: 'egreso',
                    label: Text('Egreso'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (seleccion) {
                  final nuevoTipo = seleccion.first;
                  setState(() {
                    _tipo = nuevoTipo;
                    _categoriaId = null;
                    _subcategoriaId = null;
                    _subcategoriasDisponibles = [];
                    _cargandoCategorias = true;
                  });
                  _cargarCategorias(nuevoTipo);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: decoracionCampo(context, 'Descripción'),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Escribe una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: decoracionCampo(context, 'Monto', prefijo: 'Bs. '),
                validator: (valor) {
                  final monto = double.tryParse((valor ?? '').replaceAll(',', '.'));
                  if (monto == null || monto <= 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: esquema.primary),
                      const SizedBox(width: 12),
                      Text(
                        formatearFechaCorta(_fecha),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_calendar_outlined, size: 18, color: esquema.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _cuentaId,
                decoration: decoracionCampo(context, 'Cuenta'),
                items: [
                  ..._cuentasDisponibles.map(
                    (cuenta) => DropdownMenuItem(
                      value: cuenta.id,
                      child: Text(cuenta.nombre),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _idNuevaCuenta,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 6),
                        Text('Nueva cuenta...'),
                      ],
                    ),
                  ),
                ],
                onChanged: (valor) {
                  if (valor == _idNuevaCuenta) {
                    _mostrarDialogoNuevaCuenta();
                  } else {
                    setState(() => _cuentaId = valor);
                  }
                },
                validator: (valor) => valor == null ? 'Selecciona una cuenta' : null,
              ),
              const SizedBox(height: 12),
              if (_cargandoCategorias)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int?>(
                  initialValue: _categoriaId,
                  decoration: decoracionCampo(context, 'Categoría (opcional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                    ..._categoriasDisponibles.map(
                      (categoria) => DropdownMenuItem(
                        value: categoria.id,
                        child: Text(categoria.nombre),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _idNuevaCategoria,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 6),
                          Text('Nueva categoría...'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: _seleccionarCategoria,
                ),
              const SizedBox(height: 12),
              if (_categoriaId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Elige una categoría para poder elegir subcategoría',
                    style: TextStyle(color: esquema.onSurfaceVariant, fontSize: 12),
                  ),
                )
              else if (_cargandoSubcategorias)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int?>(
                  initialValue: _subcategoriaId,
                  decoration: decoracionCampo(context, 'Subcategoría (opcional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin subcategoría')),
                    ..._subcategoriasDisponibles.map(
                      (subcategoria) => DropdownMenuItem(
                        value: subcategoria.id,
                        child: Text(subcategoria.nombre),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _idNuevaSubcategoria,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 6),
                          Text('Nueva subcategoría...'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor == _idNuevaSubcategoria) {
                      _mostrarDialogoNuevaSubcategoria();
                    } else {
                      setState(() => _subcategoriaId = valor);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(esEdicion ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }
}
