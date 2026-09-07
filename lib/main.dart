import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_inicio.dart';
import 'tema.dart';

void main() {
  // sqflite (el paquete normal) solo funciona en Android/iOS. Para poder
  // probar la app en Windows o Linux de escritorio, hay que usar la
  // implementación "ffi" de la base de datos en esos casos.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const GastosApp());
}

class GastosApp extends StatelessWidget {
  const GastosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Finanzas',
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaOscuro,
      // La app sigue el modo que tenga puesto el celular (claro u oscuro).
      themeMode: ThemeMode.system,
      home: const AppInicio(),
    );
  }
}
