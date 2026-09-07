import 'package:shared_preferences/shared_preferences.dart';

/// Guarda, en el propio celular (no en la base de datos de gastos), la
/// lista de perfiles que existen y cuál está activo en este momento.
/// Cada perfil tiene su propia base de datos separada (ver DatabaseHelper).
class PerfilService {
  static const _clavePerfiles = 'perfiles';
  static const _clavePerfilActivo = 'perfil_activo';

  Future<List<String>> obtenerPerfiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_clavePerfiles) ?? [];
  }

  Future<String?> obtenerPerfilActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clavePerfilActivo);
  }

  Future<void> establecerPerfilActivo(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePerfilActivo, nombre);
  }

  /// Agrega el perfil a la lista si todavía no estaba.
  Future<void> agregarPerfil(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    final perfiles = prefs.getStringList(_clavePerfiles) ?? [];
    if (!perfiles.contains(nombre)) {
      await prefs.setStringList(_clavePerfiles, [...perfiles, nombre]);
    }
  }
}
