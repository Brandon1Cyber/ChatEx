import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import '../../widgets/map/chatex_map.dart';

class MapLiveLocation extends StatefulWidget {
  const MapLiveLocation({
    super.key,
  });

  @override
  State<MapLiveLocation> createState() =>
      _MapLiveLocationState();
}

class _MapLiveLocationState
    extends State<MapLiveLocation> {
  // ============================================================
  // SERVICES
  // ============================================================

  final LocationService _locationService =
      LocationService();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // STREAM
  // ============================================================

  StreamSubscription<Position>?
      _locationSubscription;

  // ============================================================
  // STATE
  // ============================================================

  Position? _currentPosition;

  bool _isSharing = false;

  bool _isLoading = true;

  bool _isSaving = false;

  String _status =
      'Checking your location...';

  // ============================================================
  // COLORS
  // ============================================================

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

  static const Color green =
      Color(0xff00D68F);

  @override
  void initState() {
    super.initState();

    _loadLocation();
  }

  // ============================================================
  // LOAD LOCATION
  // ============================================================

  Future<void> _loadLocation() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;

      _status =
          'Checking your location...';
    });

    final position =
        await _locationService
            .getCurrentLocation();

    if (!mounted) {
      return;
    }

    if (position == null) {
      setState(() {
        _isLoading = false;

        _status =
            'Location permission is unavailable.';
      });

      return;
    }

    setState(() {
      _currentPosition = position;

      _isLoading = false;

      _status =
          'Your location is ready.';
    });
  }

  // ============================================================
  // START LIVE LOCATION
  // ============================================================

  Future<void> _startSharing() async {
    if (_isSharing) {
      return;
    }

    if (_currentPosition == null) {
      await _loadLocation();
    }

    if (_currentPosition == null) {
      return;
    }

    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You need to be signed in to share your location.',
      );

      return;
    }

    setState(() {
      _isSaving = true;

      _status =
          'Starting live location...';
    });

    try {
      await _saveLiveLocation(
        _currentPosition!,
      );

      await _locationSubscription
          ?.cancel();

      _locationSubscription =
          Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        _onLocationChanged,
        onError: (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            _status =
                'Live location update stopped.';
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSharing = true;

        _isSaving = false;

        _status =
            'Your location is being shared live.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;

        _status =
            'Could not start live location.';
      });

      _showMessage(
        'Could not start live location.',
      );
    }
  }

  // ============================================================
  // LOCATION CHANGED
  // ============================================================

  Future<void> _onLocationChanged(
    Position position,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentPosition = position;

      _status =
          'Live location updated.';
    });

    if (!_isSharing) {
      return;
    }

    await _saveLiveLocation(
      position,
    );
  }

  // ============================================================
  // SAVE LIVE LOCATION
  // ============================================================

  Future<void> _saveLiveLocation(
    Position position,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'latitude':
            position.latitude,

        'longitude':
            position.longitude,

        'accuracy':
            position.accuracy,

        'altitude':
            position.altitude,

        'heading':
            position.heading,

        'speed':
            position.speed,

        'isLiveLocation':
            _isSharing,

        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // STOP SHARING
  // ============================================================

  Future<void> _stopSharing() async {
    if (!_isSharing) {
      return;
    }

    setState(() {
      _isSaving = true;

      _status =
          'Stopping live location...';
    });

    await _locationSubscription
        ?.cancel();

    _locationSubscription =
        null;

    final user =
        _auth.currentUser;

    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'isLiveLocation':
              false,
        },
        SetOptions(
          merge: true,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSharing = false;

      _isSaving = false;

      _status =
          'Live location sharing stopped.';
    });
  }

  // ============================================================
  // TOGGLE
  // ============================================================

  Future<void> _toggleSharing() async {
    if (_isSaving) {
      return;
    }

    if (_isSharing) {
      await _stopSharing();

      return;
    }

    await _startSharing();
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _refreshLocation() async {
    if (_isSaving) {
      return;
    }

    await _loadLocation();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _locationSubscription
        ?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final position =
        _currentPosition;

    return Scaffold(
      backgroundColor:
          background,

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
                      latitude:
                          position.latitude,
                      longitude:
                          position.longitude,
                      initialZoom: 16,
                      showCurrentLocation:
                          true,
                      showZoomControls:
                          true,
                      showLocationButton:
                          false,
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
                    icon:
                        Icons.arrow_back_rounded,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );
                    },
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Container(
                      height: 48,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            panel.withValues(
                          alpha: .96,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                        border: Border.all(
                          color:
                              pink.withValues(
                            alpha: .28,
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
                              color:
                                  pink.withValues(
                                alpha: .10,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .radar_rounded,
                              color: pink,
                              size: 17,
                            ),
                          ),

                          const SizedBox(
                            width: 9,
                          ),

                          const Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Live Location',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        13,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                                Text(
                                  'ChattªX Maps',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white38,
                                    fontSize:
                                        9,
                                  ),
                                ),
                              ],
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
            // LIVE STATUS
            // ==================================================

            Positioned(
              top: 76,
              left: 18,
              child:
                  _buildStatusBadge(),
            ),

            // ==================================================
            // REFRESH
            // ==================================================

            Positioned(
              right: 15,
              bottom: 205,
              child: _circleButton(
                icon:
                    Icons.my_location_rounded,
                color: cyan,
                onTap:
                    _refreshLocation,
              ),
            ),

            // ==================================================
            // BOTTOM PANEL
            // ==================================================

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child:
                  _buildBottomPanel(),
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
      color:
          const Color(0xff0C1725),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                color: cyan,
                strokeWidth: 2,
              )
            : Container(
                margin:
                    const EdgeInsets.symmetric(
                  horizontal: 35,
                ),
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                decoration:
                    BoxDecoration(
                  color: panel,
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  border: Border.all(
                    color:
                        pink.withValues(
                      alpha: .25,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration:
                          BoxDecoration(
                        color:
                            pink.withValues(
                          alpha: .10,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          const Icon(
                        Icons
                            .location_off_rounded,
                        color: pink,
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    const Text(
                      'Location unavailable',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      _status,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    GestureDetector(
                      onTap:
                          _refreshLocation,
                      child:
                          Container(
                        height: 42,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              cyan.withValues(
                            alpha: .10,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          border:
                              Border.all(
                            color:
                                cyan.withValues(
                              alpha: .25,
                            ),
                          ),
                        ),
                        child:
                            const Row(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            Icon(
                              Icons
                                  .refresh_rounded,
                              color: cyan,
                              size: 17,
                            ),
                            SizedBox(
                              width: 7,
                            ),
                            Text(
                              'Try again',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge() {
    final Color color =
        _isSharing
            ? pink
            : cyan;

    final IconData icon =
        _isSharing
            ? Icons
                .radio_button_checked_rounded
            : Icons
                .location_searching_rounded;

    final String text =
        _isSharing
            ? 'LIVE'
            : 'READY';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            panel.withValues(
          alpha: .94,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color:
              color.withValues(
            alpha: .28,
          ),
        ),
        boxShadow: [
          if (_isSharing)
            BoxShadow(
              color:
                  pink.withValues(
                alpha: .18,
              ),
              blurRadius: 14,
            ),
        ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            text,
            style:
                TextStyle(
              color: color,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  .5,
            ),
          ),

          if (_isSharing) ...[
            const SizedBox(
              width: 6,
            ),
            Container(
              width: 5,
              height: 5,
              decoration:
                  const BoxDecoration(
                color: pink,
                shape:
                    BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM PANEL
  // ============================================================

  Widget _buildBottomPanel() {
    final position =
        _currentPosition;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        15,
        16,
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            panel.withValues(
          alpha: .98,
        ),
        borderRadius:
            BorderRadius.circular(
          26,
        ),
        border: Border.all(
          color:
              pink.withValues(
            alpha: .25,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: .42,
            ),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          // ====================================================
          // HANDLE
          // ====================================================

          Container(
            width: 38,
            height: 4,
            decoration:
                BoxDecoration(
              color: Colors.white24,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          // ====================================================
          // HEADER
          // ====================================================

          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                    BoxDecoration(
                  color:
                      pink.withValues(
                    alpha: .10,
                  ),
                  shape:
                      BoxShape.circle,
                  border: Border.all(
                    color:
                        pink.withValues(
                      alpha: .22,
                    ),
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .radar_rounded,
                  color: pink,
                  size: 22,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'Live Location',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _status,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          // ====================================================
          // COORDINATES
          // ====================================================

          if (position != null)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                11,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.black.withValues(
                  alpha: .16,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .gps_fixed_rounded,
                    color: cyan,
                    size: 17,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          '${position.latitude.toStringAsFixed(6)}, '
                          '${position.longitude.toStringAsFixed(6)}',
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          'Accuracy: ${position.accuracy.toStringAsFixed(1)} m',
                          style:
                              const TextStyle(
                            color:
                                Colors.white38,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
            height: 13,
          ),

          // ====================================================
          // SHARE BUTTON
          // ====================================================

          GestureDetector(
            onTap:
                _toggleSharing,
            child: Container(
              width:
                  double.infinity,
              height: 49,
              decoration:
                  BoxDecoration(
                color: _isSharing
                    ? pink.withValues(
                        alpha: .12,
                      )
                    : cyan.withValues(
                        alpha: .10,
                      ),
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                border: Border.all(
                  color: _isSharing
                      ? pink.withValues(
                          alpha: .35,
                        )
                      : cyan.withValues(
                          alpha: .30,
                        ),
                ),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          color: cyan,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            _isSharing
                                ? Icons
                                    .stop_circle_rounded
                                : Icons
                                    .play_circle_rounded,
                            color:
                                _isSharing
                                    ? pink
                                    : cyan,
                            size: 20,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Text(
                            _isSharing
                                ? 'Stop Live Location'
                                : 'Start Live Location',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          // ====================================================
          // PRIVACY NOTE
          // ====================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons
                    .lock_outline_rounded,
                color:
                    Colors.white38,
                size: 13,
              ),

              const SizedBox(
                width: 5,
              ),

              const Text(
                'Your live location is controlled by you.',
                style:
                    TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        decoration:
            BoxDecoration(
          color:
              panel.withValues(
            alpha: .96,
          ),
          shape:
              BoxShape.circle,
          border: Border.all(
            color:
                color.withValues(
              alpha: .22,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: .25,
              ),
              blurRadius: 12,
            ),
          ],
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
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor: panel,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        content: Text(
          message,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}