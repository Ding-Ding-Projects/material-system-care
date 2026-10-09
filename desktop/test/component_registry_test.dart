import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/component_registry.dart';

void main() {
  test('registered component guard accepts official controls', () {
    expect(
      () => requireMaterialComponents({
        'FilledButton',
        'SearchBar',
        'NavigationRail',
      }),
      returnsNormally,
    );
  });
  test('negative regression rejects a generic replacement control', () {
    expect(
      () => requireMaterialComponents({
        'FilledButton',
        'CustomClickableContainer',
      }),
      throwsStateError,
    );
  });
}
