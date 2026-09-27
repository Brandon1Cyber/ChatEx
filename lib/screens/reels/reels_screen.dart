import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({
    super.key,
    this.initialVideoUrl,
    this.initialPostData,
  });

  /// Used when Feed opens a specific video.
  ///
  /// Example:
  /// ReelsScreen(
  ///   initialVideoUrl: videoUrl,
  ///   initialPostData: postData,
  /// )
  final String? initialVideoUrl;

  /// Complete Firestore post data for the video opened from Feed.
  final Map<String, dynamic>? initialPostData;

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

  final List<_ReelData> _reels = [
    const _ReelData(
      imageUrl:
          'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=1400&q=90',
      username: '@Lerato',
      location: 'Johannesburg, South Africa',
      caption: 'Exploring Johannesburg 🏙️🌙',
      hashtags: '#ChattªX #Vibes #NightLife',
      sound: 'Original ChattªX Sound',
      likes: '12.4K',
      fires: '3.2K',
      reposts: '8.1K',
      comments: '342',
      shares: '1.2K',
      avatarUrl: 'https://i.pravatar.cc/300?img=47',
      verified: true,
    ),
    const _ReelData(
      imageUrl:
          'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1400&q=90',
      username: '@Thando',
      location: 'Johannesburg, South Africa',
      caption: 'The city never sleeps ✨',
      hashtags: '#ChattªX #CityLights #FutureVibes',
      sound: 'Midnight Motion',
      likes: '18.7K',
      fires: '6.8K',
      reposts: '4.3K',
      comments: '721',
      shares: '2.4K',
      avatarUrl: 'https://i.pravatar.cc/300?img=32',
      verified: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _insertInitialFeedVideo();

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

  // ==========================================================================
  // INSERT VIDEO OPENED FROM FEED
  // ==========================================================================

  void _insertInitialFeedVideo() {
    final String? videoUrl = widget.initialVideoUrl;

    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return;
    }

    final Map<String, dynamic> data =
        widget.initialPostData ?? <String, dynamic>{};

    _reels.insert(
      0,
      _ReelData(
        videoUrl: videoUrl,
        imageUrl: '',
        username: _buildUsername(data),
        location: _readString(
          data,
          const [
            'location',
            'locationName',
            'placeName',
          ],
        ),
        caption: _readString(
          data,
          const [
            'text',
            'caption',
          ],
        ),
        hashtags: _readString(
          data,
          const [
            'hashtags',
          ],
        ),
        sound: 'Original ChattªX Sound',
        likes: _formatCount(
          data['likeCount'],
        ),
        fires: _formatCount(
          data['fireCount'],
        ),
        reposts: _formatCount(
          data['repostCount'],
        ),
        comments: _formatCount(
          data['commentCount'],
        ),
        shares: _formatCount(
          data['shareCount'],
        ),
        avatarUrl: _readString(
          data,
          const [
            'photoUrl',
            'photoURL',
            'avatarUrl',
          ],
        ),
        verified: data['verified'] == true,
      ),
    );
  }

  String _buildUsername(
    Map<String, dynamic> data,
  ) {
    final String name = _readString(
      data,
      const [
        'displayName',
        'name',
        'username',
      ],
    );

    if (name.isEmpty) {
      return '@ChattªX';
    }

    if (name.startsWith('@')) {
      return name;
    }

    return '@$name';
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _formatCount(
    dynamic value,
  ) {
    final int count = value is num
        ? value.toInt()
        : int.tryParse(
              value?.toString() ?? '',
            ) ??
            0;

    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }

    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }

    return count.toString();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MAIN NAVIGATION HEIGHT
  // ==========================================================================

  double _mainNavigationHeight(
    BuildContext context,
  ) {
    return 66 +
        MediaQuery.of(context).viewPadding.bottom;
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
        backgroundColor: Color(0xFF7B2FF7),
      ),
    );
  }

  // ==========================================================================
  // PROFILE SETTINGS
  // ==========================================================================

  void _openProfileSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF050816),
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
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                _profileMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  subtitle:
                      'View your ChattªX profile',
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
                color: const Color(0xFF0B0A18),
                border: Border.all(
                  color: const Color(0xFF7B2FF7),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(
                      123,
                      47,
                      247,
                      0.22,
                    ),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFFB026FF),
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
  Widget build(
    BuildContext context,
  ) {
    final double mainNavHeight =
        _mainNavigationHeight(context);

    return AnnotatedRegion<
        SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor:
            Colors.transparent,
        statusBarIconBrightness:
            Brightness.light,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
      child: Scaffold(
        extendBody: false,
        extendBodyBehindAppBar: false,
        resizeToAvoidBottomInset: false,
        backgroundColor:
            const Color(0xFF050816),
        body: Column(
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Container(
              color: const Color(0xFF050816),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTopTabs(),
                ],
              ),
            ),

            // ================================================================
            // REELS VIEWPORT
            // ================================================================

            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: mainNavHeight,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection:
                          Axis.vertical,
                      itemCount: _reels.length,
                      onPageChanged: (index) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _currentReel = index;
                        });
                      },
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        return _ReelPage(
                          key: ValueKey(
                            'reel_page_${index}_${_reels[index].videoUrl ?? _reels[index].imageUrl}',
                          ),
                          reel: _reels[index],
                          isActive:
                              index == _currentReel,
                          onCreateReel:
                              _openCreateReel,
                        );
                      },
                    ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child:
                            _buildGlobalGradient(),
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
            0.88,
            1.0,
          ],
          colors: [
            Color.fromRGBO(
              5,
              8,
              22,
              0.30,
            ),
            Color.fromRGBO(
              5,
              8,
              22,
              0.08,
            ),
            Color.fromRGBO(
              5,
              8,
              22,
              0.00,
            ),
            Color.fromRGBO(
              5,
              8,
              22,
              0.02,
            ),
            Color.fromRGBO(
              5,
              8,
              22,
              0.10,
            ),
            Color.fromRGBO(
              5,
              8,
              22,
              0.14,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildHeader() {
  return SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        7,
        7,
        10,
        0,
      ),
      child: Row(
        children: [
          // ================================================================
          // BACK BUTTON
          // ================================================================

          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const SizedBox(
              width: 42,
              height: 38,
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(width: 2),

          // ================================================================
          // REELS TITLE
          // ================================================================

          const Text(
            'Reels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          // ================================================================
          // SEARCH
          // ================================================================

          _buildHeaderIcon(
            Icons.search_rounded,
            () {},
          ),

          const SizedBox(width: 5),

          // ================================================================
          // MY PROFILE PHOTO
          // ================================================================

          GestureDetector(
            onTap: _openProfileSettings,
            child: _buildMyProfileAvatar(),
          ),
        ],
      ),
    ),
  );
}

// ==========================================================================
// MY PROFILE AVATAR
// ==========================================================================

Widget _buildMyProfileAvatar() {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return _buildFallbackProfileAvatar();
  }

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(),
    builder: (
      context,
      snapshot,
    ) {
      String photoUrl = '';

      if (snapshot.hasData && snapshot.data!.exists) {
        final Map<String, dynamic>? data =
            snapshot.data!.data();

        if (data != null) {
          final dynamic photoValue =
              data['photoUrl'] ??
              data['photoURL'] ??
              data['profilePhoto'] ??
              data['avatarUrl'];

          if (photoValue is String &&
              photoValue.trim().isNotEmpty) {
            photoUrl = photoValue.trim();
          }
        }
      }

      // Firebase Auth photo as a secondary fallback.
      if (photoUrl.isEmpty) {
        photoUrl = user.photoURL ?? '';
      }

      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF050816),
          border: Border.all(
            color: const Color(0xFF7B2FF7),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(
                123,
                47,
                247,
                0.38,
              ),
              blurRadius: 13,
            ),
          ],
        ),
        child: ClipOval(
          child: photoUrl.isEmpty
              ? _buildFallbackProfileAvatar()
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _buildFallbackProfileAvatar();
                  },
                ),
        ),
      );
    },
  );
}

