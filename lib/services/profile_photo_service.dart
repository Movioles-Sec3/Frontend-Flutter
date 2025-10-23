import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Keeps profile photo bytes alive while the app is running.
class ProfilePhotoService extends ChangeNotifier {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  Uint8List? _photoBytes;

  Uint8List? get photoBytes => _photoBytes;

  void update(Uint8List? bytes) {
    _photoBytes = bytes;
    notifyListeners();
  }

  void clear() {
    if (_photoBytes == null) return;
    _photoBytes = null;
    notifyListeners();
  }
}
