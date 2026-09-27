import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import '../widgets/verified_name.dart';

import 'create_post_screen.dart';
import 'feed_notification_screen.dart';
import 'my_profile_screen.dart';
import 'package:geocoding/geocoding.dart';
import 'feed_create_story_screen.dart';
import 'public_profile_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'reels/reels_screen.dart';
import 'story_viewer_screen.dart';


class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}
class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {


  Stream<bool> get _unseenNotificationsStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream<bool>.value(false);
    }

    return FirebaseFirestore.instance
        .collection('feed_notifications')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map<bool>(
          (snapshot) => snapshot.docs.isNotEmpty,
        );
  }

  
  // ==========================================================================
  // COLORS
  // ==========================================================================

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

  static const double _sideSpace = 7;

  // ==========================================================================
  // STATE
  // ==========================================================================

  int _selectedTopTab = 0;

  // ==========================================================================
// WHAT'S HAPPENING? ANIMATION
// ==========================================================================

late AnimationController _whatsHappeningController;
late Animation<double> _whatsHappeningOpacity;
late Animation<double> _whatsHappeningGlow;

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

  // ==========================================================================
  // CURRENT USER
  // ==========================================================================

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String? get _currentUid => _currentUser?.uid;

  String? get _profileUrl {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    final url = user.photoURL;

    if (url == null || url.trim().isEmpty) {
      return null;
    }

    return url.trim();
  }

  // ==========================================================================
// WHAT'S HAPPENING? ANIMATION SETUP
// ==========================================================================

@override
void initState() {
  super.initState();

  _whatsHappeningController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  _whatsHappeningOpacity = Tween<double>(
    begin: 0.68,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _whatsHappeningController,
      curve: Curves.easeInOut,
    ),
  );

  _whatsHappeningGlow = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _whatsHappeningController,
      curve: Curves.easeInOut,
    ),
  );

  _whatsHappeningController.repeat(
    reverse: true,
  );
}

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _background,
    body: SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ================================================================
          // HEADER
          // ================================================================

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _sideSpace,
              ),
              child: _buildHeader(),
            ),
          ),

          // ================================================================
          // FEED TABS
          // ================================================================

          SliverToBoxAdapter(
  child: _buildTabs(),
),

          // ================================================================
          // WHAT'S HAPPENING?
          // ================================================================

          SliverToBoxAdapter(
            child: _buildCreatePost(),
          ),

                    // ================================================================
          // STORIES
          // ================================================================

          SliverToBoxAdapter(
            child: _buildStoriesSection(),
          ),

          // Small gap between stories and posts
          const SliverToBoxAdapter(
            child: SizedBox(height: 10),
          ),

          // ================================================================
          // POSTS
          // ================================================================

          _buildFirestorePosts(),

          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    ),
  );
}

  @override
void dispose() {
  _whatsHappeningController.dispose();
  super.dispose();
}

  // ==========================================================================
  // FIRESTORE POSTS
  // ==========================================================================

  Widget _buildFirestorePosts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _buildPostLoadError(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 35),
              child: Center(
                child: CircularProgressIndicator(
                  color: _brightPurple,
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return SliverList(
            delegate: SliverChildListDelegate([
              _buildDemoSunsetPost(),
              _buildDemoMusicPost(),
              _buildDemoTextPost(),
            ]),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final document = docs[index];

              return _FirestorePostCard(
  key: ValueKey(document.id),
  postId: document.id,
  data: document.data(),
  currentUid: _currentUid,
  onShowMessage: _showMessage,
  onOpenPostMenu: () {
    _showPostMenu(
      postId: document.id,
      postData: document.data(),
    );
  },
);
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }

  Widget _buildPostLoadError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        _sideSpace,
        4,
        _sideSpace,
        12,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: _mutedText,
            size: 30,
          ),
          SizedBox(height: 8),
          Text(
            'Could not load posts',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
// HEADER
// ==========================================================================
Widget _buildHeader() {
  return SizedBox(
    height: 58,
    child: Row(
      children: [
        // ================================================================
        // CHATTªX LOGO
        // ================================================================

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    "assets/chatex_logoo.png",
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(width: 7),

                const Text(
                  'Chattª',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),

                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF00E5FF),
                        Color(0xFFB026FF),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'X',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================================================================
        // CREATE
        // ================================================================

        _headerIconButton(
          icon: Icons.add_rounded,
          onTap: _showCreateMenu,
        ),

        const SizedBox(width: 2),

        // ================================================================
        // SEARCH
        // ================================================================

        _headerIconButton(
          icon: Icons.search_rounded,
          onTap: _showSearch,
        ),

        const SizedBox(width: 2),

        // ================================================================
        // NOTIFICATIONS
        // ================================================================

        StreamBuilder<bool>(
          stream: _unseenNotificationsStream,
          initialData: false,
          builder: (context, snapshot) {
            final hasUnseenNotifications =
                snapshot.data == true;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                _headerIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const FeedNotificationScreen(),
                      ),
                    );
                  },
                ),

                if (hasUnseenNotifications)
                  Positioned(
                    right: 5,
                    top: 5,
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
            );
          },
        ),

        const SizedBox(width: 4),

        // ================================================================
        // PROFILE
        // ================================================================

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
               builder: (_) => const MyProfileScreen(),
              ),
            );
          },
          child: _profileImage(size: 36),
        ),

        const SizedBox(width: 3),
      ],
    ),
  );
}


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

  // ==========================================================================
  // PROFILE IMAGE
  // ==========================================================================

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
          colors: [
            _purple,
            _cyan,
          ],
        ),
      ),
      child: ClipOval(
        child: photoUrl == null
            ? _profileFallback()
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
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

  // ==========================================================================
  // TABS
  // ==========================================================================

  Widget _buildTabs() {
  return SizedBox(
    height: 42,
    width: double.infinity,
    child: Row(
      children: List.generate(
        _topTabs.length,
        (index) {
          final selected = index == _selectedTopTab;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!mounted) return;

                setState(() {
                  _selectedTopTab = index;
                });
              },
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // ========================================================
                  // TAB TEXT
                  // ========================================================

                  Positioned.fill(
                    child: Center(
                      child: Text(
                        _topTabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? _brightPurple
                              : _secondaryText,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // ========================================================
                  // ACTIVE UNDERLINE
                  // ========================================================

                  if (selected)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: 58,
                        height: 2.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [
                              _brightPurple,
                              _cyan,
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x557B2FF7),
                              blurRadius: 7,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
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

  // ==========================================================================
  // CREATE POST
  // ==========================================================================

  Widget _buildCreatePost() {
  return Container(
    margin: const EdgeInsets.fromLTRB(
      _sideSpace,
      5,
      _sideSpace,
      10,
    ),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: _border,
      ),
    ),
    child: Row(
      children: [
        // ================================================================
        // PROFILE
        // ================================================================

        _profileImage(size: 40),

        const SizedBox(width: 9),

        // ================================================================
        // WHAT'S HAPPENING?
        // ================================================================

        Expanded(
          child: GestureDetector(
            onTap: _showCreatePost,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _borderSoft,
                ),
              ),
              child: AnimatedBuilder(
  animation: _whatsHappeningController,
  builder: (context, child) {
    final glow = _whatsHappeningGlow.value;

    return Opacity(
      opacity: _whatsHappeningOpacity.value,
      child: Text(
        "What's happening?",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _secondaryText,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: _cyan.withValues(
                alpha: 0.10 * glow,
              ),
              blurRadius: 7 * glow,
            ),
            Shadow(
              color: _brightPurple.withValues(
                alpha: 0.07 * glow,
              ),
              blurRadius: 10 * glow,
            ),
          ],
        ),
      ),
    );
  },
),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ================================================================
        // PURPLE PLUS
        // ================================================================

        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreatePostScreen(),
              ),
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [
                  _purple,
                  _brightPurple,
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x447B2FF7),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Icon(
Icons.add_rounded,
color: Color(0xFF00E5FF),
size: 25,
),
          ),
        ),
      ],
    ),
  );
}

// ==========================================================================
// STORIES
// ==========================================================================

// ==========================================================================
// STORIES
// ==========================================================================

Widget _buildStoriesSection() {
  final User? currentUser =
      FirebaseAuth.instance.currentUser;

  final String? currentUid = currentUser?.uid;

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('stories')
        .where(
          'expiresAt',
          isGreaterThan: Timestamp.now(),
        )
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _buildStoriesFallback();
      }

      if (snapshot.connectionState ==
              ConnectionState.waiting &&
          !snapshot.hasData) {
        return _buildStoriesLoading();
      }

      final List<Map<String, dynamic>> stories =
          <Map<String, dynamic>>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(
          document.data(),
        );

        final String userId =
            (data['userId'] ??
                    data['createdBy'] ??
                    '')
                .toString();

        if (userId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------------
        // PRIVACY
        // --------------------------------------------------------------

        final String privacy =
            (data['privacy'] ?? 'everyone')
                .toString()
                .toLowerCase()
                .trim();

        // The owner can always see their own story.
        if (currentUid != null &&
            userId == currentUid) {
          data['storyId'] = document.id;
          stories.add(data);
          continue;
        }

        // "Only me" is never visible to another user.
        if (privacy == 'only me' ||
            privacy == 'only_me' ||
            privacy == 'private') {
          continue;
        }

        // Everyone is visible.
        if (privacy == 'everyone' ||
            privacy == 'public') {
          data['storyId'] = document.id;
          stories.add(data);
          continue;
        }

        // --------------------------------------------------------------
        // FRIENDS
        // --------------------------------------------------------------
        //
        // We intentionally do NOT assume a friends collection/path here.
        // Until your existing friendship structure is connected,
        // friend-only stories are hidden from other users rather than
        // accidentally exposing them.
        //

        if (privacy == 'friends' ||
            privacy == 'friend') {
          continue;
        }

        // Unknown privacy values are treated conservatively.
        continue;
      }

      // ================================================================
      // GROUP STORIES BY USER
      // ================================================================

      final Map<String, List<Map<String, dynamic>>>
          storiesByUser =
          <String, List<Map<String, dynamic>>>{};

      for (final Map<String, dynamic> story in stories) {
        final String userId =
            (story['userId'] ?? '').toString();

        if (userId.isEmpty) {
          continue;
        }

        storiesByUser.putIfAbsent(
          userId,
          () => <Map<String, dynamic>>[],
        );

        storiesByUser[userId]!.add(story);
      }

      // ================================================================
      // SORT STORIES
      // ================================================================

      for (final List<Map<String, dynamic>> userStories
          in storiesByUser.values) {
        userStories.sort(
          (Map<String, dynamic> a,
              Map<String, dynamic> b) {
            final Timestamp? aTime =
                a['createdAt'] is Timestamp
                    ? a['createdAt'] as Timestamp
                    : null;

            final Timestamp? bTime =
                b['createdAt'] is Timestamp
                    ? b['createdAt'] as Timestamp
                    : null;

            return (aTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(
              bTime?.millisecondsSinceEpoch ?? 0,
            );
          },
        );
      }

      // ================================================================
      // BUILD STORY USERS
      // ================================================================

      final List<Map<String, dynamic>> storyUsers =
          storiesByUser.entries.map(
        (
          MapEntry<String, List<Map<String, dynamic>>> entry,
        ) {
          final List<Map<String, dynamic>> userStories =
              entry.value;

          final Map<String, dynamic> latest =
              userStories.last;

          return <String, dynamic>{
            'userId': entry.key,
            'stories': userStories,
            'displayName':
                (latest['displayName'] ??
                        latest['name'] ??
                        'User')
                    .toString(),
            'photoUrl':
                (latest['photoUrl'] ??
                        latest['photoURL'] ??
                        latest['userPhoto'] ??
                        '')
                    .toString(),
          };
        },
      ).toList();

      // ================================================================
      // CURRENT USER FIRST
      // ================================================================

      if (currentUid != null) {
        final int ownIndex =
            storyUsers.indexWhere(
          (Map<String, dynamic> story) =>
              story['userId'] == currentUid,
        );

        if (ownIndex > 0) {
          final Map<String, dynamic> ownStory =
              storyUsers.removeAt(ownIndex);

          storyUsers.insert(0, ownStory);
        }
      }

      // ================================================================
      // NO STORIES
      // ================================================================

      return SizedBox(
        height: 178,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
          ),
          itemCount: storyUsers.length + 1,
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            if (index == 0) {
              return _storyCard(
                image: null,
                name: 'Create story',
                isCreate: true,
              );
            }

            final Map<String, dynamic> storyUser =
                storyUsers[index - 1];

            final List<Map<String, dynamic>> userStories =
                List<Map<String, dynamic>>.from(
              storyUser['stories'] as List,
            );

            return _storyCard(
              image:
                  (storyUser['photoUrl'] ?? '')
                      .toString(),
              name:
                  (storyUser['displayName'] ?? 'User')
                      .toString(),
              storyData: userStories,
            );
          },
        ),
      );
    },
  );
} 

