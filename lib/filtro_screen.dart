import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'models/categoria.dart';
import 'models/movimiento.dart';
import 'models/subcategoria.dart';
import 'tema.dart';
import 'utils/fechas.dart';

/// Pantalla para filtrar y agrupar los movimientos: por año, mes, tipo,
/// categoría y subcategoría. Muestra el total de lo filtrado y la lista
/// de movimientos que cumplen esos filtros.
class FiltroScreen extends StatefulWidget {
  const FiltroScreen({super.key});

  @override
  State<FiltroScreen> createState() => _FiltroScreenState();
}

class _FiltroScreenState extends State<FiltroScreen> {
  bool _cargando = true;
  List<Movimiento> _todos = [];
  List<Categoria> _categorias = [];
  List<Subcategoria> _subcategorias = [];

  String? _tipo; // null = todos
  int? _anio; // null = todos
  int? _mes; // null = todos, 1-12
  int? _categoriaId; // null = todas
  int? _subcategoriaId; // null = todas

  /// 'movimientos' = la lista de siempre, 'categorias' = el reporte de
  /// mayor a menor gasto/ingreso por categoría.
  String _vista = 'movimientos';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final todos = await DatabaseHelper.instancia.obtenerMovimientos();
    final categorias = await DatabaseHelper.instancia.obtenerCategorias();
    setState(() {
      _todos = todos;
      _categorias = categorias;
      _cargando = false;
    });
  }

  Future<void> _cambiarCategoria(int? valor) async {
    setState(() {
      _categoriaId = valor;
      _subcategoriaId = null;
      _subcategorias = [];
    });
    if (valor != null) {
      final subcategorias = await DatabaseHelper.instancia.obtenerSubcategorias(valor);
      if (!mounted) return;
      setState(() => _subcategorias = subcategorias);
    }
  }

  List<int> get _aniosDisponibles {
    final anios = _todos.map((m) => m.fecha.year).toSet().toList();
    anios.sort((a, b) => b.compareTo(a));
    return anios;
  }

  List<Movimiento> get _filtrados {
    return _todos.where((m) {
      if (_tipo != null && m.tipo != _tipo) return false;
      if (_anio != null && m.fecha.year != _anio) return false;
      if (_mes != null && m.fecha.month != _mes) return false;
      if (_categoriaId != null && m.categoriaId != _categoriaId) return false;
      if (_subcategoriaId != null && m.subcategoriaId != _subcategoriaId) return false;
      return true;
    }).toList();
  }

  double get _totalIngresos =>
      _filtrados.where((m) => m.esIngreso).fold(0.0, (s, m) => s + m.monto);

  double get _totalEgresos =>
      _filtrados.where((m) => !m.esIngreso).fold(0.0, (s, m) => s + m.monto);

  /// Agrupa los movimientos filtrados según [clave] (nombre de categoría o
  /// subcategoría), sumando el monto de cada grupo y ordenando de mayor a
  /// menor. Usado por los reportes "Por categoría" y "Por subcategoría".
  Map<String, double> _totales({
    required bool esIngreso,
    required String Function(Movimiento) clave,
  }) {
    final mapa = <String, double>{};
    for (final m in _filtrados) {
      if (m.esIngreso != esIngreso) continue;
      final nombre = clave(m);
      mapa[nombre] = (mapa[nombre] ?? 0) + m.monto;
    }
    final entradas = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entradas) e.key: e.value};
  }

  Map<String, double> _totalesPorCategoria({required bool esIngreso}) => _totales(
        esIngreso: esIngreso,
        clave: (m) => m.categoriaNombre ?? 'Sin categoría',
      );

  Map<String, double> _totalesPorSubcategoria({required bool esIngreso}) => _totales(
        esIngreso: esIngreso,
        clave: (m) => m.subcategoriaNombre ?? 'Sin subcategoría',
      );

  void _limpiarFiltros() {
    setState(() {
      _tipo = null;
      _anio = null;
      _mes = null;
      _categoriaId = null;
      _subcategoriaId = null;
      _subcategorias = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final finanzas = ColoresFinanzas.de(context);

    final hayFiltrosActivos = _tipo != null ||
        _anio != null ||
        _mes != null ||
        _categoriaId != null ||
        _subcategoriaId != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Filtrar y agrupar',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
        actions: [
          if (hayFiltrosActivos)
            TextButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Limpiar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _tipo,
                              decoration: decoracionCampo(context, 'Tipo'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Todos')),
                                DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                                DropdownMenuItem(value: 'egreso', child: Text('Egreso')),
                              ],
                              onChanged: (valor) => setState(() => _tipo = valor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _anio,
                              decoration: decoracionCampo(context, 'Año'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos')),
                                ..._aniosDisponibles.map(
                                  (anio) => DropdownMenuItem(
                                    value: anio,
                                    child: Text('$anio'),
                                  ),
                                ),
                              ],
                              onChanged: (valor) => setState(() => _anio = valor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _mes,
                        decoration: decoracionCampo(context, 'Mes'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          ...List.generate(
                            12,
                            (i) => DropdownMenuItem(value: i + 1, child: Text(nombresMeses[i])),
                          ),
                        ],
                        onChanged: (valor) => setState(() => _mes = valor),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _categoriaId,
                        decoration: decoracionCampo(context, 'Categoría'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas')),
                          ..._categorias.map(
                            (categoria) => DropdownMenuItem(
                              value: categoria.id,
                              child: Text(categoria.nombre),
                            ),
                          ),
                        ],
                        onChanged: _cambiarCategoria,
                      ),
                      if (_categoriaId != null) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: _subcategoriaId,
                          decoration: decoracionCampo(context, 'Subcategoría'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todas')),
                            ..._subcategorias.map(
                              (subcategoria) => DropdownMenuItem(
                                value: subcategoria.id,
                                child: Text(subcategoria.nombre),
                              ),
                            ),
                          ],
                          onChanged: (valor) => setState(() => _subcategoriaId = valor),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResumenColumna(
                          etiqueta: 'Ingresos',
                          monto: _totalIngresos,
                          color: finanzas.ingreso,
                        ),
                      ),
                      _Separador(color: esquema.outlineVariant),
                      Expanded(
                        child: _ResumenColumna(
                          etiqueta: 'Egresos',
                          monto: _totalEgresos,
                          color: finanzas.egreso,
                        ),
                      ),
                      _Separador(color: esquema.outlineVariant),
                      Expanded(
                        child: _ResumenColumna(
                          etiqueta: 'Balance',
                          monto: _totalIngresos - _totalEgresos,
                          color: (_totalIngresos - _totalEgresos) >= 0
                              ? finanzas.ingreso
                              : finanzas.egreso,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    // Que ocupe todo el ancho disponible, repartido en
                    // partes iguales entre los 3 botones, en vez de que
                    // cada uno mida según su texto (eso era lo que hacía
                    // que "Subcategoría" se cortara en pantallas angostas).
                    expandedInsets: EdgeInsets.zero,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: esquema.primaryContainer,
                      selectedForegroundColor: esquema.onPrimaryContainer,
                      side: BorderSide(color: esquema.outlineVariant),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'movimientos',
                        label: Text('Movimientos', overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 'categorias',
                        label: Text('Categoría', overflow: TextOverflow.ellipsis),
                      ),
                      ButtonSegment(
                        value: 'subcategorias',
                        label: Text('Subcategoría', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    selected: {_vista},
                    onSelectionChanged: (seleccion) => setState(() => _vista = seleccion.first),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _filtrados.isEmpty
                      ? Center(
                          child: Text(
                            'No hay movimientos con estos filtros',
                            style: TextStyle(color: esquema.onSurfaceVariant),
                          ),
                        )
                      : switch (_vista) {
                          'categorias' => _ReporteCategorias(
                              etiqueta: 'CATEGORÍA',
                              egresos: _totalesPorCategoria(esIngreso: false),
                              totalEgresos: _totalEgresos,
                              ingresos: _totalesPorCategoria(esIngreso: true),
                              totalIngresos: _totalIngresos,
                            ),
                          'subcategorias' => _ReporteCategorias(
                              etiqueta: 'SUBCATEGORÍA',
                              egresos: _totalesPorSubcategoria(esIngreso: false),
                              totalEgresos: _totalEgresos,
                              ingresos: _totalesPorSubcategoria(esIngreso: true),
                              totalIngresos: _totalIngresos,
                            ),
                          _ => ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _filtrados.length,
                              itemBuilder: (context, index) {
                                return _FilaResultado(movimiento: _filtrados[index]);
                              },
                            ),
                        },
                ),
              ],
            ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: color.withValues(alpha: 0.5),
    );
  }
}

class _ResumenColumna extends StatelessWidget {
  const _ResumenColumna({
    required this.etiqueta,
    required this.monto,
    required this.color,
  });

  final String etiqueta;
  final double monto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: esquema.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatearBs(monto),
            style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// Fila de la lista de resultados. Es como la de la pantalla principal, pero
/// sin poder tocarla ni deslizarla: aquí solo se consulta.
class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.movimiento});

  final Movimiento movimiento;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final finanzas = ColoresFinanzas.de(context);
    final esIngreso = movimiento.esIngreso;

    final detalle = <String>[
      movimiento.cuentaNombre ?? '',
      formatearFechaCorta(movimiento.fecha),
      if (movimiento.subcategoriaNombre != null)
        movimiento.subcategoriaNombre!
      else if (movimiento.categoriaNombre != null)
        movimiento.categoriaNombre!,
    ].where((p) => p.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: finanzas.colorSuave(esIngreso),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esIngreso ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 18,
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
                  detalle,
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
    );
  }
}

