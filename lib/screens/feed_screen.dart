import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // ===========================================================================
  // CHATTªX FEED
  // ===========================================================================

  static const double _sideSpace = 7.0;

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color _background = Color(0xFF050816);
  static const Color _card = Color(0xFF080D1A);
  static const Color _surface = Color(0xFF0D1324);
  static const Color _surfaceDark = Color(0xFF070B17);
  static const Color _surfaceRaised = Color(0xFF10182A);

  static const Color _border = Color(0xFF18243A);
  static const Color _borderSoft = Color(0xFF202E48);

  static const Color _purple = Color(0xFF7B2FF7);
  static const Color _brightPurple = Color(0xFFB026FF);

  static const Color _cyan = Color(0xFF00D9FF);
  static const Color _brightCyan = Color(0xFF00E5FF);

  static const Color _primaryText = Color(0xFFF5F7FF);
  static const Color _secondaryText = Color(0xFF9AA3B5);
  static const Color _mutedText = Color(0xFF68738A);
  static const Color _buttonText = Color(0xFFB9C1D2);

  // ===========================================================================
  // STATE
  // ===========================================================================

  int _selectedTopTab = 0;

  bool _likedSunset = false;
  bool _likedText = false;

  bool _savedSunset = false;
  bool _savedMusic = false;
  bool _savedText = false;

  bool _playingMusic = false;

  int _sunsetReactions = 243;
  int _textReactions = 87;

  final List<String> _topTabs = const [
    'Feed',
    'Following',
    'Trending',
    'Nearby',
  ];

  // ===========================================================================
  // CURRENT USER
  // ===========================================================================

  User? get _currentUser {
    return FirebaseAuth.instance.currentUser;
  }

  String? get _profileUrl {
    final url = _currentUser?.photoURL;

    if (url == null || url.trim().isEmpty) {
      return null;
    }

    return url;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // -----------------------------------------------------------------
            // HEADER
            // -----------------------------------------------------------------

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _sideSpace,
                ),
                child: _buildHeader(),
              ),
            ),

            // -----------------------------------------------------------------
            // TABS
            // -----------------------------------------------------------------

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _sideSpace,
                ),
                child: _buildTabs(),
              ),
            ),

            // -----------------------------------------------------------------
            // CREATE POST
            // -----------------------------------------------------------------

            SliverToBoxAdapter(
              child: _buildCreatePost(),
            ),

            // -----------------------------------------------------------------
            // POSTS
            // -----------------------------------------------------------------

            SliverToBoxAdapter(
              child: _buildSunsetPost(),
            ),

            SliverToBoxAdapter(
              child: _buildMusicPost(),
            ),

            SliverToBoxAdapter(
              child: _buildTextPost(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          // -------------------------------------------------------------------
          // BRAND
          // -------------------------------------------------------------------

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 7,
              ),
              child: Row(
                children: [
                  const Text(
                    'Chattª',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _brightPurple,
                          _cyan,
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'X',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // HEADER ACTIONS
          //
          // All three icons now have:
          // - no background
          // - same size
          // - same spacing
          // -------------------------------------------------------------------

          _headerIconButton(
            icon: Icons.add_rounded,
            onTap: _showCreateMenu,
          ),

          const SizedBox(width: 4),

          _headerIconButton(
            icon: Icons.search_rounded,
            onTap: _showSearch,
          ),

          const SizedBox(width: 4),

          Stack(
            clipBehavior: Clip.none,
            children: [
              _headerIconButton(
                icon: Icons.notifications_none_rounded,
                onTap: () {
                  _showMessage('Notifications');
                },
              ),

              Positioned(
                right: 5,
                top: 3,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _brightPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 5),

          // -------------------------------------------------------------------
          // PROFILE
          // -------------------------------------------------------------------

          GestureDetector(
            onTap: () {
              _showMessage('Profile');
            },
            child: _profileImage(
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER ICON BUTTON
  // ===========================================================================

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 40,
        child: Center(
          child: Icon(
            icon,
            size: 25,
            color: const Color(0xFFB8C0D1),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PROFILE IMAGE
  // ===========================================================================

  Widget _profileImage({
    required double size,
  }) {
    final photoUrl = _profileUrl;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _purple,
            _cyan,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x447B2FF7),
            blurRadius: 9,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl == null
            ? _profileFallback()
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _profileFallback();
                },
              ),
      ),
    );
  }

  Widget _profileFallback() {
    return Container(
      color: _surface,
      child: const Icon(
        Icons.person_rounded,
        color: _brightPurple,
        size: 22,
      ),
    );
  }

  // ===========================================================================
  // TOP TABS
  // ===========================================================================

  Widget _buildTabs() {
    return SizedBox(
      height: 56,
      child: Row(
        children: List.generate(
          _topTabs.length,
          (index) {
            final selected = index == _selectedTopTab;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedTopTab = index;
                  });
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: Text(
                        _topTabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? _brightPurple
                              : _secondaryText,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 55,
                        height: 2.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              _brightPurple,
                              _cyan,
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x887B2FF7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // CREATE POST
  // ===========================================================================

  Widget _buildCreatePost() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        _sideSpace,
        4,
        _sideSpace,
        12,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _profileImage(
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showCreatePost,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _borderSoft,
                        ),
                      ),
                      child: const Text(
                        "What's happening?",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _showMessage('ChattªX AI');
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _surfaceRaised,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: _purple,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _brightCyan,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: _border,
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                _createAction(
                  Icons.image_outlined,
                  'Photo',
                  _brightCyan,
                ),
                _createAction(
                  Icons.videocam_outlined,
                  'Video',
                  _cyan,
                ),
                _createAction(
                  Icons.radio_button_checked_rounded,
                  'Live',
                  _brightPurple,
                ),
                _createAction(
                  Icons.poll_outlined,
                  'Poll',
                  _purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createAction(
    IconData icon,
    String label,
    Color color,
  ) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _showMessage(label);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 21,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _buttonText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUNSET POST
  // ===========================================================================

  Widget _buildSunsetPost() {
    return _postCard(
      child: Column(
        children: [
          _postHeader(
            name: 'Siso Mkhize',
            time: '1h ago',
            image: 'assets/siso.jpg',
            verified: true,
          ),
          _postText(
            'Chasing sunsets and good vibes only 🌅  #ChattªX',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AspectRatio(
                aspectRatio: 1.7,
                child: _assetImage(
                  'assets/feed_sunset.jpg',
                  icon: Icons.landscape_rounded,
                ),
              ),
            ),
          ),
          _reactionSummary(
            reactions: _sunsetReactions,
            comments: 32,
            shares: 8,
          ),
          _postButtons(
            liked: _likedSunset,
            saved: _savedSunset,
            onReact: () {
              setState(() {
                _likedSunset = !_likedSunset;
                _sunsetReactions += _likedSunset ? 1 : -1;
              });
            },
            onComment: () {
              _showMessage('Comments');
            },
            onShare: () {
              _showMessage('Share');
            },
            onSave: () {
              setState(() {
                _savedSunset = !_savedSunset;
              });
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MUSIC POST
  // ===========================================================================

  Widget _buildMusicPost() {
    return _postCard(
      child: Column(
        children: [
          _postHeader(
            name: 'Zama The Creator',
            time: '3h ago',
            image: 'assets/zama.jpg',
            verified: true,
          ),
          _postText(
            'New track out now! Let me know what you think 🔥',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: _musicCard(),
          ),
          const SizedBox(height: 10),
          _musicStats(),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  // ===========================================================================
  // MUSIC CARD
  // ===========================================================================

  Widget _musicCard() {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderSoft,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            height: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                  child: SizedBox(
                    width: 105,
                    height: double.infinity,
                    child: _assetImage(
                      'assets/music_cover.jpg',
                      icon: Icons.music_note_rounded,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _playingMusic = !_playingMusic;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xCC03050A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _brightPurple,
                      ),
                    ),
                    child: Icon(
                      _playingMusic
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                13,
                11,
                10,
                9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'After The Silence',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Zama The Creator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _brightPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _waveform(),
                  const SizedBox(height: 3),
                  const Row(
                    children: [
                      Text(
                        '1:34',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 10,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '2:45',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 10,
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
    );
  }

  // ===========================================================================
  // WAVEFORM
  // ===========================================================================

  Widget _waveform() {
    const heights = [
      7.0,
      15.0,
      11.0,
      20.0,
      12.0,
      24.0,
      14.0,
      28.0,
      19.0,
      31.0,
      16.0,
      25.0,
      13.0,
      29.0,
      18.0,
      23.0,
      12.0,
      30.0,
      20.0,
      27.0,
      14.0,
      23.0,
      17.0,
      28.0,
      13.0,
      21.0,
      11.0,
      25.0,
      15.0,
      20.0,
      10.0,
      17.0,
    ];

    return SizedBox(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          heights.length,
          (index) {
            final active =
                _playingMusic && index < 22;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1,
                ),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 250,
                  ),
                  height: heights[index],
                  decoration: BoxDecoration(
                    color: active
                        ? _brightCyan
                        : index < 22
                            ? _purple
                            : const Color(0xFF303A50),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // MUSIC STATS
  // ===========================================================================

  Widget _musicStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        children: [
          _miniStat(
            Icons.chat_bubble_outline_rounded,
            '51',
            _cyan,
          ),
          const SizedBox(width: 25),
          _miniStat(
            Icons.send_outlined,
            '23',
            _brightCyan,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _savedMusic = !_savedMusic;
              });
            },
            child: Icon(
              _savedMusic
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _brightPurple,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TEXT POST
  // ===========================================================================

  Widget _buildTextPost() {
    return _postCard(
      child: Column(
        children: [
          _postHeader(
            name: 'Lunga',
            time: '5h ago',
            image: 'assets/story_lunga.jpg',
          ),
          _postText(
            "Sometimes you don't need a plan. You just need to start. ✨",
            large: true,
          ),
          _reactionSummary(
            reactions: _textReactions,
            comments: 14,
            shares: 5,
          ),
          _postButtons(
            liked: _likedText,
            saved: _savedText,
            onReact: () {
              setState(() {
                _likedText = !_likedText;
                _textReactions += _likedText ? 1 : -1;
              });
            },
            onComment: () {
              _showMessage('Comments');
            },
            onShare: () {
              _showMessage('Share');
            },
            onSave: () {
              setState(() {
                _savedText = !_savedText;
              });
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // POST TEXT
  // ===========================================================================

  Widget _postText(
    String text, {
    bool large = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        large ? 17 : 12,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: large
                ? const Color(0xFFE0E4ED)
                : const Color(0xFFD4D9E5),
            fontSize: large ? 17 : 15,
            height: large ? 1.45 : 1.35,
            fontWeight: large
                ? FontWeight.w500
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // POST CARD
  // ===========================================================================

  Widget _postCard({
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        _sideSpace,
        0,
        _sideSpace,
        12,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ===========================================================================
  // POST HEADER
  // ===========================================================================

  Widget _postHeader({
    required String name,
    required String time,
    required String image,
    bool verified = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        8,
        7,
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _purple,
                  _cyan,
                ],
              ),
            ),
            child: ClipOval(
              child: _assetImage(
                image,
                icon: Icons.person_rounded,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _purple,
                              _brightPurple,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.public_rounded,
                      color: _mutedText,
                      size: 11,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showPostMenu,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF8893A8),
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REACTION SUMMARY
  // ===========================================================================

  Widget _reactionSummary({
    required int reactions,
    required int comments,
    required int shares,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        9,
        12,
        8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 27,
            child: Stack(
              children: [
                _reactionBubble(
                  Icons.favorite_rounded,
                  _brightPurple,
                  0,
                ),
                _reactionBubble(
                  Icons.local_fire_department_rounded,
                  _cyan,
                  19,
                ),
                _reactionBubble(
                  Icons.auto_awesome_rounded,
                  _purple,
                  38,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$reactions',
            style: const TextStyle(
              color: Color(0xFFAAB4C6),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            '$comments Comments',
            style: const TextStyle(
              color: Color(0xFFAAB4C6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$shares Shares',
            style: const TextStyle(
              color: Color(0xFFAAB4C6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REACTION BUBBLE
  // ===========================================================================

  Widget _reactionBubble(
    IconData icon,
    Color color,
    double left,
  ) {
    return Positioned(
      left: left,
      top: 0,
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: _card,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: 0.30,
              ),
              blurRadius: 7,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 15,
        ),
      ),
    );
  }

  // ===========================================================================
  // POST BUTTONS
  // ===========================================================================

  Widget _postButtons({
    required bool liked,
    required bool saved,
    required VoidCallback onReact,
    required VoidCallback onComment,
    required VoidCallback onShare,
    required VoidCallback onSave,
  }) {
    return Container(
      height: 59,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: _border,
          ),
        ),
      ),
      child: Row(
        children: [
          _postButton(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.auto_awesome_rounded,
            text: 'React',
            color: liked
                ? _brightPurple
                : _brightCyan,
            onTap: onReact,
          ),
          _postButton(
            icon: Icons.chat_bubble_outline_rounded,
            text: 'Comment',
            color: _cyan,
            onTap: onComment,
          ),
          _postButton(
            icon: Icons.send_outlined,
            text: 'Share',
            color: _brightCyan,
            onTap: onShare,
          ),
          _postButton(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            text: 'Save',
            color: _brightPurple,
            onTap: onSave,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // POST BUTTON
  // ===========================================================================

  Widget _postButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _buttonText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MINI STAT
  // ===========================================================================

  Widget _miniStat(
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFAAB4C6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // IMAGE
  // ===========================================================================

  Widget _assetImage(
    String path, {
    required IconData icon,
  }) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF111A30),
                Color(0xFF060A15),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: _brightPurple,
              size: 30,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // CREATE MENU
  // ===========================================================================

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderSoft,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Create',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _bottomAction(
                  Icons.edit_rounded,
                  'Create Post',
                ),
                _bottomAction(
                  Icons.radio_rounded,
                  'Go Live',
                ),
                _bottomAction(
                  Icons.poll_rounded,
                  'Create Poll',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BOTTOM ACTION
  // ===========================================================================

  Widget _bottomAction(
    IconData icon,
    String title,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _border,
          ),
        ),
        child: Icon(
          icon,
          color: _brightPurple,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _showMessage(title);
      },
    );
  }

  // ===========================================================================
  // CREATE POST SHEET
  // ===========================================================================

  void _showCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _borderSoft,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Create a post',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLines: 5,
                style: const TextStyle(
                  color: _primaryText,
                ),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: const TextStyle(
                    color: _mutedText,
                  ),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(17),
                    borderSide:
                        const BorderSide(
                      color: _purple,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(15),
                    gradient:
                        const LinearGradient(
                      colors: [
                        _purple,
                        _brightPurple,
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage(
                        'Post created',
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.transparent,
                      shadowColor:
                          Colors.transparent,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _FeedSearchDelegate(),
    );
  }

  // ===========================================================================
  // POST MENU
  // ===========================================================================

  void _showPostMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.bookmark_border_rounded,
                    color: _brightPurple,
                  ),
                  title: const Text(
                    'Save post',
                    style: TextStyle(
                      color: _primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    color: _cyan,
                  ),
                  title: const Text(
                    'Turn on notifications',
                    style: TextStyle(
                      color: _primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.report_outlined,
                    color: _brightPurple,
                  ),
                  title: const Text(
                    'Report post',
                    style: TextStyle(
                      color: _primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(
          milliseconds: 900,
        ),
      ),
    );
  }
}

// ============================================================================
// SEARCH DELEGATE
// ============================================================================

class _FeedSearchDelegate
    extends SearchDelegate<String?> {
  final List<String> suggestions = const [
    'Siso Mkhize',
    'Zama The Creator',
    'Lunga',
    'Nandi',
    'Trending',
    'Music',
    'Sunsets',
    '#ChattªX',
  ];

  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor:
          const Color(0xFF050816),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF080D1A),
        foregroundColor: Color(0xFFF5F7FF),
        elevation: 0,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Color(0xFF68738A),
        ),
        border: InputBorder.none,
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
          icon: const Icon(
            Icons.clear_rounded,
          ),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      icon: const Icon(
        Icons.arrow_back_rounded,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return _results();
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _results();
  }

  Widget _results() {
    final filtered = suggestions
        .where(
          (item) => item
              .toLowerCase()
              .contains(
                query.toLowerCase(),
              ),
        )
        .toList();

    return Container(
      color: const Color(0xFF050816),
      child: ListView.builder(
        physics:
            const BouncingScrollPhysics(),
        itemCount: filtered.length,
        itemBuilder: (
          context,
          index,
        ) {
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 3,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color(0xFF0D1324),
                border: Border.all(
                  color:
                      const Color(0xFF7B2FF7),
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color:
                    Color(0xFFB026FF),
              ),
            ),
            title: Text(
              filtered[index],
              style: const TextStyle(
                color:
                    Color(0xFFF5F7FF),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'ChattªX',
              style: TextStyle(
                color:
                    Color(0xFF68738A),
              ),
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}