import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/verified_name.dart';

class ChatHeader extends StatelessWidget {
  final String name;
  final String status;
  final String image;
  final String userId;
  final bool showQuickActions;
  final bool isVerified;
  final bool isOnline;
  final bool isTyping;

  final VoidCallback? onBack;
  final VoidCallback? onNameTap;
  final VoidCallback? onVideoCall;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onSearch;
  final VoidCallback? onMenu;
  final VoidCallback? onProfileTap;

  const ChatHeader({
    super.key,
    required this.name,
    required this.status,
    required this.image,
    required this.userId,
    this.showQuickActions = true,
    this.isVerified = false,
    this.isOnline = false,
    this.isTyping = false,
    this.onBack,
    this.onNameTap,
    this.onVideoCall,
    this.onVoiceCall,
    this.onSearch,
    this.onMenu,
    this.onProfileTap,
  });

  // ============================================================
  // CHATTªX COLORS
  // ============================================================

  static const Color background =
      Color(0xff020611);

  static const Color header =
      Color(0xff030817);

  static const Color buttonBackground =
      Color(0xff080D20);

  static const Color primaryText =
      Colors.white;

  static const Color secondaryText =
      Color(0xffC9CBE0);

  static const Color cyan =
      Color(0xff00D9FF);

  static const Color blue =
      Color(0xff168EFF);

  static const Color purple =
      Color(0xff762CFF);

  static const Color pink =
      Color(0xffB64DFF);

