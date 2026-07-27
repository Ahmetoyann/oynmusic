import 'package:flutter_test/flutter_test.dart';
import 'package:audio_session/audio_session.dart';

void main() {
  test('check audio session', () async {
    expect(AudioDeviceType.bluetoothA2dp, isNotNull);
  });
}
