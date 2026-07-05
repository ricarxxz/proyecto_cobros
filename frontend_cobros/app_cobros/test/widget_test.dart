import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_cobros/main.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Login - Sistema de Cobros'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
