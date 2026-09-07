class Subcategoria {
  final int? id;
  final String nombre;
  final int categoriaId;

  Subcategoria({
    this.id,
    required this.nombre,
    required this.categoriaId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'categoria_id': categoriaId,
      };

  factory Subcategoria.fromMap(Map<String, dynamic> map) {
    return Subcategoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      categoriaId: map['categoria_id'] as int,
    );
  }
}