  static const Color online =
      Color(0xff16F15D);

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // LOAD VERIFICATION STATUS FROM FIRESTORE
    // ============================================================
    //
    // The blue tick is shown when either:
    //
    // 1. isVerified was already passed as true
    // OR
    // 2. users/{userId}/verified is true
    //
    // ============================================================

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),

      builder: (context, snapshot) {
        bool firestoreVerified = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();

          if (data != null) {
            firestoreVerified =
                data['verified'] == true;
          }
        }

        final bool verified =
            isVerified || firestoreVerified;

        return AnimatedContainer(
          duration:
              const Duration(milliseconds: 250),

          curve:
              Curves.easeOut,

          padding:
              const EdgeInsets.only(
            top: 4,
            bottom: 0,
          ),

          decoration:
              const BoxDecoration(
            color:
                background,
          ),

          child:
              SizedBox(
            height: 78,

            child:
                Stack(
              clipBehavior:
                  Clip.none,

              children: [

                // ======================================================
                // HEADER BACKGROUND
                // ======================================================

                ClipPath(
                  clipper:
                      _ChatHeaderClipper(),

                  child:
                      BackdropFilter(
                    filter:
                        ImageFilter.blur(
                      sigmaX: 18,
                      sigmaY: 18,
                    ),

                    child:
                        Container(
                      height: 78,

                      decoration:
                          const BoxDecoration(
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment.topCenter,

                          end:
                              Alignment.bottomCenter,

                          colors: [
                            Color(
                              0xff020714,
                            ),
                            Color(
                              0xff03091A,
                            ),
                            Color(
                              0xff020611,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ======================================================
                // SUBTLE NEON EDGE
                // ======================================================

                Positioned.fill(
                  child:
                      IgnorePointer(
                    child:
                        CustomPaint(
                      painter:
                          _HeaderGlowPainter(),
                    ),
                  ),
                ),

                // ======================================================
                // HEADER CONTENT
                // ======================================================

                Row(
                  children: [

                    // ==================================================
                    // BACK BUTTON
                    // ==================================================

                    GestureDetector(
                      onTap:
                          onBack,

                      child:
                          _circleButton(
                        icon:
                            Icons.arrow_back_rounded,

                        iconColor:
                            Colors.white,

                        size:
                            28,
                      ),
                    ),

                    // ==================================================
                    // PROFILE AREA
                    // ==================================================

                    Expanded(
                      child:
                          GestureDetector(
                        behavior:
                            HitTestBehavior.opaque,

                        onTap:
                            onProfileTap,

                        child:
                            Row(
                          children: [

                            const SizedBox(
                              width: 5,
                            ),

                            // ==================================================
                            // PROFILE IMAGE
                            // ==================================================

                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                right: 6,
                              ),

                              child:
                                  Stack(
                                alignment:
                                    Alignment.center,

                                children: [

                                  // ==================================================
                                  // OUTER PROFILE RING
                                  // ==================================================

                                  Container(
                                    width: 48,
                                    height: 48,

                                    decoration:
                                        const BoxDecoration(
                                      shape:
                                          BoxShape.circle,

                                      gradient:
                                          LinearGradient(
                                        begin:
                                            Alignment.topLeft,

                                        end:
                                            Alignment.bottomRight,

                                        colors: [
                                          cyan,
                                          blue,
                                          purple,
                                          pink,
                                        ],
                                      ),
                                    ),
                                  ),

                                  // ==================================================
                                  // INNER DARK RING
                                  // ==================================================

                                  Container(
                                    width: 45,
                                    height: 45,

                                    decoration:
                                        const BoxDecoration(
                                      color:
                                          header,

                                      shape:
                                          BoxShape.circle,
                                    ),
                                  ),

                                  // ==================================================
                                  // PROFILE IMAGE
                                  // ==================================================

                                  CircleAvatar(
                                    radius: 21,

                                    backgroundColor:
                                        buttonBackground,

                                    backgroundImage:
                                        image.isNotEmpty
                                            ? image.startsWith(
                                                "http",
                                              )
                                                ? NetworkImage(
                                                    image,
                                                  )
                                                : AssetImage(
                                                    image,
                                                  ) as ImageProvider
                                            : null,

                                    child:
                                        image.isEmpty
                                            ? const Icon(
                                                Icons.person,

                                                color:
                                                    Colors.white54,

                                                size:
                                                    23,
                                              )
                                            : null,
                                  ),
                                ],
                              ),
                            ),

                            // ==================================================
                            // NAME + STATUS
                            // ==================================================

                            Expanded(
                              child:
                                  Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,

                                crossAxisAlignment:
                                    CrossAxisAlignment.start,

                                children: [

                                  // ==================================================
                                  // NAME + VERIFIED
                                  // ==================================================

                                  GestureDetector(
  onTap: onNameTap,
  behavior: HitTestBehavior.opaque,
  child: VerifiedName(
    name: name,
    verified: verified,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    textColor: primaryText,
  ),
),

                                  const SizedBox(
                                    height: 3,
                                  ),

                                  // ==================================================
                                  // STATUS
                                  // ==================================================

                                  Row(
                                    children: [

                                      if (isOnline)
                                        Container(
                                          width: 6,
                                          height: 6,

                                          decoration:
                                              const BoxDecoration(
                                            color:
                                                online,

                                            shape:
                                                BoxShape.circle,
                                          ),
                                        ),

                                      if (isOnline)
                                        const SizedBox(
                                          width: 6,
                                        ),

                                      Flexible(
                                        child:
                                            Text(
                                          isTyping
                                              ? 'typing...'
                                              : status,

                                          maxLines:
                                              1,

                                          overflow:
                                              TextOverflow.ellipsis,

                                          style:
                                              TextStyle(
                                            color:
                                                isTyping
                                                    ? cyan
                                                    : secondaryText,

                                            fontSize:
                                                11,

                                            fontWeight:
                                                isTyping
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (showQuickActions) ...[
                      const SizedBox(
                        width: 6,
                      ),

                      // ==================================================
                      // VIDEO CALL
                      // ==================================================

                      GestureDetector(
                        onTap:
                            onVideoCall,

                        child:
                            _circleButton(
                          icon:
                              Icons.videocam_rounded,

                          iconColor:
                              Colors.white,

                          size:
                              28,
                        ),
                      ),

                      const SizedBox(
                        width: 6,
                      ),

                      // ==================================================
                      // VOICE CALL
                      // ==================================================

                      GestureDetector(
                        onTap:
                            onVoiceCall,

                        child:
                            _circleButton(
                          icon:
                              Icons.call_rounded,

                          iconColor:
                              Colors.white,

                          size:
                              28,
                        ),
                      ),

                      const SizedBox(
                        width: 6,
                      ),

                      // ==================================================
                      // MENU
                      // ==================================================

                      GestureDetector(
                        onTap:
                            onMenu,

                        child:
                            _circleButton(
                          icon:
                              Icons.more_vert_rounded,

                          iconColor:
                              Colors.white,

                          size:
                              28,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CHATTªX CIRCLE BUTTON
  // ============================================================

  Widget _circleButton({
    required IconData icon,
    required Color iconColor,
    required double size,
  }) {
    return Container(
      width:
          size,

      height:
          size,

      decoration:
          BoxDecoration(
        color:
            buttonBackground,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xff5538FF,
          ).withValues(
            alpha: 0.48,
          ),

          width:
              1,
        ),

        boxShadow: [
          // VERY SMALL BLUE GLOW
          BoxShadow(
            color:
                cyan.withValues(
              alpha: 0.045,
            ),

            blurRadius:
                7,

            spreadRadius:
                0,
          ),

          // VERY SMALL PURPLE GLOW
          BoxShadow(
            color:
                purple.withValues(
              alpha: 0.055,
            ),

            blurRadius:
                8,

            spreadRadius:
                0,
          ),
        ],
      ),

      child:
          Icon(
        icon,

        size:
            20,

        color:
            iconColor,
      ),
    );
  }
}

// ================================================================
// HEADER SHAPE
// ================================================================

class _ChatHeaderClipper
    extends CustomClipper<Path> {

  @override
  Path getClip(
    Size size,
  ) {
    final Path path =
        Path();

    path.moveTo(
      0,
      0,
    );

    path.lineTo(
      size.width,
      0,
    );

    path.lineTo(
      size.width,
      54,
    );

    path.cubicTo(
      size.width * .94,
      60,

      size.width * .90,
      68,

      size.width * .80,
      73,
    );

    path.cubicTo(
      size.width * .70,
      78,

      size.width * .58,
      78,

      size.width * .45,
      78,
    );

    path.lineTo(
      0,
      78,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant CustomClipper<Path> oldClipper,
  ) {
    return false;
  }
}

// ================================================================
// SUBTLE NEON BOTTOM LINE
// ================================================================

class _HeaderGlowPainter
    extends CustomPainter {

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Path path =
        Path();

    path.moveTo(
      0,
      78,
    );

    path.cubicTo(
      size.width * .35,
      78,

      size.width * .58,
      78,

      size.width * .70,
      77,
    );

    path.cubicTo(
      size.width * .82,
      76,

      size.width * .91,
      69,

      size.width * .96,
      62,
    );

    path.cubicTo(
      size.width * .985,
      58,

      size.width * .995,
      56,

      size.width,
      54,
    );

    // ============================================================
    // VERY SUBTLE OUTER GLOW
    // ============================================================

    final Paint softGlow =
        Paint()
          ..style =
              PaintingStyle.stroke

          ..strokeWidth =
              1.5

          ..maskFilter =
              const MaskFilter.blur(
            BlurStyle.normal,
            3,
          )

          ..shader =
              const LinearGradient(
            colors: [
              Color(0xff00D9FF),
              Color(0xff168EFF),
              Color(0xff762CFF),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              0,
              size.width,
              size.height,
            ),
          );

    canvas.drawPath(
      path,
      softGlow,
    );

    // ============================================================
    // MAIN SHARP LINE
    // ============================================================

    final Paint linePaint =
        Paint()
          ..style =
              PaintingStyle.stroke

          ..strokeWidth =
              0.9

          ..shader =
              const LinearGradient(
            colors: [
              Color(0xff00D9FF),
              Color(0xff168EFF),
              Color(0xff762CFF),
              Color(0xffB64DFF),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              0,
              size.width,
              size.height,
            ),
          );

    canvas.drawPath(
      path,
      linePaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}