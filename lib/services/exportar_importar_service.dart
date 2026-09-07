import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';

class ExportarImportarService {
  String _nombreArchivoSeguro(String nombrePerfil) {
    final limpio = nombrePerfil.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'gastos_$limpio.json';
  }

  /// Junta todos los datos del perfil activo en un archivo .json y abre
  /// el menú para compartir del celular (WhatsApp, correo, Bluetooth...).
  Future<void> exportarPerfilActivo(String nombrePerfil) async {
    final datos = await DatabaseHelper.instancia.exportarTodo();

    final contenido = jsonEncode({
      'app': 'app-presupuesto-familiar',
      'perfil': nombrePerfil,
      'version': 1,
      'exportadoEl': DateTime.now().toIso8601String(),
      ...datos,
    });

    final directorio = await getTemporaryDirectory();
    final archivo = File('${directorio.path}/${_nombreArchivoSeguro(nombrePerfil)}');
    await archivo.writeAsString(contenido);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(archivo.path)],
        text: 'Datos de gastos de $nombrePerfil',
      ),
    );
  }

  /// Abre el explorador de archivos para elegir un .json exportado desde
  /// esta misma app, e importa ese perfil (creándolo o sobreescribiéndolo
  /// si ya existía). Devuelve el nombre del perfil importado, o null si
  /// el usuario canceló la selección.
  Future<String?> importarDesdeArchivo() async {
    final archivoElegido = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (archivoElegido == null) return null;

    // Leemos los bytes en vez de usar la ruta: en Android el archivo puede
    // venir de Google Drive o WhatsApp y no tener una ruta local real.
    final contenido = utf8.decode(await archivoElegido.readAsBytes());
    final datos = jsonDecode(contenido) as Map<String, dynamic>;

    final nombrePerfil = datos['perfil'] as String?;
    if (nombrePerfil == null || nombrePerfil.trim().isEmpty) {
      throw const FormatException('El archivo no tiene un nombre de perfil válido.');
    }

    await DatabaseHelper.instancia.importarPerfil(nombrePerfil, datos);
    return nombrePerfil;
  }
}
