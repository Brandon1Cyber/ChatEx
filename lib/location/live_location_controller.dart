import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import 'live_location_session.dart';
import 'location_message_data.dart';

class ChattaXLiveLocationController {
  ChattaXLiveLocationController({
    LocationService? locationService,
    ChattaXLiveLocationManager? liveLocationManager,
  })  : _locationService =
            locationService ?? LocationService(),
        _liveLocationManager =
            liveLocationManager ??
                ChattaXLiveLocationManager();

  final LocationService _locationService;

  final ChattaXLiveLocationManager
      _liveLocationManager;

  // ============================================================
  // STATE
  // ============================================================

  ChattaXLiveLocationSession? _session;

  bool _isStarting = false;

  bool _isSharing = false;

  // ============================================================
  // GETTERS
  // ============================================================

  ChattaXLiveLocationSession? get session {
    return _session;
  }

  bool get isStarting {
    return _isStarting;
  }

  bool get isSharing {
    return _isSharing;
  }

  bool get hasActiveSession {
    return _session != null &&
        _session!.isActive &&
        !_session!.isExpired;
  }

  // ============================================================
  // START LIVE LOCATION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      startLiveLocation({
    required ChattaXLiveLocationDuration
        duration,
  }) async {
    if (_isStarting) {
      return null;
    }

    if (_isSharing &&
        hasActiveSession) {
      return _session;
    }

    _isStarting = true;

    try {
      // ========================================================
      // CHECK LOCATION PERMISSION
      // ========================================================

      final permission =
          await _locationService
              .requestPermission();

      if (!permission) {
        return null;
      }

      // ========================================================
      // GET CURRENT GPS LOCATION
      // ========================================================

      Position? position =
          await _locationService
              .getBestAvailableLocation();

      // ========================================================
      // IF LAST KNOWN LOCATION WASN'T AVAILABLE,
      // GET A FRESH GPS LOCATION.
      // ========================================================

      position ??=
          await _locationService
              .getCurrentLocation();

      if (position == null) {
        return null;
      }

      // ========================================================
      // CREATE FIREBASE LIVE LOCATION SESSION
      // ========================================================

      final createdSession =
          await _liveLocationManager
              .createSession(
        latitude:
            position.latitude,
        longitude:
            position.longitude,
        duration:
            duration,
      );

      if (createdSession == null) {
        return null;
      }

      // ========================================================
      // SAVE SESSION LOCALLY
      // ========================================================

      _session =
          createdSession;

      _isSharing = true;

      // ========================================================
      // START GPS TRACKING
      // ========================================================
      //
      // We use the existing LocationService.
      //
      // The tracking itself does NOT automatically expose
      // the location to everyone.
      //
      // The controller below will decide when the session
      // should update Firebase.
      //

      await _locationService
          .startTracking(
        distanceFilter: 5,
        accuracy:
            LocationAccuracy.high,
      );

      return createdSession;
    } finally {
      _isStarting = false;
    }
  }

  // ============================================================
  // UPDATE LIVE LOCATION
  // ============================================================
  //
  // Call this when a new GPS position is received.
  //
  // It updates only the active ChattªX live-location session.
  //

  Future<bool> updateLiveLocation(
    Position position,
  ) async {
    final currentSession =
        _session;

    if (currentSession == null) {
      return false;
    }

    if (!currentSession.isActive) {
      return false;
    }

    if (currentSession.isExpired) {
      await stopLiveLocation();

      return false;
    }

    final updated =
        await _liveLocationManager
            .updateLocation(
      sessionId:
          currentSession.sessionId,
      latitude:
          position.latitude,
      longitude:
          position.longitude,
    );

    if (updated) {
      _session =
          currentSession.copyWith(
        latitude:
            position.latitude,
        longitude:
            position.longitude,
        lastUpdatedAt:
            DateTime.now(),
      );
    }

    return updated;
  }

  // ============================================================
  // UPDATE USING LAST GPS POSITION
  // ============================================================

  Future<bool> updateFromCurrentPosition()
      async {
    final position =
        _locationService.lastPosition;

    if (position == null) {
      return false;
    }

    return updateLiveLocation(
      position,
    );
  }

  // ============================================================
  // STOP LIVE LOCATION
  // ============================================================

  Future<bool> stopLiveLocation() async {
    final currentSession =
        _session;

    if (currentSession == null) {
      _isSharing = false;

      await _locationService
          .stopTracking();

      return true;
    }

    final stopped =
        await _liveLocationManager
            .stopSession(
      currentSession.sessionId,
    );

    await _locationService
        .stopTracking();

    if (stopped) {
      _session =
          currentSession.copyWith(
        isActive: false,
        lastUpdatedAt:
            DateTime.now(),
      );
    }

    _isSharing = false;

    return stopped;
  }

  // ============================================================
  // LOAD EXISTING ACTIVE SESSION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      loadExistingSession() async {
    final existing =
        await _liveLocationManager
            .getMyActiveSession();

    if (existing == null) {
      _session = null;
      _isSharing = false;

      return null;
    }

    if (existing.isExpired) {
      await _liveLocationManager
          .stopSession(
        existing.sessionId,
      );

      _session = null;
      _isSharing = false;

      return null;
    }

    _session = existing;

    _isSharing = true;

    return existing;
  }

  // ============================================================
  // REFRESH SESSION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      refreshSession() async {
    final currentSession =
        _session;

    if (currentSession == null) {
      return null;
    }

    final refreshed =
        await _liveLocationManager
            .getSession(
      currentSession.sessionId,
    );

    if (refreshed == null) {
      _session = null;
      _isSharing = false;

      return null;
    }

    if (refreshed.isExpired) {
      await stopLiveLocation();

      return null;
    }

    _session = refreshed;

    _isSharing =
        refreshed.isActive;

    return refreshed;
  }

  // ============================================================
  // LOCATION STREAM
  // ============================================================
  //
  // This is available for the ChatScreen or another controller
  // when we wire continuous updates.
  //

  Stream<Position> get positionStream {
    return _locationService
        .positionStream;
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Position? get currentPosition {
    return _locationService
        .lastPosition;
  }

  // ============================================================
  // REMAINING TIME
  // ============================================================

  Duration? get remainingDuration {
    final currentSession =
        _session;

    if (currentSession == null) {
      return null;
    }

    return currentSession
        .remainingDuration;
  }

  // ============================================================
  // REMAINING TIME LABEL
  // ============================================================

  String get remainingLabel {
    final currentSession =
        _session;

    if (currentSession == null) {
      return '';
    }

    return currentSession
        .remainingLabel;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _locationService
        .stopTracking();

    _session = null;

    _isSharing = false;
    _isStarting = false;
  }
}