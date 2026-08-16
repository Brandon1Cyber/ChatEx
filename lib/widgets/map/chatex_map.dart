import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ================================================================
// CHATTªX MAP COLORS
// ================================================================

const Color chatexMapPanelColor =
    Color(0xff101827);

const Color chatexMapPurple =
    Color(0xff8A3DFF);

const Color chatexMapBlue =
    Color(0xff00E5FF);

const Color chatexMapGreen =
    Color(0xff00D68F);

const Color chatexMapPink =
    Color(0xffFF3D81);

// ================================================================
// CHATTªX MAP
// ================================================================

class ChatexMap extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  final double initialZoom;

  final bool showCurrentLocation;

  final bool showZoomControls;

  final bool showLocationButton;

  final bool followCurrentLocation;

  final List<ChatexMapMarkerData> markers;

  final ValueChanged<LatLng>? onMapTap;

  final ValueChanged<LatLng>? onMapLongPress;

  const ChatexMap({
    super.key,
    this.latitude,
    this.longitude,
    this.initialZoom = 15,
    this.showCurrentLocation = true,
    this.showZoomControls = true,
    this.showLocationButton = true,
    this.followCurrentLocation = false,
    this.markers = const [],
    this.onMapTap,
    this.onMapLongPress,
  });

  @override
  State<ChatexMap> createState() =>
      _ChatexMapState();
}

// ================================================================
// MAP STATE
// ================================================================

class _ChatexMapState extends State<ChatexMap> {
  final MapController _mapController =
      MapController();

  StreamSubscription<Position>?
      _positionSubscription;

  bool _mapReady = false;

  LatLng? _sharedLocation;

  LatLng? _currentLocation;

  bool _locationLoading = false;

  bool _locationPermissionDenied = false;

  bool _locationServiceDisabled = false;

  static const LatLng defaultLocation =
      LatLng(
    -26.2041,
    28.0473,
  );

  @override
  void initState() {
    super.initState();

    _sharedLocation =
        _getProvidedLocation();

    if (widget.showCurrentLocation) {
      _initializeLocation();
    }
  }

  // ==============================================================
  // PROVIDED LOCATION
  // ==============================================================

