// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mushroom_classifier/main.dart';

void main() {
  testWidgets('App shows title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MushroomClassifierApp());

    // SplashScreen uses a 3-second delay before navigating to HomeScreen.
    // Advance the clock to allow the timer to fire and avoid pending timers.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify that the app title on HomeScreen is displayed.
    expect(find.text('Klasifikasi Jamur'), findsWidgets);
  });
}
