import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapLocationDetails extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String title;

  const MapLocationDetails({
    super.key,
    this.latitude,
    this.longitude,
    this.title = 'Shared location',
  });

  @override
  State<MapLocationDetails> createState() =>
      _MapLocationDetailsState();
}

class _MapLocationDetailsState
    extends State<MapLocationDetails> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color background =
      Color(0xff070C16);

  static const Color panel =
      Color(0xff101827);

  static const Color panelDark =
      Color(0xff0D1421);

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  static const Color pink =
      Color(0xffFF3D81);

  // ============================================================
  // MAP CONTROLLER
  // ============================================================

  final MapController _mapController =
      MapController();

  // ============================================================
  // STATE
  // ============================================================

  bool _mapReady = false;

  double _zoom = 16;

  // ============================================================
  // GET LOCATION
  // ============================================================

  LatLng? get _location {
    final latitude =
        widget.latitude;

    final longitude =
        widget.longitude;

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

  // ============================================================
  // MOVE TO LOCATION
  // ============================================================

  void _centerLocation() {
    final location =
        _location;

    if (location == null) {
      return;
    }

    if (!_mapReady) {
      return;
    }

    _mapController.move(
      location,
      16,
    );

    setState(() {
      _zoom = 16;
    });
  }

  // ============================================================
  // ZOOM IN
  // ============================================================

  void _zoomIn() {
    final location =
        _location;

    if (location == null ||
        !_mapReady) {
      return;
    }

    final newZoom =
        (_zoom + 1)
            .clamp(3.0, 19.0);

    _mapController.move(
      _mapController.camera.center,
      newZoom,
    );

    setState(() {
      _zoom = newZoom;
    });
  }

  // ============================================================
  // ZOOM OUT
  // ============================================================

  void _zoomOut() {
    final location =
        _location;

    if (location == null ||
        !_mapReady) {
      return;
    }

    final newZoom =
        (_zoom - 1)
            .clamp(3.0, 19.0);

    _mapController.move(
      _mapController.camera.center,
      newZoom,
    );

    setState(() {
      _zoom = newZoom;
    });
  }

  // ============================================================
  // COPY COORDINATES
  // ============================================================

  void _copyCoordinates() {
    final location =
        _location;

    if (location == null) {
      return;
    }

    final coordinates =
        '${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          'Coordinates: $coordinates',
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
        backgroundColor:
            panel,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SHARE LOCATION
  // ============================================================

  void _shareLocation() {
    final location =
        _location;

    if (location == null) {
      return;
    }

    final link =
        'https://www.openstreetmap.org/'
        '?mlat=${location.latitude}'
        '&mlon=${location.longitude}'
        '#map=17/'
        '${location.latitude}/'
        '${location.longitude}';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          link,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
        backgroundColor:
            panel,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OPEN EXTERNAL MAP
  // ============================================================

  void _openDirections() {
    final location =
        _location;

    if (location == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: const Text(
          'Directions will be connected to ChattªX navigation.',
          style:
              TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
        backgroundColor:
            panel,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INVALID LOCATION SCREEN
  // ============================================================

  Widget _invalidLocation() {
    return Scaffold(
      backgroundColor:
          background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    30,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration:
                            BoxDecoration(
                          color:
                              pink.withValues(
                            alpha: .10,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                pink.withValues(
                              alpha: .25,
                            ),
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .location_off_rounded,
                          color:
                              pink,
                          size: 32,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Location unavailable',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      const Text(
                        'This location does not contain valid coordinates.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white38,
                          fontSize:
                              10,
                          height:
                              1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration:
          BoxDecoration(
        color:
            background.withValues(
          alpha: .97,
        ),
        border: Border(
          bottom:
              BorderSide(
            color:
                purple.withValues(
              alpha: .18,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(
                context,
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    panel,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      purple.withValues(
                    alpha: .35,
                  ),
                ),
              ),
              child:
                  const Icon(
                Icons
                    .arrow_back_rounded,
                color:
                    Colors.white,
                size: 22,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                const Row(
                  children: [
                    Icon(
                      Icons
                          .explore_rounded,
                      color:
                          cyan,
                      size: 12,
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      'ChattªX Maps',
                      style:
                          TextStyle(
                        color:
                            Colors.white38,
                        fontSize:
                            8.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap:
                _shareLocation,
            child: Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    cyan.withValues(
                  alpha: .08,
                ),
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      cyan.withValues(
                    alpha: .20,
                  ),
                ),
              ),
              child:
                  const Icon(
                Icons
                    .share_rounded,
                color:
                    cyan,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _locationCard(
    LatLng location,
  ) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 20,
      child: Container(
        padding:
            const EdgeInsets.all(
          13,
        ),
        decoration:
            BoxDecoration(
          color:
              panel.withValues(
            alpha: .97,
          ),
          borderRadius:
              BorderRadius.circular(
            21,
          ),
          border:
              Border.all(
            color:
                purple.withValues(
              alpha: .25,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: .35,
              ),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color:
                        cyan.withValues(
                      alpha: .10,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .location_on_rounded,
                    color:
                        cyan,
                    size: 23,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        widget.title,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${location.latitude.toStringAsFixed(6)}, '
                        '${location.longitude.toStringAsFixed(6)}',
                        style:
                            const TextStyle(
                          color:
                              Colors.white38,
                          fontSize:
                              9,
                        ),
                      ),
                    ],
                  ),
                ),

                GestureDetector(
                  onTap:
                      _copyCoordinates,
                  child:
                      Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white.withValues(
                        alpha: .05,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .content_copy_rounded,
                      color:
                          Colors.white54,
                      size:
                          17,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 11,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _bottomAction(
                    icon: Icons
                        .my_location_rounded,
                    title:
                        'Center',
                    color:
                        cyan,
                    onTap:
                        _centerLocation,
                  ),
                ),

                const SizedBox(
                  width: 7,
                ),

                Expanded(
                  child:
                      _bottomAction(
                    icon: Icons
                        .directions_rounded,
                    title:
                        'Directions',
                    color:
                        purple,
                    onTap:
                        _openDirections,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTION
  // ============================================================

  Widget _bottomAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 43,
        decoration:
            BoxDecoration(
          color:
              color.withValues(
            alpha: .09,
          ),
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border:
              Border.all(
            color:
                color.withValues(
              alpha: .22,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  color,
              size: 17,
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize:
                    10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ZOOM CONTROLS
  // ============================================================

  Widget _zoomControls() {
    return Positioned(
      right: 14,
      bottom: 225,
      child: Container(
        width: 45,
        decoration:
            BoxDecoration(
          color:
              panel.withValues(
            alpha: .95,
          ),
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border:
              Border.all(
            color:
                purple.withValues(
              alpha: .25,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: .25,
              ),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap:
                  _zoomIn,
              child:
                  const SizedBox(
                width: 45,
                height: 45,
                child: Icon(
                  Icons.add_rounded,
                  color:
                      Colors.white,
                  size: 22,
                ),
              ),
            ),

            Container(
              height: 1,
              margin:
                  const EdgeInsets
                      .symmetric(
                horizontal: 9,
              ),
              color:
                  Colors.white10,
            ),

            GestureDetector(
              onTap:
                  _zoomOut,
              child:
                  const SizedBox(
                width: 45,
                height: 45,
                child: Icon(
                  Icons.remove_rounded,
                  color:
                      Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP MARKER
  // ============================================================

  Widget _marker() {
    return Stack(
      alignment:
          Alignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration:
              BoxDecoration(
            color:
                cyan.withValues(
              alpha: .10,
            ),
            shape:
                BoxShape.circle,
          ),
        ),

        Container(
          width: 38,
          height: 38,
          decoration:
              BoxDecoration(
            color:
                cyan.withValues(
              alpha: .16,
            ),
            shape:
                BoxShape.circle,
          ),
        ),

        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(
            color:
                cyan,
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    cyan.withValues(
                  alpha: .45,
                ),
                blurRadius: 14,
              ),
            ],
          ),
          child:
              const Icon(
            Icons
                .location_on_rounded,
            color:
                Color(0xff070C16),
            size: 17,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap(
    LatLng location,
  ) {
    return FlutterMap(
      mapController:
          _mapController,
      options:
          MapOptions(
        initialCenter:
            location,
        initialZoom:
            _zoom,
        minZoom:
            3,
        maxZoom:
            19,
        onMapReady: () {
          setState(() {
            _mapReady = true;
          });
        },
        onPositionChanged:
            (
          position,
          hasGesture,
        ) {
          final currentZoom =
              position.zoom;

          if (currentZoom !=
              _zoom) {
            setState(() {
              _zoom =
                  currentZoom;
            });
          }
        },
      ),
      children: [
        // ======================================================
        // REAL OPENSTREETMAP TILES
        // ======================================================

        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName:
              'com.chattax.app',
          maxZoom:
              19,
        ),

        // ======================================================
        // MARKER
        // ======================================================

        MarkerLayer(
          markers: [
            Marker(
              point:
                  location,
              width:
                  70,
              height:
                  70,
              child:
                  _marker(),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final location =
        _location;

    if (location == null) {
      return _invalidLocation();
    }

    return Scaffold(
      backgroundColor:
          background,

      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // REAL MAP
            // ==================================================

            Positioned.fill(
              child:
                  _buildMap(
                location,
              ),
            ),

            // ==================================================
            // TOP GRADIENT
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child:
                    Container(
                  height: 115,
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        background
                            .withValues(
                          alpha:
                              .90,
                        ),
                        background
                            .withValues(
                          alpha:
                              .0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // HEADER
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child:
                  _buildHeader(),
            ),

            // ==================================================
            // CURRENT LOCATION / CENTER
            // ==================================================

            Positioned(
              right: 14,
              bottom: 285,
              child:
                  GestureDetector(
                onTap:
                    _centerLocation,
                child:
                    Container(
                  width: 47,
                  height: 47,
                  decoration:
                      BoxDecoration(
                    color:
                        panel.withValues(
                      alpha:
                          .96,
                    ),
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          cyan.withValues(
                        alpha:
                            .30,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(
                          alpha:
                              .25,
                        ),
                        blurRadius:
                            14,
                      ),
                    ],
                  ),
                  child:
                      const Icon(
                    Icons
                        .my_location_rounded,
                    color:
                        cyan,
                    size:
                        21,
                  ),
                ),
              ),
            ),

            // ==================================================
            // ZOOM
            // ==================================================

            _zoomControls(),

            // ==================================================
            // LOCATION CARD
            // ==================================================

            _locationCard(
              location,
            ),
          ],
        ),
      ),
    );
  }
}