Widget _buildFallbackProfileAvatar() {
  return const ColoredBox(
    color: Color(0xFF0B0A18),
    child: Center(
      child: Icon(
        Icons.person_outline_rounded,
        color: Colors.white,
        size: 21,
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
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(18),
          color:
              const Color.fromRGBO(
            31,
            8,
            62,
            0.78,
          ),
          border: Border.all(
            color:
                const Color(0xFF7B2FF7),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(
                123,
                47,
                247,
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
              color:
                  Color(0xFFB026FF),
              size: 15,
            ),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color:
                    Color(0xFFB026FF),
                fontSize: 10,
                fontWeight:
                    FontWeight.w900,
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
      height: 36,
      child: ListView.builder(
        scrollDirection:
            Axis.horizontal,
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
                left: index == 0
                    ? 14
                    : 0,
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
                          ? const Color(
                              0xFFB026FF,
                            )
                          : const Color(
                              0xFFD0D0D8,
                            ),
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 220,
                    ),
                    width: selected
                        ? 42
                        : 0,
                    height: 2,
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFF7B2FF7,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color:
                              Color(
                            0xFF7B2FF7,
                          ),
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
}

// ============================================================================
// REEL PAGE
// ============================================================================
//
// Each page owns its own video controller.
//
// This means:
//
// Feed video -> ReelScreen -> video automatically plays
//
// Swiping away -> video pauses
//
// Swiping back -> video resumes
//
// Demo image reels continue to work normally.
// ============================================================================

class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.onCreateReel,
  });

  final _ReelData reel;
  final bool isActive;
  final VoidCallback onCreateReel;

  @override
  State<_ReelPage> createState() =>
      _ReelPageState();
}

class _ReelPageState
    extends State<_ReelPage> {
  VideoPlayerController? _videoController;

  bool _loadingVideo = false;
  bool _videoError = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();

    if (_hasVideo) {
      _initializeVideo();
    }
  }

  bool get _hasVideo {
    return widget.reel.videoUrl != null &&
        widget.reel.videoUrl!
            .trim()
            .isNotEmpty;
  }

  Future<void> _initializeVideo() async {
    final String url =
        widget.reel.videoUrl!;

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingVideo = true;
      _videoError = false;
    });

    final controller =
        VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _videoController = controller;

    try {
      await controller.initialize();

      if (!mounted) {
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(1.0);

      if (widget.isActive) {
        await controller.play();
      }

      setState(() {
        _loadingVideo = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingVideo = false;
        _videoError = true;
      });
    }
  }

  @override
  void didUpdateWidget(
    covariant _ReelPage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_hasVideo) {
      return;
    }

    final VideoPlayerController?
        controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (widget.isActive) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  Future<void> _toggleVideo() async {
    final controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showControls = true;
    });

    Future.delayed(
      const Duration(
        milliseconds: 850,
      ),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _showControls = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUILD REEL PAGE
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(),

        _buildReelOverlay(),

        // ================================================================
        // CREATOR AVATAR
        // ================================================================

        Positioned(
          right: 5,
          bottom: 410,
          child:
              _buildCreatorAddButton(),
        ),

        // ================================================================
        // ACTIONS
        // ================================================================

        Positioned(
          right: 5,
          bottom: 43,
          child:
              _buildActionColumn(),
        ),

        // ================================================================
        // CREATOR INFORMATION
        // ================================================================

        Positioned(
          left: 0,
          right: 82,
          bottom: 43,
          child:
              _buildCreatorInformation(),
        ),

        // ================================================================
        // PAGE INDICATOR
        // ================================================================

        // Page indicator intentionally remains
        // inside the parent screen's original design.
      ],
    );
  }

  // ==========================================================================
  // MEDIA
  // ==========================================================================

  Widget _buildMedia() {
    if (!_hasVideo) {
      return _buildImageMedia();
    }

    final controller =
        _videoController;

    if (_loadingVideo ||
        controller == null) {
      return Container(
        color: const Color(0xFF050816),
        child: const Center(
          child:
              CircularProgressIndicator(
            color: Color(0xFFB026FF),
            strokeWidth: 2.2,
          ),
        ),
      );
    }

    if (_videoError ||
        !controller.value.isInitialized) {
      return Container(
        decoration:
            const BoxDecoration(
          gradient: LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(0xFF17102E),
              Color(0xFF050816),
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons
                .video_library_outlined,
            color: Colors.white,
            size: 68,
          ),
        ),
      );
    }

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: _toggleVideo,
      child: Center(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width:
                  controller.value.size.width,
              height:
                  controller.value.size.height,
              child:
                  VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageMedia() {
    if (widget.reel.imageUrl
        .trim()
        .isEmpty) {
      return Container(
        color:
            const Color(0xFF050816),
      );
    }

    return Image.network(
      widget.reel.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
              colors: [
                Color(0xFF17102E),
                Color(0xFF050816),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons
                  .play_circle_fill_rounded,
              color: Colors.white,
              size: 82,
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PLAY / PAUSE INDICATOR
  // ==========================================================================

  Widget _buildPlaybackIndicator() {
    final controller =
        _videoController;

    if (!_hasVideo ||
        controller == null ||
        !controller.value.isInitialized ||
        !_showControls) {
      return const SizedBox
          .shrink();
    }

    final bool playing =
        controller.value.isPlaying;

    return Center(
      child: AnimatedOpacity(
        opacity: _showControls
            ? 1
            : 0,
        duration:
            const Duration(
          milliseconds: 180,
        ),
        child: Container(
          width: 70,
          height: 70,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color:
                const Color.fromRGBO(
              5,
              8,
              22,
              0.68,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFB026FF,
              ),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color.fromRGBO(
                  176,
                  38,
                  255,
                  0.32,
                ),
                blurRadius: 22,
              ),
            ],
          ),
          child: Icon(
            playing
                ? Icons
                    .pause_rounded
                : Icons
                    .play_arrow_rounded,
            color:
                Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // REEL OVERLAY
  // ==========================================================================

  Widget _buildReelOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(
                  5,
                  8,
                  22,
                  0.15,
                ),
                Color.fromRGBO(
                  5,
                  8,
                  22,
                  0.00,
                ),
                Color.fromRGBO(
                  5,
                  8,
                  22,
                  0.00,
                ),
                Color.fromRGBO(
                  5,
                  8,
                  22,
                  0.38,
                ),
              ],
              stops: [
                0,
                0.28,
                0.58,
                1,
              ],
            ),
          ),
        ),

        _buildPlaybackIndicator(),
      ],
    );
  }

  // ==========================================================================
  // CREATOR AVATAR + PLUS
  // ==========================================================================

  Widget _buildCreatorAddButton() {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          padding:
              const EdgeInsets.all(2),
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  const Color(
                0xFFB026FF,
              ),
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color.fromRGBO(
                  176,
                  38,
                  255,
                  0.48,
                ),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child:
                _buildAvatar(
              widget.reel.avatarUrl,
            ),
          ),
        ),
        Transform.translate(
          offset:
              const Offset(0, -2),
          child: GestureDetector(
            onTap:
                widget.onCreateReel,
            child: Container(
              width: 23,
              height: 23,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(
                      0xFF7B2FF7,
                    ),
                    Color(
                      0xFFB026FF,
                    ),
                  ],
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFE1C4FF,
                  ),
                  width: 1,
                ),
                boxShadow:
                    const [
                  BoxShadow(
                    color:
                        Color.fromRGBO(
                      123,
                      47,
                      247,
                      0.55,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child:
                  const Icon(
                Icons.add_rounded,
                color:
                    Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(
    String url,
  ) {
    if (url.trim().isEmpty) {
      return const ColoredBox(
        color: Color(0xFF0B0A18),
        child: Icon(
          Icons.person,
          color: Colors.white,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return const ColoredBox(
          color: Color(0xFF0B0A18),
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        );
      },
    );
  }

  // ==========================================================================
  // ACTION COLUMN
  // ==========================================================================

  Widget _buildActionColumn() {
    final reel =
        widget.reel;

    return SizedBox(
      width: 55,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _actionButton(
            icon:
                Icons.favorite_border_rounded,
            count: reel.likes,
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFFB026FF,
            ),
            onTap: () {},
          ),
          const SizedBox(
            height: 3,
          ),
          _actionButton(
            icon:
                Icons.local_fire_department_rounded,
            count: reel.fires,
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFFB026FF,
            ),
            onTap: () {},
          ),
          const SizedBox(
            height: 3,
          ),
          _actionButton(
            icon:
                Icons.repeat_rounded,
            count:
                reel.reposts,
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFF7B2FF7,
            ),
            onTap: () {},
          ),
          const SizedBox(
            height: 3,
          ),
          _actionButton(
            icon:
                Icons.chat_bubble_outline_rounded,
            count:
                reel.comments,
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFFB026FF,
            ),
            onTap: () {},
          ),
          const SizedBox(
            height: 3,
          ),
          _actionButton(
            icon:
                Icons.near_me_rounded,
            count:
                reel.shares,
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFF7B2FF7,
            ),
            onTap: () {},
          ),
          const SizedBox(
            height: 3,
          ),
          _actionButton(
            icon:
                Icons.more_horiz_rounded,
            count: '',
            iconColor:
                Colors.white,
            glowColor:
                const Color(
              0xFF9A9AA7,
            ),
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
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    const Color.fromRGBO(
                  5,
                  8,
                  22,
                  0.62,
                ),
                border:
                    Border.all(
                  color:
                      glowColor.withValues(
                    alpha: 0.72,
                  ),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        glowColor.withValues(
                      alpha: 0.26,
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color:
                    iconColor,
                size: 22,
              ),
            ),
          ),
          if (count.isNotEmpty) ...[
            const SizedBox(
              height: 2,
            ),
            Text(
              count,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
                shadows: [
                  Shadow(
                    color:
                        Colors.black,
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
  // ==========================================================================

  Widget _buildCreatorInformation() {
    final reel =
        widget.reel;

    return Padding(
      padding:
          const EdgeInsets.only(
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
                padding:
                    const EdgeInsets.all(
                  1.5,
                ),
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFF7B2FF7,
                    ),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child:
                      _buildAvatar(
                    reel.avatarUrl,
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Flexible(
                child: Text(
                  reel.username,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              if (reel.verified) ...[
                const SizedBox(
                  width: 5,
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        Color(
                      0xFF7B2FF7,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons.check_rounded,
                    color:
                        Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),

          if (reel.location
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 9,
            ),
            Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .location_on_outlined,
                  color:
                      Color(
                    0xFFB026FF,
                  ),
                  size: 17,
                ),
                const SizedBox(
                  width: 4,
                ),
                Flexible(
                  child: Text(
                    reel.location,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (reel.caption
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 7,
            ),
            Text(
              reel.caption,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],

          if (reel.hashtags
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 3,
            ),
            Text(
              reel.hashtags,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Color(0xFFB026FF),
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(
            height: 5,
          ),

          Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note_rounded,
                color:
                    Color(0xFFB026FF),
                size: 14,
              ),
              const SizedBox(
                width: 4,
              ),
              Flexible(
                child: Text(
                  reel.sound,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
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
// REEL DATA
// ============================================================================

class _ReelData {
  final String? videoUrl;
  final String imageUrl;

  final String username;
  final String location;
  final String caption;
  final String hashtags;
  final String sound;

  final String likes;
  final String fires;
  final String reposts;
  final String comments;
  final String shares;

  final String avatarUrl;
  final bool verified;

  const _ReelData({
    this.videoUrl,
    required this.imageUrl,
    required this.username,
    required this.location,
    required this.caption,
    required this.hashtags,
    required this.sound,
    required this.likes,
    required this.fires,
    required this.reposts,
    required this.comments,
    required this.shares,
    required this.avatarUrl,
    required this.verified,
  });
}