import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ============================================================================
/// CHATTªX — DISCOVER SCREEN
/// ============================================================================
///
/// • No scrolling
/// • No Community Challenges
/// • No withOpacity()
/// • No color.red / color.green / color.blue
/// • Responsive
/// • Designed to fit on one screen
/// • Almost edge-to-edge
/// • Feed-matched ChattªX logo
/// • Futuristic ChattªX design
/// ============================================================================

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _selectedBottomIndex = 3;

  // ==========================================================================
  // COLORS
  // ==========================================================================

  static const Color background = Color(0xFF02050B);
  static const Color surface = Color(0xFF080D17);
  static const Color surface2 = Color(0xFF0D1320);

  static const Color cyan = Color(0xFF00D9FF);
  static const Color blue = Color(0xFF2979FF);
  static const Color purple = Color(0xFF7B2FFF);
  static const Color violet = Color(0xFFB026FF);
  static const Color pink = Color(0xFFFF1478);
  static const Color eventAccent = Color(0xFFFF245F);

  static const Color border = Color(0xFF182235);
  static const Color borderSoft = Color(0xFF1A2639);

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: _buildDiscoverContent(
                    context,
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                ),
                _buildBottomNavigation(size.width),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN CONTENT
  // ==========================================================================

  Widget _buildDiscoverContent(
    BuildContext context,
    double width,
    double height,
  ) {
    // Almost edge-to-edge.
    final horizontalPadding = width < 380 ? 5.0 : 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        4,
        horizontalPadding,
        2,
      ),
      child: Column(
        children: [
          _buildTopHeader(width),

          const SizedBox(height: 4),

          _buildSearchBar(width),

          const SizedBox(height: 7),

          _buildPulseCard(width),

          const SizedBox(height: 7),

          Expanded(
            child: Column(
              children: [
                // =================================================================
                // FEATURE CARDS
                // =================================================================

                Expanded(
                  flex: 25,
                  child: _buildFeatureGrid(width),
                ),

                const SizedBox(height: 4),

                // =================================================================
                // TRENDING
                // =================================================================

                Expanded(
                  flex: 9,
                  child: _buildTrendingSection(width),
                ),

                const SizedBox(height: 4),

                // =================================================================
                // EVENTS
                // =================================================================

                Expanded(
                  flex: 20,
                  child: _buildEventsSection(width),
                ),

                const SizedBox(height: 4),

                // =================================================================
                // POPULAR COMMUNITIES
                // =================================================================

                Expanded(
                  flex: 10,
                  child: _buildPopularCommunities(width),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildTopHeader(double width) {
    final logoSize = width < 380 ? 27.0 : 29.0;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // ====================================================================
          // CHATTªX LOGO
          // EXACT SAME STYLE AS FEED SCREEN
          // ====================================================================

          Expanded(
            child: Row(
              children: [
                Text(
                  'Chattª',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: logoSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),

                const SizedBox(width: 1),

                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        violet,
                        cyan,
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'X',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: logoSize + 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================================
          // NOTIFICATIONS
          // ====================================================================

          _headerButton(
            icon: Icons.notifications_none_rounded,
            badge: true,
          ),

          const SizedBox(width: 5),

          // ====================================================================
          // MORE OPTIONS
          // ====================================================================

          _headerButton(
            icon: Icons.more_horiz_rounded,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER BUTTON
  // ==========================================================================

  Widget _headerButton({
    required IconData icon,
    bool badge = false,
  }) {
    return Container(
      width: 47,
      height: 43,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFFB9BCC7),
            size: 26,
          ),

          if (badge)
            Positioned(
              top: 7,
              right: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: violet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SEARCH BAR
  // ==========================================================================

  Widget _buildSearchBar(double width) {
    return Container(
      height: 45,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: borderSoft,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF8290AD),
            size: 25,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Search people, worlds, communities...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF9AA6BF),
                fontSize: width < 380 ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PULSE CARD
  // ==========================================================================

  Widget _buildPulseCard(double width) {
    final compact = width < 380;

    return Container(
      height: compact ? 103 : 108,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF4710E8),
            Color(0xFF3210A1),
            Color(0xFF150A3B),
          ],
        ),
        border: Border.all(
          color: violet,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x407B2FFF),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          _pulseOrb(compact),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ChattªX Pulse',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 19 : 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '24,583 people connected now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '3,420 conversations happening',
                    style: TextStyle(
                      color: const Color(0xFFD9D4FF),
                      fontSize: compact ? 11 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PULSE ORB
  // ==========================================================================

  Widget _pulseOrb(bool compact) {
    final orbSize = compact ? 62.0 : 69.0;

    return Container(
      width: orbSize,
      height: orbSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cyan,
            blue,
            purple,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x6600D9FF),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'ϟ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 43,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FEATURE GRID
  // ==========================================================================

  Widget _buildFeatureGrid(double width) {
    return Row(
      children: [
        Expanded(
          child: _featureCard(
            title: 'ChattªX World',
            subtitle: 'Discover people',
            icon: Icons.public_rounded,
            color: violet,
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: _featureCard(
            title: 'Communities',
            subtitle: 'Join interests',
            icon: Icons.groups_rounded,
            color: purple,
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: _featureCard(
            title: "Who's Nearby",
            subtitle: 'People near you',
            icon: Icons.location_on_rounded,
            color: pink,
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: _featureCard(
            title: 'Events',
            subtitle: 'Things happening',
            icon: Icons.event_available_rounded,
            color: eventAccent,
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: _featureCard(
            title: 'Places',
            subtitle: 'Explore nearby',
            icon: Icons.location_pin,
            color: cyan,
          ),
        ),

        const SizedBox(width: 4),

        Expanded(
          child: _featureCard(
            title: 'Music',
            subtitle: 'Songs & artists',
            icon: Icons.music_note_rounded,
            color: violet,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // FEATURE CARD
  // ==========================================================================

  Widget _featureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: border,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = math.min(
            constraints.maxWidth * 0.48,
            41.0,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _realFeatureIcon(
                  icon,
                  color,
                  iconSize,
                ),

                const SizedBox(height: 3),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 1),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF8490AA),
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // FEATURE ICON
  // ==========================================================================

  Widget _realFeatureIcon(
    IconData icon,
    Color color,
    double size,
  ) {
    final innerSize = size * 0.69;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            _darken(color),
          ],
        ),
        border: Border.all(
          color: color,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300D9FF),
            blurRadius: 10,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF080D1D),
            border: Border.all(
              color: Colors.white,
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: innerSize * 0.58,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DARKEN
  // ==========================================================================

  Color _darken(Color color) {
    return Color.lerp(
          color,
          Colors.black,
          0.55,
        ) ??
        color;
  }

  // ==========================================================================
  // TRENDING
  // ==========================================================================

  Widget _buildTrendingSection(double width) {
    return Column(
      children: [
        _sectionHeader(
          emoji: '🔥',
          title: 'Trending Topics',
        ),

        const SizedBox(height: 3),

        Expanded(
          child: Row(
            children: [
              _topic('#Music', violet),
              const SizedBox(width: 4),
              _topic('#Gaming', cyan),
              const SizedBox(width: 4),
              _topic('#Football', pink),
              const SizedBox(width: 4),
              _topic('#Tech', blue),
              const SizedBox(width: 4),
              _topic('#Business', purple),
              const SizedBox(width: 4),
              _topic('#Fashion', cyan),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TOPIC
  // ==========================================================================

  Widget _topic(
    String text,
    Color color,
  ) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF070D1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION HEADER
  // ==========================================================================

  Widget _sectionHeader({
    required String emoji,
    required String title,
  }) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 15,
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Text(
            'View all',
            style: TextStyle(
              color: violet,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // EVENTS
  // ==========================================================================

  Widget _buildEventsSection(double width) {
    return Column(
      children: [
        _sectionHeader(
          emoji: '📅',
          title: 'Upcoming Events',
        ),

        const SizedBox(height: 2),

        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _eventRow(
                    icon: Icons.music_note_rounded,
                    color: violet,
                    title: 'Amapiano Night',
                    info: 'Tonight • 8:00 PM',
                    place: 'Johannesburg',
                    people: '+23',
                    buttonText: 'Interested',
                  ),
                ),

                const Divider(
                  height: 1,
                  color: Color(0xFF17233B),
                ),

                Expanded(
                  child: _eventRow(
                    icon: Icons.sports_esports_rounded,
                    color: cyan,
                    title: 'Gaming Tournament',
                    info: 'Tomorrow • 12:00 PM',
                    place: 'Durban',
                    people: '+18',
                    buttonText: 'Going',
                  ),
                ),

                const Divider(
                  height: 1,
                  color: Color(0xFF17233B),
                ),

                Expanded(
                  child: _eventRow(
                    icon: Icons.mic_rounded,
                    color: purple,
                    title: 'Open Mic Session',
                    info: 'May 30 • 7:00 PM',
                    place: 'Pretoria',
                    people: '+12',
                    buttonText: 'Interested',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // EVENT ROW
  // ==========================================================================

  Widget _eventRow({
    required IconData icon,
    required Color color,
    required String title,
    required String info,
    required String place,
    required String people,
    required String buttonText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  _darken(color),
                ],
              ),
              border: Border.all(
                color: color,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x25000000),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 1),

                Text(
                  info,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8C97AE),
                    fontSize: 7,
                  ),
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: pink,
                      size: 8,
                    ),

                    const SizedBox(width: 2),

                    Flexible(
                      child: Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cyan,
                          fontSize: 7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 3),

          Text(
            people,
            style: const TextStyle(
              color: Color(0xFF8994AA),
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 3),

          Container(
            width: 64,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonText,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // POPULAR COMMUNITIES
  // ==========================================================================

  Widget _buildPopularCommunities(double width) {
    return Column(
      children: [
        _sectionHeader(
          emoji: '👥',
          title: 'Popular Communities',
        ),

        const SizedBox(height: 2),

        Expanded(
          child: Row(
            children: [
              _community(
                'Amapiano',
                '12.6K',
                Icons.music_note_rounded,
                violet,
              ),

              const SizedBox(width: 4),

              _community(
                'Gamers',
                '8.9K',
                Icons.sports_esports_rounded,
                purple,
              ),

              const SizedBox(width: 4),

              _community(
                'Tech',
                '6.2K',
                Icons.settings_rounded,
                cyan,
              ),

              const SizedBox(width: 4),

              _community(
                'Creative',
                '9.1K',
                Icons.psychology_rounded,
                pink,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // COMMUNITY
  // ==========================================================================

  Widget _community(
    String name,
    String members,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    _darken(color),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x25000000),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 15,
              ),
            ),

            const SizedBox(width: 4),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  Text(
                    '$members members',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7D89A2),
                      fontSize: 6.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BOTTOM NAVIGATION
  // ==========================================================================

  Widget _buildBottomNavigation(double width) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF080E1E),
        border: Border(
          top: BorderSide(
            color: Color(0xFF172442),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _navItem(
            icon: Icons.chat_bubble_rounded,
            label: 'Chats',
            index: 0,
          ),

          _navItem(
            icon: Icons.dynamic_feed_rounded,
            label: 'Feed',
            index: 1,
          ),

          _navItem(
            icon: Icons.call_rounded,
            label: 'Calls',
            index: 2,
          ),

          _navItem(
            icon: Icons.explore_rounded,
            label: 'Discover',
            index: 3,
          ),

          _navItem(
            icon: Icons.play_circle_fill_rounded,
            label: 'Reels',
            index: 4,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // NAV ITEM
  // ==========================================================================

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _selectedBottomIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedBottomIndex = index;
          });
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            width: selected ? 68 : 53,
            height: selected ? 60 : 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        purple,
                        Color(0xFF4213B8),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(
                      color: violet,
                      width: 1,
                    )
                  : null,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x507B2FFF),
                        blurRadius: 18,
                        spreadRadius: -3,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: selected ? 24 : 21,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF8792A9),
                ),

                const SizedBox(height: 2),

                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF8792A9),
                    fontSize: 8,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}