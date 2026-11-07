import 'dart:io';

import 'package:path/path.dart' as p;

/// The fixtures folder.
final String fixtures = p.join(Directory.current.path, 'test', 'fixtures');

/// Copies the fixture project [name] into a fresh temp folder and returns it.
String copyFixture(String name) {
  final dest = Directory.systemTemp.createTempSync('transly_${name}_').path;
  _copy(Directory(p.join(fixtures, name)), Directory(dest));
  return dest;
}

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final target = p.join(to.path, p.basename(e.path));
    if (e is Directory) {
      _copy(e, Directory(target));
    } else if (e is File) {
      e.copySync(target);
    }
  }
}

/// Reads a file under [root].
String read(String root, String rel) => File(p.join(root, rel)).readAsStringSync();

/// Writes a file under [root].
void write(String root, String rel, String content) {
  final f = File(p.join(root, rel));
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}
