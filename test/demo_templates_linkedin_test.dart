import 'package:bitacora_web/services/demo_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LinkedIn demo template is a realistic technical survey', () {
    final spec = resolveDemoTemplateFromSlug('linkedin');

    expect(spec, isNotNull);
    expect(spec!.sheetName, contains('Patagonia Ingenieria'));
    expect(spec.headers, <String>[
      'Fecha',
      'Progresiva',
      'Sector',
      'Elemento',
      'Estado',
      'Medicion',
      'GPS',
      'Evidencia',
      'Observaciones',
    ]);
    expect(spec.rows.length, inInclusiveRange(12, 20));

    final flattened = spec.rows.expand((row) => row).join('\n');
    expect(flattened, contains('Patagonia Ingenieria SRL'));
    expect(flattened, contains('Neuquen Capital'));
    expect(flattened, contains('OK'));
    expect(flattened, contains('Atención'));
    expect(flattened, contains('Crítico'));
    expect(flattened, contains('Pendiente'));
    expect(flattened, contains('ñ'));
    expect(flattened, contains('"Rack A"'));
    expect(flattened, contains('\nSegunda linea'));
    expect(flattened, contains('⚙️'));
    expect(
      spec.rows.any((row) => row.any((cell) => cell.trim().isEmpty)),
      isTrue,
    );

    const allowedStatuses = <String>{'OK', 'Atención', 'Crítico', 'Pendiente'};
    for (final row in spec.rows) {
      expect(row.length, spec.headers.length);
      expect(double.tryParse(row[1]), isNotNull);
      expect(allowedStatuses, contains(row[4]));
    }
  });
}
