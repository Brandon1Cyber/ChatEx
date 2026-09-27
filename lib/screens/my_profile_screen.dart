import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'feed_earnings_screen.dart';

import '../widgets/verified_name.dart';
import 'package:video_player/video_player.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    this.userId,
  });

  /// UID of the profile being viewed.
  /// If null, the currently signed-in user's profile is shown.
  final String? userId;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // ============================================================
// COLORS — CHATTªX FUTURISTIC PROFILE
// ============================================================

static const Color background = Color(0xFF030309);

static const Color card = Color(0xFF0A0A18);

static const Color cardDark = Color(0xFF070711);

static const Color border = Color(0xFF19152D);

// Screenshot-inspired purple / cyan
static const Color neonPurple = Color(0xFF7B2FFF);

static const Color neonBlue = Color(0xFF00C8FF);

  // ============================================================
  // STATE
  // ============================================================

  String selectedFilter = 'All posts';
  String selectedSort = 'Newest';
  bool _bioExpanded = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // CURRENT USER / PROFILE STREAM
  // ============================================================

  User? get _currentUser => _auth.currentUser;

  String? get _profileUid => widget.userId ?? _currentUser?.uid;

bool get _isMyProfile =>
    widget.userId == null || widget.userId == _currentUser?.uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream() {
  final uid = _profileUid;

  if (uid == null || uid.isEmpty) {
    return const Stream.empty();
  }

  return _firestore
      .collection('users')
      .doc(uid)
      .snapshots();
}

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            'Please sign in again.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _background(),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _profileStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: neonPurple,
                    strokeWidth: 2,
                  ),
                );
              }

              final data = snapshot.data?.data() ?? <String, dynamic>{};

              return SafeArea(
  top: false,
  bottom: false,
  child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _topHeader(data),
                    _profileHeader(data),
                    SliverToBoxAdapter(child: _actionsRow()),
                    SliverToBoxAdapter(child: _profileTabs()),
                    SliverToBoxAdapter(child: _filterBar()),
                    _postsSliver(data),
                    SliverToBoxAdapter(
  child: SizedBox(
    height: MediaQuery.of(context).padding.bottom + 40,
  ),
),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _background() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -160,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    neonPurple.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 420,
            right: -220,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    neonBlue.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP HEADER — flat, edge-to-edge
  // ============================================================

  SliverAppBar _topHeader(Map<String, dynamic> data) {
    final name = _displayName(data);
    final verified = _isVerified(data);

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: background.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 52,
      expandedHeight: 52,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _headerButton(Icons.arrow_back_ios_new_rounded, () {
              Navigator.maybePop(context);
            }),
            const SizedBox(width: 2),
            Expanded(
              child: VerifiedName(
                name: name.isEmpty ? 'Profile' : name,
                verified: verified,
                fontSize: 17,
              ),
            ),
            _headerButton(Icons.search_rounded, _showSearch),
            _headerButton(Icons.more_horiz_rounded, _showProfileMenu),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  SliverToBoxAdapter _profileHeader(Map<String, dynamic> data) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A18),
borderRadius: BorderRadius.circular(22),
border: Border.all(
  color: neonPurple.withValues(alpha: 0.65),
  width: 1.2,
),
boxShadow: [
  BoxShadow(
    color: neonPurple.withValues(alpha: 0.08),
    blurRadius: 18,
    spreadRadius: 1,
  ),
],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _coverPhoto(data),
            Padding(
  padding: const EdgeInsets.fromLTRB(14, 0, 14, 17),
  child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -48),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _profileAvatar(data),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _profileIdentity(data),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -27),
                    child: Column(
                      children: [
                        _stats(data),
                        const SizedBox(height: 12),
                        _bio(data),
                        const SizedBox(height: 10),
                        _infoChips(data),
                      ],
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

  // ============================================================
  // IDENTITY
  // ============================================================

  Widget _profileIdentity(Map<String, dynamic> data) {
    final name = _displayName(data);
    final username = _username(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VerifiedName(
          name: name.isEmpty ? 'User' : name,
          verified: _isVerified(data),
          fontSize: 20,
        ),
        const SizedBox(height: 3),
        Text(
          username.isEmpty
              ? '@${_profileUid != null && _profileUid!.length >= 8
    ? _profileUid!.substring(0, 8)
    : 'user'}'
              : username.startsWith('@')
                  ? username
                  : '@$username',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(
            color: Color(0xFF9EA7BA),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COVER
  // ============================================================

  Widget _coverPhoto(Map<String, dynamic> data) {
    final coverUrl = _coverImage(data);

    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
  Color(0xFF111225),
  Color(0xFF0A0818),
  Color(0xFF030309),
],
              ),
            ),
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        CustomPaint(painter: CoverPainter(), size: Size.infinite),
                  )
                : CustomPaint(painter: CoverPainter(), size: Size.infinite),
          ),

          // "Share a vibe..." pill