Widget _buildStoriesLoading() {
  return SizedBox(
    height: 178,
    child: ListView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      children: <Widget>[
        _storyCard(
          image: null,
          name: 'Create story',
          isCreate: true,
        ),
        ...List<Widget>.generate(
          4,
          (int index) {
            return Container(
              width: 105,
              margin: const EdgeInsets.only(
                right: 5,
              ),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: _border,
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildStoriesFallback() {
  return SizedBox(
    height: 178,
    child: ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      children: [
        _storyCard(
          image: null,
          name: 'Create story',
          isCreate: true,
        ),
      ],
    ),
  );
}


Widget _storyCard({
  required String? image,
  required String name,
  bool isCreate = false,
  List<Map<String, dynamic>>? storyData,
}) {
  return GestureDetector(
    onTap: () async {
      // ============================================================
      // CREATE STORY
      // ============================================================

      if (isCreate) {
        final bool? published =
            await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const FeedCreateStoryScreen(),
          ),
        );

        // The Firestore stories stream normally updates this
        // screen automatically. This simply ensures the widget
        // is still alive after returning.
        if (!mounted) {
          return;
        }

        if (published == true) {
          setState(() {});
        }

        return;
      }

      // ============================================================
      // OPEN STORY VIEWER
      // ============================================================

      if (storyData == null ||
          storyData.isEmpty) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(
            stories: storyData,
            initialIndex: 0,
          ),
        ),
      );
    },
    child: Container(
      width: 105,
      margin: const EdgeInsets.only(
        right: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isCreate
              ? _brightPurple
              : _borderSoft,
          width: 1,
        ),
        boxShadow: [
          if (isCreate)
            const BoxShadow(
              color: Color(0x447B2FF7),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          if (!isCreate)
            const BoxShadow(
              color: Color(0x2200D9FF),
              blurRadius: 5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ========================================================
            // BACKGROUND
            // ========================================================

            if (isCreate)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF17102D),
                      Color(0xFF080D1A),
                      Color(0xFF06141C),
                    ],
                  ),
                ),
              )
            else if (image != null &&
                image.isNotEmpty)
              Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _storyFallbackBackground();
                },
              )
            else
              _storyFallbackBackground(),

            // ========================================================
            // DARK GRADIENT
            // ========================================================

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [
                      0.0,
                      0.35,
                      0.72,
                      1.0,
                    ],
                    colors: [
                      Colors.black.withValues(
                        alpha: 0.10,
                      ),
                      Colors.transparent,
                      const Color(0x55000000),
                      const Color(0xEE03050A),
                    ],
                  ),
                ),
              ),
            ),

            // ========================================================
            // TOP NEON LINE
            // ========================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _purple,
                      _cyan,
                    ],
                  ),
                ),
              ),
            ),

            // ========================================================
            // AVATAR
            // ========================================================

            Positioned(
              top: 9,
              left: 9,
              child: isCreate
                  ? Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _purple,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x667B2FF7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    )
                  : Container(
                      width: 35,
                      height: 35,
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _brightPurple,
                            _cyan,
                          ],
                        ),
                      ),
                      child: ClipOval(
                        child: image != null &&
                                image.isNotEmpty
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return _storyAvatarFallback();
                                },
                              )
                            : _storyAvatarFallback(),
                      ),
                    ),
            ),

            // ========================================================
            // ACTIVE STORY INDICATOR
            // ========================================================

            if (!isCreate)
              Positioned(
                top: 10,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _brightCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xAA00E5FF),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

            // ========================================================
            // STORY COUNT
            // ========================================================

            if (!isCreate &&
                storyData != null &&
                storyData.length > 1)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC03050A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _borderSoft,
                    ),
                  ),
                  child: Text(
                    '${storyData.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // ========================================================
            // NAME
            // ========================================================

            Positioned(
              left: 10,
              right: 7,
              bottom: 10,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // ========================================================
            // CREATE SUBTITLE
            // ========================================================

            if (isCreate)
              const Positioned(
                left: 10,
                right: 10,
                bottom: 30,
                child: Text(
                  'Share your moment',
                  maxLines: 2,
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _storyFallbackBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF17102D),
          Color(0xFF06141C),
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.person_rounded,
        color: _brightPurple,
        size: 40,
      ),
    ),
  );
}

