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

  /// Junta los datos de TODOS los perfiles indicados en un solo archivo
  /// .json (uno anidado dentro de otro) y abre el menú para compartir.
  /// Se distingue de un export de un solo perfil por el campo "tipo".
  Future<void> exportarTodosLosPerfiles(List<String> nombresPerfiles) async {
    final perfiles = <String, dynamic>{};
    for (final nombre in nombresPerfiles) {
      perfiles[nombre] = await DatabaseHelper.instancia.exportarPerfil(nombre);
    }

    final contenido = jsonEncode({
      'app': 'app-presupuesto-familiar',
      'tipo': 'todos_los_perfiles',
      'version': 1,
      'exportadoEl': DateTime.now().toIso8601String(),
      'perfiles': perfiles,
    });

    final directorio = await getTemporaryDirectory();
    final archivo = File('${directorio.path}/mis_finanzas_todos_los_perfiles.json');
    await archivo.writeAsString(contenido);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(archivo.path)],
        text: 'Todos los perfiles de Mis Finanzas',
      ),
    );
  }

  /// Abre el explorador de archivos para elegir un .json exportado desde
  /// esta misma app, e importa lo que traiga (creando o sobreescribiendo
  /// los perfiles que ya existieran). Acepta tanto un archivo de un solo
  /// perfil como uno de "todos los perfiles". Devuelve la lista de
  /// nombres de los perfiles importados, o null si el usuario canceló la
  /// selección.
  Future<List<String>?> importarDesdeArchivo() async {
    final archivoElegido = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (archivoElegido == null) return null;

    // Leemos los bytes en vez de usar la ruta: en Android el archivo puede
    // venir de Google Drive o WhatsApp y no tener una ruta local real.
    final contenido = utf8.decode(await archivoElegido.readAsBytes());
    final datos = jsonDecode(contenido) as Map<String, dynamic>;

    if (datos['tipo'] == 'todos_los_perfiles' && datos['perfiles'] is Map) {
      final perfilesData = (datos['perfiles'] as Map).cast<String, dynamic>();
      if (perfilesData.isEmpty) {
        throw const FormatException('El archivo no tiene ningún perfil.');
      }
      final nombresImportados = <String>[];
      for (final entrada in perfilesData.entries) {
        await DatabaseHelper.instancia.importarPerfil(
          entrada.key,
          (entrada.value as Map).cast<String, dynamic>(),
        );
        nombresImportados.add(entrada.key);
      }
      return nombresImportados;
    }

    final nombrePerfil = datos['perfil'] as String?;
    if (nombrePerfil == null || nombrePerfil.trim().isEmpty) {
      throw const FormatException('El archivo no tiene un nombre de perfil válido.');
    }

    await DatabaseHelper.instancia.importarPerfil(nombrePerfil, datos);
    return [nombrePerfil];
  }
}
