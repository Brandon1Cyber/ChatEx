import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map_location_details.dart';
import 'map_live_location.dart';
import 'map_nearby.dart';
import 'map_saved_places.dart';

class ChatexMapScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? title;
  final String mode;

  const ChatexMapScreen({
    super.key,
    this.latitude,
    this.longitude,
    this.title,
    this.mode = 'map',
  });

  @override
  State<ChatexMapScreen> createState() => _ChatexMapScreenState();
}

class _ChatexMapScreenState extends State<ChatexMapScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  final MapController _mapController = MapController();

  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Position>? _positionSubscription;

  Timer? _navigationTimer;

  // ============================================================
  // STATE
  // ============================================================

  int _selectedIndex = 0;

  bool _showSearchResults = false;

  String _searchText = '';

  bool _isNavigating = false;

  bool _isLoadingRoute = false;

  bool _voiceEnabled = true;

  bool _locationReady = false;

  bool _routeError = false;

  String _routeErrorMessage = '';

  String _navigationInstruction = 'Follow the route';

  String _nextInstruction = 'Preparing navigation...';

  double _remainingDistance = 0;

  double _remainingDuration = 0;

  double _currentRouteProgress = 0;

  int _currentManeuverIndex = 0;

  // ============================================================
  // LOCATION
  // ============================================================

  LatLng? _currentLocation;

  LatLng? _destination;

  // ============================================================
  // ROUTE
  // ============================================================

  final List<LatLng> _routePoints = [];

  final List<_NavigationManeuver> _maneuvers = [];

  // ============================================================
  // NAVIGATION MODE
  // ============================================================

  _NavigationMode _navigationMode = _NavigationMode.driving;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xff070C16);
  static const Color panel = Color(0xff101827);
  static const Color purple = Color(0xff8A3DFF);
  static const Color cyan = Color(0xff00E5FF);
  static const Color pink = Color(0xffFF3D81);
  static const Color green = Color(0xff00D68F);
  static const Color yellow = Color(0xffFFB020);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _destination = _validDestination();

    _initializeTts();

    _initializeLocation();
  }

  // ============================================================
  // VALID DESTINATION
  // ============================================================

  LatLng? _validDestination() {
    if (widget.latitude == null || widget.longitude == null) {
      return null;
    }

    if (widget.latitude!.isNaN || widget.longitude!.isNaN) {
      return null;
    }

    if (!widget.latitude!.isFinite || !widget.longitude!.isFinite) {
      return null;
    }

    return LatLng(
      widget.latitude!,
      widget.longitude!,
    );
  }

  // ============================================================
  // TEXT TO SPEECH
  // ============================================================

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (!_voiceEnabled) {
      return;
    }

    if (text.trim().isEmpty) {
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  // ============================================================
  // LOCATION INITIALIZATION
  // ============================================================

  Future<void> _initializeLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          _showMessage(
            'Turn on location services to use navigation.',
          );
        }

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showMessage(
            'Location permission is required for navigation.',
          );
        }

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = LatLng(
          position.latitude,
          position.longitude,
        );

        _locationReady = true;
      });

      _mapController.move(
        _currentLocation!,
        15,
      );

      _startLocationTracking();

      if (_destination != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showNavigationModeChooser(
              destination: _destination!,
              automatic: false,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to get your current location.',
        );
      }
    }
  }

  // ============================================================
  // LOCATION TRACKING
  // ============================================================

  void _startLocationTracking() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });

      if (_isNavigating) {
        _updateNavigation(location);
      }
    });
  }

  // ============================================================
  // UPDATE NAVIGATION
  // ============================================================

  void _updateNavigation(
    LatLng currentPosition,
  ) {
    if (_maneuvers.isEmpty) {
      return;
    }

    if (_currentManeuverIndex >= _maneuvers.length) {
      return;
    }

    final maneuver =
        _maneuvers[_currentManeuverIndex];

    final distanceToManeuver = _distanceInMeters(
      currentPosition,
      maneuver.location,
    );

    if (distanceToManeuver < 25 &&
        _currentManeuverIndex < _maneuvers.length - 1) {
      _currentManeuverIndex++;

      final next =
          _maneuvers[_currentManeuverIndex];

      setState(() {
        _navigationInstruction =
            next.instruction;

        _nextInstruction =
            _currentManeuverIndex + 1 < _maneuvers.length
                ? _maneuvers[
                    _currentManeuverIndex + 1
                  ].instruction
                : 'You are almost there.';
      });

      _speak(next.instruction);
    }

    if (distanceToManeuver < 100 &&
        distanceToManeuver > 30) {
      final warning =
          _maneuverDistanceText(
        distanceToManeuver,
      );

      _speak(
        '$warning. ${maneuver.instruction}',
      );
    }

    if (_destination != null) {
      final destinationDistance =
          _distanceInMeters(
        currentPosition,
        _destination!,
      );

      setState(() {
        _remainingDistance =
            destinationDistance;
      });

      if (destinationDistance < 20) {
        _finishNavigation();
        return;
      }
    }

    _centerNavigationCamera(
      currentPosition,
    );

    if (mounted) {
      setState(() {
        _currentRouteProgress =
            _navigationProgress();
      });
    }
  }

  // ============================================================
  // CENTER CAMERA
  // ============================================================

  void _centerNavigationCamera(
    LatLng position,
  ) {
    if (!_isNavigating) {
      return;
    }

    _mapController.move(
      position,
      17,
    );
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double _distanceInMeters(
    LatLng a,
    LatLng b,
  ) {
    const distance = Distance();

    return distance.as(
      LengthUnit.Meter,
      a,
      b,
    );
  }

  // ============================================================
  // DISTANCE TEXT
  // ============================================================

  String _distanceText(
    double meters,
  ) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _maneuverDistanceText(
    double meters,
  ) {
    if (meters < 1000) {
      return 'In ${meters.round()} meters';
    }

    return 'In ${(meters / 1000).toStringAsFixed(1)} kilometers';
  }

  // ============================================================
  // OPEN FEATURE
  // ============================================================

  void _openFeature(String feature) {
    switch (feature) {
      case 'location':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapLocationDetails(
              latitude: widget.latitude,
              longitude: widget.longitude,
              title: widget.title ?? 'Shared location',
            ),
          ),
        );
        break;

      case 'live':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MapLiveLocation(),
          ),
        );
        break;

      case 'nearby':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MapNearby(),
          ),
        );
        break;

      case 'saved':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MapSavedPlaces(),
          ),
        );
        break;
    }
  }

  // ============================================================
  // DIRECTIONS
  // ============================================================

  void _openDirections() {
    if (_destination == null) {
      _showMessage(
        'Choose a destination first.',
      );

      return;
    }

    _showNavigationModeChooser(
      destination: _destination!,
    );
  }

  // ============================================================
  // NAVIGATION MODE CHOOSER
  // ============================================================

  void _showNavigationModeChooser({
    required LatLng destination,
    bool automatic = false,
  }) {
    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            28,
          ),
          decoration: const BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cyan.withValues(
                          alpha: .12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_rounded,
                        color: cyan,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How are you travelling?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ChattªX will choose the best route for you.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _navigationModeButton(
                  icon: Icons.directions_car_rounded,
                  title: 'Driving',
                  subtitle: 'Best roads for vehicles',
                  color: green,
                  mode: _NavigationMode.driving,
                  destination: destination,
                ),

                const SizedBox(height: 10),

                _navigationModeButton(
                  icon: Icons.directions_walk_rounded,
                  title: 'Walking',
                  subtitle: 'Pedestrian paths & shortcuts',
                  color: cyan,
                  mode: _NavigationMode.walking,
                  destination: destination,
                ),

                const SizedBox(height: 10),

                _navigationModeButton(
                  icon: Icons.directions_bike_rounded,
                  title: 'Cycling',
                  subtitle: 'Bike-friendly routes',
                  color: purple,
                  mode: _NavigationMode.cycling,
                  destination: destination,
                ),

                if (automatic) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Shared location detected',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MODE BUTTON
  // ============================================================

  Widget _navigationModeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required _NavigationMode mode,
    required LatLng destination,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);

        _navigationMode = mode;

        _startNavigation(
          destination,
          mode,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: .035,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(
              alpha: .25,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: .10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 23,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withValues(
                alpha: .8,
              ),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // START NAVIGATION
  // ============================================================

  Future<void> _startNavigation(
    LatLng destination,
    _NavigationMode mode,
  ) async {
    if (_currentLocation == null) {
      _showMessage(
        'Waiting for your location...',
      );

      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = false;
      _routeErrorMessage = '';
      _destination = destination;
    });

    final route = await _requestRoute(
      _currentLocation!,
      destination,
      mode,
    );

    if (!mounted) {
      return;
    }

    if (route == null || route.points.isEmpty) {
      setState(() {
        _isLoadingRoute = false;
        _routeError = true;
        _routeErrorMessage =
            'Could not find a route to this destination.';
      });

      _showMessage(
        'No route could be found.',
      );

      return;
    }

    setState(() {
      _routePoints
        ..clear()
        ..addAll(route.points);

      _maneuvers
        ..clear()
        ..addAll(route.maneuvers);

      _remainingDistance = route.distance;

      _remainingDuration = route.duration;

      _currentManeuverIndex = 0;

      _navigationInstruction =
          route.maneuvers.isNotEmpty
              ? route.maneuvers.first.instruction
              : 'Follow the route';

      _nextInstruction =
          route.maneuvers.length > 1
              ? route.maneuvers[1].instruction
              : 'You are almost there.';

      _isNavigating = true;

      _isLoadingRoute = false;

      _currentRouteProgress = 0;
    });

    _fitRouteOnMap();

    if (_maneuvers.isNotEmpty) {
      await _speak(
        _maneuvers.first.instruction,
      );
    }
  }

  // ============================================================
  // ROUTING
  // ============================================================

  Future<_RouteResult?> _requestRoute(
    LatLng start,
    LatLng destination,
    _NavigationMode mode,
  ) async {
    try {
      String costing;

      switch (mode) {
        case _NavigationMode.driving:
          costing = 'auto';
          break;

        case _NavigationMode.walking:
          costing = 'pedestrian';
          break;

        case _NavigationMode.cycling:
          costing = 'bicycle';
          break;
      }

      final body = {
        'locations': [
          {
            'lat': start.latitude,
            'lon': start.longitude,
          },
          {
            'lat': destination.latitude,
            'lon': destination.longitude,
          },
        ],
        'costing': costing,
        'units': 'kilometers',
        'directions_options': {
          'units': 'kilometers',
          'language': 'en-US',
        },
      };

      final response = await http.post(
        Uri.parse(
          'https://valhalla1.openstreetmap.de/route',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return null;
      }

      final trip = data['trip'];

      if (trip is! Map) {
        return null;
      }

      final summary = trip['summary'];

      final distance =
          (summary?['length'] ?? 0).toDouble();

      final durationSeconds =
          (summary?['time'] ?? 0).toDouble();

      final legs = trip['legs'];

      if (legs is! List || legs.isEmpty) {
        return null;
      }

      final firstLeg = legs.first;

      if (firstLeg is! Map) {
        return null;
      }

      final shape = firstLeg['shape'];

      if (shape == null) {
        return null;
      }

      final points = _decodePolyline(
        shape.toString(),
      );

      if (points.isEmpty) {
        return null;
      }

      final maneuvers =
          <_NavigationManeuver>[];

      final rawManeuvers =
          firstLeg['maneuvers'];

      if (rawManeuvers is List) {
        for (final item in rawManeuvers) {
          if (item is! Map) {
            continue;
          }

          final instruction =
              item['instruction']
                  ?.toString()
                  .trim();

          final beginShapeIndex =
              item['begin_shape_index'];

          if (instruction == null ||
              instruction.isEmpty) {
            continue;
          }

          if (beginShapeIndex == null) {
            continue;
          }

          final index =
              int.tryParse(
            beginShapeIndex.toString(),
          );

          if (index == null ||
              index < 0 ||
              index >= points.length) {
            continue;
          }

          maneuvers.add(
            _NavigationManeuver(
              instruction: instruction,
              location: points[index],
            ),
          );
        }
      }

      return _RouteResult(
        points: points,
        maneuvers: maneuvers,
        distance: distance * 1000,
        duration: durationSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // VALHALLA POLYLINE DECODER
  // ============================================================

  List<LatLng> _decodePolyline(
    String encoded,
  ) {
    final points = <LatLng>[];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int byte;

      do {
        if (index >= encoded.length) {
          return points;
        }

        byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final deltaLatitude =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      latitude += deltaLatitude;

      result = 0;
      shift = 0;

      do {
        if (index >= encoded.length) {
          return points;
        }

        byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final deltaLongitude =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      longitude += deltaLongitude;

      points.add(
        LatLng(
          latitude / 1e6,
          longitude / 1e6,
        ),
      );
    }

    return points;
  }

  // ============================================================
  // FIT ROUTE
  // ============================================================

  void _fitRouteOnMap() {
    if (_routePoints.isEmpty) {
      return;
    }

    final bounds =
        LatLngBounds.fromPoints(
      _routePoints,
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  // ============================================================
  // FINISH NAVIGATION
  // ============================================================

  Future<void> _finishNavigation() async {
    if (!_isNavigating) {
      return;
    }

    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isNavigating = false;
      _navigationInstruction =
          'You have arrived';
      _nextInstruction =
          'Destination reached';
      _remainingDistance = 0;
      _remainingDuration = 0;
      _currentRouteProgress = 1;
    });

    await _speak(
      'You have arrived at your destination.',
    );

    if (mounted) {
      _showArrivalDialog();
    }
  }

  // ============================================================
  // ARRIVAL DIALOG
  // ============================================================

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: green.withValues(
                      alpha: .12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: green,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'You have arrived',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  widget.title ??
                      'Destination reached',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STOP NAVIGATION
  // ============================================================

  Future<void> _stopNavigation() async {
    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isNavigating = false;
      _routePoints.clear();
      _maneuvers.clear();
      _currentRouteProgress = 0;
    });

    _showMessage(
      'Navigation stopped.',
    );
  }

  // ============================================================
  // VOICE TOGGLE
  // ============================================================

  Future<void> _toggleVoice() async {
    if (_voiceEnabled) {
      await _tts.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _voiceEnabled = false;
      });
    } else {
      setState(() {
        _voiceEnabled = true;
      });

      await _speak(
        _navigationInstruction,
      );
    }
  }

  // ============================================================
  // MAP MENU
  // ============================================================

  void _showMapMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            25,
          ),
          decoration: const BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                _menuItem(
                  Icons.location_on_rounded,
                  'Location',
                  'View shared location',
                  cyan,
                  () {
                    Navigator.pop(context);
                    _openFeature('location');
                  },
                ),

                _menuItem(
                  Icons.directions_rounded,
                  'Directions',
                  'Navigate to a destination',
                  green,
                  () {
                    Navigator.pop(context);
                    _openDirections();
                  },
                ),

                _menuItem(
                  Icons.radar_rounded,
                  'Nearby',
                  'Find ChattªX users nearby',
                  purple,
                  () {
                    Navigator.pop(context);
                    _openFeature('nearby');
                  },
                ),

                _menuItem(
                  Icons.bookmark_rounded,
                  'Saved places',
                  'Open your saved locations',
                  yellow,
                  () {
                    Navigator.pop(context);
                    _openFeature('saved');
                  },
                ),

                _menuItem(
                  Icons.share_location_rounded,
                  'Share location',
                  'Send your location',
                  pink,
                  () {
                    Navigator.pop(context);

                    _showMessage(
                      'Location sharing can be connected here.',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MENU ITEM
  // ============================================================

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: .10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(
    String value,
  ) {
    setState(() {
      _searchText = value;
      _showSearchResults =
          value.trim().isNotEmpty;
    });
  }

  void _onSearchSubmitted(
    String value,
  ) {
    final search = value.trim();

    if (search.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _searchText = search;
      _showSearchResults = true;
    });
  }

  void _closeSearchResults() {
    FocusScope.of(context).unfocus();

    setState(() {
      _showSearchResults = false;
    });
  }

  // ============================================================
  // MAP TAP
  // ============================================================

  void _onMapTap(
    TapPosition tapPosition,
    LatLng point,
  ) {
    if (_showSearchResults) {
      _closeSearchResults();
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  void _goToCurrentLocation() {
    if (_currentLocation == null) {
      _showMessage(
        'Your location is not available yet.',
      );

      return;
    }

    _mapController.move(
      _currentLocation!,
      _isNavigating ? 17 : 15,
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onBottomNavigation(
    int index,
  ) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        _openFeature('live');
        break;

      case 2:
        _openFeature('nearby');
        break;

      case 3:
        _openFeature('saved');
        break;
    }
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
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          90,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: cyan,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // MAP
            // ==================================================

            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _currentLocation ??
                          _destination ??
                          const LatLng(
                            -26.2041,
                            28.0473,
                          ),
                  initialZoom: 15,
                  onTap: _onMapTap,
                  interactionOptions:
                      const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.chatex.app',
                  ),

                  // ==================================================
                  // ROUTE
                  // ==================================================

                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 8,
                          color: Colors.black.withValues(
                            alpha: .25,
                          ),
                        ),
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5,
                          color:
                              _navigationMode ==
                                      _NavigationMode.walking
                                  ? cyan
                                  : purple,
                        ),
                      ],
                    ),

                  // ==================================================
                  // DESTINATION
                  // ==================================================

                  if (_destination != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _destination!,
                          width: 60,
                          height: 60,
                          child: _destinationMarker(),
                        ),
                      ],
                    ),

                  // ==================================================
                  // CURRENT LOCATION
                  // ==================================================

                  if (_currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 50,
                          height: 50,
                          child:
                              _currentLocationMarker(),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ==================================================
            // SEARCH BAR
            // ==================================================

            if (!_isNavigating)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: _buildSearchBar(),
              ),

            // ==================================================
            // NAVIGATION TOP BAR
            // ==================================================

            if (_isNavigating)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: _buildNavigationHeader(),
              ),

            // ==================================================
            // SEARCH RESULTS
            // ==================================================

            if (_showSearchResults &&
                !_isNavigating)
              Positioned(
                top: 70,
                left: 14,
                right: 14,
                child: _buildSearchResults(),
              ),

            // ==================================================
            // MAP LABEL
            // ==================================================

            if (!_showSearchResults &&
                !_isNavigating)
              Positioned(
                top: 76,
                left: 18,
                child: _buildMapLabel(),
              ),

            // ==================================================
            // ROUTE LOADING
            // ==================================================

            if (_isLoadingRoute)
              Positioned(
                top: 82,
                left: 18,
                right: 18,
                child: _buildRouteLoading(),
              ),

            // ==================================================
            // ROUTE ERROR
            // ==================================================

            if (_routeError &&
                !_isNavigating &&
                !_isLoadingRoute)
              Positioned(
                top: 82,
                left: 18,
                right: 18,
                child: _buildRouteError(),
              ),

            // ==================================================
            // NAVIGATION BOTTOM PANEL
            // ==================================================

            if (_isNavigating)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _buildNavigationPanel(),
              ),

            // ==================================================
            // NORMAL MAP CONTROLS
            // ==================================================

            if (!_isNavigating) ...[
              Positioned(
                right: 15,
                bottom: 182,
                child:
                    _buildCurrentLocationButton(),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 94,
                child: _buildMapActions(),
              ),

              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: _buildBottomNavigation(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: purple.withValues(alpha: .28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),

          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              decoration:
                  const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search ChattªX Maps',
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: _showMapMenu,
            child: Container(
              width: 42,
              height: 42,
              margin:
                  const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: purple.withValues(
                  alpha: .12,
                ),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: cyan,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP LABEL
  // ============================================================

  Widget _buildMapLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: cyan.withValues(alpha: .25),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_rounded,
            color: cyan,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'ChattªX Maps',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESTINATION MARKER
  // ============================================================

  Widget _destinationMarker() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: pink,
      ),
      padding: const EdgeInsets.all(8),
      child: const Icon(
        Icons.location_on_rounded,
        color: Colors.white,
        size: 27,
      ),
    );
  }

  // ============================================================
  // CURRENT LOCATION MARKER
  // ============================================================

  Widget _currentLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cyan.withValues(
              alpha: .12,
            ),
            shape: BoxShape.circle,
          ),
        ),

        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: cyan,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(
                  alpha: .5,
                ),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CURRENT LOCATION BUTTON
  // ============================================================

  Widget _buildCurrentLocationButton() {
    return GestureDetector(
      onTap: _goToCurrentLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: panel.withValues(alpha: .96),
          shape: BoxShape.circle,
          border: Border.all(
            color: cyan.withValues(alpha: .35),
          ),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: .12),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: cyan,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // MAP ACTIONS
  // ============================================================

  Widget _buildMapActions() {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        children: [
          _mapAction(
            icon: Icons.directions_rounded,
            title: 'Directions',
            color: green,
            onTap: _openDirections,
          ),

          _mapAction(
            icon:
                Icons.add_location_alt_rounded,
            title: 'Pick',
            color: yellow,
            onTap: () {
              _showMessage(
                'Tap and hold a location to pick it.',
              );
            },
          ),

          _mapAction(
            icon:
                Icons.share_location_rounded,
            title: 'Share',
            color: pink,
            onTap: () {
              _showMessage(
                'Location sharing can be connected here.',
              );
            },
          ),

          _mapAction(
            icon: Icons.layers_rounded,
            title: 'Layers',
            color: purple,
            onTap: () {
              _showMessage(
                'Map layers coming next.',
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP ACTION BUTTON
  // ============================================================

  Widget _mapAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
        ),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: .96),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: .35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color:
            const Color(0xff0D1421)
                .withValues(alpha: .98),
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color: purple.withValues(
            alpha: .28,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(
            icon: Icons.map_rounded,
            label: 'Map',
            index: 0,
          ),
          _bottomItem(
            icon: Icons.radar_rounded,
            label: 'Live',
            index: 1,
          ),
          _bottomItem(
            icon: Icons.near_me_rounded,
            label: 'Nearby',
            index: 2,
          ),
          _bottomItem(
            icon: Icons.bookmark_rounded,
            label: 'Saved',
            index: 3,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM ITEM
  // ============================================================

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected =
        _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        _onBottomNavigation(index);
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: selected
              ? purple.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? cyan
                  : Colors.white54,
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white54,
                fontSize: 9.5,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION HEADER
  // ============================================================

  Widget _buildNavigationHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .97),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: cyan.withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _stopNavigation,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    pink.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _modeTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.title ?? 'Destination',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _voiceEnabled
                    ? cyan.withValues(
                        alpha: .12,
                      )
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _voiceEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: _voiceEnabled
                    ? cyan
                    : Colors.white54,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODE TITLE
  // ============================================================

  String _modeTitle() {
    switch (_navigationMode) {
      case _NavigationMode.driving:
        return 'Driving navigation';

      case _NavigationMode.walking:
        return 'Walking navigation';

      case _NavigationMode.cycling:
        return 'Cycling navigation';
    }
  }

  // ============================================================
  // NAVIGATION PANEL
  // ============================================================

  Widget _buildNavigationPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        15,
        15,
        15,
        13,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .98),
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color: cyan.withValues(alpha: .22),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .4),
            blurRadius: 25,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      cyan.withValues(alpha: .10),
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: Icon(
                  _instructionIcon(),
                  color: cyan,
                  size: 26,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  _navigationInstruction,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Container(
            height: 1,
            color: Colors.white10,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _navigationStat(
                _distanceText(
                  _remainingDistance,
                ),
                'remaining',
              ),

              _navigationStat(
                _formatDuration(
                  _remainingDuration,
                ),
                'ETA',
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      _nextInstruction,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          LinearProgressIndicator(
            minHeight: 4,
            value: _currentRouteProgress,
            backgroundColor: Colors.white10,
            valueColor:
                const AlwaysStoppedAnimation<Color>(
              cyan,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAVIGATION STAT
  // ============================================================

  Widget _navigationStat(
    String value,
    String label,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
  // PROGRESS
  // ============================================================

  double _navigationProgress() {
    if (_destination == null ||
        _currentLocation == null ||
        _routePoints.isEmpty) {
      return 0;
    }

    final total = _routePoints.length;

    if (total <= 1) {
      return 0;
    }

    double closestDistance =
        double.infinity;

    int closestIndex = 0;

    for (int i = 0;
        i < _routePoints.length;
        i++) {
      final distance =
          _distanceInMeters(
        _currentLocation!,
        _routePoints[i],
      );

      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    return (closestIndex /
            (total - 1))
        .clamp(0.0, 1.0);
  }

  // ============================================================
  // INSTRUCTION ICON
  // ============================================================

  IconData _instructionIcon() {
    final instruction =
        _navigationInstruction.toLowerCase();

    if (instruction.contains('u-turn')) {
      return Icons.u_turn_left_rounded;
    }

    if (instruction.contains('left')) {
      return Icons.turn_left_rounded;
    }

    if (instruction.contains('right')) {
      return Icons.turn_right_rounded;
    }

    if (instruction.contains('arrive')) {
      return Icons.location_on_rounded;
    }

    return Icons.straight_rounded;
  }

  // ============================================================
  // DURATION
  // ============================================================

  String _formatDuration(
    double seconds,
  ) {
    final minutes =
        (seconds / 60).round();

    if (minutes < 1) {
      return '<1 min';
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;

    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours hr';
    }

    return '$hours hr $remaining min';
  }

  // ============================================================
  // ROUTE LOADING
  // ============================================================

  Widget _buildRouteLoading() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .97),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: cyan.withValues(alpha: .25),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color: cyan,
            ),
          ),

          SizedBox(width: 11),

          Expanded(
            child: Text(
              'Finding the best route...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE ERROR
  // ============================================================

  Widget _buildRouteError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .97),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: pink.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: pink,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _routeErrorMessage.isEmpty
                  ? 'Could not find a route.'
                  : _routeErrorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  Widget _buildSearchResults() {
    return Container(
      constraints:
          const BoxConstraints(
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: .98),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: purple.withValues(alpha: .28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              15,
              13,
              12,
              8,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: cyan,
                  size: 19,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Search for "$_searchText"',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap:
                      _closeSearchResults,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: Colors.white10,
          ),

          _searchOption(
            icon:
                Icons.my_location_rounded,
            color: cyan,
            title:
                'Search around my location',
            subtitle:
                'Use your current position',
            onTap: () {
              _closeSearchResults();
              _goToCurrentLocation();
            },
          ),

          _searchOption(
            icon:
                Icons.near_me_rounded,
            color: purple,
            title:
                'Find nearby places',
            subtitle:
                'Discover places around you',
            onTap: () {
              _closeSearchResults();
              _openFeature('nearby');
            },
          ),

          _searchOption(
            icon:
                Icons.directions_rounded,
            color: green,
            title:
                'Get directions',
            subtitle:
                'Choose driving, walking or cycling',
            onTap: () {
              _closeSearchResults();
              _openDirections();
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH OPTION
  // ============================================================

  Widget _searchOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: .10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _navigationTimer?.cancel();

    _positionSubscription?.cancel();

    _searchController.dispose();

    // IMPORTANT:
    // FlutterTts has stop(), not shutdown().
    // dispose() cannot be async, so do not use await here.
    _tts.stop();

    super.dispose();
  }
}

// ================================================================
// NAVIGATION MODE
// ================================================================

enum _NavigationMode {
  driving,
  walking,
  cycling,
}

// ================================================================
// ROUTE RESULT
// ================================================================

class _RouteResult {
  final List<LatLng> points;

  final List<_NavigationManeuver> maneuvers;

  final double distance;

  final double duration;

  const _RouteResult({
    required this.points,
    required this.maneuvers,
    required this.distance,
    required this.duration,
  });
}

// ================================================================
// NAVIGATION MANEUVER
// ================================================================

class _NavigationManeuver {
  final String instruction;

  final LatLng location;

  const _NavigationManeuver({
    required this.instruction,
    required this.location,
  });
}