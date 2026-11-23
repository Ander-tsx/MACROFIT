import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/theme.dart';
import 'package:macrofit_app/features/progress/presentation/weights/weights_view.dart';
import 'package:macrofit_app/features/progress/presentation/weights/weights_view_model.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fakes.dart';

const _input = Key('weight_input');
const _submit = Key('submit_weight');

Future<FakeWeightsRepository> pumpWeights(WidgetTester tester) async {
  final repository = FakeWeightsRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider(
        create: (_) => WeightsViewModel(repository: repository)..load(),
        child: const WeightsView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

String _fieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(_input),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  testWidgets('al registrar un peso el campo queda vacío', (tester) async {
    final repository = await pumpWeights(tester);

    await tester.enterText(find.byKey(_input), '72.5');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(repository.weights.map((w) => w.weightKg), [72.5]);
    expect(find.text('Peso registrado correctamente'), findsOneWidget);
    expect(_fieldText(tester), isEmpty);
  });

  testWidgets('se puede registrar otro peso justo después del primero', (
    tester,
  ) async {
    final repository = await pumpWeights(tester);

    await tester.enterText(find.byKey(_input), '72.5');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_input), '72.0');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(repository.weights.map((w) => w.weightKg), [72.0, 72.5]);
    expect(find.text('El peso es obligatorio'), findsNothing);
  });

  testWidgets('un peso inválido se conserva en el campo con su mensaje', (
    tester,
  ) async {
    final repository = await pumpWeights(tester);

    await tester.enterText(find.byKey(_input), '300');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(repository.weights, isEmpty);
    expect(find.text('El peso debe estar entre 35 y 250 kg'), findsOneWidget);
    expect(_fieldText(tester), '300');
  });
}
