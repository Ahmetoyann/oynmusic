import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muzik_app/providers/song_provider.dart';

void main() {
  test('device artwork bytes are saved as a real local image file', () async {
    final imageBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    final savedPath = await SongProvider.saveArtworkBytesToLocalFile(
      'device-42',
      imageBytes,
    );

    expect(savedPath, isNotNull);
    expect(File(savedPath!).existsSync(), isTrue);
    expect(File(savedPath).readAsBytesSync(), equals(imageBytes));

    await File(savedPath).delete();
  });
}
