import 'dart:io';

/// Run from the project root. Produces the static site in build/web.
Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this command from the trust_app project root.');
    exitCode = 1;
    return;
  }
  final adminAsset = File('assets/demo_admin.json');
  final temporaryAsset = !adminAsset.existsSync();
  if (temporaryAsset) {
    await adminAsset.parent.create(recursive: true);
    await adminAsset.writeAsString('{}');
  }
  try {
    final build = await Process.start(
      'flutter',
      ['build', 'web', '--release', '--no-web-resources-cdn'],
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await build.exitCode;
  } finally {
    // The native administrator seed must never be distributed with the website.
    final publishedAdmin = File('build/web/assets/assets/demo_admin.json');
    if (await publishedAdmin.exists()) await publishedAdmin.delete();
    if (temporaryAsset && await adminAsset.exists()) await adminAsset.delete();
  }
}
