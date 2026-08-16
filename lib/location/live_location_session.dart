import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_message_data.dart';

class ChattaXLiveLocationSession {
  final String sessionId;
  final String ownerId;

  final double latitude;
  final double longitude;

  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime lastUpdatedAt;

  final ChattaXLiveLocationDuration duration;

  final bool isActive;

  const ChattaXLiveLocationSession({
    required this.sessionId,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.startedAt,
    required this.expiresAt,
    required this.lastUpdatedAt,
    required this.duration,
    required this.isActive,
  });

  /// Creates a live-location session from Firestore.
  factory ChattaXLiveLocationSession.fromMap(
    Map<String, dynamic> map,
  ) {
    return ChattaXLiveLocationSession(
      sessionId:
          map['sessionId']?.toString() ?? '',
      ownerId:
          map['ownerId']?.toString() ?? '',
      latitude:
          _readDouble(map['latitude']),
      longitude:
          _readDouble(map['longitude']),
      startedAt:
          _readDateTime(map['startedAt']) ??
          DateTime.now(),
      expiresAt:
          _readDateTime(map['expiresAt']) ??
          DateTime.now(),
      lastUpdatedAt:
          _readDateTime(map['lastUpdatedAt']) ??
          DateTime.now(),
      duration:
          _readDuration(map['duration']),
      isActive:
          map['isActive'] == true,
    );
  }

  /// Converts the session into Firestore data.
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'ownerId': ownerId,
      'latitude': latitude,
      'longitude': longitude,
      'startedAt': Timestamp.fromDate(
        startedAt,
      ),
      'expiresAt': Timestamp.fromDate(
        expiresAt,
      ),
      'lastUpdatedAt': Timestamp.fromDate(
        lastUpdatedAt,
      ),
      'duration': duration.name,
      'isActive': isActive,
    };
  }

  /// Returns a copy with changed values.
  ChattaXLiveLocationSession copyWith({
    String? sessionId,
    String? ownerId,
    double? latitude,
    double? longitude,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? lastUpdatedAt,
    ChattaXLiveLocationDuration? duration,
    bool? isActive,
  }) {
    return ChattaXLiveLocationSession(
      sessionId:
          sessionId ?? this.sessionId,
      ownerId:
          ownerId ?? this.ownerId,
      latitude:
          latitude ?? this.latitude,
      longitude:
          longitude ?? this.longitude,
      startedAt:
          startedAt ?? this.startedAt,
      expiresAt:
          expiresAt ?? this.expiresAt,
      lastUpdatedAt:
          lastUpdatedAt ?? this.lastUpdatedAt,
      duration:
          duration ?? this.duration,
      isActive:
          isActive ?? this.isActive,
    );
  }

  /// Whether this session has expired.
  bool get isExpired {
    return DateTime.now().isAfter(
      expiresAt,
    );
  }

  /// Remaining time for the live location.
  Duration get remainingDuration {
    final remaining =
        expiresAt.difference(
      DateTime.now(),
    );

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  /// User-friendly remaining time.
  String get remainingLabel {
    final remaining =
        remainingDuration;

    if (remaining == Duration.zero) {
      return 'Expired';
    }

    final hours =
        remaining.inHours;

    final minutes =
        remaining.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    }

    if (minutes > 0) {
      return '${minutes}m remaining';
    }

    return 'Less than 1m remaining';
  }

  static double _readDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  static DateTime? _readDateTime(
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

  static ChattaXLiveLocationDuration
      _readDuration(
    dynamic value,
  ) {
    switch (value) {
      case 'fifteenMinutes':
        return ChattaXLiveLocationDuration
            .fifteenMinutes;

      case 'oneHour':
        return ChattaXLiveLocationDuration
            .oneHour;

      case 'eightHours':
        return ChattaXLiveLocationDuration
            .eightHours;

      case 'thirtyDays':
        return ChattaXLiveLocationDuration
            .thirtyDays;

      default:
        return ChattaXLiveLocationDuration
            .fifteenMinutes;
    }
  }
}


// ============================================================
// LIVE LOCATION MANAGER
// ============================================================

