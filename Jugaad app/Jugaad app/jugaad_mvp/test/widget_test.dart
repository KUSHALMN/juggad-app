import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const JugaadApp());
    expect(find.text('Jugaad MVP - User Mode'), findsOneWidget);
  });
}
