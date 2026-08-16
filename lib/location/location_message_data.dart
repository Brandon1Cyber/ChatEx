import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================
/// CHATTªX LOCATION MESSAGE DATA
/// ============================================================
///
/// Stores location information used inside ChattªX messages.
///
/// Supports:
/// • Normal/current location
/// • Live location
/// • Live-location session tracking
/// • Live-location expiration
/// • Last GPS update time
///
/// A normal location message does NOT require a session ID.
///
/// A live-location message uses [liveLocationSessionId] to
/// connect the chat message to the Firestore document inside:
///
/// live_location_sessions/{sessionId}
///
class ChattaXLocationMessageData {
  // ============================================================
  // BASIC LOCATION
  // ============================================================

  final double latitude;

  final double longitude;

  /// Optional name or address of the location.
  final String? locationName;

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  /// True when this message represents a live location.
  final bool isLiveLocation;

  /// UID of the user sharing the live location.
  final String? locationOwnerId;

  /// Firestore ID of the live-location session.
  ///
  /// This connects the chat message to:
  ///
  /// live_location_sessions/{sessionId}
  ///
  /// The receiver can use this ID to watch the sender's
  /// coordinates update in real time.
  final String? liveLocationSessionId;

  /// Time when the live location expires.
  final DateTime? liveLocationExpiresAt;