class ChattaXLiveLocationManager {
  ChattaXLiveLocationManager({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ??
                FirebaseFirestore.instance,
        _auth =
            auth ??
                FirebaseAuth.instance;

  final FirebaseFirestore _firestore;

  final FirebaseAuth _auth;

  // ============================================================
  // COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      get _collection {
    return _firestore.collection(
      'live_location_sessions',
    );
  }

  // ============================================================
  // CREATE SESSION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      createSession({
    required double latitude,
    required double longitude,
    required ChattaXLiveLocationDuration
        duration,
  }) async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        return null;
      }

      final now =
          DateTime.now();

      final expiresAt =
          now.add(duration.duration);

      final document =
          _collection.doc();

      final session =
          ChattaXLiveLocationSession(
        sessionId:
            document.id,
        ownerId:
            user.uid,
        latitude:
            latitude,
        longitude:
            longitude,
        startedAt:
            now,
        expiresAt:
            expiresAt,
        lastUpdatedAt:
            now,
        duration:
            duration,
        isActive:
            true,
      );

      await document.set(
        session.toMap(),
      );

      return session;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // UPDATE LOCATION
  // ============================================================

  Future<bool> updateLocation({
    required String sessionId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        return false;
      }

      final document =
          await _collection
              .doc(sessionId)
              .get();

      if (!document.exists) {
        return false;
      }

      final data =
          document.data();

      if (data == null) {
        return false;
      }

      final ownerId =
          data['ownerId']?.toString();

      if (ownerId != user.uid) {
        return false;
      }

      final isActive =
          data['isActive'] == true;

      if (!isActive) {
        return false;
      }

      final expiresAt =
          _readDateTime(
        data['expiresAt'],
      );

      if (expiresAt == null) {
        return false;
      }

      if (DateTime.now()
          .isAfter(expiresAt)) {
        await stopSession(
          sessionId,
        );

        return false;
      }

      await _collection
          .doc(sessionId)
          .update({
        'latitude':
            latitude,
        'longitude':
            longitude,
        'lastUpdatedAt':
            FieldValue.serverTimestamp(),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // STOP SESSION
  // ============================================================

  Future<bool> stopSession(
    String sessionId,
  ) async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        return false;
      }

      final document =
          await _collection
              .doc(sessionId)
              .get();

      if (!document.exists) {
        return false;
      }

      final data =
          document.data();

      if (data == null) {
        return false;
      }

      final ownerId =
          data['ownerId']?.toString();

      if (ownerId != user.uid) {
        return false;
      }

      await _collection
          .doc(sessionId)
          .update({
        'isActive': false,
        'lastUpdatedAt':
            FieldValue.serverTimestamp(),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // GET SESSION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      getSession(
    String sessionId,
  ) async {
    try {
      final document =
          await _collection
              .doc(sessionId)
              .get();

      if (!document.exists) {
        return null;
      }

      final data =
          document.data();

      if (data == null) {
        return null;
      }

      return ChattaXLiveLocationSession
          .fromMap(data);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // WATCH SESSION
  // ============================================================

  Stream<ChattaXLiveLocationSession?>
      watchSession(
    String sessionId,
  ) {
    return _collection
        .doc(sessionId)
        .snapshots()
        .map(
      (snapshot) {
        if (!snapshot.exists) {
          return null;
        }

        final data =
            snapshot.data();

        if (data == null) {
          return null;
        }

        return ChattaXLiveLocationSession
            .fromMap(data);
      },
    );
  }

  // ============================================================
  // GET USER'S ACTIVE SESSION
  // ============================================================

  Future<ChattaXLiveLocationSession?>
      getMyActiveSession() async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        return null;
      }

      final query =
          await _collection
              .where(
                'ownerId',
                isEqualTo: user.uid,
              )
              .where(
                'isActive',
                isEqualTo: true,
              )
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        return null;
      }

      return ChattaXLiveLocationSession
          .fromMap(
        query.docs.first.data(),
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // STOP MY ACTIVE SESSION
  // ============================================================

  Future<bool> stopMyActiveSession() async {
    final session =
        await getMyActiveSession();

    if (session == null) {
      return false;
    }

    return stopSession(
      session.sessionId,
    );
  }

  // ============================================================
  // CLEAN UP
  // ============================================================

  Future<void> dispose() async {}
  
  static DateTime? _readDateTime(
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
}