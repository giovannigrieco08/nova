/// Tests for ImageCompressor utility class
///
/// Tests constants, file extension detection, and compression ratio calculation.
/// Note: Actual image compression requires platform plugin (FlutterImageCompress)
/// and cannot be unit tested directly.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/utils/image_compressor.dart';

void main() {
  group('ImageCompressor', () {
    // =========================================================================
    // CONSTANTS
    // =========================================================================

    group('constants', () {
      test('target dimensions are 3:4 aspect ratio (happy)', () {
        expect(ImageCompressor.targetWidth, equals(1080));
        expect(ImageCompressor.targetHeight, equals(1440));
        // Verify 3:4 ratio
        expect(
          ImageCompressor.targetWidth / ImageCompressor.targetHeight,
          closeTo(3.0 / 4.0, 0.001),
        );
      });

      test('max file size is 500KB (happy)', () {
        expect(ImageCompressor.maxFileSizeBytes, equals(500 * 1024));
      });

      test('quality settings are within valid range (happy)', () {
        expect(ImageCompressor.webpQuality, greaterThan(0));
        expect(ImageCompressor.webpQuality, lessThanOrEqualTo(100));
        expect(ImageCompressor.jpegQuality, greaterThan(0));
        expect(ImageCompressor.jpegQuality, lessThanOrEqualTo(100));
      });
    });

    // =========================================================================
    // getImageExtension - magic byte detection
    // =========================================================================

    group('getImageExtension', () {
      test('detects WebP format from magic bytes (happy)', () {
        // RIFF....WEBP
        final webpBytes = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size placeholder
          0x57, 0x45, 0x42, 0x50, // WEBP
          0x00, 0x00, // extra bytes
        ]);

        expect(ImageCompressor.getImageExtension(webpBytes), equals('webp'));
      });

      test('detects JPEG format from magic bytes (happy)', () {
        final jpegBytes = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, // JPEG SOI marker
          0xE0, 0x00, 0x10, // JFIF marker
        ]);

        expect(ImageCompressor.getImageExtension(jpegBytes), equals('jpg'));
      });

      test('returns jpg as default for unknown format (edge)', () {
        final unknownBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);

        expect(ImageCompressor.getImageExtension(unknownBytes), equals('jpg'));
      });

      test('handles very short byte arrays gracefully (edge)', () {
        final shortBytes = Uint8List.fromList([0x00]);

        expect(ImageCompressor.getImageExtension(shortBytes), equals('jpg'));
      });

      test('empty bytes return default jpg (edge)', () {
        final emptyBytes = Uint8List(0);

        expect(ImageCompressor.getImageExtension(emptyBytes), equals('jpg'));
      });
    });

    // =========================================================================
    // calculateCompressionRatio
    // =========================================================================

    group('calculateCompressionRatio', () {
      test('50% compression returns 50.0 (happy)', () {
        final ratio = ImageCompressor.calculateCompressionRatio(1000, 500);
        expect(ratio, closeTo(50.0, 0.01));
      });

      test('no compression returns 0.0 (edge)', () {
        final ratio = ImageCompressor.calculateCompressionRatio(1000, 1000);
        expect(ratio, closeTo(0.0, 0.01));
      });

      test('zero original size returns 0.0 (edge)', () {
        final ratio = ImageCompressor.calculateCompressionRatio(0, 500);
        expect(ratio, equals(0.0));
      });

      test('full compression returns 100.0 (edge)', () {
        final ratio = ImageCompressor.calculateCompressionRatio(1000, 0);
        expect(ratio, closeTo(100.0, 0.01));
      });
    });

    // =========================================================================
    // ImageCompressionException
    // =========================================================================

    group('ImageCompressionException', () {
      test('stores message and formats toString (happy)', () {
        final exception = ImageCompressionException('compression failed');

        expect(exception.message, equals('compression failed'));
        expect(exception.toString(),
            equals('ImageCompressionException: compression failed'));
      });

      test('implements Exception (edge)', () {
        expect(ImageCompressionException('test'), isA<Exception>());
      });
    });
  });
}
