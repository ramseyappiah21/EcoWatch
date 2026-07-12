import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Platform-aware photo and video capture for incident evidence.
class MediaCaptureService {
  MediaCaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  bool get supportsLiveCamera =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<XFile?> pickPhoto({required bool useCamera}) async {
    final source = useCamera && supportsLiveCamera
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 70,
      );
    } on StateError {
      return _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 70,
      );
    }
  }

  Future<XFile?> pickVideo({required bool useCamera}) async {
    final source = useCamera && supportsLiveCamera
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      return await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
    } on StateError {
      return _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
    }
  }
}