Positioned(
  left: 24,
  bottom: 48,
  child: GestureDetector(
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Composer coming next.'),
        ),
      );
    },
    child: Container(
      width: 116,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B18).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: neonPurple.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: neonPurple.withValues(alpha: 0.18),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bubble_chart_rounded,
            color: Color.fromARGB(255, 131, 13, 171),
            size: 14,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Share a vibe...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),

          // Edit profile
          Positioned(
            right: 12,
            top: 12,
            child: GestureDetector(
              onTap: _editProfile,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
  color: const Color(0xFF0B0A1A).withValues(alpha: 0.94),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: neonPurple.withValues(alpha: 0.85),
    width: 1.2,
  ),
  boxShadow: [
    BoxShadow(
      color: neonPurple.withValues(alpha: 0.18),
      blurRadius: 10,
      spreadRadius: 1,
    ),
  ],
),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
  Icons.edit_rounded,
  color: neonBlue,
  size: 14,
),
                    SizedBox(width: 5),
                    Text(
                      'Edit profile',
                      style: TextStyle(
                        color: Color(0xFFE9E7FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _profileAvatar(Map<String, dynamic> data) {
    final photoUrl = _profileImage(data);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 102,
          height: 102,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [neonPurple, neonBlue]),
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration:
                const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 0,
          child: GestureDetector(
            onTap: _changeProfilePhoto,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF030711),
                shape: BoxShape.circle,
                border: Border.all(color: neonBlue, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return const ColoredBox(
      color: Color(0xFF101828),
      child: Center(
        child: Icon(Icons.person, color: Colors.white, size: 45),
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _stats(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _stat(_formatNumber(_followersCount(data)), 'Followers'),
          _divider(),
          _stat(_formatNumber(_followingCount(data)), 'Following'),
          _divider(),
          _stat(_formatNumber(_postsCount(data)), 'Posts'),
          _divider(),
          _stat(_formatNumber(_resharedCount(data)), 'Reshared'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C96AA),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 29, color: border);

  // ============================================================
  // BIO — with warning icon + expand/collapse "more"
  // ============================================================

  Widget _bio(Map<String, dynamic> data) {
    final bio = _stringValue(data, ['bio', 'description', 'about']);
    if (bio.isEmpty) return const SizedBox.shrink();

    final isLong = bio.length > 60;
    final display =
        (!_bioExpanded && isLong) ? '${bio.substring(0, 60).trimRight()}…' : bio;

    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          children: [
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFC94A), size: 15),
              ),
            ),
            TextSpan(
              text: display,
              style: const TextStyle(
                color: Color(0xFFE1E6EF),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isLong)
              TextSpan(
                text: _bioExpanded ? '  less' : '  more',
                style: const TextStyle(
                  color: Color(0xFF8C96AA),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                recognizer: TapGestureDetectorHolder.build(() {
                  setState(() => _bioExpanded = !_bioExpanded);
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CHIPS
  // ============================================================

  Widget _infoChips(Map<String, dynamic> data) {
    final profession = _stringValue(data, ['profession', 'job', 'occupation']);
    final location = _stringValue(data, ['location', 'city', 'place']);
    final link = _stringValue(data, ['website', 'link', 'handle2']);

    final chips = <Widget>[];
    if (profession.isNotEmpty) {
      chips.add(_infoChip(Icons.work_outline_rounded, profession));
    }
    if (location.isNotEmpty) {
      chips.add(_infoChip(Icons.location_on_outlined, location));
    }
    if (link.isNotEmpty) {
      chips.add(_infoChip(Icons.link_rounded, link));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFD5DBE8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS ROW — Earnings / Add to story / Insights / Creator tools
  // ============================================================

  Widget _actionsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              Icons.bar_chart_rounded,
              'Earnings',
              onTap: _showDashboard,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _actionButton(
              Icons.add_circle_outline_rounded,
              'Add to story',
              onTap: _addToStory,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _actionButton(
              Icons.trending_up_rounded,
              'Insights',
              onTap: _showInsights,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _actionButton(
  Icons.auto_graph_rounded,
  'Creator tools',
  onTap: _showTools,
),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String text, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A18),
borderRadius: BorderRadius.circular(16),
border: Border.all(
  color: neonPurple.withValues(alpha: 0.45),
),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: neonBlue, size: 17),
            const SizedBox(height: 3),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _profileTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: cardDark,
        border: Border(top: BorderSide(color: border), bottom: BorderSide(color: border)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: neonPurple,
        indicatorWeight: 3,
        labelColor: neonPurple,
        unselectedLabelColor: const Color(0xFF8791A5),
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'My Posts'),
          Tab(text: 'Reshared'),
          Tab(text: 'Saved'),
          Tab(text: 'Drafts'),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 3),
      child: Row(
        children: [
          _filterButton(selectedFilter, _showFilterMenu),
          const Spacer(),
          _filterButton(selectedSort, _showSortMenu),
        ],
      ),
    );
  }

  Widget _filterButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 15),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // POSTS
  // ============================================================

  Widget _postsSliver(Map<String, dynamic> data) {
    final uid = _currentUser?.uid;
    if (uid == null) {
      return SliverToBoxAdapter(child: _emptyState());
    }

    switch (_tabController.index) {
      case 1:
        return _resharedPosts(uid);
      case 2:
        return _savedPosts(uid);
      case 3:
        return _draftPosts(uid);
      default:
        return _myPosts(uid, data);
    }
  }

  Widget _myPosts(String uid, Map<String, dynamic> profileData) {
    final query = _firestore
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final docs = snapshot.data?.docs ?? [];

        // No real posts yet — show sample content so the feed is never empty.
        if (docs.isEmpty) {
  return SliverToBoxAdapter(
    child: _emptyState(
      title: 'Nothing here yet',
      subtitle: 'This user has not posted anything yet.',
    ),
  );
}

        final posts =
            docs.map((doc) => ChattaxPost.fromFirestore(doc)).toList();
        _sortPosts(posts);

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _feedPost(posts[index], index),
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _resharedPosts(String uid) {
    final query = _firestore
        .collection('posts')
        .where('resharedBy', arrayContains: uid)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'Nothing reshared',
              subtitle: 'Posts you reshare will appear here.',
            ),
          );
        }

        final posts = docs
            .map((doc) => ChattaxPost.fromFirestore(doc, reshared: true))
            .toList();
        _sortPosts(posts);

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _feedPost(posts[index], index),
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _savedPosts(String uid) {
    final query =
        _firestore.collection('users').doc(uid).collection('savedPosts').limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'No saved posts',
              subtitle: 'Posts you save will appear here.',
            ),
          );
        }

        final posts =
            docs.map((doc) => ChattaxPost.fromFirestore(doc)).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _feedPost(posts[index], index),
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _draftPosts(String uid) {
    final query =
        _firestore.collection('users').doc(uid).collection('drafts').limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'No drafts',
              subtitle: 'Your unfinished posts will appear here.',
            ),
          );
        }

        final posts =
            docs.map((doc) => ChattaxPost.fromFirestore(doc)).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _feedPost(posts[index], index),
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _loadingSliver() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: 45),
        child: Center(
          child: CircularProgressIndicator(color: neonPurple, strokeWidth: 2),
        ),
      ),
    );
  }

  // ============================================================
  // SAMPLE / FAKE POSTS — text, picture, milestone
  // ============================================================

  List<ChattaxPost> _samplePosts({
    required String authorName,
    required bool authorVerified,
  }) {
    final now = DateTime.now();

    return [
      ChattaxPost(
        id: 'sample-text',
        imageUrl: '',
        caption:
            'Just vibing today, grateful for every single one of you 🙏 #ChattaX #GoodEnergy',
        time: '2h',
        likes: 184,
        comments: 12,
        shares: 4,
        authorName: authorName,
        authorVerified: authorVerified,
        timestamp: now.subtract(const Duration(hours: 2)),
        type: PostType.text,
      ),
      ChattaxPost(
        id: 'sample-image',
        imageUrl: 'https://picsum.photos/seed/chattax-city/800/800',
        caption: 'City lights hit different tonight 🌃 #ChattaX',
        time: '6h',
        likes: 932,
        comments: 58,
        shares: 21,
        authorName: authorName,
        authorVerified: authorVerified,
        timestamp: now.subtract(const Duration(hours: 6)),
        type: PostType.image,
      ),
      ChattaxPost(
        id: 'sample-milestone',
        imageUrl: '',
        caption: 'Just crossed a new follower milestone — thank you! 🎉',
        time: '1d',
        likes: 2400,
        comments: 210,
        shares: 96,
        authorName: authorName,
        authorVerified: authorVerified,
        timestamp: now.subtract(const Duration(days: 1)),
        type: PostType.milestone,
        milestoneValue: '10K Followers',
      ),
    ];
  }

  // ============================================================
  // POST CARD
  // ============================================================

  Widget _feedPost(ChattaxPost post, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 5, 4, 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 7, 8),
            child: Row(
              children: [
                _postAvatar(post),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VerifiedName(
                        name: post.authorName,
                        verified: post.authorVerified,
                        fontSize: 13,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            post.time,
                            style: const TextStyle(
                              color: Color(0xFF8D97AA),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.public_rounded,
                              color: Color(0xFF8D97AA), size: 11),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showPostMenu(post),
                  icon:
                      const Icon(Icons.more_horiz_rounded, color: Color(0xFFB9C1D0)),
                ),
              ],
            ),
          ),

          if (post.isReshared)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 7),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, color: neonBlue, size: 15),
                  SizedBox(width: 5),
                  Text(
                    'You reshared this',
                    style: TextStyle(
                        color: neonBlue, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 2, 13, 11),
              child: _captionWithHashtag(post.caption),
            ),

          if (post.type == PostType.image && post.imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1.15,
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFF080D18),
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: neonPurple),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF080D18),
                  child: const Center(
                    child:
                        Icon(Icons.image_outlined, color: neonPurple, size: 45),
                  ),
                ),
              ),
            ),

            // ==========================================================================
