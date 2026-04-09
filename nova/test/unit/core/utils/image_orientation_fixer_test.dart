/// Tests for ImageOrientationFixer utility class
///
/// Note: ImageOrientationFixer uses Platform.isIOS for conditional logic
/// and dart:io File operations. On non-iOS platforms (like test runner),
/// fixOrientation returns the original path and fixOrientationFromBytes
/// returns the original bytes. We test these code paths.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/utils/image_orientation_fixer.dart';

void main() {
  group('ImageOrientationFixer', () {
    // =========================================================================
    // HAPPY PATH - Non-iOS platform (test environment)
    // =========================================================================

    group('fixOrientation on non-iOS', () {
      test('returns original path on non-iOS platform (happy)', () async {
        const testPath = '/tmp/test_image.jpg';

        final result = await ImageOrientationFixer.fixOrientation(testPath);

        // On non-iOS (Windows/Linux test runner), returns original path
        expect(result, equals(testPath));
      });

      test('returns original path regardless of isFrontCamera flag (happy)', () async {
        const testPath = '/tmp/front_camera.jpg';

        final result = await ImageOrientationFixer.fixOrientation(
          testPath,
          isFrontCamera: true,
        );

        expect(result, equals(testPath));
      });
    });

    // =========================================================================
    // fixOrientationFromBytes on non-iOS
    // =========================================================================

    group('fixOrientationFromBytes on non-iOS', () {
      test('returns original bytes on non-iOS platform (edge)', () async {
        final testBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

        final result =
            await ImageOrientationFixer.fixOrientationFromBytes(testBytes);

        expect(result, equals(testBytes));
      });

      test('handles empty bytes on non-iOS (edge)', () async {
        final emptyBytes = Uint8List(0);

        final result =
            await ImageOrientationFixer.fixOrientationFromBytes(emptyBytes);

        expect(result, equals(emptyBytes));
      });
    });
  });
}
