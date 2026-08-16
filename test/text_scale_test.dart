import 'package:flutter_test/flutter_test.dart';

import 'package:clustez/data/settings_controller.dart';

void main() {
  group('text-scale ladder — STRICT presets only', () {
    test('the ladder is exactly Small 0.9, Default 0.95, Large 1.0', () {
      expect(kTextScalePresets, [0.9, 0.95, 1.0]);
    });

    test('presets pass through unchanged', () {
      for (final p in kTextScalePresets) {
        expect(snapTextScale(p), p);
      }
    });

    test('old-ladder values snap onto the current ladder', () {
      expect(snapTextScale(1.15), 1.0); // old Large
      expect(snapTextScale(1.05), 1.0); // interim Large
      expect(snapTextScale(1.0), 1.0); // old Default == today's Large scale
    });

    test('arbitrary/corrupt values can never render off-ladder', () {
      expect(snapTextScale(0.2), 0.9);
      expect(snapTextScale(3.0), 1.0);
      expect(snapTextScale(0.93), closeTo(0.95, 1e-9));
      for (final v in [0.0, 0.5, 0.91, 0.97, 1.2, 9.9]) {
        expect(kTextScalePresets.contains(snapTextScale(v)), isTrue,
            reason: '$v must snap to a preset');
      }
    });
  });
}
