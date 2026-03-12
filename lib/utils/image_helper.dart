import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageHelper {
  /// Compress image and convert to Base64 string
  /// Returns null if compression fails
  static Future<String?> toBase64(File imageFile) async {
    try {
      // Compress to max 200x200, 60% quality — keeps it well under 1MB
      final compressed = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth:  200,
        minHeight: 200,
        quality:   60,
        format:    CompressFormat.jpeg,
      );
      if (compressed == null) return null;
      return base64Encode(compressed);
    } catch (e) {
      return null;
    }
  }

  /// Convert Base64 string back to bytes for display
  static Future<String> toDataUri(String base64String) async {
    return 'data:image/jpeg;base64,$base64String';
  }
}