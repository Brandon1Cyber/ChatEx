import 'package:flutter/material.dart';

// ================================================================
// CHATTªX USER MAP MARKER
// ================================================================
//
// This widget is used for showing a ChattªX user on the map.
//
// Later we can pass the real user's Firebase profile picture,
// username, online status and other information into it.
//

class ChatexUserMapMarker extends StatelessWidget {
  final String? imageUrl;

  final String? name;

  final bool isOnline;

  final bool isMe;

  final double size;

  final VoidCallback? onTap;

  const ChatexUserMapMarker({
    super.key,
    this.imageUrl,
    this.name,
    this.isOnline = false,
    this.isMe = false,
    this.size = 52,
    this.onTap,
  });

  // ============================================================
  // CHATTªX COLORS
  // ============================================================

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  static const Color pink =
      Color(0xffFF3D81);

  static const Color dark =
      Color(0xff101827);

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 16,
        height: size + 30,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [

            // ====================================================
            // USER AVATAR
            // ====================================================

            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isMe
                      ? const [
                          cyan,
                          purple,
                        ]
                      : isOnline
                          ? const [
                              cyan,
                              purple,
                            ]
                          : const [
                              purple,
                              Color(0xff4B267F),
                            ],
                ),

                boxShadow: [
                  BoxShadow(
                    color: isOnline
                        ? cyan.withValues(
                            alpha: .35,
                          )
                        : purple.withValues(
                            alpha: .25,
                          ),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),

              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark,
                ),
                clipBehavior:
                    Clip.antiAlias,

                child: _buildProfileImage(),
              ),
            ),

            // ====================================================
            // ONLINE INDICATOR
            // ====================================================

            if (isOnline)
              Positioned(
                right: 5,
                top: 2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xff00D68F,
                    ),
                    border: Border.all(
                      color: dark,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xff00D68F,
                        ).withValues(
                          alpha: .45,
                        ),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ),

            // ====================================================
            // USER NAME
            // ====================================================

            if (name != null &&
                name!.trim().isNotEmpty)
              Positioned(
                top: size + 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    constraints:
                        BoxConstraints(
                      maxWidth:
                          size + 20,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration:
                        BoxDecoration(
                      color: dark.withValues(
                        alpha: .94,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                      border:
                          Border.all(
                        color:
                            purple.withValues(
                          alpha: .25,
                        ),
                      ),
                    ),
                    child: Text(
                      name!,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w600,
                      ),
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
  // PROFILE IMAGE
  // ============================================================

  Widget _buildProfileImage() {
    if (imageUrl == null ||
        imageUrl!.trim().isEmpty) {
      return _buildDefaultAvatar();
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,

      loadingBuilder:
          (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return _buildDefaultAvatar();
      },

      errorBuilder:
          (
        context,
        error,
        stackTrace,
      ) {
        return _buildDefaultAvatar();
      },
    );
  }

  // ============================================================
  // DEFAULT AVATAR
  // ============================================================

  Widget _buildDefaultAvatar() {
    return Container(
      color: dark,
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white54,
          size: 25,
        ),
      ),
    );
  }
}

// ================================================================
// CURRENT LOCATION MARKER
// ================================================================
//
// Used for the phone's own location.
//

class ChatexCurrentLocationMarker
    extends StatelessWidget {
  final double size;

  const ChatexCurrentLocationMarker({
    super.key,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [

          // ======================================================
          // OUTER GLOW
          // ======================================================

          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xff00E5FF,
              ).withValues(
                alpha: .13,
              ),
            ),
          ),

          // ======================================================
          // MIDDLE RING
          // ======================================================

          Container(
            width: size * .62,
            height: size * .62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xff00E5FF,
              ).withValues(
                alpha: .20,
              ),
            ),
          ),

          // ======================================================
          // LOCATION DOT
          // ======================================================

          Container(
            width: size * .34,
            height: size * .34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xff00E5FF,
              ),
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xff00E5FF,
                  ).withValues(
                    alpha: .55,
                  ),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SIMPLE PLACE MARKER
// ================================================================
//
// Used for restaurants, shops, saved places, etc.
//

class ChatexPlaceMapMarker
    extends StatelessWidget {
  final IconData icon;

  final Color color;

  final String? label;

  final double size;

  final VoidCallback? onTap;

  const ChatexPlaceMapMarker({
    super.key,
    this.icon = Icons.location_on_rounded,
    this.color = const Color(
      0xff8A3DFF,
    ),
    this.label,
    this.size = 42,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 20,
        height: size + 30,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [

            // ====================================================
            // ICON
            // ====================================================

            Container(
              width: size,
              height: size,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xff101827,
                ),
                border: Border.all(
                  color:
                      color.withValues(
                    alpha: .55,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        color.withValues(
                      alpha: .25,
                    ),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: size * .48,
              ),
            ),

            // ====================================================
            // LABEL
            // ====================================================

            if (label != null &&
                label!.trim().isNotEmpty)
              Container(
                margin:
                    const EdgeInsets.only(
                  top: 3,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration:
                    BoxDecoration(
                  color: const Color(
                    0xff101827,
                  ).withValues(
                    alpha: .94,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    7,
                  ),
                ),
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}