// VIDEO POST
// ==========================================================================

if (post.videoUrls.isNotEmpty)
  _profileVideoSection(post.videoUrls),

          if (post.type == PostType.milestone)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [neonPurple, neonBlue],
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      post.milestoneValue ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
  padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
  child: Row(
    children: [
      // ❤️ 184
      const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFFF315C),
        size: 17,
      ),

      const SizedBox(width: 6),

      Text(
        _formatNumber(post.likes),
        style: const TextStyle(
          color: Color(0xFFB8C1D1),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),

      const Spacer(),

      // 12 Comments
      Text(
        '${post.comments} Comments',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB8C1D1),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(width: 12),

      // 4 Shares
      Text(
        '${post.shares} Shares',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB8C1D1),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
),

          Divider(height: 1, color: border),

          SizedBox(
  height: 46,
  child: Row(
    children: [
      _postAction(
        Icons.favorite_border_rounded,
        'Like',
        const Color(0xFFB8C1D1),
      ),
      _postAction(
        Icons.chat_bubble_outline_rounded,
        'Comment',
        const Color(0xFFB8C1D1),
      ),
      _postAction(
        Icons.send_rounded,
        'Share',
        const Color(0xFFB8C1D1),
      ),
      _postAction(
        Icons.bookmark_border_rounded,
        'Save',
        const Color(0xFFB8C1D1),
      ),
    ],
  ),
),
        ],
      ),
    );
  }

  // ============================================================
