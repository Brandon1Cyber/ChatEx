import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';
import '../../widgets/map/chatex_map.dart';

class MapNearby extends StatefulWidget {
  const MapNearby({
    super.key,
  });

  @override
  State<MapNearby> createState() => _MapNearbyState();
}

class _MapNearbyState extends State<MapNearby> {
  // ============================================================
  // SERVICES
  // ============================================================

  final LocationService _locationService = LocationService();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  Position? _currentPosition;

  bool _loading = true;

  bool _refreshing = false;

  String _status = 'Finding people near you...';

  double _radiusKm = 10;

  List<_NearbyUser> _nearbyUsers = [];

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xff070C16);

  static const Color panel = Color(0xff101827);

  static const Color purple = Color(0xff8A3DFF);

  static const Color cyan = Color(0xff00E5FF);

  static const Color green = Color(0xff00D68F);

  static const Color pink = Color(0xffFF3D81);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadNearbyUsers();
  }

  // ============================================================
  // LOAD NEARBY USERS
  // ============================================================

  Future<void> _loadNearbyUsers() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Finding people near you...';
    });

    try {
      final position =
          await _locationService.getCurrentLocation();

      if (position == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
          _status = 'Location permission is unavailable.';
        });

        return;
      }

      _currentPosition = position;

      final snapshot =
          await _firestore.collection('users').get();

      final currentUser = _auth.currentUser;

      final List<_NearbyUser> users = [];

      for (final document in snapshot.docs) {
        if (currentUser != null &&
            document.id == currentUser.uid) {
          continue;
        }

        final data = document.data();

        final latitude = _toDouble(
          data['latitude'],
        );

        final longitude = _toDouble(
          data['longitude'],
        );

        if (latitude == null || longitude == null) {
          continue;
        }

        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );

        if (distance > _radiusKm) {
          continue;
        }

        users.add(
          _NearbyUser(
            uid: document.id,
            name: _getName(data),
            username: _getUsername(data),
            photoUrl: _getPhotoUrl(data),
            latitude: latitude,
            longitude: longitude,
            distanceKm: distance,
            isLive: _getBool(
              data['isLiveLocation'],
            ),
            isOnline: _getBool(
              data['isOnline'],
            ),
            updatedAt: _getDateTime(
              data['locationUpdatedAt'],
            ),
          ),
        );
      }

      users.sort(
        (a, b) => a.distanceKm.compareTo(
          b.distanceKm,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearbyUsers = users;

        _loading = false;

        _status = users.isEmpty
            ? 'No ChattªX users found nearby.'
            : '${users.length} people found nearby.';
      });
    } catch (e) {
      debugPrint(
        'ChattªX Nearby error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _status = 'Could not load nearby users.';
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    await _loadNearbyUsers();

    if (!mounted) {
      return;
    }

    setState(() {
      _refreshing = false;
    });
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double _calculateDistance(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const double earthRadius = 6371;

    final double dLat = _degreesToRadians(
      latitude2 - latitude1,
    );

    final double dLon = _degreesToRadians(
      longitude2 - longitude1,
    );

    final double a =
        math.sin(dLat / 2) *
                math.sin(dLat / 2) +
            math.cos(
                  _degreesToRadians(
                    latitude1,
                  ),
                ) *
                math.cos(
                  _degreesToRadians(
                    latitude2,
                  ),
                ) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final double c = 2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // ============================================================
  // CONVERSION HELPERS
  // ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  bool _getBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  String _getName(
    Map<String, dynamic> data,
  ) {
    final name = data['displayName'] ??
        data['name'] ??
        data['fullName'];

    if (name == null ||
        name.toString().trim().isEmpty) {
      return 'ChattªX User';
    }

    return name.toString();
  }

  String? _getUsername(
    Map<String, dynamic> data,
  ) {
    final username =
        data['username'] ?? data['userName'];

    if (username == null) {
      return null;
    }

    final value = username.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  String? _getPhotoUrl(
    Map<String, dynamic> data,
  ) {
    final photo = data['photoURL'] ??
        data['photoUrl'] ??
        data['profilePicture'] ??
        data['profileImage'];

    if (photo == null) {
      return null;
    }

    final value = photo.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  DateTime? _getDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // MAP MARKERS
  // ============================================================

  List<ChatexMapMarkerData> _buildMapMarkers() {
    return _nearbyUsers.map(
      (user) {
        return ChatexMapMarkerData(
          latitude: user.latitude,
          longitude: user.longitude,
          width: 72,
          height: 82,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _showUserLocation(user);
            },
            child: _NearbyMapMarker(
              user: user,
            ),
          ),
        );
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final position = _currentPosition;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // MAP
            // ==================================================

            Positioned.fill(
              child: position == null
                  ? _buildEmptyMap()
                  : ChatexMap(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      initialZoom: 12,
                      showCurrentLocation: true,
                      showZoomControls: true,
                      showLocationButton: false,
                      markers: _buildMapMarkers(),
                    ),
            ),

            // ==================================================
            // TOP BAR
            // ==================================================

            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Container(
                      height: 48,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: panel.withValues(
                          alpha: .96,
                        ),
                        borderRadius:
                            BorderRadius.circular(25),
                        border: Border.all(
                          color: purple.withValues(
                            alpha: .30,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 29,
                            height: 29,
                            decoration:
                                BoxDecoration(
                              color: purple.withValues(
                                alpha: .12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.near_me_rounded,
                              color: cyan,
                              size: 17,
                            ),
                          ),

                          const SizedBox(width: 9),

                          const Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nearby',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'People around you',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          GestureDetector(
                            onTap: _refresh,
                            child: _refreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      color: cyan,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // RADIUS
            // ==================================================

            Positioned(
              top: 76,
              left: 18,
              child: _buildRadiusBadge(),
            ),

            // ==================================================
            // USERS PANEL
            // ==================================================

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildNearbyPanel(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY MAP
  // ============================================================

  Widget _buildEmptyMap() {
    return Container(
      color: const Color(0xff0C1725),
      child: Center(
        child: _loading
            ? const CircularProgressIndicator(
                color: cyan,
                strokeWidth: 2,
              )
            : Container(
                margin:
                    const EdgeInsets.symmetric(
                  horizontal: 35,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color: purple.withValues(
                      alpha: .25,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_searching_rounded,
                      color: cyan,
                      size: 42,
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Location unavailable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 15),

                    _smallButton(
                      icon: Icons.refresh_rounded,
                      title: 'Try again',
                      color: cyan,
                      onTap: _refresh,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // RADIUS BADGE
  // ============================================================

  Widget _buildRadiusBadge() {
    return GestureDetector(
      onTap: _showRadiusSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: panel.withValues(
            alpha: .94,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: cyan.withValues(
              alpha: .24,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.radar_rounded,
              color: cyan,
              size: 15,
            ),

            const SizedBox(width: 6),

            Text(
              'Within ${_formatRadius()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(width: 3),

            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  String _formatRadius() {
    if (_radiusKm < 1) {
      return '${(_radiusKm * 1000).round()} m';
    }

    return '${_radiusKm.toStringAsFixed(0)} km';
  }

  // ============================================================
  // RADIUS SELECTOR
  // ============================================================

  void _showRadiusSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            25,
          ),
          decoration: const BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 17),

              const Text(
                'Nearby radius',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 15),

              ...[
                1.0,
                5.0,
                10.0,
                25.0,
                50.0,
              ].map(
                (value) {
                  final selected =
                      _radiusKm == value;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        _radiusKm = value;
                      });

                      _loadNearbyUsers();
                    },
                    child: Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 7,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? purple.withValues(
                                alpha: .14,
                              )
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? purple.withValues(
                                  alpha: .35,
                                )
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .radio_button_checked_rounded,
                            color: selected
                                ? cyan
                                : Colors.white38,
                            size: 17,
                          ),

                          const SizedBox(width: 9),

                          Text(
                            '${value.toStringAsFixed(0)} km',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),

                          const Spacer(),

                          if (selected)
                            const Icon(
                              Icons.check_rounded,
                              color: cyan,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // NEARBY PANEL
  // ============================================================

  Widget _buildNearbyPanel() {
    return Container(
      constraints:
          const BoxConstraints(maxHeight: 340),
      padding: const EdgeInsets.fromLTRB(
        15,
        13,
        15,
        14,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(
          alpha: .98,
        ),
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: purple.withValues(
            alpha: .25,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: .42,
            ),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                color: cyan,
                size: 19,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'People Nearby',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Text(
                '${_nearbyUsers.length}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: cyan,
                strokeWidth: 2,
              ),
            )
          else if (_nearbyUsers.isEmpty)
            _buildEmptyUsers()
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics:
                    const BouncingScrollPhysics(),
                itemCount: _nearbyUsers.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  return _buildUserTile(
                    _nearbyUsers[index],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY USERS
  // ============================================================

  Widget _buildEmptyUsers() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        15,
        13,
        15,
        8,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_rounded,
            color: Colors.white24,
            size: 30,
          ),

          const SizedBox(height: 7),

          const Text(
            'No one nearby',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER TILE
  // ============================================================

  Widget _buildUserTile(
    _NearbyUser user,
  ) {
    return GestureDetector(
      onTap: () {
        _showUserLocation(user);
      },
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 7,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: .12,
          ),
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(user),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),

                      if (user.isLive)
                        Container(
                          margin:
                              const EdgeInsets.only(
                            left: 6,
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                pink.withValues(
                              alpha: .12,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              6,
                            ),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: pink,
                              fontSize: 7,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (user.username != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 2,
                      ),
                      child: Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ),

                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Icon(
                        user.isOnline
                            ? Icons.circle
                            : Icons.schedule_rounded,
                        color: user.isOnline
                            ? green
                            : Colors.white30,
                        size: 7,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        user.isOnline
                            ? 'Online'
                            : _formatUpdated(
                                user.updatedAt,
                              ),
                        style:
                            const TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 7),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDistance(
                    user.distanceKm,
                  ),
                  style:
                      const TextStyle(
                    color: cyan,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(
    _NearbyUser user,
  ) {
    return Stack(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: user.isLive
                  ? pink
                  : purple.withValues(
                      alpha: .40,
                    ),
              width: user.isLive ? 1.5 : 1,
            ),
          ),
          child: ClipOval(
            child: user.photoUrl != null &&
                    user.photoUrl!.isNotEmpty
                ? Image.network(
                    user.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _avatarFallback(user);
                    },
                  )
                : _avatarFallback(user),
          ),
        ),

        if (user.isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: panel,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarFallback(
    _NearbyUser user,
  ) {
    final name = user.name.trim();

    final letter = name.isEmpty
        ? '?'
        : name[0].toUpperCase();

    return Container(
      color: purple.withValues(
        alpha: .16,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: cyan,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // SHOW USER LOCATION
  // ============================================================

  void _showUserLocation(
    _NearbyUser user,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _NearbyUserLocationScreen(
          user: user,
        ),
      ),
    );
  }

  // ============================================================
  // DISTANCE FORMAT
  // ============================================================

  String _formatDistance(
    double distanceKm,
  ) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  // ============================================================
  // UPDATED FORMAT
  // ============================================================

  String _formatUpdated(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Location available';
    }

    final difference =
        DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Updated just now';
    }

    if (difference.inMinutes < 60) {
      return 'Updated ${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return 'Updated ${difference.inHours}h ago';
    }

    return 'Updated ${difference.inDays}d ago';
  }

  // ============================================================
  // CIRCLE BUTTON
  // ============================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: panel.withValues(
            alpha: .96,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(
              alpha: .22,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
    );
  }

  // ============================================================
  // SMALL BUTTON
  // ============================================================

  Widget _smallButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: .10,
          ),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(
              alpha: .25,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 17,
            ),

            const SizedBox(width: 7),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NEARBY USER MODEL
// ================================================================

class _NearbyUser {
  final String uid;

  final String name;

  final String? username;

  final String? photoUrl;

  final double latitude;

  final double longitude;

  final double distanceKm;

  final bool isLive;

  final bool isOnline;

  final DateTime? updatedAt;

  const _NearbyUser({
    required this.uid,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.isLive,
    required this.isOnline,
    this.username,
    this.photoUrl,
    this.updatedAt,
  });
}

// ================================================================
// MAP PROFILE MARKER
// ================================================================

class _NearbyMapMarker extends StatelessWidget {
  final _NearbyUser user;

  const _NearbyMapMarker({
    required this.user,
  });

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  static const Color green =
      Color(0xff00D68F);

  static const Color pink =
      Color(0xffFF3D81);

  static const Color panel =
      Color(0xff101827);

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 72,
      height: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ======================================================
          // PROFILE MARKER
          // ======================================================

          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isLive
                      ? pink
                      : purple,
                  boxShadow: [
                    BoxShadow(
                      color: (user.isLive
                              ? pink
                              : purple)
                          .withValues(
                        alpha: .45,
                      ),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: panel,
                  ),
                  padding:
                      const EdgeInsets.all(2),
                  child: ClipOval(
                    child: user.photoUrl != null &&
                            user.photoUrl!.isNotEmpty
                        ? Image.network(
                            user.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return _fallback();
                            },
                          )
                        : _fallback(),
                  ),
                ),
              ),

              // ==================================================
              // ONLINE DOT
              // ==================================================

              if (user.isOnline)
                Positioned(
                  right: -1,
                  bottom: 2,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration:
                        BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: panel,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: green.withValues(
                            alpha: .45,
                          ),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // LIVE BADGE
              // ==================================================

              if (user.isLive)
                Positioned(
                  top: -7,
                  left: 50,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: pink,
                      borderRadius:
                          BorderRadius.circular(6),
                      border: Border.all(
                        color: panel,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 3),

          // ======================================================
          // NAME LABEL
          // ======================================================

          Container(
            constraints:
                const BoxConstraints(
              maxWidth: 68,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: panel.withValues(
                alpha: .94,
              ),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color: purple.withValues(
                  alpha: .25,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: .25,
                  ),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    final name = user.name.trim();

    final letter = name.isEmpty
        ? '?'
        : name[0].toUpperCase();

    return Container(
      color: purple.withValues(
        alpha: .18,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: cyan,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ================================================================
// NEARBY USER LOCATION SCREEN
// ================================================================

class _NearbyUserLocationScreen
    extends StatelessWidget {
  final _NearbyUser user;

  const _NearbyUserLocationScreen({
    required this.user,
  });

  static const Color background =
      Color(0xff070C16);

  static const Color panel =
      Color(0xff101827);

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  static const Color pink =
      Color(0xffFF3D81);

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ChatexMap(
                latitude: user.latitude,
                longitude: user.longitude,
                initialZoom: 16,
                showCurrentLocation: false,
                showZoomControls: true,
                showLocationButton: false,
                markers: [
                  ChatexMapMarkerData(
                    latitude: user.latitude,
                    longitude: user.longitude,
                    width: 72,
                    height: 82,
                    child: _NearbyMapMarker(
                      user: user,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // BACK
            // ==================================================

            Positioned(
              top: 12,
              left: 14,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color: panel.withValues(
                      alpha: .96,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: purple.withValues(
                        alpha: .30,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),

            // ==================================================
            // USER CARD
            // ==================================================

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: panel.withValues(
                    alpha: .98,
                  ),
                  borderRadius:
                      BorderRadius.circular(25),
                  border: Border.all(
                    color: purple.withValues(
                      alpha: .28,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: .40,
                      ),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                          BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isLive
                              ? pink
                              : purple,
                        ),
                      ),
                      child: ClipOval(
                        child: user.photoUrl != null &&
                                user.photoUrl!
                                    .isNotEmpty
                            ? Image.network(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return _fallback();
                                },
                              )
                            : _fallback(),
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),

                          if (user.username != null)
                            Text(
                              '@${user.username}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white38,
                                fontSize: 9,
                              ),
                            ),

                          const SizedBox(height: 4),

                          Text(
                            '${user.distanceKm.toStringAsFixed(1)} km away',
                            style:
                                const TextStyle(
                              color: cyan,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (user.isLive)
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              pink.withValues(
                            alpha: .12,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                          border: Border.all(
                            color:
                                pink.withValues(
                              alpha: .25,
                            ),
                          ),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: pink,
                            fontSize: 8,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    final name = user.name.trim();

    final letter = name.isEmpty
        ? '?'
        : name[0].toUpperCase();

    return Container(
      color: purple.withValues(
        alpha: .15,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: cyan,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}