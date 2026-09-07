import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Paleta "Verde bosque + terracota"
// ---------------------------------------------------------------------------
// La idea detrás de estos colores:
//
// - El verde es el color de la app y también el de los ingresos.
// - El fondo es un crema cálido en vez de blanco o gris frío. El verde se ve
//   mucho más natural sobre un neutro cálido.
// - Los egresos usan terracota en vez de rojo puro: se distinguen igual de
//   bien, pero no se siente una alarma cada vez que anotas un gasto.
// - El ámbar aparece solo en detalles pequeños, para dar un respiro al verde.
//
// Todo el color de la app sale de aquí. Si algún día quieres cambiar la
// paleta, este es el único archivo que tendrías que tocar.

const _verdeBosque = Color(0xFF1B6B50);
const _verdeAgua = Color(0xFFD7EDE2);
const _crema = Color(0xFFF8F6F0);
const _terracota = Color(0xFFC0553B);
const _carbon = Color(0xFF1C1F1D);

const _verdeMenta = Color(0xFF7FD3B0);

/// Colores para cuando el celular está en modo claro.
const _esquemaClaro = ColorScheme(
  brightness: Brightness.light,
  primary: _verdeBosque,
  onPrimary: Colors.white,
  primaryContainer: _verdeAgua,
  onPrimaryContainer: Color(0xFF06301F),
  secondary: Color(0xFF4F6156),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFDCE7E0),
  onSecondaryContainer: Color(0xFF11241A),
  tertiary: Color(0xFF8A6A1F),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFAEBC8),
  onTertiaryContainer: Color(0xFF2E2000),
  error: _terracota,
  onError: Colors.white,
  errorContainer: Color(0xFFF8DED7),
  onErrorContainer: Color(0xFF43160B),
  surface: _crema,
  onSurface: _carbon,
  onSurfaceVariant: Color(0xFF4A544D),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFCFAF5),
  surfaceContainer: Color(0xFFF1EEE6),
  surfaceContainerHigh: Color(0xFFEBE8E0),
  surfaceContainerHighest: Color(0xFFE5E2DA),
  outline: Color(0xFF79837B),
  outlineVariant: Color(0xFFC9D2CA),
  inverseSurface: Color(0xFF2F332F),
  onInverseSurface: Color(0xFFF0F1EC),
  inversePrimary: _verdeMenta,
);

/// Los mismos colores, pero pensados para modo oscuro: el verde se aclara
/// (uno oscuro sobre fondo negro no se vería) y el fondo es un negro con un
/// toque de verde, no un gris plano.
const _esquemaOscuro = ColorScheme(
  brightness: Brightness.dark,
  primary: _verdeMenta,
  onPrimary: Color(0xFF003825),
  primaryContainer: Color(0xFF12513A),
  onPrimaryContainer: Color(0xFF9BEFCB),
  secondary: Color(0xFFB4CCBF),
  onSecondary: Color(0xFF203529),
  secondaryContainer: Color(0xFF364B3F),
  onSecondaryContainer: Color(0xFFD0E8DA),
  tertiary: Color(0xFFE8C06B),
  onTertiary: Color(0xFF3D2E00),
  tertiaryContainer: Color(0xFF57430A),
  onTertiaryContainer: Color(0xFFFFDF9E),
  error: Color(0xFFEF9C84),
  onError: Color(0xFF5A1A0B),
  errorContainer: Color(0xFF7A2D1A),
  onErrorContainer: Color(0xFFFFDBD0),
  surface: Color(0xFF111412),
  onSurface: Color(0xFFE2E4E0),
  onSurfaceVariant: Color(0xFFBEC9C0),
  surfaceContainerLowest: Color(0xFF0B0E0C),
  surfaceContainerLow: Color(0xFF191D1A),
  surfaceContainer: Color(0xFF1D211E),
  surfaceContainerHigh: Color(0xFF272B28),
  surfaceContainerHighest: Color(0xFF323633),
  outline: Color(0xFF88938B),
  outlineVariant: Color(0xFF3E4842),
  inverseSurface: Color(0xFFE2E4E0),
  onInverseSurface: Color(0xFF2F332F),
  inversePrimary: _verdeBosque,
);

ThemeData _construirTema(ColorScheme esquema) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: esquema.surface,
  );
}

final ThemeData temaClaro = _construirTema(_esquemaClaro);
final ThemeData temaOscuro = _construirTema(_esquemaOscuro);

/// Colores propios de la app que Material no trae: el verde de los ingresos
/// y el terracota de los egresos, cada uno con una versión "suave" para usar
/// de fondo en círculos e insignias.
///
/// Se usa así:
/// ```dart
/// final finanzas = ColoresFinanzas.de(context);
/// Text('...', style: TextStyle(color: finanzas.color(movimiento.esIngreso)));
/// ```
class ColoresFinanzas {
  const ColoresFinanzas({
    required this.ingreso,
    required this.ingresoSuave,
    required this.egreso,
    required this.egresoSuave,
  });

  final Color ingreso;
  final Color ingresoSuave;
  final Color egreso;
  final Color egresoSuave;

  static const claro = ColoresFinanzas(
    ingreso: _verdeBosque,
    ingresoSuave: _verdeAgua,
    egreso: _terracota,
    egresoSuave: Color(0xFFF8DED7),
  );

  static const oscuro = ColoresFinanzas(
    ingreso: _verdeMenta,
    ingresoSuave: Color(0xFF17402F),
    egreso: Color(0xFFEF9C84),
    egresoSuave: Color(0xFF4A2318),
  );

  /// Elige la versión que toca según el modo (claro u oscuro) del celular.
  static ColoresFinanzas de(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oscuro : claro;

  /// El color fuerte que corresponde a un movimiento.
  Color color(bool esIngreso) => esIngreso ? ingreso : egreso;

  /// El color de fondo suave que corresponde a un movimiento.
  Color colorSuave(bool esIngreso) => esIngreso ? ingresoSuave : egresoSuave;
}

/// Estilo único para todos los campos de texto y desplegables de la app:
/// fondo suave y esquinas redondeadas, en vez de la línea de abajo que trae
/// Flutter por defecto. Así todos los formularios se ven iguales.
InputDecoration decoracionCampo(
  BuildContext context,
  String etiqueta, {
  String? ayuda,
  String? prefijo,
}) {
  final esquema = Theme.of(context).colorScheme;
  const radio = BorderRadius.all(Radius.circular(14));

  return InputDecoration(
    labelText: etiqueta,
    hintText: ayuda,
    prefixText: prefijo,
    filled: true,
    fillColor: esquema.surfaceContainerHigh,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: const OutlineInputBorder(borderRadius: radio, borderSide: BorderSide.none),
    enabledBorder: const OutlineInputBorder(borderRadius: radio, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: esquema.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: esquema.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: esquema.error, width: 2),
    ),
  );
}
