import 'package:test/test.dart';
import '../skirout/enums.dart' as enums;
import '../symbols_check/skirout/symbols_check.dart';

// The symbols_check companion generator rebuilds every enum variant with the
// provider's constructor from the value its value accessor reads, so a rebuilt
// value equals the original only if both symbols agree with the generated
// code.
void main() {
  test('symbol provider rebuilds constant and wrapper variants', () {
    final values = [
      enums.JsonValue.null_,
      enums.JsonValue.wrapBoolean(true),
      enums.JsonValue.wrapString('skir'),
      enums.JsonValue.wrapArray([enums.JsonValue.wrapNumber(1.0)]),
    ];
    for (final value in values) {
      expect(value.rebuild(), equals(value));
    }
  });

  test('symbol provider rebuilds variants with conflicting names', () {
    final values = [
      enums.EnumWithNameConflict.serializer_,
      enums.EnumWithNameConflict.wrapIf(true),
    ];
    for (final value in values) {
      expect(value.rebuild(), equals(value));
    }
  });
}
