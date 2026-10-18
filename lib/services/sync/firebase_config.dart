import 'package:firebase_core/firebase_core.dart';

/// Firebase is optional. The app is fully functional offline; cloud sync is
/// only offered when a Firebase project is provided at build time:
///
/// ```sh
/// flutter build apk \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=...
/// ```
///
/// Or with `--dart-define-from-file=firebase.json` (see `firebase.example.json`).
abstract final class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get isConfigured => _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions? get options => isConfigured
      ? const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        )
      : null;

  /// Returns true when Firebase is ready to use.
  static Future<bool> initialize() async {
    final options = FirebaseConfig.options;
    if (options == null) return false;
    try {
      await Firebase.initializeApp(options: options);
      return true;
    } catch (_) {
      return false;
    }
  }
}
