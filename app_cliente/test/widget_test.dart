import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_cliente/pages/login_page.dart';

void main() {
  testWidgets('cliente inicia sesion desde el front y entra al dashboard', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/login-cliente/');
      expect(request.method, 'POST');
      expect(request.body, contains('demo.cliente@si2.local'));
      expect(request.body, contains('1234'));

      return http.Response(
        '{"mensaje":"Bienvenido","usuario":"Demo","usuario_id":7}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(home: LoginPage(client: mockClient)));

    expect(find.text('demo.cliente@si2.local'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Auxilio Vial'), findsOneWidget);
  });
}