// PROFILE VIDEO SECTION
// ============================================================

Widget _profileVideoSection(
  List<String> videoUrls,
) {
  if (videoUrls.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    children: [
      for (int index = 0;
          index < videoUrls.length;
          index++)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            8,
            0,
            8,
            8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _ProfileVideoPlayer(
              key: ValueKey(
  'profile_video_${index}_${videoUrls[index]}',
),
              url: videoUrls[index],
            ),
          ),
        ),
    ],
  );
}

  Widget _postAvatar(ChattaxPost post) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final photo = _profileImage(data);

        return Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [neonPurple, neonBlue]),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration:
                const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: ClipOval(
              child: photo.isNotEmpty
                  ? Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
        );
      },
    );
  }

  Widget _reactionStack() {
  return const Icon(
    Icons.favorite_rounded,
    color: Color(0xFFFF315C),
    size: 17,
  );
}

  Widget _postAction(
  IconData icon,
  String label,
  Color color,
) {
  return Expanded(
    child: InkWell(
      onTap: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
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

  Widget _captionWithHashtag(String caption) {
    final words = caption.split(' ');

    return RichText(
      text: TextSpan(
        children: words.map((word) {
          final hashtag = word.startsWith('#');
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              color: hashtag ? neonPurple : const Color(0xFFE4E8F0),
              fontSize: 13,
              fontWeight: hashtag ? FontWeight.w800 : FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState({
    String title = 'Nothing here yet',
    String subtitle = 'Your content will appear here.',
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 65),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: neonPurple),
              ),
              child: const Icon(Icons.layers_outlined, color: neonPurple, size: 29),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7E8799), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE DATA HELPERS
  // ============================================================

  String _displayName(Map<String, dynamic> data) {
    final value = _stringValue(data, ['displayName', 'name', 'fullName']);
    if (value.isNotEmpty) return value;
    return _currentUser?.displayName?.trim() ?? '';
  }

  String _username(Map<String, dynamic> data) {
    return _stringValue(data, ['username', 'userName', 'handle']);
  }

  String _profileImage(Map<String, dynamic> data) {
    final value = _stringValue(data, [
      'photoUrl',
      'profilePhoto',
      'profileImage',
      'profileImageUrl',
      'photoURL',
      'avatarUrl',
      'avatar',
    ]);
    if (value.isNotEmpty) return value;
    return '';
  }

  String _coverImage(Map<String, dynamic> data) {
    return _stringValue(
        data, ['coverPhoto', 'coverPhotoUrl', 'coverImage', 'coverImageUrl']);
  }

  bool _isVerified(Map<String, dynamic> data) {
    final values = [
      data['isVerified'],
      data['verified'],
      data['verification'],
      data['verifiedUser'],
    ];

    for (final value in values) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return false;
  }

  int _followersCount(Map<String, dynamic> data) =>
      _numberValue(data, ['followersCount', 'followers', 'followerCount']);

  int _followingCount(Map<String, dynamic> data) =>
      _numberValue(data, ['followingCount', 'following']);

  int _postsCount(Map<String, dynamic> data) =>
      _numberValue(data, ['postsCount', 'postCount', 'posts']);

  int _resharedCount(Map<String, dynamic> data) =>
      _numberValue(data, ['resharedCount', 'reshares', 'reshared', 'reposts']);

  String _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  int _numberValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is List) return value.length;
      if (value is Map) return value.length;
    }
    return 0;
  }

  // ============================================================
  // SORT
  // ============================================================

  void _sortPosts(List<ChattaxPost> posts) {
    switch (selectedSort) {
      case 'Oldest':
        posts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'Most liked':
        posts.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case 'Most commented':
        posts.sort((a, b) => b.comments.compareTo(a.comments));
        break;
      case 'Most reshared':
        posts.sort((a, b) => b.shares.compareTo(a.shares));
        break;
      default:
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }

  // ============================================================
  // NUMBER FORMAT
  // ============================================================

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      final value = number / 1000;
      if (value == value.roundToDouble()) return '${value.toInt()}K';
      return '${value.toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // ============================================================
  // MENUS
  // ============================================================

  void _showSearch() {
    showSearch(context: context, delegate: ProfileSearchDelegate());
  }

  void _showProfileMenu() {
    _showSheet('Profile options', [
      _sheetItem(Icons.share_rounded, 'Share profile', () {}),
      _sheetItem(Icons.qr_code_rounded, 'My ChattaX QR', () {}),
      _sheetItem(Icons.lock_outline_rounded, 'Privacy settings', () {}),
      _sheetItem(Icons.settings_outlined, 'Profile settings', () {}),
    ]);
  }

  void _showPostMenu(ChattaxPost post) {
    _showSheet('Manage post', [
      _sheetItem(Icons.edit_outlined, 'Edit post', () {}),
      _sheetItem(Icons.push_pin_outlined, 'Pin to profile', () {}),
      _sheetItem(Icons.visibility_off_outlined, 'Hide from profile', () {}),
      _sheetItem(Icons.archive_outlined, 'Archive post', () {}),
      _sheetItem(
        Icons.delete_outline_rounded,
        'Delete post',
        () => _deletePost(post),
        danger: true,
      ),
    ]);
  }

  void _showSheet(String title, List<Widget> children) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF384258),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 17),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFF3A0812) : const Color(0xFF0B1323),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: danger ? const Color(0xFFFF3D63) : Colors.white),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: danger ? const Color(0xFFFF3D63) : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF677289)),
    );
  }

  // ============================================================
  // DASHBOARD / INSIGHTS / TOOLS / ADD TO STORY
  // ============================================================

  void _showDashboard() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const FeedEarningsScreen(),
    ),
  );
}

  void _addToStory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story composer coming next.')),
    );
  }

  void _showInsights() {
    _showSheet('Profile insights', [
      _insight(Icons.visibility_outlined, 'Profile views', 'Live'),
      _insight(Icons.people_outline_rounded, 'Audience', 'Live'),
      _insight(Icons.favorite_border_rounded, 'Engagement', 'Live'),
      _insight(Icons.person_add_alt_rounded, 'Followers', 'Live'),
    ]);
  }

  Widget _insight(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1221),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: neonBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: neonPurple, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  void _showTools() {
    _showSheet('Creator tools', [
      _sheetItem(Icons.auto_graph_rounded, 'Analytics', () {}),
      _sheetItem(Icons.monetization_on_outlined, 'ChattaX Monetization', () {}),
      _sheetItem(Icons.campaign_outlined, 'Promote a post', () {}),
      _sheetItem(Icons.verified_outlined, 'Creator verification', () {}),
    ]);
  }

  // ============================================================
  // FILTER / SORT MENUS
  // ============================================================

  void _showFilterMenu() {
    _choiceSheet(
      'Post filter',
      ['All posts', 'Photos', 'Videos', 'Text', 'Polls', 'Events'],
      (value) {
        if (!mounted) return;
        setState(() => selectedFilter = value);
      },
    );
  }

  void _showSortMenu() {
    _choiceSheet(
      'Sort posts',
      ['Newest', 'Oldest', 'Most liked', 'Most commented', 'Most reshared'],
      (value) {
        if (!mounted) return;
        setState(() => selectedSort = value);
      },
    );
  }

  void _choiceSheet(
    String title,
    List<String> options,
    Function(String) callback,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF384258),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map((option) {
                  final selected =
                      option == selectedFilter || option == selectedSort;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      callback(option);
                    },
                    title: Text(
                      option,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: neonPurple)
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ACTION PLACEHOLDERS
  // ============================================================

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile editor coming next.')),
    );
  }

  void _changeProfilePhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo picker coming next.')),
    );
  }

  void _deletePost(ChattaxPost post) {
    final uid = _currentUser?.uid;
    if (uid == null || post.id.isEmpty || post.id.startsWith('sample-')) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF090F1D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'Delete post?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This post will be permanently removed from ChattaX.',
            style: TextStyle(color: Color(0xFF9BA5B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _firestore.collection('posts').doc(post.id).delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Post deleted')));
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not delete post.')));
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF3D63), fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// TAP RECOGNIZER HOLDER (keeps GestureRecognizer alive for RichText spans)
// ============================================================================

class TapGestureDetectorHolder {
  static GestureRecognizer build(VoidCallback onTap) {
    return TapGestureRecognizer()..onTap = onTap;
  }
}

// ============================================================================
// POST MODEL
// ============================================================================

enum PostType {
  text,
  image,
  video,
  milestone,
}

class ChattaxPost {
  final String id;

  final String imageUrl;

  final List<String> videoUrls;

  final String caption;

  final String time;

  final int likes;

  final int comments;

  final int shares;

  final bool isReshared;

  final String authorName;

  final bool authorVerified;

  final DateTime timestamp;

  final PostType type;

  final String? milestoneValue;

  const ChattaxPost({
    this.id = '',
    this.imageUrl = '',
    this.videoUrls = const [],
    required this.caption,
    required this.time,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isReshared = false,
    this.authorName = 'User',
    this.authorVerified = false,
    required this.timestamp,
    this.type = PostType.text,
    this.milestoneValue,
  });

  // ==========================================================================
  // FIRESTORE
  // ==========================================================================

  factory ChattaxPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool reshared = false,
  }) {
    final data = doc.data() ?? <String, dynamic>{};

    // ------------------------------------------------------------------------
    // TIMESTAMP
    // ------------------------------------------------------------------------

    final rawTimestamp =
        data['createdAt'] ??
        data['timestamp'] ??
        data['created_at'];

    DateTime timestamp;

    if (rawTimestamp is Timestamp) {
      timestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      timestamp = rawTimestamp;
    } else {
      timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }

    // ------------------------------------------------------------------------
    // IMAGE
    // ------------------------------------------------------------------------

    final imageUrl = _firstString(
      data,
      [
        'imageUrl',
        'image',
        'attachmentUrl',
      ],
    );

    // ------------------------------------------------------------------------
    // VIDEOS
    // ------------------------------------------------------------------------

    final List<String> videoUrls =
        _extractUrls(
          data['videoUrls'],
        );

    // ------------------------------------------------------------------------
    // BACKWARD COMPATIBILITY
    // ------------------------------------------------------------------------

    final String singleVideoUrl =
        _firstString(
          data,
          [
            'videoUrl',
            'video',
          ],
        );

    if (singleVideoUrl.isNotEmpty &&
        !videoUrls.contains(singleVideoUrl)) {
      videoUrls.add(singleVideoUrl);
    }

    // ------------------------------------------------------------------------
    // AUTHOR
    // ------------------------------------------------------------------------

    final authorName = _firstString(
      data,
      [
        'authorName',
        'displayName',
        'name',
      ],
    );

    // ------------------------------------------------------------------------
    // POST TYPE
    // ------------------------------------------------------------------------

    PostType type = PostType.text;

    if (videoUrls.isNotEmpty) {
      type = PostType.video;
    } else if (imageUrl.isNotEmpty) {
      type = PostType.image;
    }

    // ------------------------------------------------------------------------
    // RETURN
    // ------------------------------------------------------------------------

    return ChattaxPost(
      id: doc.id,
      imageUrl: imageUrl,
      videoUrls: List.unmodifiable(videoUrls),
      caption: _firstString(
        data,
        [
          'caption',
          'text',
          'content',
          'message',
        ],
      ),
      time: _postTime(timestamp),
      likes: _firstNumber(
        data,
        [
          'likes',
          'likesCount',
          'likeCount',
        ],
      ),
      comments: _firstNumber(
        data,
        [
          'comments',
          'commentsCount',
          'commentCount',
        ],
      ),
      shares: _firstNumber(
        data,
        [
          'shares',
          'sharesCount',
          'shareCount',
          'reshares',
        ],
      ),
      isReshared: reshared,
      authorName:
          authorName.isEmpty
              ? 'User'
              : authorName,
      authorVerified: _firstBool(
        data,
        [
          'authorVerified',
          'isVerified',
          'verified',
        ],
      ),
      timestamp: timestamp,
      type: type,
    );
  }

  // ==========================================================================
  // EXTRACT URL LIST
  // ==========================================================================

  static List<String> _extractUrls(dynamic value) {
    final urls = <String>[];

    if (value is List) {
      for (final item in value) {
        if (item is String &&
            item.trim().isNotEmpty) {
          urls.add(item.trim());
        }
      }
    } else if (value is String &&
        value.trim().isNotEmpty) {
      urls.add(value.trim());
    }

    return urls;
  }

  // ==========================================================================
  // STRING
  // ==========================================================================

  static String _firstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  // ==========================================================================
  // NUMBER
  // ==========================================================================

  static int _firstNumber(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      if (value is String) {
        final parsed = int.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }

      if (value is List) {
        return value.length;
      }
    }

    return 0;
  }

  // ==========================================================================
  // BOOL
  // ==========================================================================

  static bool _firstBool(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is bool) {
        return value;
      }

      if (value is String) {
        return value.toLowerCase() == 'true';
      }
    }

    return false;
  }

  // ==========================================================================
  // POST TIME
  // ==========================================================================

  static String _postTime(DateTime date) {
    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
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
}

