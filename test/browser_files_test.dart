@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:trust_app/src/platform_files_web.dart';

void main() {
  test('IndexedDB persists binary documents and atomic replacements', () async {
    final file = File('/test/document');
    await file.writeAsBytes([0, 1, 128, 255]);
    expect(await File(file.path).readAsBytes(), [0, 1, 128, 255]);
    await File('/test/state').writeAsString('previous');
    await File('/test/state.tmp').writeAsString('updated');
    await File('/test/state.tmp').rename('/test/state');
    expect(await File('/test/state').readAsString(), 'updated');
    expect(await File('/test/state.tmp').exists(), isFalse);
  });
}
