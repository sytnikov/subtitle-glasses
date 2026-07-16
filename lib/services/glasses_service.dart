import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps the Meta Wearables DAT plugin: registration, camera permission,
/// and session-based photo capture into an in-memory stack.
class GlassesService extends ChangeNotifier with WidgetsBindingObserver {
  static const _permissionCacheKey = 'camera_permission_granted';

  RegistrationState registrationState = RegistrationState.unavailable;
  bool cameraPermissionGranted = false;
  StreamSessionState streamSessionState = StreamSessionState.stopped;

  final List<Uint8List> capturedImages = [];

  StreamSubscription<RegistrationState>? _registrationSub;
  StreamSubscription<StreamSessionState>? _streamStateSub;
  StreamSubscription<Object>? _streamErrorSub;

  final _streamErrorsController = StreamController<String>.broadcast();

  /// Human-readable notifications for streams that die mid-session
  /// (glasses folded, overheated, disconnected, ...).
  Stream<String> get streamErrors => _streamErrorsController.stream;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // The native permission check throws whenever the glasses aren't
    // actively connected, so a cold start with sleeping glasses can't
    // answer it. Start from the last known value instead.
    final prefs = await SharedPreferences.getInstance();
    cameraPermissionGranted = prefs.getBool(_permissionCacheKey) ?? false;

    // Subscribe to state streams before the first status read: if the read
    // throws, the app must still hear about later state changes.
    _registrationSub = MetaWearablesDat.registrationStateStream().listen((
      state,
    ) {
      registrationState = state;
      notifyListeners();
    });

    _streamStateSub = MetaWearablesDat.streamSessionStateStream().listen((
      state,
    ) {
      streamSessionState = state;
      notifyListeners();
    });

    _streamErrorSub = MetaWearablesDat.streamSessionErrorStream().listen((
      error,
    ) {
      _streamErrorsController.add(_describeStreamError(error));
    });

    await refreshStatus();
  }

  String _describeStreamError(Object error) {
    if (error is SessionError) {
      if (error.isHingesClosed) {
        return 'Stream stopped: the glasses were folded.';
      }
      if (error.isThermalCritical) {
        return 'Stream stopped: the glasses overheated. '
            'Let them cool down for a bit.';
      }
      if (error.isDeviceDisconnected) {
        return 'Stream stopped: the glasses disconnected.';
      }
      if (error.isPermissionDenied) {
        return 'Stream stopped: camera permission was revoked. '
            'Grant it again to continue.';
      }
      if (error.isTimeout) {
        return 'Stream stopped: the connection timed out.';
      }
      return 'Stream stopped: ${error.message}';
    }
    return 'Stream stopped unexpectedly.';
  }

  /// Re-reads registration and permission state from the plugin.
  ///
  /// Connecting and granting camera permission both round-trip through the
  /// Meta AI app, and the plugin's streams don't always re-emit when we
  /// come back — so this also runs on every app-foreground transition.
  ///
  /// Each read is best-effort: the native SDK throws for these calls when
  /// it can't answer (no device connected, SDK not settled yet), and a
  /// failed read must never overwrite a known-good value.
  Future<void> refreshStatus() async {
    try {
      registrationState = await MetaWearablesDat.getRegistrationState();
    } on Exception {
      // Keep the previous value; the registration stream will correct it.
    }
    try {
      final granted = await MetaWearablesDat.getCameraPermissionStatus();
      await _setCameraPermission(granted);
    } on Exception {
      // Unanswerable right now (glasses disconnected) — keep the last
      // known value rather than downgrading a real grant.
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshStatus();
    }
  }

  Future<void> connect() async {
    await MetaWearablesDat.requestAndroidPermissions();
    await MetaWearablesDat.startRegistration();
  }

  /// Unpairs the glasses so the full registration cycle can be re-tested.
  Future<void> unpair() async {
    await _stopStreamQuietly();
    capturedImages.clear();
    await MetaWearablesDat.startUnregistration();
    await _setCameraPermission(false);
    await refreshStatus();
  }

  Future<void> ensureCameraPermission() async {
    final granted = await MetaWearablesDat.requestCameraPermission();
    await _setCameraPermission(granted);
    notifyListeners();
  }

  Future<void> _setCameraPermission(bool granted) async {
    cameraPermissionGranted = granted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionCacheKey, granted);
  }

  bool get sessionActive =>
      streamSessionState == StreamSessionState.streaming ||
      streamSessionState == StreamSessionState.starting ||
      streamSessionState == StreamSessionState.waitingForDevice;

  /// True when a stream died mid-session with captures still in hand:
  /// offer resume / translate instead of a fresh start.
  bool get sessionInterrupted => !sessionActive && capturedImages.isNotEmpty;

  /// Starts a fresh session, discarding any previous captures.
  Future<void> startSession() async {
    capturedImages.clear();
    notifyListeners();
    await _startStream(retryOnExistingSession: true);
  }

  /// Restarts the stream while keeping already-captured frames — for when
  /// the SDK stopped the stream mid-session.
  Future<void> resumeSession() async {
    await _startStream(retryOnExistingSession: true);
  }

  Future<void> _startStream({required bool retryOnExistingSession}) async {
    // Always reset native state first. When the SDK stops a stream on its
    // own, the plugin keeps a dead texture id cached and would "start" by
    // returning it without creating a new session; a failed start can also
    // leak a half-created device session (sessionAlreadyExists on retry).
    await _stopStreamQuietly();
    try {
      await MetaWearablesDat.startStreamSession(
        fps: 15,
        quality: StreamQuality.low,
      );
    } on DatError catch (e) {
      await _stopStreamQuietly();
      final leftoverSession =
          e is DeviceSessionError && e.isSessionAlreadyExists;
      if (leftoverSession && retryOnExistingSession) {
        await _startStream(retryOnExistingSession: false);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _stopStreamQuietly() async {
    try {
      await MetaWearablesDat.stopStreamSession();
    } on Exception {
      // Cleanup is best-effort; nothing actionable if it fails.
    }
  }

  Future<void> capture() async {
    final result = await MetaWearablesDat.capturePhoto(
      format: PhotoFormat.jpeg,
    );
    capturedImages.add(result.bytes);
    notifyListeners();
  }

  Future<List<Uint8List>> stopSession() async {
    await _stopStreamQuietly();
    return List<Uint8List>.of(capturedImages);
  }

  /// Called after a successful translation: the captures have served their
  /// purpose, so the next visit to the watch screen offers a fresh start
  /// instead of "session interrupted". Kept on failure so the user can
  /// retry translating without recapturing.
  void clearCaptures() {
    capturedImages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _registrationSub?.cancel();
    _streamStateSub?.cancel();
    _streamErrorSub?.cancel();
    _streamErrorsController.close();
    super.dispose();
  }
}
