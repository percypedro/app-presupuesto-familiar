import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/categoria.dart';
import '../models/cuenta.dart';
import '../models/movimiento.dart';
import '../models/subcategoria.dart';

/// Maneja toda la conexión y las consultas a la base de datos local
/// (SQLite, vía sqflite).
///
/// Cada perfil tiene su propio archivo de base de datos separado
/// (`gastos_<nombre>.db`), para que los datos de una persona nunca se
/// mezclen con los de otra. Antes de usar cualquier método hay que llamar
/// a [abrirPerfil] (normalmente se hace una sola vez, al iniciar la app o
/// al cambiar de perfil).
class DatabaseHelper {
  DatabaseHelper._interno();
  static final DatabaseHelper instancia = DatabaseHelper._interno();

  static const _version = 3;

  static Database? _db;
  static String? _perfilActivo;

  Future<Database> get database async {
    if (_db == null) {
      throw StateError(
        'No hay un perfil abierto todavía. Llama a DatabaseHelper.instancia.abrirPerfil(nombre) primero.',
      );
    }
    return _db!;
  }

  String get perfilActivo => _perfilActivo ?? '';

  String _nombreArchivoSeguro(String nombrePerfil) {
    final limpio = nombrePerfil.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'gastos_$limpio.db';
  }

  Future<String> rutaBaseDeDatos(String nombrePerfil) async {
    return join(await getDatabasesPath(), _nombreArchivoSeguro(nombrePerfil));
  }

