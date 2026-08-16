import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';

import 'share_qr_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import 'birthdays_screen.dart';
import 'settings_screen.dart';
import 'live/go_live_screen.dart';
import 'new_friends_screen.dart';
import 'chat_screen.dart';

import '../services/chat_service.dart';
import '../services/chat_cache_service.dart';
import '../services/user_cache_service.dart';
import '../widgets/verified_name.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // SERVICES
  // ============================================================

  final ChatService _chatService = ChatService();

  final ChatCacheService _cacheService =
      ChatCacheService();

  final UserCacheService _userCache =
      UserCacheService();

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchDebounce;

  bool _isSearching = false;

  List<_SearchResult> _searchResults = [];

  // ============================================================
  // HOME STATE
  // ============================================================

  String selectedFilter = "All";
  String selectedActivity = "online";

  int allChatsCount = 0;
  int unreadChatsCount = 0;

  List<Map<String, dynamic>> cachedChats = [];

  bool cacheLoaded = false;

  // ============================================================
  // ONLINE
  // ============================================================

  String get myUid =>
      _auth.currentUser?.uid ?? "";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _setOnlineStatus(true);

    _loadCachedChats();

    _loadUserCache();
  }

  // ============================================================
  // USER CACHE
  // ============================================================

  Future<void> _loadUserCache() async {
    try {
      await _userCache.load();
    } catch (e) {
      debugPrint(
        "ChattªX user cache load error: $e",
      );
    }
  }

  // ============================================================
  // CHAT CACHE
  // ============================================================

  Future<void> _loadCachedChats() async {
    try {
      final chats = _cacheService.getChats();

      if (!mounted) return;

      setState(() {
        cachedChats =
            List<Map<String, dynamic>>.from(chats);

        cacheLoaded = true;
      });
    } catch (e) {
      debugPrint(
        "ChattªX chat cache load error: $e",
      );

      if (!mounted) return;

      setState(() {
        cachedChats = [];
        cacheLoaded = true;
      });
    }
  }

  Future<void> _saveChatsToCache(
    List<QueryDocumentSnapshot> chats,
  ) async {
    try {
      final List<Map<String, dynamic>> cache = [];

      for (final chat in chats) {
        final data =
            Map<String, dynamic>.from(
          chat.data() as Map<String, dynamic>,
        );

        cache.add(data);
      }

      await _cacheService.saveChats(cache);
    } catch (e) {
      debugPrint(
        "ChattªX save chat cache error: $e",
      );
    }
  }

  // ============================================================
  // ONLINE STATUS
  // ============================================================

  Future<void> _setOnlineStatus(bool online) async {
    if (myUid.isEmpty) return;

    try {
      await _firestore
          .collection("users")
          .doc(myUid)
          .set(
        {
          "isOnline": online,
          "lastSeen":
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        "ChattªX online status error: $e",
      );
    }
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _setOnlineStatus(false);

    _searchDebounce?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, "0");

    final period =
        date.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute $period";
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });

      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _performSearch(query);
      },
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    final String search =
        query.trim().toLowerCase();

    try {
      final Map<String, _SearchResult> results =
          {};

      // ========================================================
      // PEOPLE
      // ========================================================

      final usersSnapshot = await _firestore
          .collection("users")
          .limit(100)
          .get();

      for (final document in usersSnapshot.docs) {
        if (document.id == myUid) {
          continue;
        }

        final data = document.data();

        final String name =
            (data["name"] ?? "User").toString();

        final String username =
            (data["username"] ?? "").toString();

        final String email =
            (data["email"] ?? "").toString();

        final bool matches =
            name.toLowerCase().contains(search) ||
                username
                    .toLowerCase()
                    .contains(search) ||
                email
                    .toLowerCase()
                    .contains(search);

        if (!matches) {
          continue;
        }

        results[document.id] =
            _SearchResult(
          type: _SearchResultType.person,
          id: document.id,
          name: name,
          username: username,
          photoUrl:
              (data["photoUrl"] ?? "").toString(),
          online:
              data["isOnline"] == true,
          verified:
              data["verified"] == true,
          message: "",
          time: "",
        );
      }

      // ========================================================
      // CONVERSATIONS
      // ========================================================

      if (myUid.isNotEmpty) {
        try {
          final chatsSnapshot =
              await _firestore
                  .collection("chat_rooms")
                  .where(
                    "participants",
                    arrayContains: myUid,
                  )
                  .limit(100)
                  .get();

          for (final document
              in chatsSnapshot.docs) {
            final data = document.data();

            final participants =
                List<String>.from(
              data["participants"] ?? [],
            );

            final String receiverId =
                participants.firstWhere(
              (id) => id != myUid,
              orElse: () => "",
            );

            if (receiverId.isEmpty) {
              continue;
            }

            final String lastMessage =
                (data["lastMessage"] ?? "")
                    .toString();

            if (!lastMessage
                .toLowerCase()
                .contains(search)) {
              continue;
            }

            if (results.containsKey(receiverId)) {
              continue;
            }

            String name =
                (data["receiverName"] ?? "User")
                    .toString();

            String photo =
                (data["receiverPhoto"] ?? "")
                    .toString();

            bool online = false;
            bool verified = false;

            try {
              final userSnapshot =
                  await _firestore
                      .collection("users")
                      .doc(receiverId)
                      .get();

              if (userSnapshot.exists) {
                final user =
                    userSnapshot.data()!;

                name =
                    (user["name"] ?? name)
                        .toString();

                photo =
                    (user["photoUrl"] ?? photo)
                        .toString();

                online =
                    user["isOnline"] == true;

                verified =
                    user["verified"] == true;
              }
            } catch (_) {}

            String time = "";

            if (data["lastMessageTime"]
                is Timestamp) {
              time = _formatTime(
                data["lastMessageTime"],
              );
            }

            results[receiverId] =
                _SearchResult(
              type:
                  _SearchResultType
                      .conversation,
              id: receiverId,
              name: name,
              username: "",
              photoUrl: photo,
              online: online,
              verified: verified,
              message: lastMessage,
              time: time,
            );
          }
        } catch (e) {
          debugPrint(
            "ChattªX conversation search error: $e",
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _searchResults =
            results.values.toList();
      });
    } catch (e) {
      debugPrint(
        "ChattªX search error: $e",
      );

      if (!mounted) return;

      setState(() {
        _searchResults = [];
      });
    }
  }

  // ============================================================
  // CLEAR SEARCH
  // ============================================================

  void _clearSearch() {
    _searchController.clear();

    _searchDebounce?.cancel();

    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
  }

  // ============================================================
  // OPEN SEARCH RESULT
  // ============================================================

  void _openSearchResult(
    _SearchResult result,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: result.id,
          receiverName: result.name,
          receiverImage: result.photoUrl,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE PHOTO VIEWER
  // ============================================================

  void _openProfilePhoto({
    required String imageUrl,
    required String name,
    bool verified = false,
  }) {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration:
            const Duration(milliseconds: 220),
        reverseTransitionDuration:
            const Duration(milliseconds: 180),
        pageBuilder:
            (
          context,
          animation,
          secondaryAnimation,
        ) {
          return _ProfilePhotoViewer(
            imageUrl: imageUrl,
            name: name,
            verified: verified,
          );
        },
        transitionsBuilder:
            (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.96,
                end: 1.0,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery =
        MediaQuery.of(context);

    final screenWidth =
        mediaQuery.size.width;

    final double headerHeight =
        screenWidth < 360
            ? 148
            : screenWidth < 400
                ? 152
                : 156;

    return Scaffold(
      backgroundColor:
          const Color(0xFF050816),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                height: headerHeight,
                child: Container(
                  color:
                      const Color(0xFF050816),
                  padding:
                      const EdgeInsets.only(
                    top: 2,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 4),

                      _buildSearchBar(),

                      const SizedBox(height: 8),

                      Expanded(
                        child:
                            _buildActivityBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isSearching)
              SliverToBoxAdapter(
                child:
                    _buildSearchResults(),
              )
            else
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildAiCard(),

                    _buildFilters(
                      allChatsCount,
                    ),

                    _buildChatList(),

                    const SizedBox(
                      height: 20,
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
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth;

        final bool compact =
            width < 380;

        final double logoSize =
            compact ? 40 : 46;

        final double titleSize =
            compact ? 26 : 30;

        final double xSize =
            compact ? 34 : 40;

        return SizedBox(
          height:
              compact ? 40 : 46,
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  compact ? 10 : 12,
                ),
                child: Image.asset(
                  "assets/chatex_logoo.png",
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                ),
              ),

              SizedBox(
                width:
                    compact ? 6 : 8,
              ),

              Expanded(
                child: FittedBox(
                  fit:
                      BoxFit.scaleDown,
                  alignment:
                      Alignment.centerLeft,
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(
                        "Chattª",
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              titleSize,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              -1,
                        ),
                      ),

                      ShaderMask(
                        shaderCallback:
                            (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(
                                  0xFF00E5FF),
                              Color(
                                  0xFFB026FF),
                            ],
                          ).createShader(
                            bounds,
                          );
                        },
                        child: Text(
                          "X",
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                xSize,
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing:
                                -2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                width: 4,
              ),

              _topButton(
                Icons.qr_code_scanner_outlined,
              ),

              const SizedBox(
                width: 4,
              ),

              _profileButton(),

              const SizedBox(
                width: 4,
              ),

              _settingsButton(),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return SizedBox(
      height: 48,
      child: Container(
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF111827),
          borderRadius:
              BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: TextField(
          controller:
              _searchController,
          onChanged:
              _onSearchChanged,
          style:
              const TextStyle(
            color: Colors.white,
          ),
          textInputAction:
              TextInputAction.search,
          decoration:
              InputDecoration(
            border:
                InputBorder.none,
            hintText:
                "Search people or conversations",
            hintStyle:
                const TextStyle(
              color:
                  Colors.white54,
            ),
            prefixIcon:
                const Icon(
              Icons.search,
              color:
                  Colors.white54,
            ),
            suffixIcon:
                _searchController
                        .text
                        .isNotEmpty
                    ? IconButton(
                        onPressed:
                            _clearSearch,
                        icon:
                            const Icon(
                          Icons
                              .close_rounded,
                          color:
                              Colors.white54,
                        ),
                      )
                    : const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons
                                .mic_none_rounded,
                            color:
                                Colors.white54,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Icon(
                            Icons
                                .tune_rounded,
                            color:
                                Colors.white54,
                          ),
                          SizedBox(
                            width: 14,
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.only(
          top: 35,
          left: 20,
          right: 20,
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFF111827),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons.search_off_rounded,
                color:
                    Colors.white54,
                size: 32,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              "No results found",
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              "Try searching for a person's name, username or a message.",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final people =
        _searchResults.where(
      (result) =>
          result.type ==
          _SearchResultType.person,
    );

    final conversations =
        _searchResults.where(
      (result) =>
          result.type ==
          _SearchResultType.conversation,
    );

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 10,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (people.isNotEmpty) ...[
            _searchSectionTitle(
              "People",
              Icons.people_outline_rounded,
            ),

            ...people.map(
              _buildSearchResultTile,
            ),
          ],

          if (conversations.isNotEmpty) ...[
            _searchSectionTitle(
              "Conversations",
              Icons
                  .chat_bubble_outline_rounded,
            ),

            ...conversations.map(
              _buildSearchResultTile,
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchSectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                const Color(0xFF00D9FF),
            size: 17,
          ),

          const SizedBox(
            width: 7,
          ),

          Text(
            title,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 14,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(
    _SearchResult result,
  ) {
    return GestureDetector(
      onTap: () =>
          _openSearchResult(result),
      child: Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0x81FFFFFF),
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // ==================================================
            // SEARCH PROFILE PHOTO
            // ==================================================

            GestureDetector(
              onTap: result.photoUrl
                      .isNotEmpty
                  ? () {
                      _openProfilePhoto(
                        imageUrl:
                            result.photoUrl,
                        name:
                            result.name,
                        verified:
                            result.verified,
                      );
                    }
                  : null,
              child: Stack(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: result
                              .photoUrl
                              .isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl:
                                  result.photoUrl,
                              width: 52,
                              height: 52,
                              fit:
                                  BoxFit.cover,
                              fadeInDuration:
                                  Duration.zero,
                              fadeOutDuration:
                                  Duration.zero,
                              errorWidget:
                                  (
                                context,
                                url,
                                error,
                              ) {
                                return _defaultAvatar(
                                  52,
                                );
                              },
                            )
                          : _defaultAvatar(
                              52,
                            ),
                    ),
                  ),

                  if (result.online)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child:
                          Container(
                        width: 14,
                        height: 14,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF34F58A,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF050816,
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  VerifiedName(
  name: result.name,
  verified: result.verified,
  fontSize: 16,
  fontWeight: FontWeight.bold,
  textColor: Colors.white,
),
                  const SizedBox(
                    height: 4,
                  ),

                  if (result.type ==
                      _SearchResultType.person)
                    Text(
                      result.username
                              .isNotEmpty
                          ? "@${result.username}"
                          : result.online
                              ? "Online"
                              : "ChattªX user",
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.message,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        if (result.time
                            .isNotEmpty)
                          const SizedBox(
                            width: 6,
                          ),

                        if (result.time
                            .isNotEmpty)
                          Text(
                            result.time,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTIVITY BAR
  // ============================================================

  Widget _buildActivityBar() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final width =
            constraints.maxWidth;

        final bool compact =
            width < 380;

        final double fontSize =
            compact ? 8.5 : 10;

        final double iconSize =
            compact ? 10 : 11;

        return Container(
          height: 38,
          padding:
              const EdgeInsets.all(2),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF111827),
            borderRadius:
                BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child:
                    StreamBuilder<
                        QuerySnapshot>(
                  stream:
                      _firestore
                          .collection(
                              "users")
                          .where(
                            "isOnline",
                            isEqualTo:
                                true,
                          )
                          .snapshots(),
                  builder:
                      (context, snapshot) {
                    int online = 0;

                    if (snapshot.hasData) {
                      online =
                          snapshot.data!.docs.length;

                      if (myUid
                              .isNotEmpty &&
                          online > 0) {
                        online--;
                      }

                      if (online < 0) {
                        online = 0;
                      }
                    }

                    return _activityChip(
                      "online",
                      Icons.circle,
                      "$online Online",
                      const Color(
                          0xFF34F58A),
                      fontSize:
                          fontSize,
                      iconSize:
                          iconSize,
                    );
                  },
                ),
              ),

              Expanded(
                child:
                    _activityChip(
                  "birthdays",
                  Icons.cake_outlined,
                  "Birthdays",
                  Colors.orange,
                  fontSize:
                      fontSize,
                  iconSize:
                      iconSize,
                ),
              ),

              Expanded(
                child:
                    _activityChip(
                  "live",
                  Icons.podcasts_rounded,
                  "Go Live",
                  Colors.redAccent,
                  fontSize:
                      fontSize,
                  iconSize:
                      iconSize,
                ),
              ),

              Expanded(
                child:
                    _activityChip(
                  "friends",
                  Icons
                      .person_add_alt_1,
                  "New Friends",
                  Colors.cyan,
                  fontSize:
                      fontSize,
                  iconSize:
                      iconSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ACTIVITY CHIP
  // ============================================================

  Widget _activityChip(
    String id,
    IconData icon,
    String text,
    Color color, {
    double fontSize = 10,
    double iconSize = 11,
  }) {
    final bool selected =
        selectedActivity == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedActivity = id;
        });

        if (id == "birthdays") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const BirthdaysScreen(),
            ),
          );
        }

        if (id == "live") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const GoLiveScreen(),
            ),
          );
        }

        if (id == "friends") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const NewFriendsScreen(),
            ),
          );
        }
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 1,
          vertical: 3,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 6,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: selected
                  ? Colors.white
                  : color,
            ),

            const SizedBox(
              width: 3,
            ),

            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white70,
                  fontSize:
                      fontSize,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QR
  // ============================================================

  Widget _topButton(
    IconData icon,
  ) {
    return SizedBox(
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ShareQrScreen(),
            ),
          );
        },
        child: Container(
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF111827),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Icon(
            icon,
            color:
                Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE BUTTON
  // ============================================================

  Widget _profileButton() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return _emptyProfileButton();
    }

    final photoUrl =
        user.photoURL ?? "";

    return SizedBox(
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ProfileScreen(),
            ),
          );

          try {
            await _auth.currentUser
                ?.reload();
          } catch (_) {}

          if (mounted) {
            setState(() {});
          }
        },
        child: Container(
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF111827),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(11),
            child: photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl:
                        photoUrl,
                    width: 40,
                    height: 40,
                    fit:
                        BoxFit.cover,
                    fadeInDuration:
                        Duration.zero,
                    fadeOutDuration:
                        Duration.zero,
                    errorWidget:
                        (
                      context,
                      url,
                      error,
                    ) {
                      return const Icon(
                        Icons
                            .person_rounded,
                        color:
                            Colors.white,
                        size: 22,
                      );
                    },
                  )
                : const Icon(
                    Icons
                        .person_rounded,
                    color:
                        Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _emptyProfileButton() {
    return Container(
      width: 40,
      height: 40,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF111827),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color:
            Colors.white,
        size: 22,
      ),
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Widget _settingsButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const SettingsScreen(),
            ),
          );
        },
        child: Container(
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF111827),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child:
              const Icon(
            Icons.settings_outlined,
            color:
                Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AI CARD
  // ============================================================

  Widget _buildAiCard() {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 0,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AIScreen(),
            ),
          );
        },
        child: Container(
          height: 86,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(24),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.centerLeft,
              end:
                  Alignment.centerRight,
              colors: [
                Color(0xFF4018D8),
                Color(0xFF3511A8),
                Color(0xFF250C70),
              ],
              stops: [
                0.0,
                0.48,
                1.0,
              ],
            ),
            border: Border.all(
              color:
                  const Color(
                0xFFB026FF,
              ),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color(0x552D0B88),
                blurRadius: 18,
                spreadRadius: 0,
                offset:
                    Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                child: Image.asset(
                  "assets/ai_robot.jpeg",
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      "ChattªX AI",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    SizedBox(
                      height: 6,
                    ),

                    Text(
                      "Ask anything, get answers instantly.",
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Container(
                width: 44,
                height: 44,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0x1FFFFFFF),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .arrow_forward_rounded,
                  color:
                      Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(
    int allChatsCount,
  ) {
    final items = [
      {
        "title": "All",
        "count": allChatsCount,
      },
      {
        "title": "Unread",
        "count": unreadChatsCount,
      },
      {
        "title": "Groups",
        "count": 2,
      },
    ];

    return Container(
      height: 46,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceEvenly,
        children:
            items.map((item) {
          final title =
              item["title"]
                  as String;

          final count =
              item["count"]
                  as int;

          final selected =
              selectedFilter ==
                  title;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedFilter =
                      title;
                });
              },
              child:
                  AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),
                margin:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 5,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    22,
                  ),
                  gradient:
                      selected
                          ? const LinearGradient(
                              colors: [
                                Color(
                                    0xFF8B2CF8),
                                Color(
                                    0xFFD946EF),
                              ],
                            )
                          : null,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Flexible(
                      child:
                          Text(
                        title,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          color: selected
                              ? Colors
                                  .white
                              : Colors
                                  .white70,
                          fontWeight:
                              FontWeight
                                  .bold,
                          fontSize:
                              14,
                        ),
                      ),
                    ),

                    if (count > 0) ...[
                      const SizedBox(
                        width: 5,
                      ),

                      Container(
                        width: 18,
                        height: 18,
                        alignment:
                            Alignment
                                .center,
                        decoration:
                            const BoxDecoration(
                          color:
                              Colors
                                  .white24,
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            Text(
                          "$count",
                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white,
                            fontSize:
                                9,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // CHAT LIST
  // ============================================================

  Widget _buildChatList() {
    if (myUid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        QuerySnapshot>(
      stream: _firestore
          .collection("chat_rooms")
          .where(
            "participants",
            arrayContains:
                myUid,
          )
          .orderBy(
            "lastMessageTime",
            descending: true,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (!snapshot.hasData) {
          if (cachedChats
              .isNotEmpty) {
            return _buildCachedChatList();
          }

          return const Padding(
            padding:
                EdgeInsets.all(30),
            child: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final chats =
            snapshot.data!.docs;

        allChatsCount =
            chats.length;

        int unreadTotal = 0;

        for (final chat
            in chats) {
          final data =
              chat.data()
                  as Map<String,
                      dynamic>;

          unreadTotal +=
              _readInt(
            data[
                "unread_$myUid"],
          );
        }

        unreadChatsCount =
            unreadTotal;

        _saveChatsToCache(chats);

        if (chats.isEmpty) {
          return const Padding(
            padding:
                EdgeInsets.all(40),
            child: Center(
              child: Text(
                "No conversations yet",
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 15,
                ),
              ),
            ),
          );
        }

        List<QueryDocumentSnapshot>
            visibleChats =
            List<
                    QueryDocumentSnapshot>.from(
                chats);

        if (selectedFilter ==
            "Unread") {
          visibleChats =
              chats.where(
            (chat) {
              final data =
                  chat.data()
                      as Map<String,
                          dynamic>;

              return _readInt(
                    data[
                        "unread_$myUid"],
                  ) >
                  0;
            },
          ).toList();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount:
              visibleChats.length,
          itemBuilder:
              (context, index) {
            final data =
                visibleChats[index]
                        .data()
                    as Map<String,
                        dynamic>;

            final participants =
                List<String>.from(
              data[
                      "participants"] ??
                  [],
            );

            final receiverId =
                participants.firstWhere(
              (id) =>
                  id != myUid,
              orElse: () =>
                  "",
            );

            if (receiverId.isEmpty) {
              return const SizedBox
                  .shrink();
            }

            final String status =
                data[
                        "lastMessageStatus"] ??
                    data[
                        "lastInfinity"] ??
                    "sent";

            final int unread =
                _readInt(
              data[
                  "unread_$myUid"],
            );

            final String message =
                (data[
                            "lastMessage"] ??
                        "Start chatting...")
                    .toString();

            String time = "";

            if (data[
                    "lastMessageTime"]
                is Timestamp) {
              time =
                  _formatTime(
                data[
                    "lastMessageTime"],
              );
            }

            return FutureBuilder<
                DocumentSnapshot>(
              future:
                  _firestore
                      .collection(
                          "users")
                      .doc(
                          receiverId)
                      .get(),
              builder:
                  (
                context,
                userSnapshot,
              ) {
                String name =
                    (data[
                                "receiverName"] ??
                            "User")
                        .toString();

                String photo =
                    (data[
                                "receiverPhoto"] ??
                            "")
                        .toString();

                bool online =
                    false;

                bool verified =
                    false;

                if (userSnapshot
                    .hasData) {
                  final userData =
                      userSnapshot
                          .data;

                  if (userData !=
                          null &&
                      userData
                          .exists) {
                    final user =
                        userData.data()
                            as Map<
                                String,
                                dynamic>;

                    name =
                        (user[
                                    "name"] ??
                                name)
                            .toString();

                    photo =
                        (user[
                                    "photoUrl"] ??
                                photo)
                            .toString();

                    online =
                        user[
                                "isOnline"] ==
                            true;

                    verified =
                        user[
                                "verified"] ==
                            true;
                  }
                }

                return _chatTile(
                  receiverId,
                  name,
                  message,
                  time,
                  photo,
                  online:
                      online,
                  verified:
                      verified,
                  unread:
                      unread,
                  isLastMessageMine:
                      data[
                              "lastSenderId"] ==
                          myUid,
                  delivered:
                      status ==
                              "delivered" ||
                          status ==
                              "seen",
                  seen:
                      status ==
                          "seen",
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CACHED CHAT LIST
  // ============================================================

  Widget _buildCachedChatList() {
    if (cachedChats.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> tiles =
        [];

    for (final data
        in cachedChats) {
      try {
        final participants =
            List<String>.from(
          data[
                  "participants"] ??
              [],
        );

        final receiverId =
            participants.firstWhere(
          (id) =>
              id != myUid,
          orElse: () => "",
        );

        if (receiverId.isEmpty) {
          continue;
        }

        String time = "";

        if (data[
                "lastMessageTime"]
            is Timestamp) {
          time = _formatTime(
            data[
                "lastMessageTime"],
          );
        }

        final status =
            data[
                    "lastMessageStatus"] ??
                data[
                    "lastInfinity"] ??
                "sent";

        final unread =
            _readInt(
          data[
              "unread_$myUid"],
        );

        tiles.add(
          _chatTile(
            receiverId,
            (data[
                        "receiverName"] ??
                    "User")
                .toString(),
            (data[
                        "lastMessage"] ??
                    "Start chatting...")
                .toString(),
            time,
            (data[
                        "receiverPhoto"] ??
                    "")
                .toString(),
            unread: unread,
            isLastMessageMine:
                data[
                        "lastSenderId"] ==
                    myUid,
            delivered:
                status ==
                        "delivered" ||
                    status ==
                        "seen",
            seen:
                status ==
                    "seen",
          ),
        );
      } catch (e) {
        debugPrint(
          "ChattªX cached chat error: $e",
        );
      }
    }

    return ListView(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }

  // ============================================================
  // INTEGER
  // ============================================================

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  // ============================================================
  // CHAT TILE
  // ============================================================

  Widget _chatTile(
    String receiverId,
    String name,
    String message,
    String time,
    String image, {
    bool online = false,
    bool verified = false,
    int unread = 0,
    bool isLastMessageMine = false,
    bool delivered = false,
    bool seen = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(
              receiverId:
                  receiverId,
              receiverName:
                  name,
              receiverImage:
                  image,
            ),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 6,
        ),
        padding:
            const EdgeInsets.only(
          left: 4,
          right: 12,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            // ==================================================
            // CHAT PROFILE PICTURE
            // ==================================================

            GestureDetector(
              behavior:
                  HitTestBehavior
                      .opaque,
              onTap: image
                      .trim()
                      .isNotEmpty
                  ? () {
                      _openProfilePhoto(
                        imageUrl:
                            image,
                        name:
                            name,
                        verified:
                            verified,
                      );
                    }
                  : null,
              child: Stack(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: image
                              .isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl:
                                  image,
                              width: 56,
                              height: 56,
                              fit:
                                  BoxFit.cover,
                              fadeInDuration:
                                  Duration.zero,
                              fadeOutDuration:
                                  Duration.zero,
                              memCacheWidth:
                                  112,
                              memCacheHeight:
                                  112,
                              errorWidget:
                                  (
                                context,
                                url,
                                error,
                              ) {
                                return _defaultAvatar(
                                  56,
                                );
                              },
                            )
                          : _defaultAvatar(
                              56,
                            ),
                    ),
                  ),

                  if (online)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child:
                          Container(
                        width: 15,
                        height: 15,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF34F58A,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF050816,
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
  children: [
    Expanded(
      child: VerifiedName(
        name: name,
        verified: verified,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        textColor: Colors.white,
      ),
    ),

    const SizedBox(
      width: 6,
    ),

    Flexible(
      flex: 0,
      child: Text(
        time,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
        ),
      ),
    ),
  ],
),

                  const SizedBox(
                    height: 5,
                  ),

                  Row(
                    children: [
                      if (isLastMessageMine)
                        Text(
                          "∞",
                          style:
                              TextStyle(
                            fontSize:
                                16,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color: seen
                                ? const Color(
                                    0xFF00D9FF,
                                  )
                                : delivered
                                    ? Colors
                                        .white
                                    : Colors
                                        .grey,
                          ),
                        ),

                      if (isLastMessageMine)
                        const SizedBox(
                          width: 4,
                        ),

                      Expanded(
                        child:
                            Text(
                          message,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            color: unread >
                                    0
                                ? Colors
                                    .white
                                : Colors
                                    .white60,
                            fontWeight: unread >
                                    0
                                ? FontWeight
                                    .bold
                                : FontWeight
                                    .normal,
                          ),
                        ),
                      ),

                      if (unread > 0)
                        Container(
                          margin:
                              const EdgeInsets
                                  .only(
                            left: 8,
                          ),
                          width: 22,
                          height: 22,
                          alignment:
                              Alignment
                                  .center,
                          decoration:
                              const BoxDecoration(
                            color:
                                Color(
                              0xFF8B2CF8,
                            ),
                            shape:
                                BoxShape
                                    .circle,
                          ),
                          child:
                              Text(
                            "$unread",
                            style:
                                const TextStyle(
                              color:
                                  Colors
                                      .white,
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .bold,
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
    );
  }

  // ============================================================
  // DEFAULT AVATAR
  // ============================================================

  Widget _defaultAvatar(
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      color:
          const Color(0xFF111827),
      child: Icon(
        Icons.person_rounded,
        color:
            Colors.white,
        size:
            size * 0.46,
      ),
    );
  }
}

// ============================================================================
// FULL-SCREEN PROFILE PHOTO VIEWER
// ============================================================================

class _ProfilePhotoViewer
    extends StatefulWidget {
  final String imageUrl;
  final String name;
  final bool verified;

  const _ProfilePhotoViewer({
    required this.imageUrl,
    required this.name,
    required this.verified,
  });

  @override
  State<_ProfilePhotoViewer>
      createState() =>
          _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState
    extends State<_ProfilePhotoViewer> {
  bool _saving = false;

  // ============================================================
  // SAVE IMAGE
  // ============================================================

  Future<void> _saveImage() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final bool hasAccess =
          await Gal.hasAccess();

      if (!hasAccess) {
  final bool granted = await Gal.requestAccess();

  if (!granted) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF111827),
        content: Text(
          "Gallery permission was denied.",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );

    return;
  }
}

      final uri =
          Uri.parse(widget.imageUrl);

      final client =
          HttpClient();

      final request =
          await client.getUrl(uri);

      final response =
          await request.close();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        client.close();

        throw Exception(
          "Could not download image.",
        );
      }

      final List<int> bytes =
          await response
              .fold<List<int>>(
        <int>[],
        (
          previous,
          chunk,
        ) {
          previous.addAll(chunk);
          return previous;
        },
      );

      client.close();

      if (bytes.isEmpty) {
        throw Exception(
          "Image is empty.",
        );
      }

      final Uint8List imageBytes =
          Uint8List.fromList(bytes);

      final safeName =
          widget.name
              .trim()
              .replaceAll(
                RegExp(
                  r'[^a-zA-Z0-9_-]+',
                ),
                "_",
              );

      final fileName =
          safeName.isEmpty
              ? "ChattX_profile_photo"
              : "ChattX_${safeName}_profile";

      await Gal.putImageBytes(
        imageBytes,
        name: fileName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(
            0xFF111827,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(
                    0xFF34F58A,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons.check_rounded,
                  color:
                      Colors.black,
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Text(
                  "Profile picture saved to your gallery",
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(
            0xFF111827,
          ),
          content:
              Text(
            e.type.message,
            style:
                const TextStyle(
              color:
                  Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              Color(0xFF111827),
          content: Text(
            "Unable to save this profile picture.",
            style:
                TextStyle(
              color:
                  Colors.white,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // IMAGE
            // ==================================================

            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(
                    context,
                  );
                },
                child:
                    InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child:
                      Center(
                    child:
                        CachedNetworkImage(
                      imageUrl:
                          widget.imageUrl,
                      fit:
                          BoxFit.contain,
                      width:
                          double.infinity,
                      height:
                          double.infinity,
                      placeholder:
                          (
                        context,
                        url,
                      ) {
                        return const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                          ),
                        );
                      },
                      errorWidget:
                          (
                        context,
                        url,
                        error,
                      ) {
                        return const Center(
                          child:
                              Icon(
                            Icons
                                .broken_image_outlined,
                            color:
                                Colors.white54,
                            size:
                                60,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // TOP BAR
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  8,
                  8,
                  8,
                  14,
                ),
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
                        0xCC000000,
                      ),
                      Color(
                        0x00000000,
                      ),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // ========================================
                    // BACK
                    // ========================================

                    GestureDetector(
                      onTap: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      child:
                          Container(
                        width: 44,
                        height: 44,
                        decoration:
                            const BoxDecoration(
                          color:
                              Color(
                            0x44111111,
                          ),
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            const Icon(
                          Icons
                              .arrow_back_rounded,
                          color:
                              Colors.white,
                          size:
                              24,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    // ========================================
                    // NAME
                    // ========================================

                    Expanded(
  child: VerifiedName(
    name: widget.name,
    verified: widget.verified,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    textColor: Colors.white,
  ),
),

                    const SizedBox(
                      width: 8,
                    ),

                    // ========================================
                    // SAVE
                    // ========================================

                    GestureDetector(
                      onTap:
                          _saving
                              ? null
                              : _saveImage,
                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds:
                              180,
                        ),
                        width:
                            48,
                        height:
                            48,
                        decoration:
                            BoxDecoration(
                          color:
                              _saving
                                  ? const Color(
                                      0x44111111,
                                    )
                                  : const Color(
                                      0xFF111827,
                                    ),
                          shape:
                              BoxShape
                                  .circle,
                          border:
                              Border.all(
                            color:
                                Colors.white12,
                          ),
                        ),
                        child:
                            _saving
                                ? const SizedBox(
                                    width:
                                        20,
                                    height:
                                        20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .download_rounded,
                                    color:
                                        Colors.white,
                                    size:
                                        23,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BOTTOM HINT
            // ==================================================

            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: IgnorePointer(
                child: Center(
                  child:
                      Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          14,
                      vertical:
                          8,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0x66111111,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        const Text(
                      "Pinch to zoom  •  Tap back to close",
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            11,
                      ),
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

// ================================================================
// SEARCH RESULT TYPE
// ================================================================

enum _SearchResultType {
  person,
  conversation,
}

// ================================================================
// SEARCH RESULT MODEL
// ================================================================

class _SearchResult {
  final _SearchResultType type;

  final String id;
  final String name;
  final String username;
  final String photoUrl;

  final bool online;
  final bool verified;

  final String message;
  final String time;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.online,
    required this.verified,
    required this.message,
    required this.time,
  });
}

// ================================================================
// HEADER DELEGATE
// ================================================================

class _HeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _HeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent =>
      height;

  @override
  double get maxExtent =>
      height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      width:
          double.infinity,
      height:
          height,
      child:
          child,
    );
  }

  @override
  bool shouldRebuild(
    covariant _HeaderDelegate
        oldDelegate,
  ) {
    return oldDelegate.height !=
            height ||
        oldDelegate.child !=
            child;
  }
}