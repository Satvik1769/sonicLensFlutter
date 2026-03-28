import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_lens_flutter/app/app.dart';

void main() {
  testWidgets('SonicLens app smoke test', (WidgetTester tester) async {
    expect(SonicLensApp, isNotNull);
  });
}
