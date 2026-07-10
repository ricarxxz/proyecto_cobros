import 'package:flutter_test/flutter_test.dart';
import 'package:app_cobros/cierre_dia_service.dart';

void main() {
  group('CierreDiaService', () {
    test(
      'bloquea acciones mientras el cierre sigue vigente para el mismo día',
      () {
        final now = DateTime(2026, 7, 10, 20, 30);
        final closedAt = DateTime(2026, 7, 10, 18, 0);

        expect(CierreDiaService.shouldBlockActions(closedAt, now), isTrue);
      },
    );

    test('permite acciones después de las 23:59 del mismo día', () {
      final now = DateTime(2026, 7, 10, 23, 59, 59);
      final closedAt = DateTime(2026, 7, 10, 18, 0);

      expect(CierreDiaService.shouldBlockActions(closedAt, now), isFalse);
    });

    test('permite acciones cuando el cierre fue hecho en otro día', () {
      final now = DateTime(2026, 7, 11, 8, 0);
      final closedAt = DateTime(2026, 7, 10, 18, 0);

      expect(CierreDiaService.shouldBlockActions(closedAt, now), isFalse);
    });
  });
}
