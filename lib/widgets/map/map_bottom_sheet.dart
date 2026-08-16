import 'package:flutter/material.dart';

class ChatexMapBottomSheet extends StatelessWidget {
  final VoidCallback? onLocationPressed;
  final VoidCallback? onLivePressed;
  final VoidCallback? onNearbyPressed;
  final VoidCallback? onSavedPressed;
  final VoidCallback? onDirectionsPressed;
  final VoidCallback? onPickLocationPressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onSettingsPressed;

  const ChatexMapBottomSheet({
    super.key,
    this.onLocationPressed,
    this.onLivePressed,
    this.onNearbyPressed,
    this.onSavedPressed,
    this.onDirectionsPressed,
    this.onPickLocationPressed,
    this.onSharePressed,
    this.onSettingsPressed,
  });

  // ============================================================
  // CHATTªX COLORS
  // ============================================================

  static const Color panel = Color(0xff0D1421);
  static const Color panelLight = Color(0xff101827);

  static const Color purple = Color(0xff8A3DFF);
  static const Color cyan = Color(0xff00E5FF);
  static const Color pink = Color(0xffFF3D81);
  static const Color green = Color(0xff00D68F);
  static const Color yellow = Color(0xffFFB020);

  // ============================================================
  // SHOW
  // ============================================================

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onLocationPressed,
    VoidCallback? onLivePressed,
    VoidCallback? onNearbyPressed,
    VoidCallback? onSavedPressed,
    VoidCallback? onDirectionsPressed,
    VoidCallback? onPickLocationPressed,
    VoidCallback? onSharePressed,
    VoidCallback? onSettingsPressed,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return ChatexMapBottomSheet(
          onLocationPressed: onLocationPressed,
          onLivePressed: onLivePressed,
          onNearbyPressed: onNearbyPressed,
          onSavedPressed: onSavedPressed,
          onDirectionsPressed: onDirectionsPressed,
          onPickLocationPressed: onPickLocationPressed,
          onSharePressed: onSharePressed,
          onSettingsPressed: onSettingsPressed,
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
          border: Border.all(
            color: purple.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================================================
              // HANDLE
              // ==================================================

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cyan.withValues(alpha: 0.10),
                      border: Border.all(
                        color: cyan.withValues(alpha: 0.24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cyan.withValues(alpha: 0.08),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: cyan,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 11),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ChattªX Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Explore the world around you',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.05,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================================================
              // QUICK MAP ACTIONS
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.radar_rounded,
                      title: 'Live',
                      subtitle: 'Share live',
                      color: pink,
                      onTap: onLivePressed,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _actionButton(
                      icon: Icons.near_me_rounded,
                      title: 'Nearby',
                      subtitle: 'People nearby',
                      color: purple,
                      onTap: onNearbyPressed,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _actionButton(
                      icon: Icons.bookmark_rounded,
                      title: 'Saved',
                      subtitle: 'Saved places',
                      color: cyan,
                      onTap: onSavedPressed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ==================================================
              // NAVIGATION ACTIONS
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.directions_rounded,
                      title: 'Directions',
                      subtitle: 'Navigate',
                      color: green,
                      onTap: onDirectionsPressed,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _actionButton(
                      icon: Icons.add_location_alt_rounded,
                      title: 'Pick',
                      subtitle: 'Choose a place',
                      color: yellow,
                      onTap: onPickLocationPressed,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _actionButton(
                      icon: Icons.share_location_rounded,
                      title: 'Share',
                      subtitle: 'Send location',
                      color: cyan,
                      onTap: onSharePressed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // MY LOCATION
              //
              // Kept separate from the map's location button.
              // This is an intentional "action" rather than
              // another permanent map control.
              // ==================================================

              GestureDetector(
                onTap: onLocationPressed,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cyan.withValues(alpha: 0.12),
                        purple.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cyan.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyan.withValues(alpha: 0.10),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: cyan,
                          size: 18,
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Center the map on me',
                              style: TextStyle(
                                color: Color.fromARGB(255, 180, 162, 162),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color.fromARGB(255, 180, 162, 162),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // SETTINGS
              // ==================================================

              GestureDetector(
                onTap: onSettingsPressed,
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    color: panelLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Color.fromARGB(255, 180, 162, 162).withValues(
                        alpha: 0.07,
                      ),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: Color.fromARGB(255, 180, 162, 162),
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Map settings',
                        style: TextStyle(
                          color: Color.fromARGB(255, 180, 162, 162),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 88,
          decoration: BoxDecoration(
            color: panelLight,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: color.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color.fromARGB(255, 180, 162, 162),
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}