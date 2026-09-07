// Prueba básica: solo confirma que la app arranca sin lanzar errores.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_presupuesto_familiar/main.dart';

void main() {
  testWidgets('La app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const GastosApp());
    await tester.pump();
  });
}
