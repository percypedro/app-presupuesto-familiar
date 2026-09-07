class Categoria {
  final int? id;
  final String nombre;

  /// 'ingreso' o 'egreso' — para qué tipo de movimiento sirve esta categoría.
  final String tipo;

  Categoria({this.id, required this.nombre, required this.tipo});

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
      };

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String,
    );
  }
}