Widget _storyAvatarFallback() {
  return Container(
    color: _surface,
    child: const Icon(
      Icons.person_rounded,
      color: _brightPurple,
      size: 19,
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
          if (label == 'Photo') {
            _showMessage('Photo posting is ready to connect to storage.');
          } else if (label == 'Video') {
            _showMessage('Video posting is ready to connect to storage.');
          } else if (label == 'Live') {
            _showMessage('Live is ready to connect to your live system.');
          } else {
            _showCreatePoll();
          }
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

  // ==========================================================================
  // DEMO FALLBACK POSTS
  // ==========================================================================

  Widget _buildDemoSunsetPost() {
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
              if (!mounted) return;

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
              if (!mounted) return;

              setState(() {
                _savedSunset = !_savedSunset;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemoMusicPost() {
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

  Widget _buildDemoTextPost() {
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
              if (!mounted) return;

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
              if (!mounted) return;

              setState(() {
                _savedText = !_savedText;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MUSIC CARD
  // ==========================================================================

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
                    if (!mounted) return;

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
            final active = _playingMusic && index < 22;

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
              if (!mounted) return;

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

  // ==========================================================================
  // POST HELPERS
  // ==========================================================================

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
            fontWeight:
                large ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

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
      ),
      child: child,
    );
  }

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
                VerifiedName(
                  name: name,
                  verified: verified,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  textColor: _primaryText,
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
  onTap: () {
    _showPostMenu(
      postId: '',
      postData: const {},
    );
  },
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
        ),
        child: Icon(
          icon,
          color: color,
          size: 15,
        ),
      ),
    );
  }

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

  Widget _assetImage(
    String path, {
    required IconData icon,
  }) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
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

  // ==========================================================================
  // CREATE MENU
  // ==========================================================================

  void _showCreateMenu() {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
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
                _sheetHandle(),
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
                  sheetContext,
                  Icons.edit_rounded,
                  'Create Post',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Future<void>.delayed(
                      const Duration(milliseconds: 120),
                      () {
                        if (mounted) {
                          _showCreatePost();
                        }
                      },
                    );
                  },
                ),
                _bottomAction(
                  sheetContext,
                  Icons.radio_rounded,
                  'Go Live',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showMessage('Go Live');
                  },
                ),
                _bottomAction(
                  sheetContext,
                  Icons.poll_rounded,
                  'Create Poll',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Future<void>.delayed(
                      const Duration(milliseconds: 120),
                      () {
                        if (mounted) {
                          _showCreatePoll();
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: _borderSoft,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _bottomAction(
    BuildContext sheetContext,
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4),
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
      onTap: onTap,
    );
  }

  // ==========================================================================
  // CREATE POST - FIRESTORE
  // ==========================================================================

  Future<void> _showCreatePost() async {
  if (!mounted) return;

  final controller = TextEditingController();

  try {
    final result =
        await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceDark,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return _CreatePostSheet(
          controller: controller,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final text =
        (result['text'] as String? ?? '').trim();

    final imageUrls =
        List<String>.from(
      result['imageUrls'] ??
          const <String>[],
    );

    final videoUrls =
        List<String>.from(
      result['videoUrls'] ??
          const <String>[],
    );

    // ===============================================================
    // YOUTUBE REEL
    // ===============================================================

    final voiceUrl =
        result['voiceUrl'] as String?;

    final pollQuestion =
        result['pollQuestion'] as String?;

    final pollOptions =
        List<Map<String, dynamic>>.from(
      result['pollOptions'] ??
          const <Map<String, dynamic>>[],
    );

    final eventTitle =
        result['eventTitle'] as String?;

    final gifUrl =
        result['gifUrl'] as String?;

    // ===============================================================
    // CHECK IF THERE IS ANYTHING TO POST
    // ===============================================================

    // ===============================================================
    // CREATE FIRESTORE POST
    // ===============================================================

    await _createPost(
      text: text,
      imageUrls: imageUrls,
      videoUrls: videoUrls,

      voiceUrl: voiceUrl,
      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      eventTitle: eventTitle,
      gifUrl: gifUrl,
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _createPost({
  required String text,
  required List<String> imageUrls,
  required List<String> videoUrls,
  String? voiceUrl,
  String? pollQuestion,
  required List<Map<String, dynamic>> pollOptions,
  String? eventTitle,
  String? gifUrl,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    _showMessage('Please sign in first.');
    return;
  }

  try {
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userSnapshot.data() ?? {};

    final displayName =
        _readString(userData['displayName']) ??
        _readString(userData['name']) ??
        user.displayName ??
        'User';

    final photoUrl =
        _readString(userData['photoUrl']) ??
        _readString(userData['photoURL']) ??
        user.photoURL;

    final verified = userData['verified'] == true;

    // ---------------------------------------------------------------
    // DETERMINE POST TYPE
    // ---------------------------------------------------------------

    String postType = 'text';

    // ---------------------------------------------------------------
    // CREATE FIRESTORE POST
    // ---------------------------------------------------------------

    await FirebaseFirestore.instance
        .collection('posts')
        .add({
      'authorId': user.uid,
      'userId': user.uid,

      'displayName': displayName,
      'name': displayName,

      'photoUrl': photoUrl,
      'photoURL': photoUrl,

      'verified': verified,

      // Caption
      'text': text,

      // Normal media
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,

      // Backward-compatible singular fields
      'imageUrl':
          imageUrls.isNotEmpty
              ? imageUrls.first
              : null,

      'videoUrl':
          videoUrls.isNotEmpty
              ? videoUrls.first
              : null,

      // Other post types
      'voiceUrl': voiceUrl,
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'eventTitle': eventTitle,
      'gifUrl': gifUrl,

      'type': postType,
      'visibility': 'public',

      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,

      'createdAt':
          FieldValue.serverTimestamp(),

      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    _showMessage('Post published');
  } catch (e) {
    debugPrint(
      'ChattªX create post error: $e',
    );

    if (!mounted) return;

    _showMessage(
      'Could not publish post.',
    );
  }
}

  Future<void> _showCreatePoll() async {
    if (!mounted) return;

    _showMessage('Poll creation can be connected next.');
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _showSearch() {
    if (!mounted) return;

    showSearch<void>(
      context: context,
      delegate: _FeedSearchDelegate(),
    );
  }

  // ==========================================================================
// POST MENU
// ==========================================================================

void _showPostMenu({
  required String postId,
  required Map<String, dynamic> postData,
}) {
  if (!mounted) return;

  final User? currentUser =
      FirebaseAuth.instance.currentUser;

  final String? currentUid =
      currentUser?.uid;

  final String authorId =
      (postData['authorId'] ??
              postData['userId'] ??
              '')
          .toString();

  final bool isOwner =
      currentUid != null &&
      currentUid.isNotEmpty &&
      authorId == currentUid;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _surfaceDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(25),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ============================================================
              // SAVE POST
              // ============================================================

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
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  await _savePostFromMenu(
                    postId,
                  );
                },
              ),

              // ============================================================
              // TURN ON NOTIFICATIONS
              // ============================================================

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
                  Navigator.of(sheetContext).pop();

                  _showMessage(
                    'Post notifications turned on.',
                  );
                },
              ),

              // ============================================================
              // EDIT POST
              //
              // Only the owner sees this.
              // ============================================================

              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: _cyan,
                  ),
                  title: const Text(
                    'Edit post',
                    style: TextStyle(
                      color: _primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _showEditPostDialog(
                      postId: postId,
                      postData: postData,
                    );
                  },
                ),

              // ============================================================
              // CREATE AD
              // ============================================================

              ListTile(
                leading: const Icon(
                  Icons.campaign_outlined,
                  color: _brightPurple,
                ),
                title: const Text(
                  'Create ad',
                  style: TextStyle(
                    color: _primaryText,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();

                  _showCreateAd(
                    postId: postId,
                  );
                },
              ),

              // ============================================================
              // COPY LINK
              // ============================================================

              ListTile(
                leading: const Icon(
                  Icons.link_rounded,
                  color: _cyan,
                ),
                title: const Text(
                  'Copy link',
                  style: TextStyle(
                    color: _primaryText,
                  ),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  final String link =
                      'https://chattax.app/post/$postId';

                  await Clipboard.setData(
                    ClipboardData(
                      text: link,
                    ),
                  );

                  _showMessage(
                    'Post link copied.',
                  );
                },
              ),

              // ============================================================
              // REPORT POST
              // ============================================================

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
                  Navigator.of(sheetContext).pop();

                  _showMessage(
                    'Post reported.',
                  );
                },
              ),

              // ============================================================
              // DELETE POST
              //
              // Only the owner sees this.
              // ============================================================

              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete post',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    _confirmDeletePost(
                      postId,
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

// ==========================================================================
// SAVE POST FROM MENU
// ==========================================================================

Future<void> _savePostFromMenu(
  String postId,
) async {
  final User? user =
      FirebaseAuth.instance.currentUser;

  if (user == null) {
    _showMessage(
      'Please sign in to save posts.',
    );
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedPosts')
        .doc(postId)
        .set({
      'postId': postId,
      'savedAt':
          FieldValue.serverTimestamp(),
    });

    _showMessage(
      'Post saved.',
    );
  } catch (e) {
    debugPrint(
      'ChattªX save post error: $e',
    );

    _showMessage(
      'Could not save post.',
    );
  }
}

// ==========================================================================
// EDIT POST
// ==========================================================================

Future<void> _showEditPostDialog({
  required String postId,
  required Map<String, dynamic> postData,
}) async {
  final TextEditingController controller =
      TextEditingController(
    text:
        (postData['text'] ??
                postData['caption'] ??
                '')
            .toString(),
  );

  final String? result =
      await showDialog<String>(
    context: context,
    builder: (
      BuildContext dialogContext,
    ) {
      return AlertDialog(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          'Edit post',
          style: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          style: const TextStyle(
            color: _primaryText,
          ),
          decoration: InputDecoration(
            hintText: 'Write your caption...',
            hintStyle: const TextStyle(
              color: _secondaryText,
            ),
            filled: true,
            fillColor:
                Color(0xFF080D1A),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF18243A),
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF18243A),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: _brightPurple,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(
                controller.text.trim(),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: _brightPurple,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

  controller.dispose();

  if (result == null) {
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .update({
      'text': result,
      'caption': result,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    _showMessage(
      'Post updated.',
    );
  } catch (e) {
    debugPrint(
      'ChattªX edit post error: $e',
    );

    _showMessage(
      'Could not edit post.',
    );
  }
}

// ==========================================================================
// CONFIRM DELETE POST
// ==========================================================================

Future<void> _confirmDeletePost(
  String postId,
) async {
  final bool? confirmed =
      await showDialog<bool>(
    context: context,
    builder: (
      BuildContext dialogContext,
    ) {
      return AlertDialog(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete post?',
          style: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This post will be permanently deleted.',
          style: TextStyle(
            color: _secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(false);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .delete();

    _showMessage(
      'Post deleted.',
    );
  } catch (e) {
    debugPrint(
      'ChattªX delete post error: $e',
    );

    _showMessage(
      'Could not delete post.',
    );
  }
}

// ==========================================================================
// CREATE AD
// ==========================================================================

void _showCreateAd({
  required String postId,
}) {
  if (!mounted) {
    return;
  }

  showDialog<void>(
    context: context,
    builder: (
      BuildContext dialogContext,
    ) {
      return AlertDialog(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          'Create ad',
          style: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Turn this post into a ChattªX advertisement.',
          style: TextStyle(
            color: _secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _secondaryText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop();

              _showMessage(
                'ChattªX Ads setup will open here.',
              );
            },
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  _brightPurple,
              foregroundColor:
                  Colors.white,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),
            child: const Text(
              'Continue',
            ),
          ),
        ],
      );
    },
  );
}


  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _surfaceRaised,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(
            milliseconds: 1200,
          ),
        ),
      );
  }

  // ==========================================================================
  // SAFE STRING
  // ==========================================================================

  String? _readString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }
}

// =============================================================================
// FIRESTORE POST CARD
// =============================================================================

class _FirestorePostCard extends StatefulWidget {
  const _FirestorePostCard({
    super.key,
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.onShowMessage,
    required this.onOpenPostMenu,
  });

  final String postId;
  final Map<String, dynamic> data;
  final String? currentUid;
  final void Function(String message) onShowMessage;

  final VoidCallback onOpenPostMenu;

  @override
  State<_FirestorePostCard> createState() =>
      _FirestorePostCardState();
}

class _FirestorePostCardState extends State<_FirestorePostCard> {
  bool _busyReaction = false;
  bool _busySave = false;

  bool _liked = false;
  bool _saved = false;


  @override
  void initState() {
    super.initState();
    _loadUserPostState();
  }

  Future<void> _loadUserPostState() async {
    final uid = widget.currentUid;

    if (uid == null) {
      return;
    }

    try {
      final reaction = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('reactions')
          .doc(uid)
          .get();

      final saved = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedPosts')
          .doc(widget.postId)
          .get();

      if (!mounted) return;

      setState(() {
        _liked = reaction.exists;
        _saved = saved.exists;
      });
    } catch (_) {
      // The post can still be displayed even if state loading fails.
    }
  }

  String _string(String key, String fallback) {
    final value = widget.data[key];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  bool _bool(String key) {
    return widget.data[key] == true;
  }

  int _int(String key) {
    final value = widget.data[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  String? _readString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}

  String _timeText() {
    final value = widget.data['createdAt'];

    if (value is Timestamp) {
      final difference = DateTime.now().difference(value.toDate());

      if (difference.inMinutes < 1) {
        return 'now';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      }

      return '${value.toDate().day}/${value.toDate().month}/${value.toDate().year}';
    }

    return 'Just now';
  }

  @override
Widget build(BuildContext context) {
  final text = _string('text', '');

  // ---------------------------------------------------------------
  // MEDIA DATA
  // ---------------------------------------------------------------

  final rawImages = widget.data['imageUrls'];

  final List<String> imageUrls = rawImages is List
      ? rawImages
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList()
      : <String>[];

  final rawVideos = widget.data['videoUrls'];

  final List<String> videoUrls = rawVideos is List
      ? rawVideos
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList()
      : <String>[];

  // ---------------------------------------------------------------
  // BACKWARD COMPATIBILITY
  // ---------------------------------------------------------------

  if (imageUrls.isEmpty) {
    final imageUrl = widget.data['imageUrl'];

    if (imageUrl is String &&
        imageUrl.trim().isNotEmpty) {
      imageUrls.add(imageUrl.trim());
    }
  }

  if (videoUrls.isEmpty) {
    final videoUrl = widget.data['videoUrl'];

    if (videoUrl is String &&
        videoUrl.trim().isNotEmpty) {
      videoUrls.add(videoUrl.trim());
    }
  }
  // ---------------------------------------------------------------
  // AUTHOR
  // ---------------------------------------------------------------

  final name =
      _string(
        'displayName',
        '',
      ).isNotEmpty
          ? _string('displayName', 'User')
          : _string('name', 'User');

  final photoUrl =
      _string('photoUrl', '').isNotEmpty
          ? _string('photoUrl', '')
          : _string('photoURL', '');

  final verified = _bool('verified');

  // ---------------------------------------------------------------
  // RESHARE
  // ---------------------------------------------------------------

  final isReshare = _bool('isReshare');

  final originalAuthorName =
      _string(
        'originalAuthorName',
        'User',
      );

  final originalAuthorPhoto =
      _string(
        'originalAuthorPhoto',
        '',
      );

  final originalAuthorVerified =
      _bool('originalAuthorVerified');

  // ---------------------------------------------------------------
  // ORIGINAL TEXT
  // ---------------------------------------------------------------

  final originalText =
      _string(
        'originalText',
        '',
      );

  // Keep this read so existing reshare data remains supported.
  // ignore: unused_local_variable
  final _ = originalText;

  // ---------------------------------------------------------------
  // COUNTS
  // ---------------------------------------------------------------

  final reactions = _int('likeCount');
  final comments = _int('commentCount');
  final shares = _int('shareCount');

  // ---------------------------------------------------------------
  // POST CARD
  // ---------------------------------------------------------------

  return Container(
    margin: const EdgeInsets.fromLTRB(
      7,
      0,
      7,
      12,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFF080D1A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFF18243A),
      ),
    ),
    child: Column(
      children: [
        _buildHeader(
          name: name,
          photoUrl: photoUrl.isEmpty
              ? null
              : photoUrl,
          verified: verified,
        ),

        if (isReshare)
          _buildReshareLabel(
            originalAuthorName:
                originalAuthorName,
            originalAuthorPhoto:
                originalAuthorPhoto,
            originalAuthorVerified:
                originalAuthorVerified,
          ),

        // -----------------------------------------------------------
        // CAPTION
        // -----------------------------------------------------------

        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              4,
              12,
              12,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFD4D9E5),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ),

        // -----------------------------------------------------------
        // MEDIA
        // -----------------------------------------------------------

        _buildPostMedia(),

        // -----------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------

        _buildSummary(
          reactions: reactions,
          comments: comments,
          shares: shares,
        ),

        // -----------------------------------------------------------
        // BUTTONS
        // -----------------------------------------------------------

        _buildButtons(
          comments: comments,
        ),
      ],
    ),
  );
}

 Widget _buildPostMedia() {
  final type = _string('type', '');

  // ---------------------------------------------------------------
  // IMAGES
  // ---------------------------------------------------------------

  final rawImages = widget.data['imageUrls'];

  final List<String> imageUrls = rawImages is List
      ? rawImages
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList()
      : <String>[];

  // ---------------------------------------------------------------
  // VIDEOS
  // ---------------------------------------------------------------

  final rawVideos = widget.data['videoUrls'];

  final List<String> videoUrls = rawVideos is List
      ? rawVideos
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList()
      : <String>[];

  // ---------------------------------------------------------------
  // BACKWARD COMPATIBILITY
  // ---------------------------------------------------------------

  if (imageUrls.isEmpty) {
    final imageUrl = widget.data['imageUrl'];

    if (imageUrl is String &&
        imageUrl.trim().isNotEmpty) {
      imageUrls.add(imageUrl.trim());
    }
  }

  if (videoUrls.isEmpty) {
    final videoUrl = widget.data['videoUrl'];

    if (videoUrl is String &&
        videoUrl.trim().isNotEmpty) {
      videoUrls.add(videoUrl.trim());
    }
  }

  // ---------------------------------------------------------------
  // NO MEDIA
  // ---------------------------------------------------------------

  if (imageUrls.isEmpty &&
      videoUrls.isEmpty) {
    return const SizedBox.shrink();
  }

  final List<Widget> mediaItems = <Widget>[];

  // ---------------------------------------------------------------
  // IMAGES
  // ---------------------------------------------------------------

  for (final url in imageUrls) {
    mediaItems.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(
          8,
          0,
          8,
          8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            url,
            width: double.infinity,

            // -------------------------------------------------------------
            // IMPORTANT:
            // No fixed height.
            // Flutter uses the original image dimensions/aspect ratio.
            // -------------------------------------------------------------

            fit: BoxFit.contain,

            loadingBuilder: (
              context,
              child,
              loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                ),
                color: const Color(0xFF0D1324),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFB026FF),
                  ),
                ),
              );
            },

            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                ),
                color: const Color(0xFF0D1324),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFFB026FF),
                    size: 35,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

    // ---------------------------------------------------------------
  // VIDEOS
  // ---------------------------------------------------------------

  for (int index = 0; index < videoUrls.length; index++) {
    final url = videoUrls[index];

    mediaItems.add(
  Padding(
    padding: const EdgeInsets.fromLTRB(
      8,
      0,
      8,
      8,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: double.infinity,
        height: 260,
        child: _FeedVideoPlayer(
          key: ValueKey(
            'feed_video_${widget.postId}_$index',
          ),
          url: url,
          onOpenViewer: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReelsScreen(
                  initialVideoUrl: url,
                  initialPostData: {
                    ...widget.data,
                    'postId': widget.postId,
                  },
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
);
  }

  // ---------------------------------------------------------------
  // RETURN MEDIA
  // ---------------------------------------------------------------

  return Column(
    children: mediaItems,
  );
}

Widget _buildReshareLabel({
  required String originalAuthorName,
  required String originalAuthorPhoto,
  required bool originalAuthorVerified,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      12,
      0,
      12,
      8,
    ),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1324),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF18243A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(1.3),
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7B2FF7),
                  Color(0xFF00D9FF),
                ],
              ),
            ),
            child: ClipOval(
              child: originalAuthorPhoto
                      .trim()
                      .isEmpty
                  ? Container(
                      color:
                          const Color(0xFF080D1A),
                      child: const Icon(
                        Icons.person_rounded,
                        color:
                            Color(0xFFB026FF),
                        size: 21,
                      ),
                    )
                  : Image.network(
                      originalAuthorPhoto,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          color:
                              const Color(0xFF080D1A),
                          child:
                              const Icon(
                            Icons.person_rounded,
                            color:
                                Color(0xFFB026FF),
                            size: 21,
                          ),
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      color:
                          Color(0xFFB026FF),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Original post',
                      style: TextStyle(
                        color:
                            Color(0xFF68738A),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                VerifiedName(
                  name: originalAuthorName,
                  verified:
                      originalAuthorVerified,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                  textColor:
                      const Color(0xFFF5F7FF),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildHeader({
    required String name,
    required String? photoUrl,
    required bool verified,
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
                colors: [
                  Color(0xFF7B2FF7),
                  Color(0xFF00D9FF),
                ],
              ),
            ),
            child: ClipOval(
              child: photoUrl == null
                  ? Container(
                      color: const Color(0xFF0D1324),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFFB026FF),
                      ),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF0D1324),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFFB026FF),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                VerifiedName(
                  name: name,
                  verified: verified,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  textColor: const Color(0xFFF5F7FF),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _timeText(),
                      style: const TextStyle(
                        color: Color(0xFF68738A),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.public_rounded,
                      color: Color(0xFF68738A),
                      size: 11,
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onOpenPostMenu,
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

  Widget _buildSummary({
  required int reactions,
  required int comments,
  required int shares,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
    child: Row(
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFF315C),
          size: 17,
        ),

        const SizedBox(width: 6),

        Text(
          '$reactions',
          style: const TextStyle(
            color: Color(0xFFB8C1D1),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),

        const Spacer(),

        Text(
          '$comments Comments',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFB8C1D1),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(width: 12),

        Text(
          '$shares Shares',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFB8C1D1),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildButtons({
  required int comments,
}) {
  return SizedBox(
    height: 46,
    child: Row(
      children: [
        _button(
          icon: _liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: 'Like',
          color: _liked
              ? const Color(0xFFFF315C)
              : const Color(0xFFB8C1D1),
          loading: _busyReaction,
          onTap: _toggleReaction,
        ),

        _button(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Comment',
          color: const Color(0xFFB8C1D1),
          onTap: _showComments,
        ),

        _button(
          icon: Icons.send_rounded,
          label: 'Share',
          color: const Color(0xFFB8C1D1),
          onTap: _sharePost,
        ),

        _button(
          icon: _saved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: 'Save',
          color: const Color(0xFFB8C1D1),
          loading: _busySave,
          onTap: _toggleSave,
        ),
      ],
    ),
  );
}

  Widget _button({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
  bool loading = false,
}) {
  return Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          loading
              ? SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(
                  icon,
                  color: color,
                  size: 17,
                ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFB8C1D1),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ==========================================================================
  // REACTION
  // ==========================================================================

  Future<void> _toggleReaction() async {
  final uid = widget.currentUid;

  if (uid == null) {
    widget.onShowMessage('Please sign in first.');
    return;
  }

  if (_busyReaction) {
    return;
  }

  setState(() {
    _busyReaction = true;
  });

  try {
    final firestore = FirebaseFirestore.instance;

    final postRef = firestore
        .collection('posts')
        .doc(widget.postId);

    final reactionRef = postRef
        .collection('reactions')
        .doc(uid);

    // Get the post.
    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) {
      widget.onShowMessage('Post no longer exists.');
      return;
    }

    final postData = postSnapshot.data() ?? {};

    // Find the owner of the post.
    final ownerId = (
      postData['userId'] ??
      postData['authorId'] ??
      postData['ownerId'] ??
      ''
    ).toString();

    // Get the current like count.
    final currentCount =
        _readNumber(postData['likeCount']);

    // Check whether THIS user already liked it.
    final reactionSnapshot =
        await reactionRef.get();

    final batch = firestore.batch();

    // ================================================================
    // UNLIKE
    // ================================================================

    if (reactionSnapshot.exists) {
      batch.delete(reactionRef);

      batch.update(postRef, {
        'likeCount': currentCount > 0
            ? currentCount - 1
            : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove the notification created by this like.
      if (ownerId.isNotEmpty && ownerId != uid) {
        final notificationId =
            '${widget.postId}_${uid}_like';

        final notificationRef = firestore
            .collection('feed_notifications')
            .doc(notificationId);

        batch.delete(notificationRef);
      }
    }

    // ================================================================
    // LIKE
    // ================================================================

    else {
      batch.set(
        reactionRef,
        {
          'userId': uid,
          'type': 'like',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(postRef, {
        'likeCount': currentCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ==============================================================
      // CREATE NOTIFICATION
      // ==============================================================

      if (ownerId.isNotEmpty && ownerId != uid) {
        final currentUser =
            FirebaseAuth.instance.currentUser;

        final actorName =
            currentUser?.displayName?.trim().isNotEmpty == true
                ? currentUser!.displayName!.trim()
                : 'Someone';

        final actorPhoto =
            currentUser?.photoURL ?? '';

        final notificationId =
            '${widget.postId}_${uid}_like';

        final notificationRef = firestore
            .collection('feed_notifications')
            .doc(notificationId);

        batch.set(
          notificationRef,
          {
            'recipientId': ownerId,
            'actorId': uid,
            'actorName': actorName,
            'actorPhoto': actorPhoto,
            'type': 'postLike',
            'targetType': 'post',
            'targetId': widget.postId,
            'postId': widget.postId,
            'reaction': '',
            'commentText': '',
            'message': 'liked your post',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'readAt': null,
          },
          SetOptions(merge: true),
        );
      }
    }

    // Perform all Firestore changes together.
    await batch.commit();

    if (!mounted) {
      return;
    }

    // Update the button immediately.
    setState(() {
      _liked = !_liked;
    });
  } catch (e) {
    if (mounted) {
      widget.onShowMessage(
        'Could not update reaction.',
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _busyReaction = false;
      });
    }
  }
}

  int _readNumber(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  Future<void> _toggleSave() async {
    final uid = widget.currentUid;

    if (uid == null) {
      widget.onShowMessage('Please sign in first.');
      return;
    }

    if (_busySave) {
      return;
    }

    if (mounted) {
      setState(() {
        _busySave = true;
      });
    }

    try {
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedPosts')
          .doc(widget.postId);

      if (_saved) {
        await reference.delete();
      } else {
        await reference.set({
          'postId': widget.postId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _saved = !_saved;
      });
    } catch (_) {
      if (mounted) {
        widget.onShowMessage('Could not update saved post.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busySave = false;
        });
      }
    }
  }

  // ==========================================================================
  // COMMENTS
  // ==========================================================================

  Future<void> _showComments() async {
    if (!mounted) return;

    final controller = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF070B17),
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        builder: (sheetContext) {
          return _CommentsSheet(
            postId: widget.postId,
            controller: controller,
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  // ==========================================================================
  // SHARE
  // ==========================================================================

  Future<void> _sharePost() async {
  final uid = widget.currentUid;

  if (uid == null) {
    widget.onShowMessage('Please sign in first.');
    return;
  }

  if (!mounted) return;

  final firestore = FirebaseFirestore.instance;

  try {
    // ========================================================================
    // GET ORIGINAL POST
    // ========================================================================

    final postRef = firestore
        .collection('posts')
        .doc(widget.postId);

    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) {
      widget.onShowMessage('Post no longer exists.');
      return;
    }

    final postData = postSnapshot.data() ?? {};

    // ========================================================================
    // ORIGINAL POST OWNER
    // ========================================================================

    final ownerId = (
      postData['userId'] ??
      postData['authorId'] ??
      postData['ownerId'] ??
      ''
    ).toString();

    if (ownerId.isEmpty) {
      widget.onShowMessage(
        'This post cannot be shared because the original author is missing.',
      );
      return;
    }

    // ========================================================================
    // GET ORIGINAL AUTHOR PROFILE
    // ========================================================================

    final ownerSnapshot = await firestore
        .collection('users')
        .doc(ownerId)
        .get();

    final ownerData = ownerSnapshot.data() ?? {};

    final originalAuthorName =
        _readString(ownerData['displayName']) ??
        _readString(ownerData['name']) ??
        _readString(postData['displayName']) ??
        _readString(postData['name']) ??
        'User';

    final originalAuthorPhoto =
        _readString(ownerData['photoUrl']) ??
        _readString(ownerData['photoURL']) ??
        _readString(postData['photoUrl']) ??
        _readString(postData['photoURL']) ??
        '';

    final originalVerified =
        ownerData['verified'] == true ||
        postData['verified'] == true;

    // ========================================================================
    // CURRENT USER
    // ========================================================================

    final currentUser =
        FirebaseAuth.instance.currentUser;

    final currentUserSnapshot = await firestore
        .collection('users')
        .doc(uid)
        .get();

    final currentUserData =
        currentUserSnapshot.data() ?? {};

    final sharerName =
        _readString(currentUserData['displayName']) ??
        _readString(currentUserData['name']) ??
        currentUser?.displayName?.trim() ??
        'User';

    final sharerPhoto =
        _readString(currentUserData['photoUrl']) ??
        _readString(currentUserData['photoURL']) ??
        currentUser?.photoURL ??
        '';

    final sharerVerified =
        currentUserData['verified'] == true;

    // ========================================================================
    // ASK FOR SHARE CAPTION
    // ========================================================================

    final captionController =
        TextEditingController();

    Map<String, dynamic>? shareResult;

    try {
      shareResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: const Color(0xFF070B17),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        builder: (sheetContext) {
          return _SharePostSheet(
            originalAuthorName: originalAuthorName,
            originalAuthorPhoto: originalAuthorPhoto,
            originalVerified: originalVerified,
            sharerName: sharerName,
            sharerPhoto: sharerPhoto,
            sharerVerified: sharerVerified,
            controller: captionController,
          );
        },
      );
    } finally {
      captionController.dispose();
    }

    // User cancelled.
    if (!mounted || shareResult == null) {
      return;
    }

    final shareCaption =
        (shareResult['caption'] ?? '').toString().trim();

    // ========================================================================
    // COPY ORIGINAL MEDIA
    // ========================================================================

    final rawImages = postData['imageUrls'];

    final List<String> imageUrls = rawImages is List
        ? rawImages
            .whereType<String>()
            .where(
              (url) => url.trim().isNotEmpty,
            )
            .map((url) => url.trim())
            .toList()
        : <String>[];

    final rawVideos = postData['videoUrls'];

    final List<String> videoUrls = rawVideos is List
        ? rawVideos
            .whereType<String>()
            .where(
              (url) => url.trim().isNotEmpty,
            )
            .map((url) => url.trim())
            .toList()
        : <String>[];

    // Backward compatibility.
    if (imageUrls.isEmpty) {
      final imageUrl = postData['imageUrl'];

      if (imageUrl is String &&
          imageUrl.trim().isNotEmpty) {
        imageUrls.add(imageUrl.trim());
      }
    }

    if (videoUrls.isEmpty) {
      final videoUrl = postData['videoUrl'];

      if (videoUrl is String &&
          videoUrl.trim().isNotEmpty) {
        videoUrls.add(videoUrl.trim());
      }
    }

    // ========================================================================
    // CREATE NEW POST
    // ========================================================================

    final newPostRef = firestore
        .collection('posts')
        .doc();

    final originalText =
        _readString(postData['text']) ?? '';

    final originalCreatedAt =
        postData['createdAt'];

    final batch = firestore.batch();

    batch.set(
      newPostRef,
      {
        // ====================================================================
        // NEW POST OWNER
        // ====================================================================

        'userId': uid,
        'authorId': uid,
        'ownerId': uid,

        'displayName': sharerName,
        'name': sharerName,

        'photoUrl': sharerPhoto,
        'photoURL': sharerPhoto,

        'verified': sharerVerified,

        // ====================================================================
        // USER'S OWN SHARE CAPTION
        // ====================================================================

        'text': shareCaption,

        // ====================================================================
        // ORIGINAL POST
        // ====================================================================

        'isReshare': true,

        'originalPostId': widget.postId,
        'originalAuthorId': ownerId,

        'originalAuthorName': originalAuthorName,
        'originalAuthorPhoto': originalAuthorPhoto,
        'originalAuthorVerified': originalVerified,

        'originalText': originalText,

        'originalCreatedAt': originalCreatedAt,

        // ========================================================================
// ORIGINAL MEDIA
// ========================================================================

'imageUrls': imageUrls,
'videoUrls': videoUrls,

'imageUrl':
    imageUrls.isNotEmpty
        ? imageUrls.first
        : '',

'videoUrl':
    videoUrls.isNotEmpty
        ? videoUrls.first
        : '',

        // ====================================================================
        // COUNTERS
        // ====================================================================

        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,

        // ====================================================================
        // TIMESTAMPS
        // ====================================================================

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),

        // ====================================================================
        // SHARE INFORMATION
        // ====================================================================

        'sharedById': uid,
        'sharedByName': sharerName,
        'sharedByPhoto': sharerPhoto,
        'sharedByVerified': sharerVerified,

        'sharedAt':
            FieldValue.serverTimestamp(),

        'sourcePostId': widget.postId,
      },
    );

    // ========================================================================
    // RECORD SHARE ON ORIGINAL POST
    // ========================================================================

    final shareRecordRef = postRef
        .collection('shares')
        .doc();

    batch.set(
      shareRecordRef,
      {
        'userId': uid,
        'sharedPostId': newPostRef.id,
        'caption': shareCaption,
        'createdAt':
            FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      postRef,
      {
        'shareCount':
            FieldValue.increment(1),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    // ========================================================================
    // NOTIFICATION TO ORIGINAL AUTHOR
    // ========================================================================

    if (ownerId != uid) {
      final notificationRef = firestore
          .collection('feed_notifications')
          .doc();

      batch.set(
        notificationRef,
        {
          'recipientId': ownerId,

          'actorId': uid,
          'actorName': sharerName,
          'actorPhoto': sharerPhoto,

          'type': 'postShare',
          'targetType': 'post',
          'targetId': widget.postId,

          'postId': widget.postId,
          'sharedPostId': newPostRef.id,

          'message':
              'shared your post',

          'shareCaption': shareCaption,

          'isRead': false,

          'createdAt':
              FieldValue.serverTimestamp(),

          'readAt': null,
        },
      );
    }

    // ========================================================================
    // WRITE EVERYTHING
    // ========================================================================

    await batch.commit();

    if (!mounted) return;

    widget.onShowMessage(
      'Post shared to your feed.',
    );
  } catch (e) {
    if (mounted) {
      widget.onShowMessage(
        'Could not share post.',
      );
    }
  }
}

  // ==========================================================================
  // MENU
  // ==========================================================================

  void _showMenu() {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070B17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.bookmark_border_rounded,
                  color: Color(0xFFB026FF),
                ),
                title: const Text(
                  'Save post',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSave();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFE53935),
                ),
                title: const Text(
                  'Report post',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onShowMessage('Post reported.');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// REACTION ICON
// =============================================================================

class _ReactionIcon extends StatelessWidget {
  const _ReactionIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: const Color(0xFF080D1A),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 1.3,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 15,
      ),
    );
  }
}

// =============================================================================
// SEARCH DELEGATE
// =============================================================================

class _FeedSearchDelegate extends SearchDelegate<void> {
  final CollectionReference<Map<String, dynamic>> _usersRef =
      FirebaseFirestore.instance.collection('users');

  static const Color _bg = Color(0xFF050816);
  static const Color _appBar = Color(0xFF080D1A);
  static const Color _surface = Color(0xFF0D1324);

  static const Color _brightPurple = Color(0xFFB026FF);
  static const Color _purple = Color(0xFF7B2FF7);
  static const Color _cyan = Color(0xFF00D9FF);

  static const Color _primaryText = Color(0xFFF5F7FF);
  static const Color _secondaryText = Color(0xFF9AA3B5);
  static const Color _mutedText = Color(0xFF68738A);
  static const Color _aboutText = Color(0xFFB39DDB);
  static const Color _pinRed = Color(0xFFE53935);

  final Map<String, Future<String>> _locationCache = {};

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _appBar,
        foregroundColor: _primaryText,
        elevation: 0,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: _mutedText,
        ),
        border: InputBorder.none,
      ),
      textSelectionTheme:
          const TextSelectionThemeData(
        cursorColor: _brightPurple,
      ),
    );
  }

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    if (query.isEmpty) {
      return null;
    }

    return [
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
    return _buildUserResults(context);
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _buildUserResults(context);
  }

  Widget _buildUserResults(
    BuildContext context,
  ) {
    final searchText = query.trim();

    final currentUid =
        FirebaseAuth.instance.currentUser?.uid;

    Query<Map<String, dynamic>> usersQuery;

    if (searchText.isEmpty) {
      usersQuery = _usersRef
          .orderBy('displayName')
          .limit(20);
    } else {
      final normalized = searchText;

      final rangeEnd = '$normalized\uf8ff';

      usersQuery = _usersRef
          .orderBy('displayName')
          .startAt([normalized])
          .endAt([rangeEnd])
          .limit(20);
    }

    return Container(
      color: _bg,
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: usersQuery.snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Couldn't load profiles",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _secondaryText,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 40,
                ),
                child: CircularProgressIndicator(
                  color: _brightPurple,
                ),
              ),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          final users = documents
              .where(
                (doc) => doc.id != currentUid,
              )
              .take(20)
              .toList();

          if (users.isEmpty) {
            return Center(
              child: Text(
                searchText.isEmpty
                    ? 'No profiles yet'
                    : 'No users found for "$searchText"',
                style: const TextStyle(
                  color: _secondaryText,
                ),
              ),
            );
          }

          return ListView.separated(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(
              vertical: 6,
            ),
            itemCount: users.length,
            separatorBuilder: (
              context,
              index,
            ) {
              return const SizedBox(height: 1);
            },
            itemBuilder: (
              context,
              index,
            ) {
              final userDoc = users[index];
              final data = userDoc.data();
              final uid = userDoc.id;

              final displayName =
                  _readString(data['displayName']) ??
                  _readString(data['name']) ??
                  'Unknown';

              final bio =
                  _readString(data['bio']) ??
                  '';

              final photoUrl =
                  _readString(data['photoUrl']) ??
                  _readString(data['photoURL']);

              final verified =
                  data['verified'] == true;

              final latitude =
                  _readDouble(data['latitude']);

              final longitude =
                  _readDouble(data['longitude']);

              return _UserResultTile(
                key: ValueKey(uid),
                uid: uid,
                name: displayName,
                bio: bio,
                photoUrl: photoUrl,
                latitude: latitude,
                longitude: longitude,
                verified: verified,
                locationLoader: () {
                  return _getCityName(
                    latitude,
                    longitude,
                  );
                },
                onTap: () {
  if (!context.mounted) return;

  Navigator.of(context).pop();

  Future<void>.delayed(
    const Duration(milliseconds: 100),
    () {
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            return PublicProfileScreen(
              userId: uid,
            );
          },
        ),
      );
    },
  );
},
              );
            },
          );
        },
      ),
    );
  }

  String? _readString(dynamic value) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  Future<String> _getCityName(
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null ||
        longitude == null) {
      return Future.value('');
    }

    final key =
        '${latitude.toStringAsFixed(5)},'
        '${longitude.toStringAsFixed(5)}';

    final cached = _locationCache[key];

    if (cached != null) {
      return cached;
    }

    final future = _reverseGeocode(
      latitude,
      longitude,
    );

    _locationCache[key] = future;

    return future;
  }

  Future<String> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return '';
      }

      final place = placemarks.first;

      final candidates = <String?>[
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ];

      for (final candidate in candidates) {
        final value = candidate?.trim();

        if (value != null &&
            value.isNotEmpty) {
          return value;
        }
      }

      return '';
    } catch (_) {
      return '';
    }
  }
}

