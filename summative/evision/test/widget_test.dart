import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evision/main.dart';

void main() {
  testWidgets('EV Range Predictor app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const EVRangeApp());

    expect(find.text('⚡ EV Range Predictor'), findsOneWidget);
    expect(find.text('Predict'), findsOneWidget);
  });
}
