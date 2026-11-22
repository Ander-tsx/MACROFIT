import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/theme.dart';
import 'package:macrofit_app/core/errors/api_exception.dart';
import 'package:macrofit_app/features/coach_link/domain/entities/coach_link.dart';
import 'package:macrofit_app/features/coach_link/presentation/coach_link/coach_link_view.dart';
import 'package:macrofit_app/features/coach_link/presentation/coach_link/coach_link_view_model.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fakes.dart';

const _input = Key('invite_code_input');
const _submit = Key('submit_coach_link');
const _confirmLink = Key('coach_link_confirm');
const _cancelLink = Key('coach_link_cancel');
const _unlink = Key('unlink_coach_button');
const _confirmUnlink = Key('unlink_coach_confirm');
const _cancelUnlink = Key('unlink_coach_cancel');

const _laura = CoachLink(
  id: '1',
  coachId: 'c1',
  coachName: 'Laura',
  coachEmail: 'laura@test.com',
  status: 'active',
);

Future<void> pumpCoachLink(
  WidgetTester tester,
  FakeCoachLinkRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider(
        create: (_) => CoachLinkViewModel(repository: repository)..load(),
        child: const CoachLinkView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> submitCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(_input), code);
  await tester.tap(find.byKey(_submit));
  await tester.pumpAndSettle();
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
  testWidgets(
    'muestra el nombre del coach y vincula solo al confirmar (CU-02 pasos 4 y 5)',
    (tester) async {
      final repository = FakeCoachLinkRepository(previewName: 'Laura');
      await pumpCoachLink(tester, repository);

      await submitCode(tester, 'k7p2qx');

      expect(find.textContaining('Laura'), findsWidgets);
      expect(repository.previewCodes, ['K7P2QX']);
      expect(repository.linkCodes, isEmpty);

      await tester.tap(find.byKey(_confirmLink));
      await tester.pumpAndSettle();

      expect(repository.linkCodes, ['K7P2QX']);
      expect(find.text('¡Vinculado con éxito!'), findsOneWidget);
      expect(find.byKey(_unlink), findsOneWidget);
    },
  );

  testWidgets('cancelar la confirmación no vincula y conserva el código', (
    tester,
  ) async {
    final repository = FakeCoachLinkRepository(
      latency: const Duration(milliseconds: 300),
    );
    await pumpCoachLink(tester, repository);

    await submitCode(tester, 'K7P2QX');
    await tester.tap(find.byKey(_cancelLink));
    await tester.pumpAndSettle();

    expect(repository.linkCodes, isEmpty);
    expect(find.byKey(_unlink), findsNothing);
    expect(_fieldText(tester), 'K7P2QX');
  });

  testWidgets(
    'un código inválido muestra el error, sin confirmación y sin borrar el código (CU-02 4a)',
    (tester) async {
      final repository = FakeCoachLinkRepository(
        previewException: const ApiException(
          code: ApiErrorCode.inviteCodeNotFound,
          message: 'No existe',
        ),
        latency: const Duration(milliseconds: 300),
      );
      await pumpCoachLink(tester, repository);

      await submitCode(tester, 'ZZZZZZ');

      expect(find.text('Código inválido'), findsOneWidget);
      expect(find.byKey(_confirmLink), findsNothing);
      expect(repository.linkCodes, isEmpty);
      expect(_fieldText(tester), 'ZZZZZZ');
    },
  );

  testWidgets(
    'con un coach activo indica que debe desvincularse primero (CU-02 4b)',
    (tester) async {
      final repository = FakeCoachLinkRepository(
        previewException: const ApiException(
          code: ApiErrorCode.userAlreadyLinked,
          message: 'Ya vinculado',
        ),
      );
      await pumpCoachLink(tester, repository);

      await submitCode(tester, 'K7P2QX');

      expect(
        find.textContaining('Primero debes desvincularte'),
        findsOneWidget,
      );
      expect(find.byKey(_confirmLink), findsNothing);
    },
  );

  testWidgets(
    'desvincularse pide confirmación; cancelar conserva al coach (RF-13)',
    (tester) async {
      final repository = FakeCoachLinkRepository(linkedCoach: _laura);
      await pumpCoachLink(tester, repository);

      await tester.tap(find.byKey(_unlink));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_cancelUnlink));
      await tester.pumpAndSettle();

      expect(repository.unlinkedCalled, isFalse);
      expect(find.byKey(_unlink), findsOneWidget);
    },
  );

  testWidgets(
    'al confirmar la desvinculación vuelve a pedir un código (RF-13)',
    (tester) async {
      final repository = FakeCoachLinkRepository(linkedCoach: _laura);
      await pumpCoachLink(tester, repository);

      await tester.tap(find.byKey(_unlink));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirmUnlink));
      await tester.pumpAndSettle();

      expect(repository.unlinkedCalled, isTrue);
      expect(find.byKey(_unlink), findsNothing);
      expect(find.byKey(_input), findsOneWidget);
    },
  );

  testWidgets(
    'con un coach activo no pide código y avisa que primero debe desvincularse (CU-02 4b)',
    (tester) async {
      final repository = FakeCoachLinkRepository(linkedCoach: _laura);
      await pumpCoachLink(tester, repository);

      expect(find.byKey(_input), findsNothing);
      expect(
        find.text('Para vincularte con otro coach, primero desvincúlate.'),
        findsOneWidget,
      );
    },
  );
}
