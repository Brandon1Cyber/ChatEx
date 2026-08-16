import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();

  int _currentReel = 0;
  int _selectedTopTab = 0;

  final List<String> _topTabs = const [
    'For You',
    'Following',
    'Trending',
    'Nearby',
    'Friends',
  ];

  final List<_ReelData> _reels = const [
    _ReelData(
      imageUrl:
          'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=1400&q=90',
      username: '@Lerato',
      location: 'Johannesburg, South Africa',
      caption: 'Exploring Johannesburg 🏙️🌙',
      hashtags: '#ChattªX #Vibes #NightLife',
      sound: 'Original ChattªX Sound',
      likes: '12.4K',
      fires: '3.2K',
      hype: '5.6K',
      comments: '342',
      shares: '1.2K',
      avatarUrl: 'https://i.pravatar.cc/300?img=47',
      verified: true,
    ),
    _ReelData(
      imageUrl:
          'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1400&q=90',
      username: '@Thando',
      location: 'Johannesburg, South Africa',
      caption: 'The city never sleeps ✨',
      hashtags: '#ChattªX #CityLights #FutureVibes',
      sound: 'Midnight Motion',
      likes: '18.7K',
      fires: '6.8K',
      hype: '8.1K',
      comments: '721',
      shares: '2.4K',
      avatarUrl: 'https://i.pravatar.cc/300?img=32',
      verified: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BOTTOM NAVIGATION CLEARANCE
  // ==========================================================================

  double _bottomClearance(BuildContext context) {
    return 66 + MediaQuery.of(context).viewPadding.bottom;
  }

  // ==========================================================================
  // CREATE REEL
  // ==========================================================================

  void _openCreateReel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Create a new ChattªX Reel',
        ),
        backgroundColor: Color(0xFF7625FF),
      ),
    );
  }

  // ==========================================================================
  // PROFILE SETTINGS
  // ==========================================================================

  void _openProfileSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF080914),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF55586B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                _profileMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  subtitle: 'View your ChattªX profile',
                ),

                _profileMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Reels Settings',
                  subtitle:
                      'Privacy, playback and notifications',
                ),

                _profileMenuItem(
                  icon: Icons.bookmark_outline_rounded,
                  title: 'Saved Reels',
                  subtitle: 'Your saved videos',
                ),

                _profileMenuItem(
                  icon: Icons.analytics_outlined,
                  title: 'Creator Dashboard',
                  subtitle:
                      'Manage your content and performance',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF17152A),
                border: Border.all(
                  color: const Color(0xFF7428FF),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(
                      126,
                      38,
                      255,
                      0.22,
                    ),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFFBD7AFF),
                size: 24,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF85879A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF66697B),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: false,
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF03040A),
        body: Column(
          children: [
            Container(
              color: const Color(0xFF03040A),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTopTabs(),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _reels.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentReel = index;
                        });
                      },
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        return _buildReelPage(
                          _reels[index],
                          index,
                        );
                      },
                    ),
                  ),

                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildGlobalGradient(),
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
  // REEL PAGE
  // ==========================================================================

  Widget _buildReelPage(
    _ReelData reel,
    int index,
  ) {
    final double navClearance =
        _bottomClearance(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ======================================================================
        // REEL BACKGROUND
        // ======================================================================

        Image.network(
          reel.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF17102E),
                    Color(0xFF05060D),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 82,
                ),
              ),
            );
          },
        ),

        _buildReelOverlay(),

        // ======================================================================
        // CREATOR PROFILE + PLUS
        //
        // Positioned above the action stack with matching spacing.
        // ======================================================================

        Positioned(
          right: 5,
          bottom: navClearance + 385,
          child: _buildCreatorAddButton(reel),
        ),

        // ======================================================================
        // RIGHT ACTIONS
        // ======================================================================

        Positioned(
          right: 5,
          bottom: navClearance + 18,
          child: _buildActionColumn(reel),
        ),

        // ======================================================================
        // CREATOR INFORMATION
        // ======================================================================

        Positioned(
          left: 0,
          right: 82,
          bottom: navClearance + 18,
          child: _buildCreatorInformation(reel),
        ),

        // ======================================================================
        // PAGE INDICATOR
        // ======================================================================

        Positioned(
          left: 20,
          bottom: navClearance + 5,
          child: _buildReelPageIndicator(index),
        ),
      ],
    );
  }

  // ==========================================================================
  // GLOBAL GRADIENT
  // ==========================================================================

  Widget _buildGlobalGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            0.0,
            0.12,
            0.38,
            0.67,
            0.82,
            1.0,
          ],
          colors: [
            Color.fromRGBO(0, 0, 0, 0.30),
            Color.fromRGBO(0, 0, 0, 0.08),
            Color.fromRGBO(0, 0, 0, 0.00),
            Color.fromRGBO(0, 0, 0, 0.04),
            Color.fromRGBO(0, 0, 0, 0.46),
            Color.fromRGBO(0, 0, 0, 0.88),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // REEL OVERLAY
  // ==========================================================================

  Widget _buildReelOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(0, 0, 0, 0.15),
            Color.fromRGBO(0, 0, 0, 0.00),
            Color.fromRGBO(0, 0, 0, 0.00),
            Color.fromRGBO(0, 0, 0, 0.38),
          ],
          stops: [
            0,
            0.28,
            0.58,
            1,
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          7,
          10,
          0,
        ),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.white,
                    Color(0xFFB02DFF),
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'ChattªX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
            ),

            const SizedBox(width: 6),

            const Text(
              'Reels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            _buildLiveButton(),

            const SizedBox(width: 7),

            _buildHeaderIcon(
              Icons.search_rounded,
              () {},
            ),

            const SizedBox(width: 5),

            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _openProfileSettings,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color.fromRGBO(
                        7,
                        7,
                        18,
                        0.78,
                      ),
                      border: Border.all(
                        color: const Color(0xFF9E4DFF),
                        width: 1.1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(
                            137,
                            42,
                            255,
                            0.38,
                          ),
                          blurRadius: 13,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),

                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFB400FF),
                      border: Border.all(
                        color: const Color(0xFF080912),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LIVE BUTTON
  // ==========================================================================

  Widget _buildLiveButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color.fromRGBO(
            31,
            8,
            62,
            0.78,
          ),
          border: Border.all(
            color: const Color(0xFF8A36FF),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(
                128,
                35,
                255,
                0.28,
              ),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_tethering_rounded,
              color: Color(0xFFC264FF),
              size: 15,
            ),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color: Color(0xFFC87AFF),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER ICON
  // ==========================================================================

  Widget _buildHeaderIcon(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TOP TABS
  // ==========================================================================

  Widget _buildTopTabs() {
    return SizedBox(
      height: 43,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _topTabs.length,
        itemBuilder: (
          context,
          index,
        ) {
          final bool selected =
              _selectedTopTab == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTopTab = index;
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                left: index == 0 ? 14 : 0,
                right: 24,
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    _topTabs[index],
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFB742FF)
                          : const Color(0xFFD0D0D8),
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 7),

                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 220,
                    ),
                    width: selected ? 42 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E2DFF),
                      borderRadius:
                          BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF8B25FF),
                          blurRadius: 9,
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
    );
  }

  // ==========================================================================
  // CREATOR AVATAR + PLUS
  // ==========================================================================

  Widget _buildCreatorAddButton(
    _ReelData reel,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD33BFF),
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(
                  220,
                  43,
                  255,
                  0.48,
                ),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              reel.avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const ColoredBox(
                  color: Color(0xFF18152A),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),

        Transform.translate(
          offset: const Offset(
            0,
            -2,
          ),
          child: GestureDetector(
            onTap: _openCreateReel,
            child: Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6B1FFF),
                    Color(0xFFB328FF),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFE1C4FF),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(
                      139,
                      41,
                      255,
                      0.55,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // ACTION COLUMN
  // ==========================================================================

  Widget _buildActionColumn(
    _ReelData reel,
  ) {
    return SizedBox(
      width: 55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            icon: Icons.favorite_border_rounded,
            count: reel.likes,
            iconColor: Colors.white,
            glowColor: const Color(0xFFFF38D0),
            onTap: () {},
          ),

          const SizedBox(height: 3),

          _actionButton(
            icon: Icons.local_fire_department_rounded,
            count: reel.fires,
            iconColor: Colors.white,
            glowColor: const Color(0xFFFF6A24),
            onTap: () {},
          ),

          const SizedBox(height: 3),

          _actionButton(
            icon: Icons.auto_awesome_rounded,
            count: reel.hype,
            iconColor: Colors.white,
            glowColor: const Color(0xFF25DFFF),
            onTap: () {},
          ),

          const SizedBox(height: 3),

          _actionButton(
            icon: Icons.chat_bubble_outline_rounded,
            count: reel.comments,
            iconColor: Colors.white,
            glowColor: const Color(0xFF38CFFF),
            onTap: () {},
          ),

          const SizedBox(height: 3),

          _actionButton(
            icon: Icons.near_me_rounded,
            count: reel.shares,
            iconColor: Colors.white,
            glowColor: const Color(0xFF44F0A4),
            onTap: () {},
          ),

          const SizedBox(height: 3),

          _actionButton(
            icon: Icons.more_horiz_rounded,
            count: '',
            iconColor: Colors.white,
            glowColor: const Color(0xFF9A9AA7),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACTION BUTTON
  // ==========================================================================

  Widget _actionButton({
    required IconData icon,
    required String count,
    required Color iconColor,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 50,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromRGBO(
                  4,
                  5,
                  13,
                  0.62,
                ),
                border: Border.all(
                  color: Color.fromRGBO(
                    glowColor.red,
                    glowColor.green,
                    glowColor.blue,
                    0.72,
                  ),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(
                      glowColor.red,
                      glowColor.green,
                      glowColor.blue,
                      0.26,
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
          ),

          if (count.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              count,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // CREATOR INFORMATION
  //
  // FOLLOW BUTTON REMOVED COMPLETELY
  // ==========================================================================

  Widget _buildCreatorInformation(
    _ReelData reel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFAA3BFF),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    reel.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const ColoredBox(
                        color: Color(0xFF18152A),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                child: Text(
                  reel.username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              if (reel.verified) ...[
                const SizedBox(width: 5),

                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7541FF),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 9),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFFB13DFF),
                size: 17,
              ),

              const SizedBox(width: 4),

              Flexible(
                child: Text(
                  reel.location,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Text(
            reel.caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            reel.hashtags,
            style: const TextStyle(
              color: Color(0xFFC145FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAGE INDICATOR
  // ==========================================================================

  Widget _buildReelPageIndicator(
    int index,
  ) {
    return Row(
      children: List.generate(
        _reels.length,
        (itemIndex) {
          final bool active =
              itemIndex == index;

          return AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            margin: const EdgeInsets.only(
              right: 4,
            ),
            width: active ? 15 : 4,
            height: 3,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFB33BFF)
                  : const Color(0xFF777786),
              borderRadius:
                  BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// REEL DATA
// ============================================================================

class _ReelData {
  final String imageUrl;
  final String username;
  final String location;
  final String caption;
  final String hashtags;
  final String sound;
  final String likes;
  final String fires;
  final String hype;
  final String comments;
  final String shares;
  final String avatarUrl;
  final bool verified;

  const _ReelData({
    required this.imageUrl,
    required this.username,
    required this.location,
    required this.caption,
    required this.hashtags,
    required this.sound,
    required this.likes,
    required this.fires,
    required this.hype,
    required this.comments,
    required this.shares,
    required this.avatarUrl,
    required this.verified,
  });
}