// =============================================================================
// USER RESULT TILE
// =============================================================================

class _UserResultTile extends StatefulWidget {
  const _UserResultTile({
    super.key,
    required this.uid,
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.verified,
    required this.locationLoader,
    required this.onTap,
  });

  final String uid;
  final String name;
  final String bio;
  final String? photoUrl;

  final double? latitude;
  final double? longitude;

  final bool verified;

  final Future<String> Function() locationLoader;

  final VoidCallback onTap;

  @override
  State<_UserResultTile> createState() =>
      _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
  static const Color _surfaceDark =
      Color(0xFF0D1324);

  static const Color _purple =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  static const Color _primaryText =
      Color(0xFFF5F7FF);

  static const Color _secondaryText =
      Color(0xFF9AA3B5);

  static const Color _mutedText =
      Color(0xFF68738A);

  static const Color _aboutText =
      Color(0xFFB39DDB);

  static const Color _pinRed =
      Color(0xFFE53935);

  bool _loadingFollow = false;
  bool _loadingMessage = false;
  bool _messageSent = false;

  String? get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>
      get _followingReference {
    final uid = _currentUid;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid ?? '__no_user__')
        .collection('following')
        .doc(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid;

    if (currentUid == null) {
      return _buildTile(
        isFollowing: false,
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _followingReference.snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        final isFollowing =
            snapshot.data?.exists == true;

        return _buildTile(
          isFollowing: isFollowing,
        );
      },
    );
  }

