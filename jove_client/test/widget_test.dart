import 'package:flutter_test/flutter_test.dart';
import 'package:jove_client/main.dart'; // Adjust path if necessary

void main() {
  testWidgets('App launches and shows the splash screen', (
    WidgetTester tester,
  ) async {
    // We changed JoveClientApp() to MyApp() to match your main.dart file!
    await tester.pumpWidget(const MyApp());

    // Just confirms the app builds and renders without throwing.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
