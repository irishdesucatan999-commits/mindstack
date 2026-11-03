// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindstack_appdev/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MindStack app loads with notes screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MindStackApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('MindStack'), findsOneWidget);
    expect(find.text('Welcome to MindStack'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