  Widget _buildTile({
    required bool isFollowing,
  }) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              padding:
                  const EdgeInsets.all(2),
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    LinearGradient(
                  colors: [
                    _purple,
                    _brightPurple,
                  ],
                ),
              ),
              child: ClipOval(
                child: Container(
                  color: _surfaceDark,
                  child: widget.photoUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          color:
                              _brightPurple,
                          size: 26,
                        )
                      : Image.network(
                          widget.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return const Icon(
                              Icons.person_rounded,
                              color:
                                  _brightPurple,
                              size: 26,
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  VerifiedName(
                    name: widget.name,
                    verified: widget.verified,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                    textColor:
                        _primaryText,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.bio.isEmpty
                        ? 'No about added'
                        : widget.bio,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.bio.isEmpty
                          ? _secondaryText
                          : _aboutText,
                      fontSize: 13.5,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FutureBuilder<String>(
                    future: widget.locationLoader(),
                    builder: (
                      context,
                      snapshot,
                    ) {
                      final city =
                          snapshot.data
                                  ?.trim() ??
                              '';

                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          city.isEmpty) {
                        return const SizedBox(
                          height: 17,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 11,
                                height: 11,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: _pinRed,
                                ),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Finding location...',
                                style: TextStyle(
                                  color:
                                      _secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (city.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: _pinRed,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    _secondaryText,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_messageSent) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Message sent',
                      style: TextStyle(
                        color: Color(0xFF00D9FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            isFollowing
                ? _MessageButton(
                    loading: _loadingMessage,
                    onPressed:
                        _openMessageComposer,
                  )
                : _FollowButton(
                    loading: _loadingFollow,
                    onPressed: _followUser,
                  ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FOLLOW
  // ==========================================================================

  Future<void> _followUser() async {
    if (_loadingFollow) {
      return;
    }

    final currentUid = _currentUid;

    if (currentUid == null) {
      _showSafeDialog(
        'You must be signed in to follow someone.',
      );
      return;
    }

    if (currentUid == widget.uid) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingFollow = true;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      final followerReference = firestore
          .collection('users')
          .doc(widget.uid)
          .collection('followers')
          .doc(currentUid);

      final followingReference = firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(widget.uid);

      final batch = firestore.batch();

      batch.set(
        followerReference,
        {
          'userId': currentUid,
          'followerId': currentUid,
          'followingId': widget.uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        followingReference,
        {
          'userId': widget.uid,
          'followingId': widget.uid,
          'followerId': currentUid,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      _showSafeDialog(
        'Following ${widget.name}',
      );
    } catch (e) {
      if (!mounted) return;

      _showSafeDialog(
        'Could not follow ${widget.name}.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingFollow = false;
        });
      }
    }
  }

  // ==========================================================================
  // MESSAGE COMPOSER
  // ==========================================================================

  Future<void> _openMessageComposer() async {
    if (_loadingMessage) {
      return;
    }

    final currentUid = _currentUid;

    if (currentUid == null) {
      _showSafeDialog(
        'You must be signed in to send a message.',
      );
      return;
    }

    final controller =
        TextEditingController();

    String? message;

    try {
      message =
          await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF070B17),
        useSafeArea: true,
        shape:
            const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        builder: (sheetContext) {
          return _MessageComposerSheet(
            name: widget.name,
            verified: widget.verified,
            controller: controller,
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (!mounted || message == null) {
      return;
    }

    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      return;
    }

    await _sendMessage(cleanMessage);
  }

  // ==========================================================================
  // SEND MESSAGE
  // ==========================================================================

  Future<void> _sendMessage(
    String text,
  ) async {
    if (_loadingMessage) {
      return;
    }

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        _showSafeDialog(
          'You must be signed in to send a message.',
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingMessage = true;
      _messageSent = false;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      final currentUid =
          currentUser.uid;

      final otherUid =
          widget.uid;

      final ids = [
        currentUid,
        otherUid,
      ]..sort();

      final chatId =
          '${ids[0]}_${ids[1]}';

      final chatReference = firestore
          .collection('chat_rooms')
          .doc(chatId);

      final messageReference =
          chatReference
              .collection('messages')
              .doc();

      final currentUserSnapshot =
          await firestore
              .collection('users')
              .doc(currentUid)
              .get();

      final currentUserData =
          currentUserSnapshot.data() ?? {};

      final senderName =
          _readString(
                currentUserData[
                    'displayName'],
              ) ??
              _readString(
                currentUserData['name'],
              ) ??
              currentUser.displayName ??
              'User';

      final senderPhoto =
          _readString(
                currentUserData[
                    'photoUrl'],
              ) ??
              _readString(
                currentUserData[
                    'photoURL'],
              ) ??
              currentUser.photoURL;

      final recipientSnapshot =
          await firestore
              .collection('users')
              .doc(otherUid)
              .get();

      final recipientData =
          recipientSnapshot.data() ?? {};

      final recipientName =
          _readString(
                recipientData[
                    'displayName'],
              ) ??
              _readString(
                recipientData['name'],
              ) ??
              widget.name;

      final recipientPhoto =
          _readString(
            recipientData['photoUrl'],
          ) ??
          _readString(
            recipientData['photoURL'],
          );

      final batch =
          firestore.batch();

      batch.set(
        chatReference,
        {
          'participantIds': [
            currentUid,
            otherUid,
          ],
          'participants': [
            currentUid,
            otherUid,
          ],
          'lastMessage': text,
          'lastMessageTime':
              FieldValue.serverTimestamp(),
          'lastMessageSenderId':
              currentUid,
          'lastMessageType':
              'text',
          'updatedAt':
              FieldValue.serverTimestamp(),
          'lastSenderName':
              senderName,
          'lastSenderPhoto':
              senderPhoto,
          'recipientName':
              recipientName,
          'recipientPhoto':
              recipientPhoto,
        },
        SetOptions(merge: true),
      );

      batch.set(
        messageReference,
        {
          'senderId': currentUid,
          'receiverId': otherUid,
          'text': text,
          'message': text,
          'type': 'text',
          'timestamp':
              FieldValue.serverTimestamp(),
          'createdAt':
              FieldValue.serverTimestamp(),
          'senderName': senderName,
          'senderPhoto': senderPhoto,
          'receiverName':
              recipientName,
          'receiverPhoto':
              recipientPhoto,
          'seen': false,
        },
      );

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _loadingMessage = false;
        _messageSent = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingMessage = false;
      });

      _showSafeDialog(
        'Could not send message.',
      );
    }
  }

  String? _readString(dynamic value) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  void _showSafeDialog(String message) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF10182A),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: _brightPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// MESSAGE COMPOSER SHEET
// =============================================================================

class _MessageComposerSheet
    extends StatelessWidget {
  const _MessageComposerSheet({
    required this.name,
    required this.verified,
    required this.controller,
  });

  final String name;
  final bool verified;
  final TextEditingController controller;

  static const Color _surface =
      Color(0xFF0D1324);

  static const Color _primaryText =
      Color(0xFFF5F7FF);

  static const Color _mutedText =
      Color(0xFF68738A);

  static const Color _purple =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  static const Color _secondaryText =
      Color(0xFF9AA3B5);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context)
                .bottom +
            16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF202E48),
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Message ',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      Flexible(
                        child: VerifiedName(
                          name: name,
                          verified: verified,
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w700,
                          textColor:
                              _primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    FocusScope.of(context)
                        .unfocus();

                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context)
                          .pop();
                    }
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color:
                        _secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              minLines: 1,
              textCapitalization:
                  TextCapitalization.sentences,
              style: const TextStyle(
                color: _primaryText,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText:
                    'Write a message...',
                hintStyle:
                    const TextStyle(
                  color: _mutedText,
                ),
                filled: true,
                fillColor: _surface,
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(17),
                  borderSide:
                      BorderSide.none,
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(17),
                  borderSide:
                      const BorderSide(
                    color: _brightPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                    final text =
                        controller.text.trim();

                    if (text.isEmpty) {
                      return;
                    }

                    FocusScope.of(context)
                        .unfocus();

                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context)
                          .pop(text);
                    }
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
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARE POST SHEET
// =============================================================================

class _SharePostSheet extends StatefulWidget {
  const _SharePostSheet({
    required this.originalAuthorName,
    required this.originalAuthorPhoto,
    required this.originalVerified,
    required this.sharerName,
    required this.sharerPhoto,
    required this.sharerVerified,
    required this.controller,
  });

  final String originalAuthorName;
  final String originalAuthorPhoto;
  final bool originalVerified;

  final String sharerName;
  final String sharerPhoto;
  final bool sharerVerified;

  final TextEditingController controller;

  @override
  State<_SharePostSheet> createState() =>
      _SharePostSheetState();
}

class _SharePostSheetState
    extends State<_SharePostSheet> {
  static const Color _background =
      Color(0xFF070B17);

  static const Color _surface =
      Color(0xFF0D1324);

  static const Color _border =
      Color(0xFF202E48);

  static const Color _primaryText =
      Color(0xFFF5F7FF);

  static const Color _secondaryText =
      Color(0xFF9AA3B5);

  static const Color _mutedText =
      Color(0xFF68738A);

  static const Color _purple =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  final bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Share post',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: _sharing
                        ? null
                        : () {
                            Navigator.of(context)
                                .pop();
                          },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _secondaryText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              const Text(
                'Add something of your own before sharing.',
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // CURRENT USER
              // =================================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  _buildAvatar(
                    widget.sharerPhoto,
                    46,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: VerifiedName(
                      name: widget.sharerName,
                      verified:
                          widget.sharerVerified,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      textColor:
                          _primaryText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // =================================================================
              // CAPTION
              // =================================================================

              TextField(
                controller: widget.controller,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                textCapitalization:
                    TextCapitalization.sentences,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 15,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Say something about this post...',
                  hintStyle: const TextStyle(
                    color: _mutedText,
                  ),
                  filled: true,
                  fillColor: _surface,
                  contentPadding:
                      const EdgeInsets.all(15),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(17),
                    borderSide:
                        BorderSide.none,
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(17),
                    borderSide:
                        const BorderSide(
                      color: _brightPurple,
                      width: 1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // =================================================================
              // ORIGINAL AUTHOR PREVIEW
              // =================================================================

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius:
                      BorderRadius.circular(17),
                  border: Border.all(
                    color: _border,
                  ),
                ),
                child: Row(
                  children: [
                    _buildAvatar(
                      widget.originalAuthorPhoto,
                      42,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          VerifiedName(
                            name: widget
                                .originalAuthorName,
                            verified: widget
                                .originalVerified,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                            textColor:
                                _primaryText,
                          ),

                          const SizedBox(height: 3),

                          const Text(
                            'Original post',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.repeat_rounded,
                      color: _brightPurple,
                      size: 21,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =================================================================
              // SHARE BUTTON
              // =================================================================

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
                    onPressed: _sharing
                        ? null
                        : _share,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.transparent,
                      disabledBackgroundColor:
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
                    child: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Icon(
                                Icons
                                    .repeat_rounded,
                                color:
                                    Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Share to Feed',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // AVATAR
  // ===========================================================================

  Widget _buildAvatar(
    String url,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _purple,
            _brightPurple,
          ],
        ),
      ),
      child: ClipOval(
        child: url.trim().isEmpty
            ? Container(
                color: _surface,
                child: Icon(
                  Icons.person_rounded,
                  color: _brightPurple,
                  size: size * 0.52,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color: _surface,
                    child: Icon(
                      Icons.person_rounded,
                      color: _brightPurple,
                      size: size * 0.52,
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ===========================================================================
  // SHARE
  // ===========================================================================

  void _share() {
    if (_sharing) {
      return;
    }

    FocusScope.of(context).unfocus();

    final caption =
        widget.controller.text.trim();

    Navigator.of(context).pop(
      <String, dynamic>{
        'caption': caption,
      },
    );
  }
}
// =============================================================================
// CREATE POST SHEET
// =============================================================================

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final ImagePicker _picker = ImagePicker();

  final CloudinaryService _cloudinaryService =
      CloudinaryService();

  bool _uploading = false;

  final List<String> _imageUrls = <String>[];
  final List<String> _videoUrls = <String>[];


  // ===========================================================================
  // PICK IMAGE
  // ===========================================================================

  Future<void> _pickImage() async {
    if (_uploading) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _uploading = true;
      });

      final String? url = await CloudinaryService.uploadImage(
        File(file.path),
      );

      if (url != null && url.trim().isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _imageUrls.add(url.trim());
        });
      } else {
        if (!mounted) return;

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not upload the picture.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not upload the picture.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ===========================================================================
  // REMOVE IMAGE
  // ===========================================================================

  void _removeImage(int index) {
    if (_uploading) return;

    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Future<void> _publish() async {
  if (_uploading) return;

  final text = widget.controller.text.trim();

  if (text.isEmpty && _imageUrls.isEmpty && _videoUrls.isEmpty) {
    return;
  }

  Navigator.of(context).pop(
    <String, dynamic>{
      'text': text,
      'imageUrls': List<String>.from(_imageUrls),
      'videoUrls': List<String>.from(_videoUrls),
      'voiceUrl': null,
      'pollQuestion': null,
      'pollOptions': <Map<String, dynamic>>[],
      'eventTitle': null,
      'gifUrl': null,
    },
  );
}

  // ===========================================================================
  // IMAGE PREVIEW
  // ===========================================================================

  Widget _buildImagePreview() {
    if (_imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageUrls.length,
        separatorBuilder: (
          context,
          index,
        ) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (
          context,
          index,
        ) {
          final String url =
              _imageUrls[index];

          return Stack(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(14),
                child: Image.network(
                  url,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      width: 92,
                      height: 92,
                      color:
                          const Color(0xFF0D1324),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color:
                            Color(0xFFB026FF),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    _removeImage(index);
                  },
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration:
                        const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color:
                    const Color(0xFF202E48),
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Create a post',
              style: TextStyle(
                color: Color(0xFFF5F7FF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller:
                  widget.controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(
                color: Color(0xFFF5F7FF),
              ),
              decoration:
                  InputDecoration(
                hintText:
                    "What's on your mind?",
                hintStyle:
                    const TextStyle(
                  color:
                      Color(0xFF68738A),
                ),
                filled: true,
                fillColor:
                    const Color(0xFF0D1324),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  borderSide:
                      const BorderSide(
                    color:
                        Color(0xFF7B2FF7),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================================
            // SELECTED MEDIA
            // =================================================================

            _buildImagePreview(),

            // =================================================================
            // MEDIA BUTTONS
            // =================================================================

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap:
                        _uploading
                            ? null
                            : _pickImage,
                    child: Container(
                      height: 44,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFF0D1324,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFF202E48,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          if (_uploading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Color(
                                  0xFFB026FF,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons
                                  .photo_library_rounded,
                              color:
                                  Color(
                                0xFFB026FF,
                              ),
                              size: 20,
                            ),

                          const SizedBox(
                            width: 8,
                          ),

                          Text(
                            _uploading
                                ? 'Uploading...'
                                : 'Photo',
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFFE4E8F2,
                              ),
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                               const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================================
            // POST BUTTON
            // =================================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF7B2FF7),
                      Color(0xFFB026FF),
                    ],
                  ),
                ),
                child:
                    ElevatedButton(
                  onPressed:
                      _uploading
                          ? null
                          : _publish,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.transparent,
                    disabledBackgroundColor:
                        Colors.transparent,
                    shadowColor:
                        Colors.transparent,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
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
      ),
    );
  }
}

// =============================================================================
// COMMENTS SHEET
// =============================================================================

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.controller,
  });

  final String postId;
  final TextEditingController controller;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  bool _sending = false;

  final Set<String> _likingComments = <String>{};

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final text = widget.controller.text.trim();

    if (uid == null || text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      // ----------------------------------------------------------------------
      // GET USER DATA
      // ----------------------------------------------------------------------

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userSnapshot.data() ?? <String, dynamic>{};

      final displayNameValue = userData['displayName'];
      final nameValue = userData['name'];
      final photoValue = userData['photoUrl'];

      final String name =
          displayNameValue is String &&
                  displayNameValue.trim().isNotEmpty
              ? displayNameValue.trim()
              : nameValue is String && nameValue.trim().isNotEmpty
                  ? nameValue.trim()
                  : 'User';

      final String? photoUrl =
          photoValue is String && photoValue.trim().isNotEmpty
              ? photoValue.trim()
              : null;

      // ----------------------------------------------------------------------
// CREATE COMMENT
// ----------------------------------------------------------------------

final commentRef = FirebaseFirestore.instance
    .collection('posts')
    .doc(widget.postId)
    .collection('comments')
    .doc();

await commentRef.set({
  'postId': widget.postId,
  'userId': uid,
  'displayName': name,
  'text': text,
  'photoUrl': photoUrl,
  'createdAt': FieldValue.serverTimestamp(),
  'likeCount': 0,
});

      // Clear only after Firestore confirms the write.
      widget.controller.clear();

      if (mounted) {
        FocusScope.of(context).unfocus();
      }

      // ----------------------------------------------------------------------
      // UPDATE POST COMMENT COUNT
      // ----------------------------------------------------------------------

      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
          'commentCount': FieldValue.increment(1),
        });
      } catch (_) {
        // The comment itself has already been successfully created.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send comment. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ==========================================================================
  // LIKE COMMENT
  // ==========================================================================

  // ==========================================================================
// LIKE / UNLIKE COMMENT
// ==========================================================================

Future<void> _toggleCommentLike(
  String commentId,
  Map<String, dynamic> data,
) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null ||
      _likingComments.contains(commentId)) {
    return;
  }

  final uid = user.uid;

  setState(() {
    _likingComments.add(commentId);
  });

  try {
    final firestore =
        FirebaseFirestore.instance;

    final commentRef = firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    final likeRef = commentRef
        .collection('likes')
        .doc(uid);

    final likeSnapshot =
        await likeRef.get();

    if (likeSnapshot.exists) {
      // ====================================================================
      // UNLIKE
      // ====================================================================

      await firestore.runTransaction(
        (transaction) async {
          final commentSnapshot =
              await transaction.get(commentRef);

          if (!commentSnapshot.exists) {
            return;
          }

          final commentData =
              commentSnapshot.data()
                  as Map<String, dynamic>;

          final currentCount =
              commentData['likeCount'] is num
                  ? (commentData['likeCount'] as num)
                      .toInt()
                  : 0;

          final newCount =
              math.max(0, currentCount - 1);

          transaction.delete(likeRef);

          transaction.update(
            commentRef,
            {
              'likeCount': newCount,
            },
          );
        },
      );
    } else {
      // ====================================================================
      // LIKE
      // ====================================================================

      await firestore.runTransaction(
        (transaction) async {
          final commentSnapshot =
              await transaction.get(commentRef);

          if (!commentSnapshot.exists) {
            return;
          }

          final commentData =
              commentSnapshot.data()
                  as Map<String, dynamic>;

          final currentCount =
              commentData['likeCount'] is num
                  ? (commentData['likeCount'] as num)
                      .toInt()
                  : 0;

          transaction.set(
            likeRef,
            {
              'userId': uid,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            commentRef,
            {
              'likeCount': currentCount + 1,
            },
          );
        },
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update comment like.',
          ),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _likingComments.remove(commentId);
      });
    }
  }
}

  // ==========================================================================
  // CHECK WHETHER CURRENT USER LIKED COMMENT
  // ==========================================================================

  Future<bool> _hasLikedComment(
    String commentId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return snapshot.exists;
  }

  // ==========================================================================
  // FORMAT COMMENT TIME
  // ==========================================================================

  String _formatCommentTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      final date = value.toDate();
      final now = DateTime.now();

      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'now';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours}h';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays}d';
      }

      return '${date.day}/${date.month}/${date.year}';
    }

    return 'now';
  }

  // ==========================================================================
  // COMMENT AVATAR
  // ==========================================================================

  Widget _buildAvatar(
    String? photoUrl,
    String name,
  ) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF0D1324),
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF171D31),
      child: Text(
        name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : 'U',
        style: const TextStyle(
          color: Color(0xFFB026FF),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // ==========================================================================
  // COMMENT ITEM
  // ==========================================================================

  Widget _buildCommentItem(
    QueryDocumentSnapshot<Map<String, dynamic>> comment,
  ) {
    final data = comment.data();

    final String name =
        data['displayName'] is String &&
                (data['displayName'] as String)
                    .trim()
                    .isNotEmpty
            ? (data['displayName'] as String).trim()
            : 'User';

    final String text =
        data['text'] is String
            ? (data['text'] as String).trim()
            : '';

    final String? photoUrl =
        data['photoUrl'] is String &&
                (data['photoUrl'] as String)
                    .trim()
                    .isNotEmpty
            ? (data['photoUrl'] as String).trim()
            : null;

    final int likeCount =
        data['likeCount'] is num
            ? (data['likeCount'] as num).toInt()
            : 0;

    final String time =
        _formatCommentTime(data['createdAt']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        4,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildAvatar(
            photoUrl,
            name,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    13,
                    9,
                    13,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1324),
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        text,
                        style:
                            const TextStyle(
                          color:
                              Color(0xFFE4E8F2),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Text(
                      time,
                      style:
                          const TextStyle(
                        color:
                            Color(0xFF68738A),
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(width: 15),

                    GestureDetector(
                      onTap: () {
                        // Reply functionality can be
                        // connected here next.
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color:
                              Color(0xFF9AA3B5),
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    const Spacer(),

                    FutureBuilder<bool>(
                      future: _hasLikedComment(
                        comment.id,
                      ),
                      builder:
                          (
                        context,
                        likeSnapshot,
                      ) {
                        final liked =
                            likeSnapshot.data ??
                                false;

                        final liking =
                            _likingComments.contains(
                          comment.id,
                        );

                        return Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: liking
                                  ? null
                                  : () {
                                      _toggleCommentLike(
                                        comment.id,
                                        data,
                                      );
                                    },
                              child: liking
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            1.7,
                                        color:
                                            Color(
                                          0xFFB026FF,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      liked
                                          ? Icons
                                              .favorite_rounded
                                          : Icons
                                              .favorite_border_rounded,
                                      size: 18,
                                      color: liked
                                          ? Colors.red
                                          : const Color(
                                              0xFF68738A,
                                            ),
                                    ),
                            ),

                            if (likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style:
                                    const TextStyle(
                                  color:
                                      Color(
                                    0xFF68738A,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            const SizedBox(height: 14),

            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF202E48),
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<
                      Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .snapshots(),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons
                                  .chat_bubble_outline_rounded,
                              color:
                                  Color(0xFF68738A),
                              size: 35,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text(
                              'Could not load comments.',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                color:
                                    Color(
                                  0xFF9AA3B5,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              '${snapshot.error}',
                              textAlign:
                                  TextAlign.center,
                              style:
                                  const TextStyle(
                                color:
                                    Color(
                                  0xFF68738A,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            Color(0xFFB026FF),
                      ),
                    );
                  }

                  final comments =
                      List<
                          QueryDocumentSnapshot<
                              Map<String,
                                  dynamic>>>.from(
                    snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>[],
                  );

                  // ----------------------------------------------------------
                  // SORT LOCALLY
                  //
                  // We intentionally do NOT use Firestore orderBy().
                  // This means comments continue to work even if some old
                  // comment has a missing createdAt field.
                  // ----------------------------------------------------------

                  comments.sort(
                    (
                      a,
                      b,
                    ) {
                      final aTime =
                          a.data()['createdAt'];

                      final bTime =
                          b.data()['createdAt'];

                      if (aTime is Timestamp &&
                          bTime is Timestamp) {
                        return bTime.compareTo(
                          aTime,
                        );
                      }

                      if (aTime is Timestamp) {
                        return -1;
                      }

                      if (bTime is Timestamp) {
                        return 1;
                      }

                      return 0;
                    },
                  );

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(
                          color:
                              Color(0xFF9AA3B5),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics:
                        const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.only(
                      top: 4,
                      bottom: 10,
                    ),
                    itemCount:
                        comments.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      return _buildCommentItem(
                        comments[index],
                      );
                    },
                  );
                },
              ),
            ),

            // =================================================================
            // COMMENT INPUT
            // =================================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          widget.controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization:
                          TextCapitalization.sentences,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            'Write a comment...',
                        hintStyle:
                            const TextStyle(
                          color:
                              Color(0xFF68738A),
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFF0D1324),
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _sending
                        ? null
                        : _sendComment,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(
                          colors: [
                            Color(0xFF7B2FF7),
                            Color(0xFFB026FF),
                          ],
                        ),
                      ),
                      child: _sending
                          ? const Padding(
                              padding:
                                  EdgeInsets.all(
                                14,
                              ),
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color:
                                  Colors.white,
                              size: 20,
                            ),
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
}

// =============================================================================
// FOLLOW BUTTON
// =============================================================================

class _FollowButton
    extends StatelessWidget {
  const _FollowButton({
    required this.onPressed,
    required this.loading,
  });

  final VoidCallback onPressed;
  final bool loading;

  static const Color _purple =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 82,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20),
          gradient:
              const LinearGradient(
            colors: [
              _purple,
              _brightPurple,
            ],
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Follow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// =============================================================================
// MESSAGE BUTTON
// =============================================================================

class _MessageButton
    extends StatelessWidget {
  const _MessageButton({
    required this.onPressed,
    required this.loading,
  });

  final VoidCallback onPressed;
  final bool loading;

  static const Color _surface =
      Color(0xFF0D1324);

  static const Color _border =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 82,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: _border,
            width: 1.2,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _brightPurple,
                ),
              )
            : const Text(
                'Message',
                style: TextStyle(
                  color: _brightPurple,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
// =============================================================================
// CHATTªX — FEED VIDEO PREVIEW
// =============================================================================
//
// Feed behaviour:
//
//   Feed
//      ↓
//   video enters viewport
//      ↓
//   video automatically plays
//      ↓
//   video leaves viewport
//      ↓
//   video pauses
//      ↓
//   user taps video
//      ↓
//   ReelsScreen opens
// =============================================================================

class _FeedVideoPlayer extends StatefulWidget {
  const _FeedVideoPlayer({
    super.key,
    required this.url,
    required this.onOpenViewer,
  });

  final String url;
  final VoidCallback onOpenViewer;

  @override
  State<_FeedVideoPlayer> createState() =>
      _FeedVideoPlayerState();
}

class _FeedVideoPlayerState
    extends State<_FeedVideoPlayer> {
  VideoPlayerController? _controller;

  bool _initializing = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);

      setState(() {
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _hasError = true;
      });
    }
  }

  Future<void> _handleVisibility(
    double visibleFraction,
  ) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _hasError) {
      return;
    }

    // Start playing once a meaningful portion of the
    // video is visible on screen.
    if (visibleFraction >= 0.55) {
      if (!controller.value.isPlaying) {
        try {
          await controller.play();
        } catch (_) {}
      }
    }

    // Pause when the video is mostly off-screen.
    else if (visibleFraction <= 0.15) {
      if (controller.value.isPlaying) {
        try {
          await controller.pause();
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Container(
        width: double.infinity,
        height: 260,
        color: const Color(0xFF0D1324),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFB026FF),
          ),
        ),
      );
    }

    if (_hasError ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: 260,
        color: const Color(0xFF0D1324),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_rounded,
                color: Color(0xFFB026FF),
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'Video unavailable',
                style: TextStyle(
                  color: Color(0xFF9AA3B5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;

    return VisibilityDetector(
      key: Key(
        'feed_video_visibility_${widget.url}',
      ),
      onVisibilityChanged: (info) {
        _handleVisibility(
          info.visibleFraction,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenViewer,
        child: SizedBox(
          width: double.infinity,
          height: 260,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ---------------------------------------------------------
                // CROPPED VIDEO
                // ---------------------------------------------------------
                FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),

                // ---------------------------------------------------------
                // DARK CINEMATIC OVERLAY
                // ---------------------------------------------------------
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: .08,
                        ),
                        Colors.black.withValues(
                          alpha: .28,
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------------------------------------------------------
                // PLAY INDICATOR
                // ---------------------------------------------------------
                Center(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      // Once autoplay starts, remove the play button.
                      if (controller.value.isPlaying) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: .62,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFB026FF,
                            ).withValues(
                              alpha: .72,
                            ),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFB026FF,
                              ).withValues(
                                alpha: .20,
                              ),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFF00D9FF,
                              ).withValues(
                                alpha: .10,
                              ),
                              blurRadius: 25,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      );
                    },
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