  LatLng? _getProvidedLocation() {
    final latitude = widget.latitude;
    final longitude = widget.longitude;

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // ==============================================================
  // INITIAL CENTER
  // ==============================================================

  LatLng get _initialCenter {
    return _sharedLocation ??
        _currentLocation ??
        defaultLocation;
  }

  // ==============================================================
  // INITIALIZE LOCATION
  // ==============================================================

  Future<void> _initializeLocation() async {
    if (!widget.showCurrentLocation ||
        !mounted) {
      return;
    }

    setState(() {
      _locationLoading = true;
      _locationPermissionDenied = false;
      _locationServiceDisabled = false;
    });

    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationLoading = false;
          _locationServiceDisabled = true;
        });

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationLoading = false;
          _locationPermissionDenied = true;
        });

        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = location;
        _locationLoading = false;
      });

      if (_mapReady &&
          _sharedLocation == null &&
          widget.followCurrentLocation) {
        _mapController.move(
          location,
          widget.initialZoom,
        );
      }

      _startLocationUpdates();
    } catch (error) {
      debugPrint(
        'ChattªX Maps location error: $error',
      );

      if (!mounted) return;

      setState(() {
        _locationLoading = false;
      });
    }
  }

  // ==============================================================
  // LIVE LOCATION
  // ==============================================================

  void _startLocationUpdates() {
    _positionSubscription?.cancel();

    const settings =
        LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        if (!mounted) return;

        final location = LatLng(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentLocation = location;
        });

        if (_mapReady &&
            widget.followCurrentLocation) {
          _mapController.move(
            location,
            _mapController.camera.zoom,
          );
        }
      },
      onError: (error) {
        debugPrint(
          'ChattªX Maps GPS stream error: $error',
        );
      },
    );
  }

  // ==============================================================
  // UPDATE WIDGET
  // ==============================================================

  @override
  void didUpdateWidget(
    covariant ChatexMap oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final newLocation =
        _getProvidedLocation();

    final oldLocation =
        oldWidget.latitude != null &&
                oldWidget.longitude != null
            ? LatLng(
                oldWidget.latitude!,
                oldWidget.longitude!,
              )
            : null;

    _sharedLocation = newLocation;

    if (newLocation == null) {
      return;
    }

    final changed =
        oldLocation == null ||
            oldLocation.latitude !=
                newLocation.latitude ||
            oldLocation.longitude !=
                newLocation.longitude;

    if (changed && _mapReady) {
      _mapController.move(
        newLocation,
        widget.initialZoom,
      );
    }
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: widget.initialZoom,
              minZoom: 3,
              maxZoom: 19,

              onMapReady: () {
                _mapReady = true;

                final center =
                    _sharedLocation ??
                        _currentLocation;

                if (center != null) {
                  WidgetsBinding.instance
                      .addPostFrameCallback(
                    (_) {
                      if (!mounted ||
                          !_mapReady) {
                        return;
                      }

                      _mapController.move(
                        center,
                        widget.initialZoom,
                      );
                    },
                  );
                }
              },

              onTap: (
                tapPosition,
                point,
              ) {
                widget.onMapTap?.call(
                  point,
                );
              },

              onLongPress: (
                tapPosition,
                point,
              ) {
                widget.onMapLongPress
                    ?.call(point);
              },
            ),

            children: [
              // ==================================================
              // OPEN STREET MAP
              // ==================================================

              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.chattax.app',
                maxZoom: 19,
              ),

              // ==================================================
              // SHARED LOCATION
              // ==================================================

              if (_sharedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point:
                          _sharedLocation!,
                      width: 80,
                      height: 80,
                      child:
                          const ChatexSharedLocationMarker(),
                    ),
                  ],
                ),

              // ==================================================
              // CURRENT LOCATION
              // ==================================================

              if (widget.showCurrentLocation &&
                  _currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point:
                          _currentLocation!,
                      width: 80,
                      height: 80,
                      child:
                          const ChatexCurrentLocationMarker(),
                    ),
                  ],
                ),

              // ==================================================
              // NEARBY / CUSTOM MARKERS
              // ==================================================

              if (widget.markers.isNotEmpty)
                MarkerLayer(
                  markers:
                      widget.markers.map(
                    (marker) {
                      return Marker(
                        point: LatLng(
                          marker.latitude,
                          marker.longitude,
                        ),
                        width:
                            marker.width,
                        height:
                            marker.height,
                        child:
                            GestureDetector(
                          onTap:
                              marker.onTap,
                          child:
                              marker.child,
                        ),
                      );
                    },
                  ).toList(),
                ),
            ],
          ),
        ),

        // ========================================================
        // LOCATION LOADING
        // ========================================================

        if (_locationLoading)
          Positioned(
            top: 15,
            left: 15,
            child:
                _buildLocationStatus(),
          ),

        // ========================================================
        // SERVICE DISABLED
        // ========================================================

        if (_locationServiceDisabled)
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child:
                _buildLocationWarning(
              icon:
                  Icons.location_disabled_rounded,
              text:
                  'Location is turned off',
              onTap: () async {
                await Geolocator
                    .openLocationSettings();

                await _initializeLocation();
              },
            ),
          ),

        // ========================================================
        // PERMISSION DENIED
        // ========================================================

        if (_locationPermissionDenied)
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child:
                _buildLocationWarning(
              icon:
                  Icons.location_off_rounded,
              text:
                  'Location permission is required',
              onTap: () async {
                await Geolocator
                    .openAppSettings();

                await _initializeLocation();
              },
            ),
          ),

        // ========================================================
        // ZOOM
        // ========================================================

        if (widget.showZoomControls)
          Positioned(
            right: 14,
            bottom: 25,
            child:
                _buildZoomButtons(),
          ),

        // ========================================================
        // LOCATION BUTTON
        // ========================================================

        if (widget.showLocationButton)
          Positioned(
            right: 14,
            bottom: 130,
            child:
                _buildLocationButton(),
          ),
      ],
    );
  }

  // ==============================================================
  // LOCATION STATUS
  // ==============================================================

  Widget _buildLocationStatus() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            chatexMapPanelColor
                .withValues(alpha: .96),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              chatexMapBlue
                  .withValues(alpha: .30),
        ),
      ),
      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  chatexMapBlue,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Finding your location...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // WARNING
  // ==============================================================

  Widget _buildLocationWarning({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration:
            BoxDecoration(
          color:
              chatexMapPanelColor
                  .withValues(alpha: .97),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                chatexMapPurple
                    .withValues(alpha: .30),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  chatexMapBlue,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color:
                  Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // ZOOM
  // ==============================================================

  Widget _buildZoomButtons() {
    return Container(
      width: 46,
      decoration:
          BoxDecoration(
        color:
            chatexMapPanelColor
                .withValues(alpha: .96),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              chatexMapPurple
                  .withValues(alpha: .35),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _zoomIn,
            borderRadius:
                const BorderRadius.vertical(
              top:
                  Radius.circular(18),
            ),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
          Container(
            height: 1,
            margin:
                const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            color:
                Colors.white12,
          ),
          InkWell(
            onTap: _zoomOut,
            borderRadius:
                const BorderRadius.vertical(
              bottom:
                  Radius.circular(18),
            ),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.remove_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    if (!_mapReady) return;

    final zoom =
        _mapController.camera.zoom;

    if (zoom >= 19) return;

    _mapController.move(
      _mapController.camera.center,
      (zoom + 1).clamp(
        3.0,
        19.0,
      ),
    );
  }

  void _zoomOut() {
    if (!_mapReady) return;

    final zoom =
        _mapController.camera.zoom;

    if (zoom <= 3) return;

    _mapController.move(
      _mapController.camera.center,
      (zoom - 1).clamp(
        3.0,
        19.0,
      ),
    );
  }

  // ==============================================================
  // RECENTER
  // ==============================================================

  Future<void>
      _recenterOnMyLocation() async {
    if (_currentLocation != null) {
      if (_mapReady) {
        _mapController.move(
          _currentLocation!,
          17,
        );
      }

      return;
    }

    await _initializeLocation();

    if (!mounted ||
        !_mapReady ||
        _currentLocation == null) {
      return;
    }

    _mapController.move(
      _currentLocation!,
      17,
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap:
          _recenterOnMyLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration:
            BoxDecoration(
          color:
              chatexMapPanelColor
                  .withValues(alpha: .96),
          shape:
              BoxShape.circle,
          border: Border.all(
            color:
                chatexMapBlue
                    .withValues(alpha: .35),
          ),
        ),
        child: Icon(
          _locationLoading
              ? Icons.location_searching_rounded
              : Icons.my_location_rounded,
          color:
              chatexMapBlue,
          size: 22,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();

    super.dispose();
  }
}

// ==================================================================
// CURRENT LOCATION MARKER
// ==================================================================

class ChatexCurrentLocationMarker
    extends StatefulWidget {
  const ChatexCurrentLocationMarker({
    super.key,
  });

  @override
  State<ChatexCurrentLocationMarker>
      createState() =>
          _ChatexCurrentLocationMarkerState();
}

class _ChatexCurrentLocationMarkerState
    extends State<ChatexCurrentLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1800,
      ),
    )..repeat();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation:
          _pulseController,
      builder:
          (context, child) {
        final pulse =
            _pulseController.value;

        final pulseSize =
            42 + (pulse * 24);

        final opacity =
            (1 - pulse) * .25;

        return Center(
          child: Stack(
            alignment:
                Alignment.center,
            children: [
              Container(
                width: pulseSize,
                height: pulseSize,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      chatexMapBlue
                          .withValues(
                    alpha: opacity,
                  ),
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      chatexMapBlue
                          .withValues(
                    alpha: .14,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          chatexMapBlue
                              .withValues(
                        alpha: .30,
                      ),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 25,
                height: 25,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      chatexMapBlue,
                  border:
                      Border.all(
                    color:
                        Colors.white,
                    width: 3,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}

// ==================================================================
// SHARED LOCATION MARKER
// ==================================================================

class ChatexSharedLocationMarker
    extends StatelessWidget {
  const ChatexSharedLocationMarker({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Container(
        width: 46,
        height: 46,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              chatexMapPurple,
          border:
              Border.all(
            color:
                Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  chatexMapPurple
                      .withValues(
                alpha: .55,
              ),
              blurRadius: 18,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }
}

// ==================================================================
// CUSTOM MAP MARKER DATA
// ==================================================================

class ChatexMapMarkerData {
  final double latitude;

  final double longitude;

  final Widget child;

  final double width;

  final double height;

  final VoidCallback? onTap;

  const ChatexMapMarkerData({
    required this.latitude,
    required this.longitude,
    required this.child,
    this.width = 60,
    this.height = 60,
    this.onTap,
  });
}

// ==================================================================
// CHATTªX USER MAP MARKER
// ==================================================================

class ChatexUserMapMarker
    extends StatelessWidget {
  final String name;

  final String? photoUrl;

  final bool isOnline;

  final bool isLive;

  const ChatexUserMapMarker({
    super.key,
    required this.name,
    this.photoUrl,
    this.isOnline = false,
    this.isLive = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final letter =
        name.trim().isEmpty
            ? '?'
            : name.trim()[0].toUpperCase();

    return Center(
      child: Stack(
        clipBehavior:
            Clip.none,
        children: [
          // ========================================================
          // PROFILE CIRCLE
          // ========================================================

          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              border: Border.all(
                color:
                    isLive
                        ? chatexMapPink
                        : isOnline
                            ? chatexMapGreen
                            : chatexMapPurple,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isLive
                              ? chatexMapPink
                              : chatexMapPurple)
                          .withValues(
                    alpha: .35,
                  ),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipOval(
              child:
                  photoUrl != null &&
                          photoUrl!
                              .trim()
                              .isNotEmpty
                      ? Image.network(
                          photoUrl!,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return _fallback(
                              letter,
                            );
                          },
                        )
                      : _fallback(
                          letter,
                        ),
            ),
          ),

          // ========================================================
          // ONLINE DOT
          // ========================================================

          if (isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(
                  color:
                      chatexMapGreen,
                  shape:
                      BoxShape.circle,
                  border: Border.all(
                    color:
                        chatexMapPanelColor,
                    width: 2,
                  ),
                ),
              ),
            ),

          // ========================================================
          // LIVE BADGE
          // ========================================================

          if (isLive)
            Positioned(
              top: -8,
              left: 50,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      chatexMapPink,
                  borderRadius:
                      BorderRadius.circular(
                    6,
                  ),
                  border:
                      Border.all(
                    color:
                        chatexMapPanelColor,
                    width: 1,
                  ),
                ),
                child:
                    const Text(
                  'LIVE',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        6,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(
    String letter,
  ) {
    return Container(
      color:
          chatexMapPurple
              .withValues(alpha: .20),
      alignment:
          Alignment.center,
      child: Text(
        letter,
        style:
            const TextStyle(
          color:
              chatexMapBlue,
          fontSize: 18,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}