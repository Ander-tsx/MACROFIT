import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/app/app.dart';

void main() {
  testWidgets('la app arranca en la pantalla de bienvenida', (tester) async {
    await tester.pumpWidget(const MacroFitApp());

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('MacroFit'), findsOneWidget);
  });
}
