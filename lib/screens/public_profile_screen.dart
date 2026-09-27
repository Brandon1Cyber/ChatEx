import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/verified_name.dart';

// ============================================================================
// CHATTªX PROFILE COLORS
// ============================================================================

const Color background = Color(0xFF030309);
const Color card = Color(0xFF0A0A18);
const Color cardDark = Color(0xFF070711);
const Color border = Color(0xFF19152D);

const Color neonPurple = Color(0xFF7B2FFF);
const Color neonBlue = Color(0xFF00C8FF);

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    this.userId,
    this.name = 'User',
    this.username = '',
    this.profileImage,
    this.coverImage,
    this.verified = false,
    this.online = false,
    this.followers = 0,
    this.following = 0,
  });

  final String? userId;
  final String name;
  final String username;
  final String? profileImage;
  final String? coverImage;
  final bool verified;
  final bool online;
  final int followers;
  final int following;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // FIREBASE
  // ==========================================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // ==========================================================================
  // STATE
  // ==========================================================================

  Map<String, dynamic>? _userData;

  bool _loadingProfile = true;
  bool _isFollowing = false;
  bool _followBusy = false;
  bool _bioExpanded = false;

  String selectedFilter = 'All posts';
  String selectedSort = 'Newest';

  // ==========================================================================
  // CURRENT USER / PROFILE
  // ==========================================================================

  User? get _currentUser => _auth.currentUser;

  String? get _profileUid => widget.userId ?? _currentUser?.uid;

  bool get _isMyProfile =>
      _profileUid != null && _profileUid == _currentUser?.uid;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

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

    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // LOAD PROFILE
  // ==========================================================================

  Future<void> _loadUser() async {
    final uid = _profileUid;

    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _userData = <String, dynamic>{};
        });
      }
      return;
    }

    try {
      final snapshot =
          await _firestore.collection('users').doc(uid).get();

      final data = snapshot.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _userData = data;
        _loadingProfile = false;
      });

      await _loadFollowState();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _userData = <String, dynamic>{};
        _loadingProfile = false;
      });
    }
  }

  // ==========================================================================
  // PROFILE STREAM
  // ==========================================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream() {
    final uid = _profileUid;

    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ==========================================================================
  // FOLLOW STATE
  // ==========================================================================

  Future<void> _loadFollowState() async {
    final currentUid = _currentUser?.uid;
    final profileUid = _profileUid;

    if (currentUid == null ||
        profileUid == null ||
        currentUid == profileUid) {
      return;
    }

    try {
      final followingDoc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(profileUid)
          .get();

      if (!mounted) return;

      setState(() {
        _isFollowing = followingDoc.exists;
      });
    } catch (_) {
      // Fallback to profile array if the subcollection is unavailable.
      final data = _userData ?? <String, dynamic>{};
      final followers = data['followers'];

      if (!mounted) return;

      if (followers is List) {
        setState(() {
          _isFollowing = followers.contains(currentUid);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = _currentUser?.uid;
    final profileUid = _profileUid;

    if (currentUid == null ||
        profileUid == null ||
        currentUid == profileUid ||
        _followBusy) {
      return;
    }

    setState(() {
      _followBusy = true;
    });

    final wasFollowing = _isFollowing;

    try {
      final currentUserRef =
          _firestore.collection('users').doc(currentUid);

      final profileRef =
          _firestore.collection('users').doc(profileUid);

      final followingRef = currentUserRef
          .collection('following')
          .doc(profileUid);

      final followerRef = profileRef
          .collection('followers')
          .doc(currentUid);

      final batch = _firestore.batch();

      if (wasFollowing) {
        batch.delete(followingRef);
        batch.delete(followerRef);

        batch.update(currentUserRef, {
          'following': FieldValue.arrayRemove([profileUid]),
          'followingCount': FieldValue.increment(-1),
        });

        batch.update(profileRef, {
          'followers': FieldValue.arrayRemove([currentUid]),
          'followersCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(followingRef, {
          'userId': profileUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(followerRef, {
          'userId': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.update(currentUserRef, {
          'following': FieldValue.arrayUnion([profileUid]),
          'followingCount': FieldValue.increment(1),
        });

        batch.update(profileRef, {
          'followers': FieldValue.arrayUnion([currentUid]),
          'followersCount': FieldValue.increment(1),
        });
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _isFollowing = !wasFollowing;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update follow status.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followBusy = false;
        });
      }
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child: CircularProgressIndicator(
            color: neonPurple,
            strokeWidth: 2,
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
              final data =
                  snapshot.data?.data() ?? _userData ?? <String, dynamic>{};

              if (snapshot.hasData) {
                _userData = data;
              }

              return SafeArea(
                top: false,
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _topHeader(data),
                    _profileHeader(data),
                    SliverToBoxAdapter(
                      child: _publicActions(),
                    ),
                    SliverToBoxAdapter(
                      child: _profileTabs(),
                    ),
                    SliverToBoxAdapter(
                      child: _filterBar(),
                    ),
                    _postsSliver(data),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            MediaQuery.of(context).padding.bottom + 40,
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

  // ==========================================================================
  // BACKGROUND
  // ==========================================================================

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

  // ==========================================================================
  // TOP HEADER
  // ==========================================================================

  SliverAppBar _topHeader(Map<String, dynamic> data) {
    final name = _displayName(data);

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
            _headerButton(
              Icons.arrow_back_ios_new_rounded,
              () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: VerifiedName(
                name: name.isEmpty ? 'Profile' : name,
                verified: _isVerified(data),
                fontSize: 17,
              ),
            ),
            _headerButton(
              Icons.search_rounded,
              _showSearch,
            ),
            _headerButton(
              Icons.more_horiz_rounded,
              _showProfileMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFILE HEADER
  // ==========================================================================

  SliverToBoxAdapter _profileHeader(
    Map<String, dynamic> data,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        decoration: BoxDecoration(
          color: card,
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
              padding: const EdgeInsets.fromLTRB(
                14,
                0,
                14,
                17,
              ),
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
                            padding:
                                const EdgeInsets.only(bottom: 4),
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

  // ==========================================================================
  // IDENTITY
  // ==========================================================================

  Widget _profileIdentity(
    Map<String, dynamic> data,
  ) {
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
              ? '@${_profileUid != null && _profileUid!.length >= 8 ? _profileUid!.substring(0, 8) : 'user'}'
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

  // ==========================================================================
  // COVER
  // ==========================================================================

  Widget _coverPhoto(
    Map<String, dynamic> data,
  ) {
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
                    errorBuilder: (_, _, _) {
                      return CustomPaint(
                        painter: CoverPainter(),
                        size: Size.infinite,
                      );
                    },
                  )
                : CustomPaint(
                    painter: CoverPainter(),
                    size: Size.infinite,
                  ),
          ),

          // ONLINE INDICATOR
          if (_isOnline(data))
            Positioned(
              left: 24,
              bottom: 48,
              child: Container(
                height: 31,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B18)
                      .withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: const Color(0xFF29E58C)
                        .withValues(alpha: 0.65),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Color(0xFF29E58C),
                      size: 8,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================

  Widget _profileAvatar(
    Map<String, dynamic> data,
  ) {
    final photoUrl = _profileImage(data);

    return Container(
      width: 102,
      height: 102,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            neonPurple,
            neonBlue,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
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
    );
  }

  Widget _defaultAvatar() {
    return const ColoredBox(
      color: Color(0xFF101828),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 45,
        ),
      ),
    );
  }

  // ==========================================================================
  // STATS
  // ==========================================================================

  Widget _stats(
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _stat(
            _formatNumber(_followersCount(data)),
            'Followers',
          ),
          _divider(),
          _stat(
            _formatNumber(_followingCount(data)),
            'Following',
          ),
          _divider(),
          _stat(
            _formatNumber(_postsCount(data)),
            'Posts',
          ),
          _divider(),
          _stat(
            _formatNumber(_resharedCount(data)),
            'Reshared',
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String value,
    String label,
  ) {
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 29,
      color: border,
    );
  }

  // ==========================================================================
  // BIO
  // ==========================================================================

  Widget _bio(
    Map<String, dynamic> data,
  ) {
    final bio = _stringValue(
      data,
      [
        'bio',
        'description',
        'about',
      ],
    );

    if (bio.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLong = bio.length > 60;

    final display = (!_bioExpanded && isLong)
        ? '${bio.substring(0, 60).trimRight()}…'
        : bio;

    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          children: [
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFC94A),
                  size: 15,
                ),
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
                recognizer:
                    TapGestureDetectorHolder.build(() {
                  setState(() {
                    _bioExpanded = !_bioExpanded;
                  });
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // INFO CHIPS
  // ==========================================================================

  Widget _infoChips(
    Map<String, dynamic> data,
  ) {
    final profession = _stringValue(
      data,
      [
        'profession',
        'job',
        'occupation',
      ],
    );

    final location = _stringValue(
      data,
      [
        'location',
        'city',
        'place',
      ],
    );

    final link = _stringValue(
      data,
      [
        'website',
        'link',
        'handle2',
      ],
    );

    final chips = <Widget>[];

    if (profession.isNotEmpty) {
      chips.add(
        _infoChip(
          Icons.work_outline_rounded,
          profession,
        ),
      );
    }

    if (location.isNotEmpty) {
      chips.add(
        _infoChip(
          Icons.location_on_outlined,
          location,
        ),
      );
    }

    if (link.isNotEmpty) {
      chips.add(
        _infoChip(
          Icons.link_rounded,
          link,
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: 7),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
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
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 140,
            ),
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

  // ==========================================================================
  // PUBLIC ACTIONS
  // ==========================================================================

  Widget _publicActions() {
    if (_isMyProfile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: _publicActionButton(
          Icons.person_outline_rounded,
          'This is your profile',
          enabled: false,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _publicActionButton(
              _isFollowing
                  ? Icons.person_remove_alt_1_rounded
                  : Icons.person_add_alt_1_rounded,
              _isFollowing ? 'Following' : 'Follow',
              onTap: _toggleFollow,
              busy: _followBusy,
              primary: !_isFollowing,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 5,
            child: _publicActionButton(
              Icons.chat_bubble_outline_rounded,
              'Message',
              onTap: _openMessage,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: neonPurple.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicActionButton(
    IconData icon,
    String text, {
    VoidCallback? onTap,
    bool busy = false,
    bool primary = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [
                    neonPurple,
                    Color(0xFF5C35E8),
                  ],
                )
              : null,
          color: primary ? null : card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary
                ? neonPurple
                : neonPurple.withValues(alpha: 0.45),
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: neonPurple.withValues(alpha: 0.18),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: primary
                          ? Colors.white
                          : neonBlue,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primary
                              ? Colors.white
                              : const Color(0xFFE9E7FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TABS
  // ==========================================================================

  Widget _profileTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: cardDark,
        border: Border(
          top: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: neonPurple,
        indicatorWeight: 3,
        labelColor: neonPurple,
        unselectedLabelColor: Color(0xFF8791A5),
        isScrollable: false,
        labelPadding: EdgeInsets.symmetric(horizontal: 4),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Photos'),
          Tab(text: 'Videos'),
        ],
      ),
    );
  }

  // ==========================================================================
  // FILTER BAR
  // ==========================================================================

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        6,
        10,
        6,
        3,
      ),
      child: Row(
        children: [
          _filterButton(
            selectedFilter,
            _showFilterMenu,
          ),
          const Spacer(),
          _filterButton(
            selectedSort,
            _showSortMenu,
          ),
        ],
      ),
    );
  }

  Widget _filterButton(
    String text,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
        ),
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
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // POSTS SLIVER
  // ==========================================================================

  Widget _postsSliver(
    Map<String, dynamic> profileData,
  ) {
    final uid = _profileUid;

    if (uid == null || uid.isEmpty) {
      return SliverToBoxAdapter(
        child: _emptyState(
          title: 'Profile unavailable',
          subtitle: 'This profile could not be loaded.',
        ),
      );
    }

    switch (_tabController.index) {
      case 1:
        return _photosSliver(uid);

      case 2:
        return _videosSliver(uid);

      default:
        return _postsOnlySliver(
          uid,
          profileData,
        );
    }
  }

  // ==========================================================================
  // REAL USER POSTS
  // ==========================================================================

  Widget _postsOnlySliver(
    String uid,
    Map<String, dynamic> profileData,
  ) {
    final query = _firestore
        .collection('posts')
        .where('authorId', isEqualTo: uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'Could not load posts',
              subtitle:
                  'There was a problem loading this profile.',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          final data = doc.data();

          final status =
              data['status']?.toString().toLowerCase();

          final isPublished = data['isPublished'];

          final visibility =
              data['visibility']?.toString().toLowerCase();

          if (status == 'scheduled') return false;

          if (isPublished == false) return false;

          if (visibility == 'private') return false;

          return _matchesFilter(data);
        }).toList();

        filtered.sort((a, b) {
          final aDate = _postDate(a.data());
          final bDate = _postDate(b.data());

          switch (selectedSort) {
            case 'Oldest':
              return aDate.compareTo(bDate);

            case 'Most liked':
              return _intValue(b.data()['likeCount'])
                  .compareTo(
                _intValue(a.data()['likeCount']),
              );

            case 'Most commented':
              return _intValue(
                b.data()['commentCount'],
              ).compareTo(
                _intValue(
                  a.data()['commentCount'],
                ),
              );

            case 'Most reshared':
              return _intValue(
                b.data()['shareCount'],
              ).compareTo(
                _intValue(
                  a.data()['shareCount'],
                ),
              );

            default:
              return bDate.compareTo(aDate);
          }
        });

        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'Nothing here yet',
              subtitle:
                  'Posts from this profile will appear here.',
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = filtered[index];

              return _PublicProfilePostCard(
                key: ValueKey(doc.id),
                postId: doc.id,
                data: doc.data(),
                currentUid: _currentUser?.uid,
                profileData: profileData,
                onMessage: _showMessage,
                onPostMenu: () {
                  _showPostMenu(
                    doc.id,
                    doc.data(),
                  );
                },
              );
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PHOTOS
  // ==========================================================================

  Widget _photosSliver(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final images = <String>[];

        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data();

          if (!_isPublishedPost(data)) continue;

          final urls = _stringList(data['imageUrls']);

          if (urls.isNotEmpty) {
            images.addAll(urls);
          } else {
            final single = _readString(
              data['imageUrl'],
            );

            if (single != null) {
              images.add(single);
            }
          }
        }

        if (images.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'No photos yet',
              subtitle:
                  'Photos posted by this user will appear here.',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            5,
            7,
            5,
            10,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _mediaTile(
                  images[index],
                  isVideo: false,
                );
              },
              childCount: images.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // VIDEOS
  // ==========================================================================

  Widget _videosSliver(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingSliver();
        }

        final videos = <String>[];

        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data();

          if (!_isPublishedPost(data)) continue;

          final urls = _stringList(data['videoUrls']);

          if (urls.isNotEmpty) {
            videos.addAll(urls);
          } else {
            final single = _readString(
              data['videoUrl'],
            );

            if (single != null) {
              videos.add(single);
            }
          }
        }

        if (videos.isEmpty) {
          return SliverToBoxAdapter(
            child: _emptyState(
              title: 'No videos yet',
              subtitle:
                  'Videos posted by this user will appear here.',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            5,
            7,
            5,
            10,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _mediaTile(
                  videos[index],
                  isVideo: true,
                );
              },
              childCount: videos.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
          ),
        );
      },
    );
  }

  Widget _mediaTile(
    String url, {
    required bool isVideo,
  }) {
    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _VideoViewer(
                videoUrl: url,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ImageViewer(
                imageUrl: url,
              ),
            ),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(
                color: const Color(0xFF0D1324),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: neonPurple,
                  size: 28,
                ),
              );
            },
          ),
          if (isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOADING
  // ==========================================================================

  Widget _loadingSliver() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: 45),
        child: Center(
          child: CircularProgressIndicator(
            color: neonPurple,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FILTER MATCHING
  // ==========================================================================

  bool _matchesFilter(
    Map<String, dynamic> data,
  ) {
    switch (selectedFilter) {
      case 'Photos':
        return _hasImages(data);

      case 'Videos':
        return _hasVideos(data);

      case 'Text':
        return _readString(data['text']) != null &&
            !_hasImages(data) &&
            !_hasVideos(data);

      case 'Polls':
        return _readString(data['pollQuestion']) != null;

      case 'Events':
        return _readString(data['eventTitle']) != null;

      default:
        return true;
    }
  }

  // ==========================================================================
  // EMPTY STATE
  // ==========================================================================

  Widget _emptyState({
    String title = 'Nothing here yet',
    String subtitle = 'Content will appear here.',
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
                border: Border.all(
                  color: neonPurple,
                ),
              ),
              child: const Icon(
                Icons.layers_outlined,
                color: neonPurple,
                size: 29,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7E8799),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFILE DATA HELPERS
  // ==========================================================================

  String _displayName(
    Map<String, dynamic> data,
  ) {
    final value = _stringValue(
      data,
      [
        'displayName',
        'name',
        'fullName',
      ],
    );

    if (value.isNotEmpty) return value;

    if (widget.name.trim().isNotEmpty &&
        widget.name != 'User') {
      return widget.name.trim();
    }

    return 'User';
  }

  String _username(
    Map<String, dynamic> data,
  ) {
    final value = _stringValue(
      data,
      [
        'username',
        'userName',
        'handle',
      ],
    );

    if (value.isNotEmpty) return value;

    return widget.username.trim();
  }

  String _profileImage(
    Map<String, dynamic> data,
  ) {
    final value = _stringValue(
      data,
      [
        'photoUrl',
        'profilePhoto',
        'profileImage',
        'profileImageUrl',
        'photoURL',
        'avatarUrl',
        'avatar',
      ],
    );

    if (value.isNotEmpty) return value;

    return widget.profileImage?.trim() ?? '';
  }

  String _coverImage(
    Map<String, dynamic> data,
  ) {
    final value = _stringValue(
      data,
      [
        'coverPhoto',
        'coverImage',
        'coverImageUrl',
        'coverPhotoUrl',
        'bannerUrl',
      ],
    );

    if (value.isNotEmpty) return value;

    return widget.coverImage?.trim() ?? '';
  }

  // IMPORTANT:
  // Public profile verification comes from the real users document.
  bool _isVerified(
    Map<String, dynamic> data,
  ) {
    return data['verified'] == true;
  }

  bool _isOnline(
    Map<String, dynamic> data,
  ) {
    if (data['isOnline'] == true) return true;
    if (data['online'] == true) return true;
    return widget.online;
  }

  int _followersCount(
    Map<String, dynamic> data,
  ) {
    return _numberValue(
      data,
      [
        'followersCount',
        'followerCount',
        'followers',
      ],
      fallback: widget.followers,
    );
  }

  int _followingCount(
    Map<String, dynamic> data,
  ) {
    return _numberValue(
      data,
      [
        'followingCount',
        'following',
      ],
      fallback: widget.following,
    );
  }

  int _postsCount(
    Map<String, dynamic> data,
  ) {
    final stored = _numberValue(
      data,
      [
        'postsCount',
        'postCount',
      ],
    );

    if (stored > 0) return stored;

    return 0;
  }

  int _resharedCount(
    Map<String, dynamic> data,
  ) {
    return _numberValue(
      data,
      [
        'resharedCount',
        'reshares',
        'reshared',
        'reposts',
      ],
    );
  }

  String _stringValue(
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

  int _numberValue(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) return value;

      if (value is num) return value.toInt();

      if (value is String) {
        final parsed = int.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }

      if (value is List) {
        return value.length;
      }

      if (value is Map) {
        return value.length;
      }
    }

    return fallback;
  }

  // ==========================================================================
  // POST HELPERS
  // ==========================================================================

  bool _isPublishedPost(
    Map<String, dynamic> data,
  ) {
    final status =
        data['status']?.toString().toLowerCase();

    final visibility =
        data['visibility']?.toString().toLowerCase();

    if (status == 'scheduled') return false;

    if (data['isPublished'] == false) return false;

    if (visibility == 'private') return false;

    return true;
  }

  bool _hasImages(
    Map<String, dynamic> data,
  ) {
    final urls = _stringList(data['imageUrls']);

    if (urls.isNotEmpty) return true;

    return _readString(data['imageUrl']) != null;
  }

  bool _hasVideos(
    Map<String, dynamic> data,
  ) {
    final urls = _stringList(data['videoUrls']);

    if (urls.isNotEmpty) return true;

    return _readString(data['videoUrl']) != null;
  }

  List<String> _stringList(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  String? _readString(
    dynamic value,
  ) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  DateTime _postDate(
    Map<String, dynamic> data,
  ) {
    final value =
        data['createdAt'] ??
        data['timestamp'] ??
        data['created_at'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _intValue(
    dynamic value,
  ) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _formatNumber(
    int number,
  ) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      final value = number / 1000;

      if (value == value.roundToDouble()) {
        return '${value.toInt()}K';
      }

      return '${value.toStringAsFixed(1)}K';
    }

    return number.toString();
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _showSearch() {
    showSearch(
      context: context,
      delegate: ProfileSearchDelegate(
        profileName: _displayName(
          _userData ?? <String, dynamic>{},
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFILE MENU
  // ==========================================================================

  void _showProfileMenu() {
    final isMine = _isMyProfile;

    _showSheet(
      isMine ? 'Profile options' : 'Profile options',
      [
        _sheetItem(
          Icons.share_rounded,
          'Share profile',
          _shareProfile,
        ),
        _sheetItem(
          Icons.qr_code_rounded,
          'View QR',
          () {
            _showMessage('QR profile sharing coming next.');
          },
        ),
        if (!isMine)
          _sheetItem(
            Icons.notifications_none_rounded,
            'Profile notifications',
            () {
              _showMessage(
                'Profile notifications coming next.',
              );
            },
          ),
        if (!isMine)
          _sheetItem(
            Icons.block_outlined,
            'Block user',
            _confirmBlock,
            danger: true,
          ),
        if (!isMine)
          _sheetItem(
            Icons.flag_outlined,
            'Report profile',
            _reportProfile,
            danger: true,
          ),
      ],
    );
  }

  // ==========================================================================
  // POST MENU
  // ==========================================================================

  void _showPostMenu(
    String postId,
    Map<String, dynamic> data,
  ) {
    final currentUid = _currentUser?.uid;

    final authorId =
        (data['authorId'] ??
                data['userId'] ??
                data['ownerId'])
            ?.toString();

    final isOwner =
        currentUid != null &&
        authorId == currentUid;

    _showSheet(
      'Post options',
      [
        _sheetItem(
          Icons.bookmark_border_rounded,
          'Save post',
          () => _savePostFromMenu(postId),
        ),
        _sheetItem(
          Icons.link_rounded,
          'Copy link',
          () => _copyPostLink(postId),
        ),
        if (isOwner)
          _sheetItem(
            Icons.push_pin_outlined,
            'Pin to profile',
            () => _showMessage(
              'Pin to profile coming next.',
            ),
          ),
        if (!isOwner)
          _sheetItem(
            Icons.flag_outlined,
            'Report post',
            () => _reportPost(postId),
            danger: true,
          ),
        if (isOwner)
          _sheetItem(
            Icons.delete_outline_rounded,
            'Delete post',
            () => _confirmDeletePost(postId),
            danger: true,
          ),
      ],
    );
  }

  // ==========================================================================
  // GENERIC SHEET
  // ==========================================================================

  void _showSheet(
    String title,
    List<Widget> children,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(27),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF384258),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 17),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
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
          color: danger
              ? const Color(0xFF3A0812)
              : const Color(0xFF0B1323),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: danger
              ? const Color(0xFFFF3D63)
              : Colors.white,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: danger
              ? const Color(0xFFFF3D63)
              : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF677289),
      ),
    );
  }

  // ==========================================================================
  // FILTER MENUS
  // ==========================================================================

  void _showFilterMenu() {
    _choiceSheet(
      'Post filter',
      [
        'All posts',
        'Photos',
        'Videos',
        'Text',
        'Polls',
        'Events',
      ],
      (value) {
        if (!mounted) return;

        setState(() {
          selectedFilter = value;
        });
      },
    );
  }

  void _showSortMenu() {
    _choiceSheet(
      'Sort posts',
      [
        'Newest',
        'Oldest',
        'Most liked',
        'Most commented',
        'Most reshared',
      ],
      (value) {
        if (!mounted) return;

        setState(() {
          selectedSort = value;
        });
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              17,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF384258),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map(
                  (option) {
                    final selected =
                        option == selectedFilter ||
                            option == selectedSort;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        callback(option);
                      },
                      title: Text(
                        option,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: neonPurple,
                            )
                          : null,
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
  // MESSAGE
  // ==========================================================================

  void _openMessage() {
    if (_profileUid == null) return;

    _showMessage(
      'Opening chat with ${_displayName(_userData ?? {})}...',
    );

    // Connect this to your existing ChatScreen navigation.
    //
    // Example:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => ChatScreen(
    //       otherUserId: _profileUid!,
    //     ),
    //   ),
    // );
  }

  // ==========================================================================
  // PROFILE SHARING
  // ==========================================================================

  Future<void> _shareProfile() async {
    final uid = _profileUid;

    if (uid == null) return;

    final link = 'https://chattax.app/profile/$uid';

    await Clipboard.setData(
      ClipboardData(text: link),
    );

    if (!mounted) return;

    _showMessage(
      'Profile link copied.',
    );
  }

  // ==========================================================================
  // POST ACTIONS
  // ==========================================================================

  Future<void> _savePostFromMenu(
    String postId,
  ) async {
    final uid = _currentUser?.uid;

    if (uid == null) {
      _showMessage('Please sign in first.');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('savedPosts')
          .doc(postId)
          .set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Post saved.');
    } catch (_) {
      _showMessage('Could not save post.');
    }
  }

  Future<void> _copyPostLink(
    String postId,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: 'https://chattax.app/post/$postId',
      ),
    );

    _showMessage('Post link copied.');
  }

  Future<void> _reportPost(
    String postId,
  ) async {
    final uid = _currentUser?.uid;

    if (uid == null) return;

    try {
      await _firestore.collection('post_reports').add({
        'postId': postId,
        'reporterId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Post reported.');
    } catch (_) {
      _showMessage('Could not report post.');
    }
  }

  Future<void> _reportProfile() async {
    final uid = _currentUser?.uid;
    final profileUid = _profileUid;

    if (uid == null || profileUid == null) return;

    try {
      await _firestore.collection('profile_reports').add({
        'profileId': profileUid,
        'reporterId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Profile reported.');
    } catch (_) {
      _showMessage('Could not report profile.');
    }
  }

  void _confirmBlock() {
    final profileUid = _profileUid;

    if (profileUid == null) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF090F1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Block this user?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'You will no longer see this user in normal ChattªX interactions.',
            style: TextStyle(
              color: Color(0xFF9BA5B8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                final uid = _currentUser?.uid;

                if (uid == null) return;

                try {
                  await _firestore
                      .collection('users')
                      .doc(uid)
                      .collection('blocked')
                      .doc(profileUid)
                      .set({
                    'userId': profileUid,
                    'createdAt':
                        FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;

                  _showMessage('User blocked.');
                } catch (_) {
                  if (!mounted) return;

                  _showMessage(
                    'Could not block user.',
                  );
                }
              },
              child: const Text(
                'Block',
                style: TextStyle(
                  color: Color(0xFFFF3D63),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  void _confirmDeletePost(
    String postId,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF090F1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete post?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This post will be permanently removed from ChattªX.',
            style: TextStyle(
              color: Color(0xFF9BA5B8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  await _firestore
                      .collection('posts')
                      .doc(postId)
                      .delete();

                  if (!mounted) return;

                  _showMessage('Post deleted.');
                } catch (_) {
                  if (!mounted) return;

                  _showMessage(
                    'Could not delete post.',
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFFF3D63),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // SEARCH / MESSAGE FEEDBACK
  // ==========================================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(
            milliseconds: 1400,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF101827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

// ============================================================================
// PUBLIC PROFILE POST CARD
// ============================================================================

class _PublicProfilePostCard extends StatefulWidget {
  const _PublicProfilePostCard({
    super.key,
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.profileData,
    required this.onMessage,
    required this.onPostMenu,
  });

  final String postId;
  final Map<String, dynamic> data;
  final String? currentUid;
  final Map<String, dynamic> profileData;
  final void Function(String message) onMessage;
  final VoidCallback onPostMenu;

  @override
  State<_PublicProfilePostCard> createState() =>
      _PublicProfilePostCardState();
}

class _PublicProfilePostCardState
    extends State<_PublicProfilePostCard> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _liked = false;
  bool _saved = false;

  bool _busyLike = false;
  bool _busySave = false;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final uid = widget.currentUid;

    if (uid == null) return;

    try {
      final reaction = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('reactions')
          .doc(uid)
          .get();

      final saved = await _firestore
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
    } catch (_) {}
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _string(
    String key, {
    String fallback = '',
  }) {
    final value = widget.data[key];

    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  int _int(
    String key,
  ) {
    final value = widget.data[key];

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  bool _bool(
    String key,
  ) {
    return widget.data[key] == true;
  }

  List<String> _stringList(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  String? _readString(
    dynamic value,
  ) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final text = _string('text');

    final name = _string(
      'displayName',
      fallback: _string(
        'name',
        fallback: 'User',
      ),
    );

    final photo = _string(
      'photoUrl',
      fallback: _string(
        'photoURL',
      ),
    );

    final verified =
        widget.profileData['verified'] == true;

    final imageUrls =
        _stringList(widget.data['imageUrls']);

    final videoUrls =
        _stringList(widget.data['videoUrls']);

    if (imageUrls.isEmpty) {
      final single =
          _readString(widget.data['imageUrl']);

      if (single != null) {
        imageUrls.add(single);
      }
    }

    if (videoUrls.isEmpty) {
      final single =
          _readString(widget.data['videoUrl']);

      if (single != null) {
        videoUrls.add(single);
      }
    }

    final likeCount = _int('likeCount');
    final commentCount = _int('commentCount');
    final shareCount = _int('shareCount');

    final isReshare = _bool('isReshare');

    final originalName = _string(
      'originalAuthorName',
      fallback: 'User',
    );

    final originalPhoto =
        _string('originalAuthorPhoto');

    final originalVerified =
        _bool('originalAuthorVerified');

    return Container(
      margin: const EdgeInsets.fromLTRB(
        4,
        5,
        4,
        10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF19152D)
              .withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.28,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // --------------------------------------------------------------
          // HEADER
          // --------------------------------------------------------------

          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              11,
              7,
              8,
            ),
            child: Row(
              children: [
                _avatar(
                  photo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      VerifiedName(
                        name: name,
                        verified: verified,
                        fontSize: 13,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _timeText(),
                            style: const TextStyle(
                              color:
                                  Color(0xFF8D97AA),
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.public_rounded,
                            color:
                                Color(0xFF8D97AA),
                            size: 11,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      widget.onPostMenu,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color:
                        Color(0xFFB9C1D0),
                  ),
                ),
              ],
            ),
          ),

          // --------------------------------------------------------------
          // RESHARE
          // --------------------------------------------------------------

          if (isReshare)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                0,
                12,
                8,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF0D1324),
                  borderRadius:
                      BorderRadius.circular(15),
                  border: Border.all(
                    color:
                        const Color(0xFF18243A),
                  ),
                ),
                child: Row(
                  children: [
                    _avatar(
                      originalPhoto,
                      size: 38,
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.repeat_rounded,
                      color: neonBlue,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Original post',
                      style: TextStyle(
                        color: neonBlue,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: VerifiedName(
                        name: originalName,
                        verified:
                            originalVerified,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // --------------------------------------------------------------
          // TEXT
          // --------------------------------------------------------------

          if (text.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                13,
                2,
                13,
                11,
              ),
              child: _captionWithHashtag(
                text,
              ),
            ),

          // --------------------------------------------------------------
          // POLL
          // --------------------------------------------------------------

          _buildPoll(),

          // --------------------------------------------------------------
          // EVENT
          // --------------------------------------------------------------

          _buildEvent(),

          // --------------------------------------------------------------
          // MEDIA
          // --------------------------------------------------------------

          if (imageUrls.isNotEmpty)
            ...imageUrls.map(
              (url) => _image(
                url,
              ),
            ),

          if (videoUrls.isNotEmpty)
            ...videoUrls.map(
              (url) => _video(
                url,
              ),
            ),

          // --------------------------------------------------------------
          // GIF
          // --------------------------------------------------------------

          _buildGif(),

          // --------------------------------------------------------------
          // ENGAGEMENT SUMMARY
          // --------------------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              13,
              9,
              13,
              8,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color:
                      Color(0xFFFF315C),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatNumber(likeCount),
                  style: const TextStyle(
                    color:
                        Color(0xFFB8C1D1),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$commentCount Comments',
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        Color(0xFFB8C1D1),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$shareCount Shares',
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        Color(0xFFB8C1D1),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFF19152D),
          ),

          // --------------------------------------------------------------
          // ACTIONS
          // --------------------------------------------------------------

          SizedBox(
            height: 46,
            child: Row(
              children: [
                _postAction(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: 'Like',
                  color: _liked
                      ? const Color(0xFFFF315C)
                      : const Color(0xFFB8C1D1),
                  onTap: _toggleReaction,
                  busy: _busyLike,
                ),
                _postAction(
                  icon:
                      Icons.chat_bubble_outline_rounded,
                  label: 'Comment',
                  color:
                      const Color(0xFFB8C1D1),
                  onTap: _showComments,
                ),
                _postAction(
                  icon: Icons.send_rounded,
                  label: 'Share',
                  color:
                      const Color(0xFFB8C1D1),
                  onTap: _sharePost,
                ),
                _postAction(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: 'Save',
                  color: _saved
                      ? neonBlue
                      : const Color(0xFFB8C1D1),
                  onTap: _toggleSave,
                  busy: _busySave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================

  Widget _avatar(
    String photo, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            neonPurple,
            neonBlue,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: photo.isNotEmpty
              ? Image.network(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _defaultAvatar(),
                )
              : _defaultAvatar(),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return const ColoredBox(
      color: Color(0xFF101828),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }

  // ==========================================================================
  // IMAGE
  // ==========================================================================

  Widget _image(
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder:
                (context, child, progress) {
              if (progress == null) {
                return child;
              }

              return Container(
                color:
                    const Color(0xFF0D1324),
                child: const Center(
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: neonPurple,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) {
              return Container(
                color:
                    const Color(0xFF0D1324),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: neonPurple,
                    size: 45,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // VIDEO
  // ==========================================================================

  Widget _video(
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _VideoViewer(
                videoUrl: url,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(15),
          child: Container(
            height: 300,
            color:
                const Color(0xFF0D1324),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // POLL
  // ==========================================================================

  Widget _buildPoll() {
    final question = _readString(
      widget.data['pollQuestion'],
    );

    final options =
        _stringList(widget.data['pollOptions']);

    if (question == null ||
        options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1324),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                const Color(0xFF18243A),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...options.map(
              (option) {
                return Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF111A2D),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: neonPurple
                          .withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Text(
                    option,
                    style: const TextStyle(
                      color:
                          Color(0xFFD4D9E5),
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // EVENT
  // ==========================================================================

  Widget _buildEvent() {
    final title = _readString(
      widget.data['eventTitle'],
    );

    if (title == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF21104B),
              Color(0xFF09283A),
            ],
          ),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                neonPurple.withValues(
              alpha: 0.45,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_rounded,
              color: neonBlue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // GIF
  // ==========================================================================

  Widget _buildGif() {
    final gifUrl = _readString(
      widget.data['gifUrl'],
    );

    if (gifUrl == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8,
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(15),
        child: Image.network(
          gifUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return Container(
              height: 220,
              color:
                  const Color(0xFF0D1324),
              child: const Center(
                child: Icon(
                  Icons.gif_box_outlined,
                  color: neonPurple,
                  size: 45,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // TIME
  // ==========================================================================

  String _timeText() {
    final value =
        widget.data['createdAt'];

    if (value is Timestamp) {
      final date = value.toDate();
      final difference =
          DateTime.now().difference(date);

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

    return 'Just now';
  }

  // ==========================================================================
  // CAPTION
  // ==========================================================================

  Widget _captionWithHashtag(
    String caption,
  ) {
    final words = caption.split(' ');

    return RichText(
      text: TextSpan(
        children: words.map(
          (word) {
            final hashtag =
                word.startsWith('#');

            return TextSpan(
              text: '$word ',
              style: TextStyle(
                color: hashtag
                    ? neonPurple
                    : const Color(
                        0xFFE4E8F0,
                      ),
                fontSize: 13,
                fontWeight: hashtag
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ==========================================================================
  // ACTION BUTTON
  // ==========================================================================

  Widget _postAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            busy
                ? SizedBox(
                    width: 17,
                    height: 17,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 1.8,
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
                overflow:
                    TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color:
                      Color(0xFFB8C1D1),
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LIKE
  // ==========================================================================

  Future<void> _toggleReaction() async {
    final uid = widget.currentUid;

    if (uid == null || _busyLike) return;

    setState(() {
      _busyLike = true;
    });

    try {
      final postRef = _firestore
          .collection('posts')
          .doc(widget.postId);

      final reactionRef = postRef
          .collection('reactions')
          .doc(uid);

      final postSnapshot =
          await postRef.get();

      if (!postSnapshot.exists) return;

      final postData =
          postSnapshot.data() ??
              <String, dynamic>{};

      final ownerId =
          (postData['userId'] ??
                  postData['authorId'] ??
                  postData['ownerId'])
              ?.toString();

      final currentlyLiked =
          (await reactionRef.get()).exists;

      final currentLikes =
          _numberFrom(
        postData['likeCount'],
      );

      final batch = _firestore.batch();

      if (currentlyLiked) {
        batch.delete(reactionRef);

        batch.update(
          postRef,
          {
            'likeCount':
                currentLikes > 0
                    ? currentLikes - 1
                    : 0,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      } else {
        batch.set(
          reactionRef,
          {
            'userId': uid,
            'type': 'like',
            'createdAt':
                FieldValue.serverTimestamp(),
          },
        );

        batch.update(
          postRef,
          {
            'likeCount':
                currentLikes + 1,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        if (ownerId != null &&
            ownerId.isNotEmpty &&
            ownerId != uid) {
          batch.set(
            _firestore
                .collection(
                  'feed_notifications',
                )
                .doc(
                  '${widget.postId}_${uid}_like',
                ),
            {
              'recipientId': ownerId,
              'actorId': uid,
              'actorName':
                  _string(
                    'displayName',
                    fallback: 'User',
                  ),
              'actorPhoto':
                  _string('photoUrl'),
              'type': 'postLike',
              'targetType': 'post',
              'targetId': widget.postId,
              'postId': widget.postId,
              'message':
                  'liked your post',
              'isRead': false,
              'readAt': null,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _liked = !currentlyLiked;
      });
    } catch (_) {
      widget.onMessage(
        'Could not update reaction.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyLike = false;
        });
      }
    }
  }

  int _numberFrom(
    dynamic value,
  ) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  // ==========================================================================
  // SAVE
  // ==========================================================================

  Future<void> _toggleSave() async {
    final uid = widget.currentUid;

    if (uid == null || _busySave) return;

    setState(() {
      _busySave = true;
    });

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('savedPosts')
          .doc(widget.postId);

      final existing =
          await savedRef.get();

      if (existing.exists) {
        await savedRef.delete();

        if (mounted) {
          setState(() {
            _saved = false;
          });
        }

        widget.onMessage(
          'Removed from saved posts.',
        );
      } else {
        await savedRef.set({
          'postId': widget.postId,
          'savedAt':
              FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _saved = true;
          });
        }

        widget.onMessage(
          'Post saved.',
        );
      }
    } catch (_) {
      widget.onMessage(
        'Could not update saved post.',
      );
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
    final controller =
        TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor:
            const Color(0xFF070B17),
        shape:
            const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        builder: (_) {
          return _PublicCommentsSheet(
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
    await Clipboard.setData(
      ClipboardData(
        text:
            'https://chattax.app/post/${widget.postId}',
      ),
    );

    widget.onMessage(
      'Post link copied.',
    );
  }

  // ==========================================================================
  // NUMBER FORMAT
  // ==========================================================================

  String _formatNumber(
    int number,
  ) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      final value = number / 1000;

      if (value == value.roundToDouble()) {
        return '${value.toInt()}K';
      }

      return '${value.toStringAsFixed(1)}K';
    }

    return number.toString();
  }
}

// ============================================================================
// COMMENTS SHEET
// ============================================================================

class _PublicCommentsSheet extends StatefulWidget {
  const _PublicCommentsSheet({
    required this.postId,
    required this.controller,
  });

  final String postId;
  final TextEditingController controller;

  @override
  State<_PublicCommentsSheet> createState() =>
      _PublicCommentsSheetState();
}

class _PublicCommentsSheetState
    extends State<_PublicCommentsSheet> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _sending = false;

  Future<void> _sendComment() async {
    final uid = _auth.currentUser?.uid;
    final text =
        widget.controller.text.trim();

    if (uid == null ||
        text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      final userData =
          userDoc.data() ??
              <String, dynamic>{};

      final commentRef = _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      final postRef = _firestore
          .collection('posts')
          .doc(widget.postId);

      final batch = _firestore.batch();

      batch.set(
        commentRef,
        {
          'userId': uid,
          'authorId': uid,
          'displayName':
              userData['displayName'] ??
                  userData['name'] ??
                  'User',
          'photoUrl':
              userData['photoUrl'] ??
                  userData['photoURL'] ??
                  '',
          'text': text,
          'createdAt':
              FieldValue.serverTimestamp(),
          'likeCount': 0,
        },
      );

      batch.update(
        postRef,
        {
          'commentCount':
              FieldValue.increment(1),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      widget.controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Could not send comment.'),
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

  @override
  Widget build(BuildContext context) {
    final commentsStream = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy(
          'createdAt',
          descending: false,
        )
        .snapshots();

    return SizedBox(
      height:
          MediaQuery.of(context).size.height *
              0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF384258),
              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 15),
          const Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: commentsStream,
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: Color(0xFF7B2FFF),
                      strokeWidth: 2,
                    ),
                  );
                }

                final docs =
                    snapshot.data?.docs ??
                        [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet.',
                      style: TextStyle(
                        color:
                            Color(0xFF7E8799),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  itemCount: docs.length,
                  itemBuilder:
                      (context, index) {
                    final data =
                        docs[index].data();

                    final name =
                        data['displayName']
                                ?.toString() ??
                            data['name']
                                ?.toString() ??
                            'User';

                    final text =
                        data['text']
                                ?.toString() ??
                            '';

                    final photo =
                        data['photoUrl']
                                ?.toString() ??
                            data['photoURL']
                                ?.toString() ??
                            '';

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            padding:
                                const EdgeInsets.all(
                              2,
                            ),
                            decoration:
                                const BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              gradient:
                                  LinearGradient(
                                colors: [
                                  Color(0xFF7B2FFF),
                                  Color(0xFF00C8FF),
                                ],
                              ),
                            ),
                            child: ClipOval(
                              child:
                                  photo.isNotEmpty
                                      ? Image.network(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, _, _) =>
                                                  const ColoredBox(
                                            color:
                                                Color(0xFF101828),
                                            child:
                                                Icon(
                                              Icons.person,
                                              color:
                                                  Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : const ColoredBox(
                                          color:
                                              Color(0xFF101828),
                                          child:
                                              Icon(
                                            Icons.person,
                                            color:
                                                Colors.white,
                                            size: 20,
                                          ),
                                        ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.all(
                                11,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFF0D1324,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  15,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    text,
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(0xFFD4D9E5),
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding:
                EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8 +
                  MediaQuery.of(context)
                      .viewInsets
                      .bottom,
            ),
            decoration:
                const BoxDecoration(
              color: Color(0xFF090E1B),
              border: Border(
                top: BorderSide(
                  color: Color(0xFF18243A),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        widget.controller,
                    minLines: 1,
                    maxLines: 4,
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
                            Color(0xFF68748A),
                      ),
                      filled: true,
                      fillColor:
                          const Color(
                        0xFF0D1324,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    width: 43,
                    height: 43,
                    decoration:
                        const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          LinearGradient(
                        colors: [
                          Color(0xFF7B2FFF),
                          Color(0xFF00C8FF),
                        ],
                      ),
                    ),
                    child: _sending
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              12,
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
                            size: 18,
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
}

// ============================================================================
// IMAGE VIEWER
// ============================================================================

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// VIDEO VIEWER
// ============================================================================

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  State<_VideoViewer> createState() =>
      _VideoViewerState();
}

class _VideoViewerState
    extends State<_VideoViewer> {
  late final dynamic _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    // Video playback can be connected to your
    // existing video player service.
    //
    // The profile page intentionally keeps the
    // thumbnail-style post card lightweight.
    if (mounted) {
      setState(() {
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _ready
            ? Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 25,
                    ),
                    child: Text(
                      widget.videoUrl,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        color:
                            Color(0xFF7E8799),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(
                color: Color(0xFF7B2FFF),
              ),
      ),
    );
  }
}

// ============================================================================
// SEARCH DELEGATE
// ============================================================================

class ProfileSearchDelegate
    extends SearchDelegate<String> {
  ProfileSearchDelegate({
    this.profileName = 'Profile',
  });

  final String profileName;

  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor:
          const Color(0xFF02050D),
      appBarTheme:
          const AppBarTheme(
        backgroundColor:
            Color(0xFF050A16),
        foregroundColor:
            Colors.white,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Color(0xFF7E8799),
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
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
      ),
      onPressed: () =>
          close(context, ''),
    );
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return _empty();
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return _empty();
  }

  Widget _empty() {
    return Center(
      child: Text(
        query.isEmpty
            ? 'Search $profileName'
            : 'Search this profile',
        style: const TextStyle(
          color: Color(0xFF7E8799),
        ),
      ),
    );
  }
}

// ============================================================================
// TAP RECOGNIZER HOLDER
// ============================================================================

class TapGestureDetectorHolder {
  static GestureRecognizer build(
    VoidCallback onTap,
  ) {
    return TapGestureRecognizer()
      ..onTap = onTap;
  }
}

// ============================================================================
// COVER PAINTER
// ============================================================================

class CoverPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF9B00FF)
          .withValues(alpha: 0.07);

    for (
      double x = -size.height;
      x < size.width;
      x += 45
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(
          x + size.height,
          size.height,
        ),
        linePaint,
      );
    }

    final purpleGlow = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x339B00FF),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.78,
            size.height * 0.45,
          ),
          radius: size.height,
        ),
      );

    canvas.drawCircle(
      Offset(
        size.width * 0.78,
        size.height * 0.45,
      ),
      size.height,
      purpleGlow,
    );

    final blueGlow = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x2600B9FF),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.12,
            size.height * 0.75,
          ),
          radius: size.height * 0.8,
        ),
      );

    canvas.drawCircle(
      Offset(
        size.width * 0.12,
        size.height * 0.75,
      ),
      size.height * 0.8,
      blueGlow,
    );
  }

  @override
  bool shouldRepaint(
    covariant CoverPainter oldDelegate,
  ) {
    return false;
  }
}