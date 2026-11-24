import 'package:flutter_test/flutter_test.dart';

import 'package:hello_flutter/main.dart';

void main() {
  testWidgets('App renders greet page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Hello Flutter + Skir'), findsOneWidget);
    expect(find.text('Greet'), findsOneWidget);
  });
}
