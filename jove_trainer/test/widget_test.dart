import 'package:flutter_test/flutter_test.dart';
import 'package:jove_trainer/main.dart';

void main() {
  testWidgets('App launches and shows the landing page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const JoveTrainerApp());

    // Just confirms the app builds and renders without throwing.
    expect(find.byType(JoveTrainerApp), findsOneWidget);
  });
}
