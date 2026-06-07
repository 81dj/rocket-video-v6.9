import 'package:flutter_test/flutter_test.dart';
import 'package:rocket_video_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen has version badge', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('v1.0.6'), findsOneWidget);
    expect(find.text('New Video'), findsOneWidget);
    expect(find.text('My Videos'), findsOneWidget);
  });
}
