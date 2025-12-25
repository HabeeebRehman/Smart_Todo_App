import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_todo_pro/main.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for testing. 
    // We use a temporary directory for the boxes.
    Hive.init('./test_hive_storage'); 
    await Hive.openBox('tasks');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is present (it might be in the AppBar or somewhere else)
    // Since we are using a complex UI, checking for specific text is good.
    // 'Smart To-Do Pro' is in the title of MaterialApp, but not necessarily rendered as text unless in AppBar.
    // HomeScreen has 'Hello, Friend!'
    
    expect(find.text('Hello, Friend!'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