  /// Last time the location was updated.
  final DateTime? locationUpdatedAt;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const ChattaXLocationMessageData({
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.isLiveLocation = false,
    this.locationOwnerId,
    this.liveLocationSessionId,
    this.liveLocationExpiresAt,
    this.locationUpdatedAt,
  });

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  /// Creates location data from Firestore.
  factory ChattaXLocationMessageData.fromMap(
    Map<String, dynamic> map,
  ) {
    return ChattaXLocationMessageData(
      latitude:
          _readDouble(
        map['latitude'],
      ),

      longitude:
          _readDouble(
        map['longitude'],
      ),

      locationName:
          map['locationName']
              ?.toString(),

      isLiveLocation:
          map['isLiveLocation'] == true,

      locationOwnerId:
          map['locationOwnerId']
              ?.toString(),

      liveLocationSessionId:
          map['liveLocationSessionId']
              ?.toString(),

      liveLocationExpiresAt:
          _readDateTime(
        map['liveLocationExpiresAt'],
      ),

      locationUpdatedAt:
          _readDateTime(
        map['locationUpdatedAt'],
      ),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  /// Converts the location data to Firestore data.
  Map<String, dynamic> toMap() {
    return {
      'latitude':
          latitude,

      'longitude':
          longitude,

      'locationName':
          locationName,

      'isLiveLocation':
          isLiveLocation,

      'locationOwnerId':
          locationOwnerId,

      'liveLocationSessionId':
          liveLocationSessionId,

      'liveLocationExpiresAt':
          liveLocationExpiresAt == null
              ? null
              : Timestamp.fromDate(
                  liveLocationExpiresAt!,
                ),

      'locationUpdatedAt':
          locationUpdatedAt == null
              ? null
              : Timestamp.fromDate(
                  locationUpdatedAt!,
                ),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  /// Creates a copy with selected values changed.
  ChattaXLocationMessageData copyWith({
    double? latitude,
    double? longitude,
    String? locationName,
    bool? isLiveLocation,
    String? locationOwnerId,
    String? liveLocationSessionId,
    DateTime? liveLocationExpiresAt,
    DateTime? locationUpdatedAt,
  }) {
    return ChattaXLocationMessageData(
      latitude:
          latitude ??
          this.latitude,

      longitude:
          longitude ??
          this.longitude,

      locationName:
          locationName ??
          this.locationName,

      isLiveLocation:
          isLiveLocation ??
          this.isLiveLocation,

      locationOwnerId:
          locationOwnerId ??
          this.locationOwnerId,

      liveLocationSessionId:
          liveLocationSessionId ??
          this.liveLocationSessionId,

      liveLocationExpiresAt:
          liveLocationExpiresAt ??
          this.liveLocationExpiresAt,

      locationUpdatedAt:
          locationUpdatedAt ??
          this.locationUpdatedAt,
    );
  }

  // ============================================================
  // ACTIVE
  // ============================================================

  /// Returns true if the live location is currently active.
  ///
  /// Normal location messages always return false.
  bool get isActive {
    if (!isLiveLocation) {
      return false;
    }

    if (liveLocationExpiresAt == null) {
      return false;
    }

    return DateTime.now().isBefore(
      liveLocationExpiresAt!,
    );
  }

  // ============================================================
  // EXPIRED
  // ============================================================

  /// Returns true if the live location has expired.
  ///
  /// Normal location messages always return false.
  bool get isExpired {
    if (!isLiveLocation) {
      return false;
    }

    if (liveLocationExpiresAt == null) {
      return false;
    }

    return DateTime.now().isAfter(
      liveLocationExpiresAt!,
    );
  }

  // ============================================================
  // HAS SESSION
  // ============================================================

  /// Returns true when this live-location message has a valid
  /// session ID that can be watched.
  bool get hasLiveLocationSession {
    return isLiveLocation &&
        liveLocationSessionId != null &&
        liveLocationSessionId!
            .trim()
            .isNotEmpty;
  }

  // ============================================================
  // REMAINING DURATION
  // ============================================================

  /// Returns the remaining live-location time.
  Duration? get remainingDuration {
    if (!isLiveLocation ||
        liveLocationExpiresAt == null) {
      return null;
    }

    final remaining =
        liveLocationExpiresAt!
            .difference(
      DateTime.now(),
    );

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  // ============================================================
  // REMAINING LABEL
  // ============================================================

  /// Returns a user-friendly remaining-time label.
  String get remainingLabel {
    final remaining =
        remainingDuration;

    if (remaining == null) {
      return '';
    }

    if (remaining == Duration.zero) {
      return 'Expired';
    }

    final hours =
        remaining.inHours;

    final minutes =
        remaining.inMinutes
            .remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    }

    if (minutes > 0) {
      return '${minutes}m remaining';
    }

    return 'Less than 1m remaining';
  }

  // ============================================================
  // SAFE DOUBLE READER
  // ============================================================

  /// Safely reads a number from Firestore.
  static double _readDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(
            value,
          ) ??
          0.0;
    }

    return 0.0;
  }

  // ============================================================
  // SAFE DATE READER
  // ============================================================

  /// Safely reads a DateTime from Firestore.
  static DateTime? _readDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }
}

// ============================================================
// LIVE LOCATION DURATION
// ============================================================

/// Live-location duration options available in ChattªX.
enum ChattaXLiveLocationDuration {
  fifteenMinutes,
  oneHour,
  eightHours,
  thirtyDays,
}

// ============================================================
// LIVE LOCATION DURATION EXTENSION
// ============================================================

extension ChattaXLiveLocationDurationExtension
    on ChattaXLiveLocationDuration {
  // ==========================================================
  // ACTUAL DURATION
  // ==========================================================

  /// Actual duration represented by the option.
  Duration get duration {
    switch (this) {
      case ChattaXLiveLocationDuration
          .fifteenMinutes:
        return const Duration(
          minutes: 15,
        );

      case ChattaXLiveLocationDuration
          .oneHour:
        return const Duration(
          hours: 1,
        );

      case ChattaXLiveLocationDuration
          .eightHours:
        return const Duration(
          hours: 8,
        );

      case ChattaXLiveLocationDuration
          .thirtyDays:
        return const Duration(
          days: 30,
        );
    }
  }

  // ==========================================================
  // USER LABEL
  // ==========================================================

  /// User-visible duration label.
  String get label {
    switch (this) {
      case ChattaXLiveLocationDuration
          .fifteenMinutes:
        return '15 minutes';

      case ChattaXLiveLocationDuration
          .oneHour:
        return '1 hour';

      case ChattaXLiveLocationDuration
          .eightHours:
        return '8 hours';

      case ChattaXLiveLocationDuration
          .thirtyDays:
        return '30 days';
    }
  }
}