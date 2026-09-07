class Cuenta {
  final int? id;
  final String nombre;

  Cuenta({this.id, required this.nombre});

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
      };

  factory Cuenta.fromMap(Map<String, dynamic> map) {
    return Cuenta(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
    );
  }
}