// ============================================================================
// SEARCH DELEGATE
// ============================================================================

class ProfileSearchDelegate extends SearchDelegate<String> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFF02050D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF050A16),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF7E8799)),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _empty();

  @override
  Widget buildSuggestions(BuildContext context) => _empty();

  Widget _empty() {
    return const Center(
      child: Text('Search this profile', style: TextStyle(color: Color(0xFF7E8799))),
    );
  }
}

// ============================================================================
// COVER PAINTER
// ============================================================================

class CoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF9B00FF).withValues(alpha: 0.07);

    for (double x = -size.height; x < size.width; x += 45) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), linePaint);
    }

    final purpleGlow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x339B00FF), Colors.transparent])
          .createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.45),
          radius: size.height,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.45),
      size.height,
      purpleGlow,
    );

    final blueGlow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x2600B9FF), Colors.transparent])
          .createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.12, size.height * 0.75),
          radius: size.height * 0.8,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.75),
      size.height * 0.8,
      blueGlow,
    );
  }

  @override
  bool shouldRepaint(covariant CoverPainter oldDelegate) => false;
}
// ============================================================================
// CHATTªX — PROFILE VIDEO PLAYER
// ============================================================================

class _ProfileVideoPlayer extends StatefulWidget {
  const _ProfileVideoPlayer({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<_ProfileVideoPlayer> createState() =>
      _ProfileVideoPlayerState();
}

class _ProfileVideoPlayerState
    extends State<_ProfileVideoPlayer> {
  VideoPlayerController? _controller;

  bool _loading = true;
  bool _hasError = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(0);

      setState(() {
        _loading = false;
      });
    } catch (error) {
      debugPrint(
        'CHATTªX PROFILE VIDEO ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleVideo() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_loading) {
      return Container(
        width: double.infinity,
        height: 220,
        color: const Color(0xFF080D18),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF7B2FFF),
          ),
        ),
      );
    }

    if (_hasError ||
        controller == null ||
        !controller.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: 220,
        color: const Color(0xFF080D18),
        child: const Center(
          child: Icon(
            Icons.video_library_outlined,
            color: Color(0xFF7B2FFF),
            size: 45,
          ),
        ),
      );
    }

    final aspectRatio =
        controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });

        _toggleVideo();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),

          // ================================================================
          // PLAY / PAUSE
          // ================================================================

          if (_showControls ||
              !controller.value.isPlaying)
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(
                  alpha: 0.62,
                ),
                border: Border.all(
                  color: const Color(0xFF7B2FFF)
                      .withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              child: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),

          // ================================================================
          // MUTED INDICATOR
          // ================================================================

          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.65,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volume_off_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}