  /// Cierra la base de datos actual (si había una abierta) y abre (o crea)
  /// la del perfil indicado.
  Future<void> abrirPerfil(String nombrePerfil) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final ruta = await rutaBaseDeDatos(nombrePerfil);
    _db = await openDatabase(
      ruta,
      version: _version,
      onCreate: _crearTablas,
      onUpgrade: _actualizarTablas,
    );
    _perfilActivo = nombrePerfil;
  }

  Future<void> _crearTablas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cuentas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subcategorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        categoria_id INTEGER NOT NULL,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        cuenta_id INTEGER NOT NULL,
        categoria_id INTEGER,
        subcategoria_id INTEGER,
        FOREIGN KEY (cuenta_id) REFERENCES cuentas (id),
        FOREIGN KEY (categoria_id) REFERENCES categorias (id),
        FOREIGN KEY (subcategoria_id) REFERENCES subcategorias (id)
      )
    ''');

    await _insertarDatosIniciales(db);
  }

  /// Solo relevante para perfiles que ya existían de una versión anterior
  /// de la app (antes de separar por perfiles, todos usaban "gastos.db").
  /// Un perfil nuevo siempre se crea directo en la versión más reciente.
  Future<void> _actualizarTablas(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE categorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE subcategorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          categoria_id INTEGER NOT NULL,
          FOREIGN KEY (categoria_id) REFERENCES categorias (id)
        )
      ''');

      await db.execute('ALTER TABLE movimientos ADD COLUMN categoria_id INTEGER');
      await db.execute('ALTER TABLE movimientos ADD COLUMN subcategoria_id INTEGER');

      await _insertarCategoriasIniciales(db);
    }

    if (oldVersion < 3) {
      await db.execute("ALTER TABLE categorias ADD COLUMN tipo TEXT NOT NULL DEFAULT 'egreso'");
      await db.update(
        'categorias',
        {'tipo': 'ingreso'},
        where: 'LOWER(nombre) IN (?, ?, ?)',
        whereArgs: ['sueldo', 'salario', 'ingresos'],
      );
    }
  }

  Future<void> _insertarDatosIniciales(Database db) async {
    await db.insert('cuentas', {'nombre': 'Efectivo'});
    await db.insert('cuentas', {'nombre': 'Banco'});
    await _insertarCategoriasIniciales(db);
  }

  Future<void> _insertarCategoriasIniciales(Database db) async {
    final columnas = await db.rawQuery('PRAGMA table_info(categorias)');
    final tieneTipo = columnas.any((c) => c['name'] == 'tipo');

    Map<String, dynamic> fila(String nombre, String tipo) =>
        tieneTipo ? {'nombre': nombre, 'tipo': tipo} : {'nombre': nombre};

    final alimentacionId = await db.insert('categorias', fila('Alimentación', 'egreso'));
    await db.insert('categorias', fila('Transporte', 'egreso'));
    await db.insert('categorias', fila('Vivienda', 'egreso'));
    await db.insert('categorias', fila('Entretenimiento', 'egreso'));
    await db.insert('categorias', fila('Salud', 'egreso'));
    await db.insert('categorias', fila('Otros gastos', 'egreso'));
    await db.insert('categorias', fila('Sueldo', 'ingreso'));
    await db.insert('categorias', fila('Otros ingresos', 'ingreso'));

    await db.insert('subcategorias', {'nombre': 'Supermercado', 'categoria_id': alimentacionId});
    await db.insert('subcategorias', {'nombre': 'Restaurante', 'categoria_id': alimentacionId});
  }

  // ---------- Cuentas ----------

  Future<List<Cuenta>> obtenerCuentas() async {
    final db = await database;
    final filas = await db.query('cuentas', orderBy: 'nombre');
    return filas.map((fila) => Cuenta.fromMap(fila)).toList();
  }

  Future<int> insertarCuenta(String nombre) async {
    final db = await database;
    return db.insert('cuentas', {'nombre': nombre});
  }

  Future<int> actualizarCuenta(int id, String nombre) async {
    final db = await database;
    return db.update('cuentas', {'nombre': nombre}, where: 'id = ?', whereArgs: [id]);
  }

  /// Cuántos movimientos usan esta cuenta. Antes de borrar una cuenta hay
  /// que revisar esto: si el número es mayor a cero, no se debe permitir
  /// borrarla (los movimientos se quedarían sin cuenta y romperían la
  /// lista principal, que depende de que todos tengan una).
  Future<int> contarMovimientosPorCuenta(int cuentaId) async {
    final db = await database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM movimientos WHERE cuenta_id = ?',
      [cuentaId],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<void> eliminarCuenta(int id) async {
    final db = await database;
    await db.delete('cuentas', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Categorías y subcategorías ----------

  Future<List<Categoria>> obtenerCategorias({String? tipo}) async {
    final db = await database;
    final filas = await db.query(
      'categorias',
      where: tipo != null ? 'tipo = ?' : null,
      whereArgs: tipo != null ? [tipo] : null,
      orderBy: 'nombre',
    );
    return filas.map((fila) => Categoria.fromMap(fila)).toList();
  }

  Future<int> insertarCategoria(String nombre, String tipo) async {
    final db = await database;
    return db.insert('categorias', {'nombre': nombre, 'tipo': tipo});
  }

  Future<int> actualizarCategoria(int id, String nombre) async {
    final db = await database;
    return db.update('categorias', {'nombre': nombre}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarMovimientosPorCategoria(int categoriaId) async {
    final db = await database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM movimientos WHERE categoria_id = ?',
      [categoriaId],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<int> contarSubcategoriasPorCategoria(int categoriaId) async {
    final db = await database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM subcategorias WHERE categoria_id = ?',
      [categoriaId],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  /// Solo se puede llamar si [contarMovimientosPorCategoria] y
  /// [contarSubcategoriasPorCategoria] dieron 0 — si no, hay que pedirle al
  /// usuario que primero reasigne o borre esas subcategorías/movimientos.
  Future<void> eliminarCategoria(int id) async {
    final db = await database;
    await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Subcategoria>> obtenerSubcategorias(int categoriaId) async {
    final db = await database;
    final filas = await db.query(
      'subcategorias',
      where: 'categoria_id = ?',
      whereArgs: [categoriaId],
      orderBy: 'nombre',
    );
    return filas.map((fila) => Subcategoria.fromMap(fila)).toList();
  }

  Future<int> insertarSubcategoria(String nombre, int categoriaId) async {
    final db = await database;
    return db.insert('subcategorias', {
      'nombre': nombre,
      'categoria_id': categoriaId,
    });
  }

  Future<int> actualizarSubcategoria(int id, String nombre) async {
    final db = await database;
    return db.update('subcategorias', {'nombre': nombre}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarMovimientosPorSubcategoria(int subcategoriaId) async {
    final db = await database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM movimientos WHERE subcategoria_id = ?',
      [subcategoriaId],
    );
    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  Future<void> eliminarSubcategoria(int id) async {
    final db = await database;
    await db.delete('subcategorias', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Movimientos ----------

  Future<List<Movimiento>> obtenerMovimientos() async {
    final db = await database;
    final filas = await db.rawQuery('''
      SELECT
        m.*,
        c.nombre AS cuenta_nombre,
        cat.nombre AS categoria_nombre,
        sub.nombre AS subcategoria_nombre
      FROM movimientos m
      INNER JOIN cuentas c ON c.id = m.cuenta_id
      LEFT JOIN categorias cat ON cat.id = m.categoria_id
      LEFT JOIN subcategorias sub ON sub.id = m.subcategoria_id
      ORDER BY m.fecha DESC, m.id DESC
    ''');
    return filas.map((fila) => Movimiento.fromMap(fila)).toList();
  }

  Future<int> insertarMovimiento(Movimiento movimiento) async {
    final db = await database;
    final datos = movimiento.toMap()..remove('id');
    return db.insert('movimientos', datos);
  }

  Future<int> actualizarMovimiento(Movimiento movimiento) async {
    final db = await database;
    final datos = movimiento.toMap()..remove('id');
    return db.update(
      'movimientos',
      datos,
      where: 'id = ?',
      whereArgs: [movimiento.id],
    );
  }

  Future<int> eliminarMovimiento(int id) async {
    final db = await database;
    return db.delete('movimientos', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Exportar / Importar ----------

  /// Trae todas las filas de las 4 tablas del perfil activo, tal cual
  /// están guardadas (para armar el archivo que se comparte).
  Future<Map<String, List<Map<String, Object?>>>> exportarTodo() async {
    final db = await database;
    return {
      'cuentas': await db.query('cuentas'),
      'categorias': await db.query('categorias'),
      'subcategorias': await db.query('subcategorias'),
      'movimientos': await db.query('movimientos'),
    };
  }

  /// Igual que [exportarTodo], pero para CUALQUIER perfil por nombre, no
  /// solo el que está abierto ahora mismo. Se usa para exportar todos los
  /// perfiles de una vez. Si el perfil pedido es el que ya está activo,
  /// reutiliza esa misma conexión (no abre otra) para no arriesgar cerrar
  /// por accidente la conexión que usa el resto de la app.
  Future<Map<String, List<Map<String, Object?>>>> exportarPerfil(
    String nombrePerfil,
  ) async {
    if (nombrePerfil == _perfilActivo) {
      return exportarTodo();
    }

    final ruta = await rutaBaseDeDatos(nombrePerfil);
    if (!await File(ruta).exists()) {
      return {'cuentas': [], 'categorias': [], 'subcategorias': [], 'movimientos': []};
    }

    final db = await openDatabase(
      ruta,
      version: _version,
      onCreate: _crearTablas,
      onUpgrade: _actualizarTablas,
    );
    try {
      return {
        'cuentas': await db.query('cuentas'),
        'categorias': await db.query('categorias'),
        'subcategorias': await db.query('subcategorias'),
        'movimientos': await db.query('movimientos'),
      };
    } finally {
      await db.close();
    }
  }

  /// Reconstruye por completo el perfil [nombrePerfil] a partir de los
  /// datos importados (si ya existía, se borra y se reemplaza). Los ids
  /// se vuelven a generar y las relaciones (cuenta/categoría/subcategoría
  /// de cada movimiento) se ajustan para que sigan apuntando correctamente.
  Future<void> importarPerfil(String nombrePerfil, Map<String, dynamic> datos) async {
    final eraElPerfilActivo = _perfilActivo == nombrePerfil;
    if (eraElPerfilActivo && _db != null) {
      await _db!.close();
      _db = null;
    }

    final ruta = await rutaBaseDeDatos(nombrePerfil);
    final archivo = File(ruta);
    if (await archivo.exists()) {
      await archivo.delete();
    }

    final dbImportada = await openDatabase(
      ruta,
      version: _version,
      onCreate: _crearTablas,
      onUpgrade: _actualizarTablas,
    );

    // _crearTablas ya deja las tablas vacías con datos de ejemplo (cuentas
    // y categorías por defecto); los limpiamos porque vamos a insertar los
    // datos reales que vienen del archivo importado.
    await dbImportada.delete('subcategorias');
    await dbImportada.delete('categorias');
    await dbImportada.delete('cuentas');

    final mapaCuentas = <int, int>{};
    for (final filaCruda in (datos['cuentas'] as List)) {
      final fila = Map<String, dynamic>.from(filaCruda as Map);
      final idViejo = fila['id'] as int;
      final idNuevo = await dbImportada.insert('cuentas', {'nombre': fila['nombre']});
      mapaCuentas[idViejo] = idNuevo;
    }

    final mapaCategorias = <int, int>{};
    for (final filaCruda in (datos['categorias'] as List)) {
      final fila = Map<String, dynamic>.from(filaCruda as Map);
      final idViejo = fila['id'] as int;
      final idNuevo = await dbImportada.insert('categorias', {
        'nombre': fila['nombre'],
        'tipo': fila['tipo'] ?? 'egreso',
      });
      mapaCategorias[idViejo] = idNuevo;
    }

    final mapaSubcategorias = <int, int>{};
    for (final filaCruda in (datos['subcategorias'] as List)) {
      final fila = Map<String, dynamic>.from(filaCruda as Map);
      final idViejo = fila['id'] as int;
      final categoriaViejaId = fila['categoria_id'] as int;
      final idNuevo = await dbImportada.insert('subcategorias', {
        'nombre': fila['nombre'],
        'categoria_id': mapaCategorias[categoriaViejaId],
      });
      mapaSubcategorias[idViejo] = idNuevo;
    }

    for (final filaCruda in (datos['movimientos'] as List)) {
      final fila = Map<String, dynamic>.from(filaCruda as Map);
      final cuentaViejaId = fila['cuenta_id'] as int;
      final categoriaViejaId = fila['categoria_id'] as int?;
      final subcategoriaViejaId = fila['subcategoria_id'] as int?;
      await dbImportada.insert('movimientos', {
        'tipo': fila['tipo'],
        'descripcion': fila['descripcion'],
        'monto': fila['monto'],
        'fecha': fila['fecha'],
        'cuenta_id': mapaCuentas[cuentaViejaId],
        'categoria_id': categoriaViejaId != null ? mapaCategorias[categoriaViejaId] : null,
        'subcategoria_id':
            subcategoriaViejaId != null ? mapaSubcategorias[subcategoriaViejaId] : null,
      });
    }

    if (eraElPerfilActivo) {
      _db = dbImportada;
      _perfilActivo = nombrePerfil;
    } else {
      await dbImportada.close();
    }
  }
}
