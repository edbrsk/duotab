import 'package:duotab/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots with localized title', (tester) async {
    await tester.pumpWidget(const DuoTabApp(home: SizedBox()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'DuoTab');
    expect(app.supportedLocales, contains(const Locale('en')));
  });
}
