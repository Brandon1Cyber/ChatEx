import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // LOCATION STREAM
  // ============================================================

  StreamSubscription<Position>? _positionSubscription;

  Position? _lastPosition;

  bool _isTracking = false;

  // ============================================================
  // GETTERS
  // ============================================================

  Position? get lastPosition => _lastPosition;

  bool get isTracking => _isTracking;

  bool get hasLocation => _lastPosition != null;

  double? get latitude => _lastPosition?.latitude;

  double? get longitude => _lastPosition?.longitude;

  double? get accuracy => _lastPosition?.accuracy;

  double? get altitude => _lastPosition?.altitude;

  double? get speed => _lastPosition?.speed;

  double? get heading => _lastPosition?.heading;

  // ============================================================
  // REQUEST PERMISSION
  // ============================================================

  Future<bool> requestPermission() async {
    try {
      // --------------------------------------------------------
      // CHECK GPS SERVICE
      // --------------------------------------------------------

      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return false;
      }

      // --------------------------------------------------------
      // CHECK PERMISSION
      // --------------------------------------------------------

      LocationPermission permission =
          await Geolocator.checkPermission();

      // --------------------------------------------------------
      // REQUEST PERMISSION
      // --------------------------------------------------------

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      // --------------------------------------------------------
      // DENIED
      // --------------------------------------------------------

      if (permission == LocationPermission.denied) {
        return false;
      }

      // --------------------------------------------------------
      // PERMANENTLY DENIED
      // --------------------------------------------------------

      if (permission ==
          LocationPermission.deniedForever) {
        return false;
      }

      // --------------------------------------------------------
      // ALLOWED
      // --------------------------------------------------------

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CHECK LOCATION SERVICE
  // ============================================================

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CHECK PERMISSION
  // ============================================================

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      return LocationPermission.denied;
    }
  }

  // ============================================================
  // OPEN LOCATION SETTINGS
  // ============================================================

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // OPEN APP SETTINGS
  // ============================================================

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET CURRENT LOCATION
  // ============================================================

  Future<Position?> getCurrentLocation() async {
    try {
      final allowed = await requestPermission();

      if (!allowed) {
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      _lastPosition = position;

      return position;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET LAST KNOWN LOCATION
  // ============================================================

  Future<Position?> getLastKnownLocation() async {
    try {
      final position =
          await Geolocator.getLastKnownPosition();

      if (position != null) {
        _lastPosition = position;
      }

      return position;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET BEST AVAILABLE LOCATION
  // ============================================================
  //
  // First tries the last known location because it is much
  // faster. If unavailable, it gets a fresh GPS location.
  //

  Future<Position?> getBestAvailableLocation() async {
    try {
      final lastKnown =
          await getLastKnownLocation();

      if (lastKnown != null) {
        return lastKnown;
      }

      return await getCurrentLocation();
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // SAVE CURRENT LOCATION TO FIREBASE
  // ============================================================

  Future<bool> saveLocation() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      final position =
          await getCurrentLocation();

      if (position == null) {
        return false;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // SAVE A POSITION TO FIREBASE
  // ============================================================

  Future<bool> savePosition(
    Position position,
  ) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      _lastPosition = position;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // START LIVE LOCATION TRACKING
  // ============================================================
  //
  // This watches the user's GPS location.
  //
  // It does NOT automatically publish the user's location
  // to everyone. That is important.
  //
  // We can later use this for:
  //
  // - Live location sharing
  // - ChattªX Maps
  // - Directions
  // - Nearby
  //
  // without exposing the user's location unless required.
  //

  Future<bool> startTracking({
    int distanceFilter = 5,
    LocationAccuracy accuracy =
        LocationAccuracy.high,
  }) async {
    try {
      final allowed = await requestPermission();

      if (!allowed) {
        return false;
      }

      // Stop an existing listener first.
      await stopTracking();

      final locationSettings =
          LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
        },
        onError: (error) {
          // Keep the service alive if the stream reports
          // an error.
        },
      );

      _isTracking = true;

      return true;
    } catch (e) {
      _isTracking = false;

      return false;
    }
  }

  // ============================================================
  // START FIREBASE LOCATION TRACKING
  // ============================================================
  //
  // This version updates the authenticated user's Firestore
  // profile whenever their location changes.
  //
  // Use this only when the feature actually requires location
  // sharing. Do NOT call it simply when opening the app.
  //

  Future<bool> startFirebaseTracking({
    int distanceFilter = 10,
    LocationAccuracy accuracy =
        LocationAccuracy.high,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      final allowed = await requestPermission();

      if (!allowed) {
        return false;
      }

      await stopTracking();

      final locationSettings =
          LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          _lastPosition = position;

          try {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .set({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'altitude': position.altitude,
              'speed': position.speed,
              'heading': position.heading,
              'locationUpdatedAt':
                  FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {
            // Ignore individual Firebase update errors.
          }
        },
        onError: (error) {
          // Keep tracking state controlled by stopTracking().
        },
      );

      _isTracking = true;

      return true;
    } catch (e) {
      _isTracking = false;

      return false;
    }
  }

  // ============================================================
  // STOP TRACKING
  // ============================================================

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    _isTracking = false;
  }

  // ============================================================
  // POSITION STREAM
  // ============================================================
  //
  // Useful for ChattªX Maps when the screen itself wants to
  // listen for location changes.
  //

  Stream<Position> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    );
  }

  // ============================================================
  // GET USER LOCATION FROM FIREBASE
  // ============================================================
  //
  // Used for displaying another ChattªX user's last known
  // location on the map.
  //

  Future<Position?> getUserLocation(
    String uid,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      final latitude =
          _toDouble(data['latitude']);

      final longitude =
          _toDouble(data['longitude']);

      if (latitude == null ||
          longitude == null) {
        return null;
      }

      return Position(
  longitude: longitude,
  latitude: latitude,
  timestamp: _timestampToDateTime(
    data['locationUpdatedAt'],
  ) ?? DateTime.now(),
  accuracy: _toDouble(
        data['accuracy'],
      ) ??
      0,
  altitude: _toDouble(
        data['altitude'],
      ) ??
      0,
  altitudeAccuracy: 0,
  heading: _toDouble(
        data['heading'],
      ) ??
      0,
  headingAccuracy: 0,
  speed: _toDouble(
        data['speed'],
      ) ??
      0,
  speedAccuracy: 0,
);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET MULTIPLE USERS' LOCATIONS
  // ============================================================

  Future<Map<String, Position>>
      getUsersLocations(
    List<String> userIds,
  ) async {
    final Map<String, Position> locations = {};

    for (final uid in userIds) {
      final position =
          await getUserLocation(uid);

      if (position != null) {
        locations[uid] = position;
      }
    }

    return locations;
  }

  // ============================================================
  // DISTANCE BETWEEN LOCATIONS
  // ============================================================

  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ============================================================
  // BEARING BETWEEN LOCATIONS
  // ============================================================

  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ============================================================
  // FORMAT DISTANCE
  // ============================================================

  String formatDistance(
    double meters,
  ) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    final kilometers =
        meters / 1000;

    if (kilometers < 10) {
      return '${kilometers.toStringAsFixed(1)} km';
    }

    return '${kilometers.round()} km';
  }

  // ============================================================
  // FORMAT CURRENT DISTANCE
  // ============================================================

  String formatDistanceFromCurrent(
    double latitude,
    double longitude,
  ) {
    final current =
        _lastPosition;

    if (current == null) {
      return 'Distance unavailable';
    }

    final meters =
        distanceBetween(
      current.latitude,
      current.longitude,
      latitude,
      longitude,
    );

    return formatDistance(meters);
  }

  // ============================================================
  // CHECK WHETHER LOCATION IS WITHIN RADIUS
  // ============================================================

  bool isWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    final current =
        _lastPosition;

    if (current == null) {
      return false;
    }

    final distance =
        Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      latitude,
      longitude,
    );

    return distance <= radiusMeters;
  }

  // ============================================================
  // CREATE LOCATION DATA
  // ============================================================

  Map<String, dynamic> positionToMap(
    Position position,
  ) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp':
          position.timestamp?.toIso8601String(),
    };
  }

  // ============================================================
  // CURRENT LOCATION DATA
  // ============================================================

  Map<String, dynamic>? get currentLocationData {
    final position =
        _lastPosition;

    if (position == null) {
      return null;
    }

    return positionToMap(position);
  }

  // ============================================================
  // CLEAR LAST POSITION
  // ============================================================

  void clearLastPosition() {
    _lastPosition = null;
  }

  // ============================================================
  // CONVERT FIREBASE VALUE TO DOUBLE
  // ============================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // CONVERT FIREBASE TIMESTAMP
  // ============================================================

  DateTime? _timestampToDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await stopTracking();

    _lastPosition = null;
  }
}