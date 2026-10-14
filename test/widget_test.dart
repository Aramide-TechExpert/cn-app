import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal smoke test. (Pumping the full app needs ProviderScope + Supabase +
// network, so it lives in integration tests later.) This also stops
// `flutter create` from generating its default MyApp counter test in CI.
void main() {
  testWidgets('MaterialApp builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Cluster News'))),
    );
    expect(find.text('Cluster News'), findsOneWidget);
  });
}
