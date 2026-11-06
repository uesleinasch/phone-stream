import 'package:flutter_test/flutter_test.dart';
import 'package:phone_stream_gui/phone_stream.dart';

void main() {
  group('StreamOptions.toArgs', () {
    test('monta qualidade, proporção e serial', () {
      const options = StreamOptions(serial: 'ABC', quality: Quality.q720, fit: Fit.crop, fullscreen: false);
      expect(options.toArgs(), ['--serial', 'ABC', '--quality', '720', '--fit', 'crop']);
    });

    test('inclui o app só no modo virtual', () {
      const virtual = StreamOptions(
        serial: 'ABC',
        quality: Quality.q1080,
        fit: Fit.virtual,
        fullscreen: true,
        app: 'com.google.android.youtube',
      );
      expect(virtual.toArgs(), containsAllInOrder(['--app', 'com.google.android.youtube', '--fullscreen']));

      const crop = StreamOptions(
        serial: 'ABC',
        quality: Quality.max,
        fit: Fit.crop,
        fullscreen: false,
        app: 'com.google.android.youtube',
      );
      expect(crop.toArgs(), isNot(contains('--app')));
    });
  });

  test('PhoneStream.clean remove cores ANSI', () {
    expect(PhoneStream.clean('\x1B[36m→ Transmitindo\x1B[0m  '), '→ Transmitindo');
  });
}
