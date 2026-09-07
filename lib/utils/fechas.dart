const List<String> nombresMeses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> nombresMesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// "07 sep 2026". Se lee más rápido que 07/09/2026 y ya dice el mes con
/// letras, así que no hace falta repetirlo aparte.
String formatearFechaCorta(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  return '$dia ${nombresMesesCortos[fecha.month - 1]} ${fecha.year}';
}

String formatearMesAnio(DateTime fecha) {
  return '${nombresMeses[fecha.month - 1]} ${fecha.year}';
}

/// Formato de números como se escriben en Bolivia: punto para los miles y
/// coma para los decimales. 5000 -> "5.000,00".
///
/// Está hecho a mano a propósito, para no agregar otro paquete al proyecto.
String formatearMonto(double monto) {
  final partes = monto.abs().toStringAsFixed(2).split('.');
  final entero = partes[0];

  final conPuntos = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    // Un punto cada 3 dígitos, contando desde la derecha.
    if (i > 0 && (entero.length - i) % 3 == 0) {
      conPuntos.write('.');
    }
    conPuntos.write(entero[i]);
  }

  return '$conPuntos,${partes[1]}';
}

/// "Bs. 5.000,00" (con el signo menos adelante si el monto es negativo).
String formatearBs(double monto) {
  final signo = monto < 0 ? '-' : '';
  return '${signo}Bs. ${formatearMonto(monto)}';
}
