import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_agent/app.dart';

void main() {
  testWidgets('Home screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GovAgentApp(),
      ),
    );

    // Verify the app title and start button appear
    expect(find.text('GovAgent'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
  });
}
