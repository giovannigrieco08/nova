// Core Utility: ImageOrientationFixer
// Purpose: Fix image orientation issues on iOS cameras
//
// On iOS, camera captures can have incorrect orientation due to:
// 1. EXIF orientation data not being applied when displaying
// 2. Sensor orientation not matching device orientation
//
// This utility reads the image, applies EXIF orientation, and saves
// a correctly oriented image.

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Utility to fix image orientation issues, especially on iOS
class ImageOrientationFixer {
  // Prevent instantiation - static utility class
  ImageOrientationFixer._();

  /// Fix image orientation by applying EXIF data and re-encoding
  ///
  /// This is necessary on iOS where:
  /// - Camera captures may have EXIF orientation that isn't applied when displaying
  /// - Front camera images may need horizontal flipping
  ///
  /// [imagePath] - Path to the original image file
  /// [isFrontCamera] - Whether the image was taken with front camera (for potential mirroring fix)
  ///
  /// Returns the path to the fixed image file
  static Future<String> fixOrientation(
    String imagePath, {
    bool isFrontCamera = false,
  }) async {
    // Only process on iOS - Android handles orientation correctly
    if (!Platform.isIOS) {
      return imagePath;
    }

    try {
      // Read the image file
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      // Decode the image (this reads EXIF data)
      final image = img.decodeImage(bytes);
      if (image == null) {
        return imagePath; // Can't decode, return original
      }

      // Apply EXIF orientation (bakes orientation into pixel data)
      // This handles rotation and mirroring based on EXIF orientation tag
      var fixedImage = img.bakeOrientation(image);

      // On iOS, images from the camera plugin appear mirrored.
      // We flip horizontally to correct this for both front and rear cameras.
      fixedImage = img.flipHorizontal(fixedImage);

      // Encode the fixed image as JPEG
      final fixedBytes = img.encodeJpg(fixedImage, quality: 95);

      // Save to a new temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fixedPath = '${tempDir.path}/fixed_$timestamp.jpg';
      final fixedFile = File(fixedPath);
      await fixedFile.writeAsBytes(fixedBytes);

      // Delete the original temp file to save space
      try {
        await file.delete();
      } catch (_) {
        // Ignore deletion errors
      }

      return fixedPath;
    } catch (e) {
      // On any error, return original path
      return imagePath;
    }
  }

  /// Fix orientation from bytes directly (useful when file is already loaded)
  ///
  /// Returns fixed image bytes
  static Future<Uint8List?> fixOrientationFromBytes(Uint8List bytes) async {
    // Only process on iOS
    if (!Platform.isIOS) {
      return bytes;
    }

    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      final fixedImage = img.bakeOrientation(image);
      return Uint8List.fromList(img.encodeJpg(fixedImage, quality: 95));
    } catch (e) {
      return bytes;
    }
  }
}
