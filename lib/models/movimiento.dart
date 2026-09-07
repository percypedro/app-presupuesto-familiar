/// Un movimiento puede ser un ingreso o un egreso (gasto).
class Movimiento {
  final int? id;
  final String tipo; // 'ingreso' o 'egreso'
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final int cuentaId;
  final int? categoriaId;
  final int? subcategoriaId;

  /// Estos campos solo se usan para mostrar en la lista (vienen de un JOIN,
  /// no se guardan directamente en la tabla movimientos).
  final String? cuentaNombre;
  final String? categoriaNombre;
  final String? subcategoriaNombre;

  Movimiento({
    this.id,
    required this.tipo,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.cuentaId,
    this.categoriaId,
    this.subcategoriaId,
    this.cuentaNombre,
    this.categoriaNombre,
    this.subcategoriaNombre,
  });

  bool get esIngreso => tipo == 'ingreso';

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo,
        'descripcion': descripcion,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'cuenta_id': cuentaId,
        'categoria_id': categoriaId,
        'subcategoria_id': subcategoriaId,
      };

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      descripcion: map['descripcion'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      cuentaId: map['cuenta_id'] as int,
      categoriaId: map['categoria_id'] as int?,
      subcategoriaId: map['subcategoria_id'] as int?,
      cuentaNombre: map['cuenta_nombre'] as String?,
      categoriaNombre: map['categoria_nombre'] as String?,
      subcategoriaNombre: map['subcategoria_nombre'] as String?,
    );
  }
}
