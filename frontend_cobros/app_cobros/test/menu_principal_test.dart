import 'package:flutter_test/flutter_test.dart';
import 'package:app_cobros/main.dart';

void main() {
  test('la vista de administrador muestra todos los días', () {
    expect(
      obtenerTextoVistaClientes(true, 'lunes'),
      'Vista general de todos los días',
    );
  });

  test('la vista de trabajador muestra el día seleccionado', () {
    expect(
      obtenerTextoVistaClientes(false, 'martes'),
      'Clientes del día Martes',
    );
  });
}