/// El reporte "Por categoría": una lista de gastos por categoría (de mayor
/// a menor) y, si hay, otra de ingresos por categoría, cada una con una
/// barra que muestra qué tanto pesa esa categoría sobre el total.
class _ReporteCategorias extends StatelessWidget {
  const _ReporteCategorias({
    required this.etiqueta,
    required this.egresos,
    required this.totalEgresos,
    required this.ingresos,
    required this.totalIngresos,
  });

  /// 'CATEGORÍA' o 'SUBCATEGORÍA', para armar los títulos de cada sección.
  final String etiqueta;
  final Map<String, double> egresos;
  final double totalEgresos;
  final Map<String, double> ingresos;
  final double totalIngresos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final finanzas = ColoresFinanzas.de(context);

    if (egresos.isEmpty && ingresos.isEmpty) {
      return Center(
        child: Text(
          'No hay nada que agrupar todavía',
          style: TextStyle(color: esquema.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (egresos.isNotEmpty) ...[
          _TituloReporte(texto: 'GASTOS POR $etiqueta', color: finanzas.egreso),
          const SizedBox(height: 10),
          ...egresos.entries.map(
            (entrada) => _FilaReporteCategoria(
              nombre: entrada.key,
              monto: entrada.value,
              proporcion: totalEgresos > 0 ? entrada.value / totalEgresos : 0,
              color: finanzas.egreso,
            ),
          ),
          if (ingresos.isNotEmpty) const SizedBox(height: 20),
        ],
        if (ingresos.isNotEmpty) ...[
          _TituloReporte(texto: 'INGRESOS POR $etiqueta', color: finanzas.ingreso),
          const SizedBox(height: 10),
          ...ingresos.entries.map(
            (entrada) => _FilaReporteCategoria(
              nombre: entrada.key,
              monto: entrada.value,
              proporcion: totalIngresos > 0 ? entrada.value / totalIngresos : 0,
              color: finanzas.ingreso,
            ),
          ),
        ],
      ],
    );
  }
}

class _TituloReporte extends StatelessWidget {
  const _TituloReporte({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Una fila del reporte: nombre de la categoría, monto, y una barrita que
/// muestra qué porcentaje del total (de ese tipo) representa. La lista que
/// la contiene ya viene ordenada de mayor a menor.
class _FilaReporteCategoria extends StatelessWidget {
  const _FilaReporteCategoria({
    required this.nombre,
    required this.monto,
    required this.proporcion,
    required this.color,
  });

  final String nombre;
  final double monto;
  final double proporcion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final porcentaje = (proporcion.clamp(0, 1) * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatearBs(monto),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 8, width: constraints.maxWidth, color: color.withValues(alpha: 0.15)),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * proporcion.clamp(0, 1),
                      color: color,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$porcentaje% del total',
            style: TextStyle(fontSize: 11.5, color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
