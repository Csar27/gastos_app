import 'package:flutter_test/flutter_test.dart';

import 'package:gastos_app/main.dart';

void main() {
  testWidgets('Control de Gastos app test', (WidgetTester tester) async {
    await tester.pumpWidget(const GastosApp());

    expect(find.text('Salario Total'), findsOneWidget);
    expect(find.text('Control de Gastos'), findsOneWidget);
  });
}