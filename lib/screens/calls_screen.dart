import 'package:flutter/material.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = [
    'All',
    'Missed',
    'Incoming',
    'Outgoing',
    'Video',
    'Favorites',
  ];

  final List<_CallItem> _todayCalls = [
    _CallItem(
      name: 'Brandon Hotshot',
      type: 'Incoming Video Call',
      time: '9:21 PM',
      duration: '27:43',
      direction: _CallDirection.incoming,
      video: true,
      online: true,
      favorite: true,
      avatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
    ),
    _CallItem(
      name: 'Sarah Johnson',
      type: 'Outgoing Audio Call',
      time: '6:48 PM',
      duration: '12:08',
      direction: _CallDirection.outgoing,
      online: true,
      avatar:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
    ),
    _CallItem(
      name: 'Mike Wayne',
      type: 'Missed Audio Call',
      time: '3:15 PM',
      duration: '',
      direction: _CallDirection.missed,
      online: false,
      avatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
    ),
  ];

  final List<_CallItem> _yesterdayCalls = [
    _CallItem(
      name: 'Lisa Anderson',
      type: 'Outgoing Video Call',
      time: 'Yesterday, 8:14 PM',
      duration: '45:19',
      direction: _CallDirection.outgoing,
      video: true,
      online: true,
      favorite: true,
      avatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
    ),
    _CallItem(
      name: 'Family Group',
      type: 'Incoming Group Call',
      time: 'Yesterday, 5:33 PM',
      duration: '1:02:21',
      direction: _CallDirection.incoming,
      group: true,
      online: true,
      avatar:
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=300',
    ),
  ];

  final List<_CallItem> _olderCalls = [
    _CallItem(
      name: 'Zara Smith',
      type: 'Outgoing Audio Call',
      time: 'Aug 8, 11:22 PM',
      duration: '8:32',
      direction: _CallDirection.outgoing,
      online: true,
      avatar:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300',
    ),
    _CallItem(
      name: 'David Lee',
      type: 'Incoming Audio Call',
      time: 'Aug 7, 9:07 PM',
      duration: '16:45',
      direction: _CallDirection.incoming,
      online: true,
      avatar:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300',
    ),
  ];

  Color get _purple => const Color(0xFF8A3DFF);
  Color get _brightPurple => const Color(0xFFB026FF);
  Color get _cyan => const Color(0xFF00D9FF);
  Color get _green => const Color(0xFF00E5A8);
  Color get _background => const Color(0xFF02050F);

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _background,
    extendBody: true,
    body: Stack(
      children: [
        const _BackgroundGlow(),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ==========================================================
              // FIXED HEADER
              // ==========================================================
              _buildHeader(),

              // ==========================================================
              // FIXED CALL SPACE
              // ==========================================================
              _buildCallSpace(),

              // ==========================================================
              // FIXED FILTERS
              // ==========================================================
              _buildFilters(),

              // ==========================================================
              // ONLY CALL HISTORY SCROLLS
              // ==========================================================
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 0,
                        right: 0,
                        bottom: 145,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildSectionTitle('TODAY'),
                          _buildCallGroup(_todayCalls),

                          const SizedBox(height: 16),

                          _buildSectionTitle('YESTERDAY'),
                          _buildCallGroup(_yesterdayCalls),

                          const SizedBox(height: 16),

                          _buildSectionTitle('OLDER'),
                          _buildCallGroup(_olderCalls),

                          const SizedBox(height: 30),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ========================================================================
// HEADER
// ========================================================================

Widget _buildHeader() {
  return SizedBox(
    width: double.infinity,
    height: 64,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        4,
        8,
      ),
      child: Row(
        children: [
          // ==============================================================
          // CHATTX
          // ==============================================================

          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  Color(0xFF8AA8FF),
                  Color(0xFFB026FF),
                  Color(0xFFE0B5FF),
                ],
              ).createShader(bounds);
            },
            child: const Text(
              'ChattªX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
          ),

          const SizedBox(width: 2),

          // ==============================================================
          // CALLS
          // ==============================================================

          const Text(
            'Calls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(width: 6),

          // ==============================================================
          // PURPLE STATUS DOT
          // ==============================================================

          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF8A3DFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF8A3DFF),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),

          // ==============================================================
          // PUSH ACTIONS TO THE FAR RIGHT
          // ==============================================================

          const Spacer(),

          // SEARCH
          _headerButton(
            Icons.search_rounded,
            onTap: _showSearch,
          ),

          const SizedBox(width: 4),

          // QR
          _headerButton(
            Icons.qr_code_scanner_rounded,
            onTap: _showQr,
          ),

          const SizedBox(width: 4),

          // MORE
          _headerButton(
            Icons.more_vert_rounded,
            onTap: _showMore,
          ),
        ],
      ),
    ),
  );
}

