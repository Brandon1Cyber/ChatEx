import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================
// CHATTAX VOICE CALL SCREEN
// ============================================================
//
// Futuristic Chattax voice-call interface.
//
// Includes:
// • Chattax Call header
// • End-to-end encryption indicator
// • Caller profile picture
// • Animated neon profile ring
// • Voice pulse visualization
// • Verified badge
// • Caller name
// • Call duration
// • Connection status
// • Voice Pulse
// • Atmosphere
// • Call Shield
// • Participants
// • Live Reactions
// • Call Memory
// • Mute
// • Speaker
// • Keypad
// • Add Call
// • Hold
// • End Call
// • Switch Audio
// • More
// • Swipe up for more
// • Now Playing
// • Sharing Location
//
// Uses withValues(alpha: ...) instead of withOpacity(...).
//
// ============================================================

class VoiceCallScreen extends StatefulWidget {
  final String callerName;
  final String? profileImageUrl;

  const VoiceCallScreen({
    super.key,
    this.callerName = 'Sarah Johnson',
    this.profileImageUrl,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // ANIMATION CONTROLLERS
  // ============================================================

  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _waveController;
  late AnimationController _glowController;

  // ============================================================
  // CALL STATE
  // ============================================================

  bool isMuted = false;
  bool isSpeakerOn = true;
  bool isOnHold = false;
  bool isLocationSharing = true;
  bool isCallMemoryOn = true;
  bool isVoicePulseActive = true;

  int participants = 2;

  Duration callDuration = const Duration(
    minutes: 12,
    seconds: 47,
  );

  String selectedReaction = '';

  Timer? _callTimer;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _startCallTimer();
  }

  // ============================================================
  // CALL TIMER
  // ============================================================

  void _startCallTimer() {
    _callTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || isOnHold) {
          return;
        }

        setState(() {
          callDuration += const Duration(seconds: 1);
        });
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _callTimer?.cancel();

    _pulseController.dispose();
    _ringController.dispose();
    _waveController.dispose();
    _glowController.dispose();

    super.dispose();
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // END CALL
  // ============================================================

  void _endCall() {
    _callTimer?.cancel();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // KEYPAD
  // ============================================================

  void _showKeypad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return const _KeypadSheet();
      },
    );
  }

  // ============================================================
  // MORE
  // ============================================================

  void _showMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'More Call Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _moreOption(
                  Icons.person_add_alt_1_rounded,
                  'Add Participant',
                  Colors.purpleAccent,
                ),
                _moreOption(
                  Icons.message_rounded,
                  'Open Chat',
                  Colors.cyanAccent,
                ),
                _moreOption(
                  Icons.notifications_off_rounded,
                  'Mute Notifications',
                  Colors.orangeAccent,
                ),
                _moreOption(
                  Icons.security_rounded,
                  'Security Information',
                  Colors.greenAccent,
                ),
                _moreOption(
                  Icons.report_outlined,
                  'Report Call',
                  Colors.redAccent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MORE OPTION
  // ============================================================

  Widget _moreOption(
    IconData icon,
    String title,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
        ),
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050D),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildBackground(),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 4,
                      bottom: 180,
                    ),
                    child: Column(
                      children: [
                        _buildCallerSection(),
                        const SizedBox(height: 22),
                        _buildCallInfoCards(),
                        const SizedBox(height: 16),
                        _buildLiveReactions(),
                        const SizedBox(height: 16),
                        _buildCallMemory(),
                        const SizedBox(height: 28),
                        _buildCallControls(),
                        const SizedBox(height: 18),
                        _buildSwipeIndicator(),
                        const SizedBox(height: 24),
                        _buildBottomInformation(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Center(
                child: Container(
                  width: 135,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
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
  // BACKGROUND
  // ============================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.45),
              radius: 1.15,
              colors: [
                Color(0xFF09162B),
                Color(0xFF02050D),
                Color(0xFF010309),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, child) {
            final value = _glowController.value;

            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.7,
                  colors: [
                    Colors.purple.withValues(
                      alpha: 0.035 + (value * 0.025),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 16,
            child: _circleButton(
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            top: 12,
            child: Column(
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Chattax',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' Call',
                        style: TextStyle(
                          color: Color(0xFFB75CFF),
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 17,
                      color: Colors.white54,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'End-to-end Encrypted',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 16,
            child: _circleButton(
              icon: Icons.more_vert_rounded,
              onTap: _showMore,
            ),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A111F),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // ============================================================
  // CALLER SECTION
  // ============================================================

  Widget _buildCallerSection() {
    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 265,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _VoiceWavePainter(
                        animation: _waveController.value,
                        active: isVoicePulseActive,
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _ringController,
                builder: (_, child) {
                  return Transform.rotate(
                    angle: _ringController.value *
                        math.pi *
                        2,
                    child: Container(
                      width: 248,
                      height: 248,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFF28E7FF),
                            Color(0xFF716BFF),
                            Color(0xFFC33EFF),
                            Color(0xFF28E7FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent
                                .withValues(alpha: 0.14),
                            blurRadius: 35,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.purpleAccent
                                .withValues(alpha: 0.16),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF02050D),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: ClipOval(
                            child: _buildProfileImage(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 86,
                bottom: 26,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    return Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF061421),
                        border: Border.all(
                          color: Colors.cyanAccent
                              .withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(
                              alpha: 0.15 +
                                  _pulseController.value * 0.2,
                            ),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF20F5D0),
                        size: 31,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.callerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF983DFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _formatDuration(callDuration),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_cellular_alt_rounded,
              color: Color(0xFF20EFAF),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Excellent Connection',
              style: TextStyle(
                color: Color(0xFF20EFAF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Widget _buildProfileImage() {
    if (widget.profileImageUrl != null &&
        widget.profileImageUrl!.isNotEmpty) {
      return Image.network(
        widget.profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _defaultProfile();
        },
      );
    }

    return _defaultProfile();
  }

  Widget _defaultProfile() {
    return Container(
      color: const Color(0xFF151B2B),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white38,
          size: 110,
        ),
      ),
    );
  }

  // ============================================================
  // CALL INFO CARDS
  // ============================================================

  Widget _buildCallInfoCards() {
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: const Color(0xFF07101D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _infoCard(
              icon: Icons.graphic_eq_rounded,
              iconColor: const Color(0xFF4CCEFF),
              title: 'Voice Pulse',
              subtitle: isVoicePulseActive ? 'Active' : 'Off',
              subtitleColor: const Color(0xFF4CCEFF),
              onTap: () {
                setState(() {
                  isVoicePulseActive =
                      !isVoicePulseActive;
                });
              },
            ),
          ),
          Expanded(
            child: _infoCard(
              icon: Icons.eco_rounded,
              iconColor: const Color(0xFF9BE26B),
              title: 'Atmosphere',
              subtitle: 'Cafe',
              subtitleColor: const Color(0xFF9BE26B),
              trailing: Icons.keyboard_arrow_down_rounded,
              onTap: _showAtmosphere,
            ),
          ),
          Expanded(
            child: _infoCard(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF20F5D0),
              title: 'Call Shield',
              subtitle: 'On',
              subtitleColor: const Color(0xFF8F9CFF),
              onTap: () {},
            ),
          ),
          Expanded(
            child: _infoCard(
              icon: Icons.group_rounded,
              iconColor: const Color(0xFF9D59FF),
              title: 'Participants',
              subtitle: '$participants',
              subtitleColor: const Color(0xFF9D59FF),
              trailing: Icons.keyboard_arrow_down_rounded,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 11,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 21,
                  ),
                ),
                if (trailing != null)
                  Icon(
                    trailing,
                    color: Colors.white54,
                    size: 17,
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ATMOSPHERE
  // ============================================================

  void _showAtmosphere() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Call Atmosphere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 22),
                _atmosphereOption(
                  'Cafe',
                  Icons.coffee_rounded,
                  Colors.greenAccent,
                ),
                _atmosphereOption(
                  'Lo-Fi',
                  Icons.music_note_rounded,
                  Colors.purpleAccent,
                ),
                _atmosphereOption(
                  'Rain',
                  Icons.water_drop_rounded,
                  Colors.cyanAccent,
                ),
                _atmosphereOption(
                  'None',
                  Icons.volume_off_rounded,
                  Colors.white70,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _atmosphereOption(
    String title,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white38,
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  // ============================================================
  // LIVE REACTIONS
  // ============================================================

  Widget _buildLiveReactions() {
    const reactions = [
      ('❤️', 'heart'),
      ('😂', 'laugh'),
      ('🔥', 'fire'),
      ('👏', 'clap'),
      ('👀', 'eyes'),
      ('💯', 'hundred'),
    ];

    return Container(
      height: 93,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF07101D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 12,
            ),
            child: Text(
              'Live Reactions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: reactions.length,
              separatorBuilder: (_, __) {
                return const SizedBox(width: 7);
              },
              itemBuilder: (_, index) {
                final emoji = reactions[index].$1;
                final id = reactions[index].$2;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedReaction = id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      color: selectedReaction == id
                          ? const Color(0xFF351160)
                          : const Color(0xFF10192A),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedReaction == id
                            ? const Color(0xFFB33DFF)
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 26,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D1424),
                border: Border.all(
                  color: Colors.purpleAccent,
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent
                        .withValues(alpha: 0.18),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.purpleAccent,
                size: 29,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CALL MEMORY
  // ============================================================

  Widget _buildCallMemory() {
    return Container(
      height: 119,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF07101D).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5B16A7)
                  .withValues(alpha: 0.20),
              border: Border.all(
                color: const Color(0xFF9C38FF)
                    .withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent
                      .withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              color: Color(0xFFB64DFF),
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Call Memory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'This call will be saved\nafter it ends',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                isCallMemoryOn = !isCallMemoryOn;
              });
            },
            child: Container(
              width: 105,
              height: 57,
              decoration: BoxDecoration(
                color: const Color(0xFF111A2C),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    isCallMemoryOn ? 'View' : 'Off',
                    style: const TextStyle(
                      color: Color(0xFFA7A7FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 25,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CALL CONTROLS
  // ============================================================

  Widget _buildCallControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: [
            _callControl(
              icon: isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_none_rounded,
              label: 'Mute',
              active: isMuted,
              activeColor: Colors.redAccent,
              onTap: () {
                setState(() {
                  isMuted = !isMuted;
                });
              },
            ),
            _callControl(
              icon: isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              label: 'Speaker',
              active: isSpeakerOn,
              activeColor: const Color(0xFF20F5E1),
              onTap: () {
                setState(() {
                  isSpeakerOn = !isSpeakerOn;
                });
              },
            ),
            _callControl(
              icon: Icons.dialpad_rounded,
              label: 'Keypad',
              onTap: _showKeypad,
            ),
            _callControl(
              icon: Icons.add_call,
              label: 'Add Call',
              activeColor: Colors.purpleAccent,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: [
            _callControl(
              icon: isOnHold
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              label: 'Hold',
              active: isOnHold,
              activeColor: Colors.white,
              onTap: () {
                setState(() {
                  isOnHold = !isOnHold;
                });
              },
            ),
            _callControl(
              icon: Icons.call_end_rounded,
              label: 'End Call',
              isEndCall: true,
              onTap: _endCall,
            ),
            _callControl(
              icon: Icons.hearing_rounded,
              label: 'Switch Audio',
              activeColor: const Color(0xFF20F5E1),
              onTap: () {},
            ),
            _callControl(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              onTap: _showMore,
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // INDIVIDUAL CALL CONTROL
  // ============================================================

  Widget _callControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool isEndCall = false,
    Color activeColor = Colors.white,
  }) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEndCall
                    ? const Color(0xFFF3323C)
                    : active
                        ? activeColor
                            .withValues(alpha: 0.10)
                        : const Color(0xFF0A1321),
                border: Border.all(
                  color: isEndCall
                      ? Colors.redAccent
                      : active
                          ? activeColor
                              .withValues(alpha: 0.45)
                          : Colors.white
                              .withValues(alpha: 0.10),
                  width: 1.2,
                ),
                boxShadow: isEndCall
                    ? [
                        BoxShadow(
                          color: Colors.redAccent
                              .withValues(alpha: 0.42),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ]
                    : active
                        ? [
                            BoxShadow(
                              color: activeColor
                                  .withValues(alpha: 0.15),
                              blurRadius: 20,
                            ),
                          ]
                        : [],
              ),
              child: Icon(
                icon,
                color: isEndCall
                    ? Colors.white
                    : active
                        ? activeColor
                        : Colors.white,
                size: isEndCall ? 34 : 29,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isEndCall
                  ? Colors.white
                  : Colors.white70,
              fontSize: 14,
              fontWeight: isEndCall
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SWIPE INDICATOR
  // ============================================================

  Widget _buildSwipeIndicator() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white54,
              size: 23,
            ),
            SizedBox(width: 5),
            Text(
              'Swipe up for more',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Icon(
          Icons.keyboard_arrow_up_rounded,
          color: Color(0xFF9D38FF),
          size: 30,
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM INFORMATION
  // ============================================================

  Widget _buildBottomInformation() {
    return Container(
      height: 109,
      decoration: BoxDecoration(
        color: const Color(0xFF07101D).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(14),
                      color: const Color(0xFF4D17A3)
                          .withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFFA647FF),
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Lo-Fi Cafe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chattax Atmosphere',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 58,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isLocationSharing =
                      !isLocationSharing;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 53,
                      height: 53,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(14),
                        color: const Color(0xFF00BFA5)
                            .withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        isLocationSharing
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                        color: const Color(0xFF20EFC9),
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sharing Location',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: Color(0xFF20EFC9),
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                      size: 27,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VOICE WAVE PAINTER
// ============================================================

class _VoiceWavePainter extends CustomPainter {
  final double animation;
  final bool active;

  _VoiceWavePainter({
    required this.animation,
    required this.active,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (!active) {
      return;
    }

    final centerX = size.width / 2;
    final centerY = size.height / 2 - 1;

    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const int numberOfBars = 45;

    for (int i = 0; i < numberOfBars; i++) {
      final normalized =
          i / (numberOfBars - 1);

      final distance =
          (normalized - 0.5).abs();

      final envelope = math.max(
        0,
        1 - distance * 1.65,
      );

      final wave = math.sin(
        (i * 0.72) +
            (animation * math.pi * 2),
      );

      final height =
          7 +
          (wave.abs() * 42 * envelope);

      final x =
          centerX -
          330 +
          (i * 15);

      paint.color = Color.lerp(
        const Color(0xFF17E7F4),
        const Color(0xFFC035FF),
        normalized,
      )!.withValues(
        alpha: 0.28 + (0.65 * envelope),
      );

      canvas.drawLine(
        Offset(
          x,
          centerY - height / 2,
        ),
        Offset(
          x,
          centerY + height / 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _VoiceWavePainter oldDelegate,
  ) {
    return oldDelegate.animation != animation ||
        oldDelegate.active != active;
  }
}

// ============================================================
// KEYPAD SHEET
// ============================================================

class _KeypadSheet extends StatelessWidget {
  const _KeypadSheet();

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
      ['*', ''],
      ['0', '+'],
      ['#', ''],
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          30,
          18,
          30,
          30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Keypad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount: keys.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (_, index) {
                final key = keys[index];

                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF101827),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          key[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight:
                                FontWeight.w400,
                          ),
                        ),
                        if (key[1].isNotEmpty)
                          Text(
                            key[1],
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 8,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF19DDBF),
                ),
                child: const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}