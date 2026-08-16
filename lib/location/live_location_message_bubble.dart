import 'package:flutter/material.dart';

import '../location/live_location_session.dart';

class ChattaXLiveLocationMessageBubble extends StatelessWidget {
  final ChattaXLiveLocationSession session;

  /// Called when the user wants to open the full map.
  final VoidCallback? onOpenMap;

  /// Called when the owner wants to stop sharing.
  final VoidCallback? onStopSharing;

  /// Whether the current user owns this live location.
  final bool isMine;

  const ChattaXLiveLocationMessageBubble({
    super.key,
    required this.session,
    this.onOpenMap,
    this.onStopSharing,
    this.isMine = false,
  });

  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonBlue = Color(0xFF38BDF8);
  static const Color liveRed = Color(0xFFFF3B6B);
  static const Color background = Color(0xFF12101C);

  @override
  Widget build(BuildContext context) {
    final bool active =
        session.isActive && !session.isExpired;

    return GestureDetector(
      onTap: onOpenMap,
      child: Container(
        width: 290,
        margin: const EdgeInsets.symmetric(
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? neonPurple.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? neonPurple.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapPreview(
              latitude: session.latitude,
              longitude: session.longitude,
              active: active,
              onTap: onOpenMap,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                15,
                13,
                15,
                14,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? liveRed.withValues(
                                  alpha: 0.12,
                                )
                              : Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? liveRed.withValues(
                                    alpha: 0.25,
                                  )
                                : Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? liveRed
                                    : Colors.white38,
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: liveRed
                                              .withValues(
                                            alpha: 0.65,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              active
                                  ? 'LIVE'
                                  : 'ENDED',
                              style: TextStyle(
                                color: active
                                    ? liveRed
                                    : Colors.white54,
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      Icon(
                        Icons.my_location_rounded,
                        color: active
                            ? neonBlue
                            : Colors.white38,
                        size: 17,
                      ),
                    ],
                  ),

                  const SizedBox(height: 11),

                  Text(
                    active
                        ? 'Live location'
                        : 'Location sharing ended',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '${session.latitude.toStringAsFixed(5)}, '
                    '${session.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _InfoItem(
                        icon: Icons.near_me_rounded,
                        text: 'Location',
                      ),

                      const SizedBox(width: 14),

                      _InfoItem(
                        icon: Icons.update_rounded,
                        text: active
                            ? session.remainingLabel
                            : 'Ended',
                      ),
                    ],
                  ),

                  const SizedBox(height: 13),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(
                        Icons.map_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Open ChattªX Map',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(13),
                        ),
                        textStyle:
                            const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  if (isMine &&
                      active &&
                      onStopSharing != null) ...[
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton(
                        onPressed: onStopSharing,
                        style: TextButton.styleFrom(
                          foregroundColor: liveRed,
                          backgroundColor:
                              liveRed.withValues(
                            alpha: 0.07,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Stop sharing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// MAP PREVIEW
// ============================================================

class _MapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool active;
  final VoidCallback? onTap;

  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.active,
    this.onTap,
  });

  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonBlue = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 145,
        width: double.infinity,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF171326),
                    const Color(0xFF0D1420),
                    const Color(0xFF11101C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomPaint(
                painter: _MapGridPainter(),
                child: const SizedBox.expand(),
              ),
            ),

            // Decorative roads
            Positioned(
              left: -20,
              top: 75,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  width: 340,
                  height: 2,
                  color: Colors.white.withValues(
                    alpha: 0.10,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 70,
              top: -20,
              child: Transform.rotate(
                angle: 0.65,
                child: Container(
                  width: 230,
                  height: 2,
                  color: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
            ),

            // Location pulse
            Center(
              child: _LocationPulse(
                active: active,
              ),
            ),

            // Coordinates
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Text(
                  '${latitude.toStringAsFixed(4)}, '
                  '${longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Open map indicator
            Positioned(
              right: 11,
              bottom: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: neonPurple.withValues(
                    alpha: 0.90,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Live label
            if (active)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: neonBlue,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'LIVE LOCATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
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
}


// ============================================================
// LOCATION PULSE
// ============================================================

class _LocationPulse extends StatelessWidget {
  final bool active;

  const _LocationPulse({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    const Color purple =
        Color(0xFF8B5CF6);

    const Color blue =
        Color(0xFF38BDF8);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? purple.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: active
              ? purple.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? const LinearGradient(
                    colors: [
                      purple,
                      blue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active
                ? null
                : Colors.white30,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: blue.withValues(
                        alpha: 0.55,
                      ),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    );
  }
}


// ============================================================
// INFORMATION ITEM
// ============================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 14,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


// ============================================================
// MAP GRID PAINTER
// ============================================================

class _MapGridPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: 0.035,
      )
      ..strokeWidth = 1;

    const double spacing = 30;

    for (
      double x = 0;
      x <= size.width;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (
      double y = 0;
      y <= size.height;
      y += spacing
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}