// ========================================================================
// HEADER BUTTON
// ========================================================================

Widget _headerButton(
  IconData icon, {
  required VoidCallback onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111321),
        border: Border.all(
          color: const Color(0xFF7440D9).withValues(
            alpha: 0.50,
          ),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(
              alpha: 0.10,
            ),
            blurRadius: 11,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 19,
      ),
    ),
  );
}

  // ========================================================================
  // CALL SPACE - EDGE TO EDGE
  // ========================================================================

  Widget _buildCallSpace() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Container(
      width: double.infinity,
      height: 205,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF080C1B),
        border: Border.all(
          color: _purple,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.16),
            blurRadius: 25,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: _cyan.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // ==============================================================
          // LEFT SIDE
          // ==============================================================

          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                13,
                8,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Flexible(
                        child: Text(
                          'CALL SPACE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Connect in every way',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 11),

                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _callTypeCard(
                            icon: Icons.call_rounded,
                            title: 'Audio Call',
                            subtitle: 'Start now',
                            color: _cyan,
                          ),
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: _callTypeCard(
                            icon: Icons.videocam_rounded,
                            title: 'Video Call',
                            subtitle: 'Start now',
                            color: _purple,
                          ),
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: _callTypeCard(
                            icon: Icons.groups_rounded,
                            title: 'Group Call',
                            subtitle: 'Start a space',
                            color: const Color(0xFFFF4FBF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==============================================================
          // DIVIDER
          // ==============================================================

          Container(
            width: 1,
            height: 175,
            color: _purple.withValues(alpha: 0.22),
          ),

          // ==============================================================
          // RIGHT SIDE - CREATE ROOM
          // ==============================================================

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                13,
                8,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Room',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Share a link or QR\nand anyone can join.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _createRoomButton(),

                  const Spacer(),

                  // ======================================================
                  // FIXED LINK / QR / JOIN ROW
                  // ======================================================

                  Row(
                    children: [
                      Expanded(
                        child: _roomAction(
                          Icons.link_rounded,
                          'Link',
                        ),
                      ),

                      const SizedBox(width: 2),

                      Expanded(
                        child: _roomAction(
                          Icons.qr_code_2_rounded,
                          'QR',
                        ),
                      ),

                      const SizedBox(width: 2),

                      Expanded(
                        child: _roomAction(
                          Icons.login_rounded,
                          'Join',
                        ),
                      ),
                    ],
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

  Widget _callTypeCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: const Color(0xFF0D1425),
      border: Border.all(
        color: color.withValues(alpha: 0.7),
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: 16,
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: color,
          size: 26,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

  Widget _createRoomButton() {
  return GestureDetector(
    onTap: _createRoom,
    child: Container(
      width: double.infinity,
      height: 34,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            _cyan.withValues(alpha: 0.10),
            _brightPurple.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(
          color: _cyan.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            color: _cyan,
            size: 18,
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              'Create Call Room',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _cyan,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _roomAction(
  IconData icon,
  String title,
) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      if (title == 'Link') {
        _showSnack('Call room link created');
      } else if (title == 'QR') {
        _showSnack('QR code opened');
      } else {
        _showSnack('Join call room');
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF11182A),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white70,
            size: 18,
          ),
        ),

        const SizedBox(height: 3),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

  // ========================================================================
  // FILTERS - EDGE TO EDGE
  // ========================================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 62,
      width: double.infinity,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
  6,
  15,
  6,
  8,
),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = index;
              });
            },
            child: Container(
              height: 35,
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF7B2FF7),
                          Color(0xFFB026FF),
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : const Color(0xFF101522),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF9D50FF)
                      : Colors.white.withValues(alpha: 0.07),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.30),
                          blurRadius: 15,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index == 1)
                    _filterDot(
                      const Color(0xFFFF315D),
                    ),

                  if (index == 2)
                    Icon(
                      Icons.call_received_rounded,
                      size: 15,
                      color: _green,
                    ),

                  if (index == 3)
                    Icon(
                      Icons.call_made_rounded,
                      size: 15,
                      color: _purple,
                    ),

                  if (index == 4)
                    const Icon(
                      Icons.videocam_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),

                  if (index == 5)
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFC933),
                    ),

                  if (index != 0)
                    const SizedBox(width: 6),

                  Text(
                    _filters[index],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SECTION TITLE
  // ========================================================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        2,
        0,
        8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ========================================================================
  // CALL GROUP - EDGE TO EDGE
  // ========================================================================

  Widget _buildCallGroup(
    List<_CallItem> calls,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(
          calls.length,
          (index) {
            final call = calls[index];

            return Column(
              children: [
                _buildCallTile(call),

                if (index != calls.length - 1)
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.045),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ========================================================================
  // CALL TILE
  // ========================================================================

  Widget _buildCallTile(
    _CallItem call,
  ) {
    return SizedBox(
      height: 81,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
        ),
        child: Row(
          children: [
            _buildAvatar(call),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    call.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      _directionIcon(call),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          call.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _callColor(call),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Text(
                    call.time,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            if (call.duration.isNotEmpty)
              SizedBox(
                width: 52,
                child: Text(
                  call.duration,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            if (call.video && !call.group)
              _smallActionButton(
                Icons.videocam_rounded,
                _purple,
                () => _startVideoCall(call),
              ),

            if (call.video && !call.group)
              const SizedBox(width: 8),

            _smallActionButton(
              call.group
                  ? Icons.groups_rounded
                  : Icons.call_rounded,
              call.group
                  ? _brightPurple
                  : _green,
              () => _startAudioCall(call),
            ),

            const SizedBox(width: 7),

            GestureDetector(
              onTap: () => _showCallOptions(call),
              child: const SizedBox(
                width: 28,
                height: 45,
                child: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ),

            if (call.favorite)
              const SizedBox(width: 2),

            if (call.favorite)
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFC933),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // AVATAR
  // ========================================================================

  Widget _buildAvatar(
    _CallItem call,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                call.direction == _CallDirection.missed
                    ? const Color(0xFFFF315D)
                    : _cyan,
                _purple,
                call.direction == _CallDirection.missed
                    ? const Color(0xFFFF315D)
                    : _green,
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF070B16),
            ),
            child: ClipOval(
              child: Image.network(
                call.avatar,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF20263A),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(call.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        if (call.online)
          Positioned(
            right: -1,
            bottom: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF080C18),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.6),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
          ),

        if (call.group)
          Positioned(
            right: -3,
            top: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: const Color(0xFF151B30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _purple,
                ),
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 11,
                color: Colors.white70,
              ),
            ),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length > 2
                ? 2
                : parts.first.length,
          )
          .toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }

  // ========================================================================
  // CALL ICON
  // ========================================================================

  Widget _directionIcon(
    _CallItem call,
  ) {
    IconData icon;

    switch (call.direction) {
      case _CallDirection.incoming:
        icon = Icons.call_received_rounded;
        break;

      case _CallDirection.outgoing:
        icon = Icons.call_made_rounded;
        break;

      case _CallDirection.missed:
        icon = Icons.call_missed_rounded;
        break;
    }

    return Icon(
      icon,
      size: 14,
      color: _callColor(call),
    );
  }

  Color _callColor(
    _CallItem call,
  ) {
    switch (call.direction) {
      case _CallDirection.incoming:
        return _green;

      case _CallDirection.outgoing:
        return _purple;

      case _CallDirection.missed:
        return const Color(0xFFFF315D);
    }
  }

  // ========================================================================
  // SMALL CALL BUTTON
  // ========================================================================

  Widget _smallActionButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.055),
          border: Border.all(
            color: color.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
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

  // ========================================================================
  // ACTIONS
  // ========================================================================

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _CallSearchDelegate(),
    );
  }

  void _showQr() {
    _showSnack('QR scanner opened');
  }

  void _showMore() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _sheetHandle(),
              const SizedBox(height: 15),
              _sheetItem(
                Icons.settings_outlined,
                'Call settings',
              ),
              _sheetItem(
                Icons.history_rounded,
                'Call history',
              ),
              _sheetItem(
                Icons.block_rounded,
                'Blocked contacts',
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 45,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _sheetItem(
    IconData icon,
    String title,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: _cyan,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  void _createRoom() {
    _showSnack('Creating call room...');
  }

  void _startAudioCall(
    _CallItem call,
  ) {
    _showSnack(
      'Starting audio call with ${call.name}',
    );
  }

  void _startVideoCall(
    _CallItem call,
  ) {
    _showSnack(
      'Starting video call with ${call.name}',
    );
  }

  void _showCallOptions(
    _CallItem call,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              _sheetHandle(),
              const SizedBox(height: 8),

              ListTile(
                leading: const Icon(
                  Icons.call_rounded,
                  color: Color(0xFF00E5A8),
                ),
                title: Text(
                  'Call ${call.name}',
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _startAudioCall(call);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF00D9FF),
                ),
                title: const Text(
                  'Call details',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF315D),
                ),
                title: const Text(
                  'Delete call history',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF151B2E),
        ),
      );
  }
}

// ============================================================================
// BACKGROUND
// ============================================================================

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: -130,
            child: _glow(
              const Color(0xFF6D27FF),
              260,
            ),
          ),
          Positioned(
            top: 420,
            right: -150,
            child: _glow(
              const Color(0xFF4716FF),
              300,
            ),
          ),
          Positioned(
            bottom: 180,
            left: -100,
            child: _glow(
              const Color(0xFF3015B8),
              250,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(
    Color color,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.025),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIAL PAD
// ============================================================================

class _DialPadSheet extends StatefulWidget {
  const _DialPadSheet();

  @override
  State<_DialPadSheet> createState() =>
      _DialPadSheetState();
}

class _DialPadSheetState
    extends State<_DialPadSheet> {
  String number = '';

  final List<String> keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        25,
        14,
        25,
        MediaQuery.of(context).viewInsets.bottom + 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Dial Number',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: Center(
              child: Text(
                number.isEmpty
                    ? 'Enter number'
                    : number,
                style: TextStyle(
                  color: number.isEmpty
                      ? Colors.white30
                      : Colors.white,
                  fontSize: 25,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: keys.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 20,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              final key = keys[index];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    number += key;
                  });
                },
                onLongPress: key == '0'
                    ? () {
                        setState(() {
                          number += '+';
                        });
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF101728),
                    border: Border.all(
                      color: const Color(0xFF7739E8)
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 17),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (number.isNotEmpty) {
                    setState(() {
                      number = number.substring(
                        0,
                        number.length - 1,
                      );
                    });
                  }
                },
                child: const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white54,
                  size: 27,
                ),
              ),

              const SizedBox(width: 55),

              GestureDetector(
                onTap: () {
                  if (number.isNotEmpty) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00E5A8),
                        Color(0xFF00C8FF),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEARCH
// ============================================================================

class _CallSearchDelegate
    extends SearchDelegate {
  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor:
          const Color(0xFF050816),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF050816),
        elevation: 0,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Colors.white38,
        ),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(
            Icons.clear_rounded,
            color: Colors.white70,
          ),
        ),
    ];
  }

  @override
  Widget buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(context, '');
      },
      icon: const Icon(
        Icons.arrow_back_rounded,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return _emptySearch();
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _emptySearch();
  }

  Widget _emptySearch() {
    return Container(
      color: const Color(0xFF050816),
      alignment: Alignment.center,
      child: const Text(
        'Search call history',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

enum _CallDirection {
  incoming,
  outgoing,
  missed,
}

class _CallItem {
  final String name;
  final String type;
  final String time;
  final String duration;
  final _CallDirection direction;
  final bool video;
  final bool group;
  final bool online;
  final bool favorite;
  final String avatar;

  const _CallItem({
    required this.name,
    required this.type,
    required this.time,
    required this.duration,
    required this.direction,
    this.video = false,
    this.group = false,
    this.online = false,
    this.favorite = false,
    required this.avatar,
  });
}
