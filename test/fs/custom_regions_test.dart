import 'package:chico_flutter_devkit/src/fs/custom_regions.dart';
import 'package:test/test.dart';

void main() {
  test('merge preserves user custom region body', () {
    final previous =
        '''
class A {
${CustomRegions.stub('remote.map')}
}
'''
            .replaceFirst('// User customizations\n', '  // my custom line\n');

    final generated =
        '''
class A {
${CustomRegions.stub('remote.map')}
  void other() {}
}
''';

    final merged = CustomRegions.merge(
      generated: generated,
      previous: previous,
    );
    expect(merged, contains('my custom line'));
    expect(merged, contains('void other()'));
  });

  test('onlyCustomRegionsDiffer detects region-only edits', () {
    final base =
        '''
class A {
${CustomRegions.stub('remote.map')}
}
''';
    final edited = base.replaceFirst(
      '// User customizations\n',
      '  // edited\n',
    );
    expect(
      CustomRegions.onlyCustomRegionsDiffer(previous: edited, generated: base),
      isTrue,
    );
    expect(
      CustomRegions.onlyCustomRegionsDiffer(
        previous: '$edited\n// outside\n',
        generated: base,
      ),
      isFalse,
    );
  });
}
