import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/cloudinary_service.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // FILTER
  // ============================================================

  int selectedFilter = 0;

  // ============================================================
  // UPLOAD STATE
  // ============================================================

  bool _uploadingStory = false;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // ============================================================
  // STORIES STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> get _storiesStream {
    return _firestore.collection('stories').snapshots();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _storiesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(
                    snapshot.error.toString(),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9B45FF),
                    ),
                  );
                }

                final now = DateTime.now();

                final allStories = snapshot.data!.docs
                    .map(
                      (doc) => _storyFromDocument(doc),
                    )
                    .where(
                      (story) => _isStoryActive(
                        story,
                        now,
                      ),
                    )
                    .toList();

                allStories.sort(
                  (a, b) => _storyDate(b).compareTo(
                    _storyDate(a),
                  ),
                );

                final filteredStories = _applyFilter(
                  allStories,
                );

                final storyUsers = _buildStoryUsers(
                  allStories,
                );

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          10,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/chatex_logo.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        width: 48,
                                        height: 48,
                                        decoration:
                                            BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          gradient:
                                              const LinearGradient(
                                            colors: [
                                              Color(0xFF00D9FF),
                                              Color(0xFF7B2FF7),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons
                                              .chat_bubble_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Stories',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.8,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                _showMoreOptions(context);
                              },
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==================================================
                    // SEARCH
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          4,
                        ),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius:
                                BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color(0xFF26334A),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 15),
                              const Icon(
                                Icons.search_rounded,
                                color: Colors.white54,
                                size: 27,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Search stories...',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  _showFilterInfo();
                                },
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  color: Color(0xFF9B45FF),
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // STORY CIRCLES
                    // ==================================================

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 132,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics:
                              const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            9,
                            16,
                            2,
                          ),
                          itemCount: storyUsers.length,
                          itemBuilder: (context, index) {
                            return _buildStoryCircle(
                              storyUsers[index],
                            );
                          },
                        ),
                      ),
                    ),

                    // ==================================================
                    // FILTER BAR
                    // ==================================================

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius:
                                BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color(0xFF26334A),
                            ),
                          ),
                          child: Row(
                            children: [
                              _filterButton(
                                0,
                                Icons.layers_rounded,
                                'All Stories',
                              ),
                              _filterButton(
                                1,
                                Icons.access_time_rounded,
                                'Recent',
                              ),
                              _filterButton(
                                2,
                                Icons.visibility_off_rounded,
                                'Viewed',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 12),
                    ),

                    // ==================================================
                    // EMPTY STATE
                    // ==================================================

                    if (filteredStories.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyStories(),
                      ),

                    // ==================================================
                    // STORY GRID
                    // ==================================================

                    if (filteredStories.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          110,
                        ),
                        sliver: SliverGrid(
                          delegate:
                              SliverChildBuilderDelegate(
                            (context, index) {
                              final story =
                                  filteredStories[index];

                              return _buildStoryCard(
                                story,
                              );
                            },
                            childCount:
                                filteredStories.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: .57,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ============================================================
            // UPLOAD OVERLAY
            // ============================================================

            if (_uploadingStory)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: .72,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFB026FF),
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Publishing your Story...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Uploading to ChattªX',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
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

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7B2FF7).withValues(
                  alpha: .15,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFB026FF),
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load Stories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF7B2FF7),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STORY DOCUMENT
  // ============================================================

  Map<String, dynamic> _storyFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return {
      ...data,
      '_id': document.id,
    };
  }

  // ============================================================
  // STORY ACTIVE
  // ============================================================

  bool _isStoryActive(
    Map<String, dynamic> story,
    DateTime now,
  ) {
    final expiresAt = _timestampToDate(
      story['expiresAt'],
    );

    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isAfter(now);
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime _storyDate(
    Map<String, dynamic> story,
  ) {
    return _timestampToDate(
          story['createdAt'],
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> stories,
  ) {
    if (selectedFilter == 0) {
      return stories;
    }

    if (selectedFilter == 1) {
      final cutoff = DateTime.now().subtract(
        const Duration(hours: 3),
      );

      return stories
          .where(
            (story) => _storyDate(story).isAfter(cutoff),
          )
          .toList();
    }

    if (selectedFilter == 2) {
      return stories
          .where(
            (story) => _hasViewed(story),
          )
          .toList();
    }

    return stories;
  }

  // ============================================================
  // VIEWED
  // ============================================================

  bool _hasViewed(
    Map<String, dynamic> story,
  ) {
    final viewers = story['viewers'];

    if (viewers is! List) {
      return false;
    }

    return viewers.contains(currentUserId);
  }

  // ============================================================
  // STORY USERS
  // ============================================================

  List<Map<String, dynamic>> _buildStoryUsers(
    List<Map<String, dynamic>> stories,
  ) {
    final users = <Map<String, dynamic>>[];

    final myStories = stories
        .where(
          (story) =>
              story['userId'] == currentUserId,
        )
        .toList();

    users.add({
      'name': 'Your Story',
      'image': myStories.isNotEmpty
          ? myStories.first['userImage'] ?? ''
          : '',
      'isMine': true,
      'online': false,
      'stories': myStories,
    });

    final seenUsers = <String>{};

    for (final story in stories) {
      final uid =
          story['userId']?.toString() ?? '';

      if (uid.isEmpty ||
          uid == currentUserId ||
          seenUsers.contains(uid)) {
        continue;
      }

      seenUsers.add(uid);

      final userStories = stories
          .where(
            (s) => s['userId'] == uid,
          )
          .toList();

      users.add({
        'name':
            story['username'] ??
                'ChattªX User',
        'image':
            story['userImage'] ?? '',
        'isMine': false,
        'online':
            story['online'] == true,
        'stories': userStories,
      });
    }

    return users;
  }

  // ============================================================
  // STORY CIRCLE
  // ============================================================

  Widget _buildStoryCircle(
    Map<String, dynamic> user,
  ) {
    final bool isMine =
        user['isMine'] == true;

    final bool online =
        user['online'] == true;

    final List stories =
        user['stories'] ?? [];

    return GestureDetector(
      onTap: () {
        if (isMine) {
          if (stories.isEmpty) {
            _showAddStoryOptions();
          } else {
            _openStoryList(
              List<Map<String, dynamic>>.from(
                stories,
              ),
              0,
            );
          }
        } else if (stories.isNotEmpty) {
          _openStoryList(
            List<Map<String, dynamic>>.from(
              stories,
            ),
            0,
          );
        }
      },
      child: SizedBox(
        width: 88,
        child: Padding(
          padding: const EdgeInsets.only(
            right: 6,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(0xFF00D9FF),
                          Color(0xFF7B2FF7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xFF7B2FF7,
                          ).withValues(
                            alpha: .22,
                          ),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(
                        user['image']
                                ?.toString() ??
                            '',
                        isMine
                            ? const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 38,
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                      ),
                    ),
                  ),
                  if (isMine)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 31,
                        height: 31,
                        decoration:
                            const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              LinearGradient(
                            colors: [
                              Color(0xFF9B45FF),
                              Color(0xFF00D9FF),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  if (online && !isMine)
                    Positioned(
                      right: 1,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF00E676,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF050816,
                            ),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                user['name'] ??
                    'ChattªX User',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================

  Widget _buildProfileImage(
    String url,
    Widget fallback,
  ) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF17113D),
        child: Center(
          child: fallback,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF17113D),
          child: Center(
            child: fallback,
          ),
        );
      },
    );
  }

  // ============================================================
  // FILTER BUTTON
  // ============================================================

  Widget _filterButton(
    int index,
    IconData icon,
    String title,
  ) {
    final selected =
        selectedFilter == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = index;
          });
        },
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 220,
          ),
          margin:
              const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 5,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFB026FF),
                      Color(0xFF2563EB),
                    ],
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Colors.white
                    : Colors.white54,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STORY CARD
  // ============================================================

  Widget _buildStoryCard(
    Map<String, dynamic> story,
  ) {
    final mediaUrl =
        story['mediaUrl']
                ?.toString() ??
            '';

    final mediaType =
        story['mediaType']
                ?.toString() ??
            'image';

    final username =
        story['username']
                ?.toString() ??
            'ChattªX User';

    final caption =
        story['caption']
                ?.toString() ??
            '';

    final viewed =
        _hasViewed(story);

    return GestureDetector(
      onTap: () {
        _openStoryList(
          [story],
          0,
        );
      },
      onLongPress: () {
        if (story['userId'] ==
            currentUserId) {
          _showStoryOwnerOptions(
            story,
          );
        }
      },
      child: Container(
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          color:
              const Color(0xFF111827),
          border: Border.all(
            color: viewed
                ? Colors.white12
                : const Color(
                    0xFF9B45FF,
                  ),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(
                0xFF7B2FF7,
              ).withValues(
                alpha: .10,
              ),
              blurRadius: 14,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            23,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (mediaType == 'image' &&
                  mediaUrl.isNotEmpty)
                Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _storyFallback();
                  },
                )
              else
                _storyFallback(),

              DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(
                        alpha: .15,
                      ),
                      Colors.transparent,
                      Colors.black.withValues(
                        alpha: .78,
                      ),
                    ],
                  ),
                ),
              ),

              if (mediaType == 'video')
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

              Positioned(
                top: 10,
                left: 9,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            LinearGradient(
                          colors: [
                            Color(
                              0xFF00D9FF,
                            ),
                            Color(
                              0xFF7B2FF7,
                            ),
                          ],
                        ),
                      ),
                      child: ClipOval(
                        child:
                            _buildProfileImage(
                          story['userImage']
                                  ?.toString() ??
                              '',
                          const Icon(
                            Icons
                                .person_rounded,
                            color:
                                Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (caption.isNotEmpty)
                Positioned(
                  left: 14,
                  right: 10,
                  bottom: 14,
                  child: Text(
                    caption,
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

              if (viewed)
                Positioned(
                  top: 12,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.black.withValues(
                        alpha: .45,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .visibility_off_rounded,
                      color:
                          Colors.white70,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FALLBACK
  // ============================================================

  Widget _storyFallback() {
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
            Color(0xFF7B2FF7),
            Color(0xFF050816),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 58,
          color: Colors.white.withValues(
            alpha: .25,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyStories() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        30,
        45,
        30,
        100,
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(
                colors: [
                  Color(0xFF00D9FF),
                  Color(0xFF7B2FF7),
                ],
              ),
            ),
            child:
                const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No stories yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first person to share a moment with your ChattªX friends.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed:
                _showAddStoryOptions,
            icon:
                const Icon(
              Icons.add_rounded,
            ),
            label:
                const Text(
              'Create Story',
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(
                0xFF7B2FF7,
              ),
              foregroundColor:
                  Colors.white,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 22,
                vertical: 13,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD STORY OPTIONS
  // ============================================================

  void _showAddStoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            30,
          ),
          decoration:
              const BoxDecoration(
            color:
                Color(0xFF101827),
            borderRadius:
                BorderRadius.only(
              topLeft:
                  Radius.circular(
                28,
              ),
              topRight:
                  Radius.circular(
                28,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin:
                    const EdgeInsets.only(
                  bottom: 20,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Create a Story',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _storyOption(
                Icons.photo_library_rounded,
                'Photo',
                'Share a photo',
                () {
                  Navigator.pop(context);
                  _pickStory(
                    ImageSource.gallery,
                  );
                },
              ),
              _storyOption(
                Icons.videocam_rounded,
                'Video',
                'Share a video',
                () {
                  Navigator.pop(context);
                  _pickStoryVideo();
                },
              ),
              _storyOption(
                Icons.photo_camera_rounded,
                'Camera',
                'Take a photo',
                () {
                  Navigator.pop(context);
                  _pickStory(
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // STORY OPTION
  // ============================================================

  Widget _storyOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              const Color(
            0xFF7B2FF7,
          ).withValues(
            alpha: .15,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              const Color(
            0xFFB026FF,
          ),
        ),
      ),
      title: Text(
        title,
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style:
            const TextStyle(
          color: Colors.white54,
        ),
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // PICK PHOTO
  // ============================================================

  Future<void> _pickStory(
    ImageSource source,
  ) async {
    try {
      final XFile? picked =
          await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) {
        return;
      }

      await _openStoryStudio(
        File(picked.path),
        'image',
      );
    } catch (e) {
      _showMessage(
        'Could not select the photo.',
      );
    }
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickStoryVideo() async {
    try {
      final XFile? picked =
          await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration:
            const Duration(
          seconds: 60,
        ),
      );

      if (picked == null) {
        return;
      }

      await _openStoryStudio(
        File(picked.path),
        'video',
      );
    } catch (e) {
      _showMessage(
        'Could not select the video.',
      );
    }
  }

  // ============================================================
  // OPEN STORY STUDIO
  // ============================================================

  Future<void> _openStoryStudio(
    File file,
    String mediaType,
  ) async {
    final result =
        await Navigator.push<
            StoryStudioResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoryStudioScreen(
          file: file,
          mediaType: mediaType,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _uploadStory(
      file,
      mediaType,
      result.caption,
      result.textOverlay,
      result.privacy,
    );
  }

  // ============================================================
  // UPLOAD STORY
  // ============================================================

  Future<void> _uploadStory(
    File file,
    String mediaType,
    String caption,
    String textOverlay,
    String privacy,
  ) async {
    if (currentUserId.isEmpty) {
      _showMessage(
        'You need to be logged in to post a Story.',
      );
      return;
    }

    setState(() {
      _uploadingStory = true;
    });

    try {
      String? mediaUrl;

      // ========================================================
      // CLOUDINARY
      // ========================================================

      if (mediaType == 'image') {
        mediaUrl =
            await CloudinaryService
                .uploadStoryImage(
          file,
        );
      } else {
        mediaUrl =
            await CloudinaryService
                .uploadStoryVideo(
          file,
        );
      }

      if (mediaUrl == null ||
          mediaUrl.isEmpty) {
        throw Exception(
          'Cloudinary upload failed.',
        );
      }

      // ========================================================
      // USER INFORMATION
      // ========================================================

      String username =
          _auth.currentUser
                  ?.displayName ??
              'ChattªX User';

      String userImage = '';

      try {
        final userDoc =
            await _firestore
                .collection('users')
                .doc(currentUserId)
                .get();

        final data =
            userDoc.data();

        if (data != null) {
          username =
              data['username']
                      ?.toString() ??
                  data['name']
                      ?.toString() ??
                  username;

          userImage =
              data['photoUrl']
                      ?.toString() ??
                  data['profileImage']
                      ?.toString() ??
                  data['image']
                      ?.toString() ??
                  '';
        }
      } catch (_) {}

      // ========================================================
      // FIRESTORE STORY
      // ========================================================

      final now =
          Timestamp.now();

      final expires =
          Timestamp.fromDate(
        DateTime.now().add(
          const Duration(
            hours: 24,
          ),
        ),
      );

      await _firestore
          .collection('stories')
          .add({
        'userId':
            currentUserId,
        'username':
            username,
        'userImage':
            userImage,
        'mediaUrl':
            mediaUrl,
        'mediaType':
            mediaType,
        'caption':
            caption,
        'textOverlay':
            textOverlay,
        'privacy':
            privacy,
        'createdAt':
            now,
        'expiresAt':
            expires,
        'viewers':
            <String>[],
        'viewCount':
            0,
      });

      if (!mounted) {
        return;
      }

      _showMessage(
        'Your Story has been posted! 🎉',
      );
    } catch (e) {
      debugPrint(
        'ChattªX story upload error: $e',
      );

      if (mounted) {
        _showMessage(
          'Could not post your Story. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingStory = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN STORY LIST
  // ============================================================

  void _openStoryList(
    List<Map<String, dynamic>> stories,
    int initialIndex,
  ) {
    if (stories.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierColor:
          Colors.black.withValues(
        alpha: .92,
      ),
      barrierDismissible: true,
      builder: (_) {
        return StoryViewer(
          stories: stories,
          initialIndex:
              initialIndex,
          currentUserId:
              currentUserId,
        );
      },
    );
  }

  // ============================================================
  // STORY OWNER OPTIONS
  // ============================================================

  void _showStoryOwnerOptions(
    Map<String, dynamic> story,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(
                  Icons.delete_outline,
                  color:
                      Colors.redAccent,
                ),
                title:
                    const Text(
                  'Delete Story',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  _deleteStory(
                    story,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.close_rounded,
                  color:
                      Colors.white54,
                ),
                title:
                    const Text(
                  'Cancel',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DELETE STORY
  // ============================================================

  Future<void> _deleteStory(
    Map<String, dynamic> story,
  ) async {
    final id =
        story['_id']?.toString();

    if (id == null ||
        id.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection('stories')
          .doc(id)
          .delete();

      _showMessage(
        'Story deleted.',
      );
    } catch (e) {
      _showMessage(
        'Could not delete Story.',
      );
    }
  }

  // ============================================================
  // MORE OPTIONS
  // ============================================================

  void _showMoreOptions(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            30,
          ),
          decoration:
              const BoxDecoration(
            color:
                Color(0xFF101827),
            borderRadius:
                BorderRadius.only(
              topLeft:
                  Radius.circular(
                28,
              ),
              topRight:
                  Radius.circular(
                28,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin:
                    const EdgeInsets.only(
                  bottom: 20,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              _moreItem(
                Icons.archive_rounded,
                'Story archive',
                () {
                  Navigator.pop(
                    context,
                  );
                  _showMessage(
                    'Story archive will be available here.',
                  );
                },
              ),
              _moreItem(
                Icons.lock_outline_rounded,
                'Story privacy',
                () {
                  Navigator.pop(
                    context,
                  );
                  _showMessage(
                    'Story privacy settings will be available here.',
                  );
                },
              ),
              _moreItem(
                Icons.settings_rounded,
                'Story settings',
                () {
                  Navigator.pop(
                    context,
                  );
                  _showMessage(
                    'Story settings will be available here.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MORE ITEM
  // ============================================================

  Widget _moreItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              const Color(
            0xFF7B2FF7,
          ).withValues(
            alpha: .15,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              const Color(
            0xFFB026FF,
          ),
        ),
      ),
      title: Text(
        title,
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // FILTER INFO
  // ============================================================

  void _showFilterInfo() {
    _showMessage(
      selectedFilter == 0
          ? 'Showing all active Stories.'
          : selectedFilter == 1
              ? 'Showing Stories from the last 3 hours.'
              : 'Showing Stories you have viewed.',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            const Color(
          0xFF111827,
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// STORY STUDIO RESULT
// ============================================================================

class StoryStudioResult {
  final String caption;
  final String textOverlay;
  final String privacy;

  const StoryStudioResult({
    required this.caption,
    required this.textOverlay,
    required this.privacy,
  });
}

// ============================================================================
// STORY STUDIO
// ============================================================================

class StoryStudioScreen extends StatefulWidget {
  final File file;
  final String mediaType;

  const StoryStudioScreen({
    super.key,
    required this.file,
    required this.mediaType,
  });

  @override
  State<StoryStudioScreen> createState() =>
      _StoryStudioScreenState();
}

class _StoryStudioScreenState
    extends State<StoryStudioScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  VideoPlayerController?
      _videoController;

  final TextEditingController
      _captionController =
      TextEditingController();

  final TextEditingController
      _textController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _loadingVideo = false;
  bool _muted = false;

  bool _showTextEditor = false;
  bool _showCaptionEditor = false;

  String _privacy = 'Friends';

  Color _textColor = Colors.white;

  double _textSize = 28;

  // ============================================================
  // DRAWING
  // ============================================================

  final List<StoryDrawingPoint>
      _drawingPoints = [];

  Color _brushColor =
      const Color(0xFF00D9FF);

  double _brushSize = 5;

  bool _drawingMode = false;

  // ============================================================
  // EMOJIS
  // ============================================================

  final List<String> _emojiOptions = [
    '🔥',
    '❤️',
    '😂',
    '😍',
    '😎',
    '😮',
    '👏',
    '🎉',
    '💜',
    '⚡',
    '✨',
    '🚀',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Future<void> _initializeVideo() async {
    setState(() {
      _loadingVideo = true;
    });

    final controller =
        VideoPlayerController.file(
      widget.file,
    );

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _videoController =
          controller;

      controller.setLooping(true);

      await controller.play();

      if (mounted) {
        setState(() {
          _loadingVideo = false;
        });
      }
    } catch (e) {
      await controller.dispose();

      if (mounted) {
        setState(() {
          _loadingVideo = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _videoController?.dispose();

    _captionController.dispose();
    _textController.dispose();

    super.dispose();
  }

  // ============================================================
  // POST
  // ============================================================

  void _postStory() {
    Navigator.pop(
      context,
      StoryStudioResult(
        caption:
            _captionController.text.trim(),
        textOverlay:
            _textController.text.trim(),
        privacy:
            _privacy,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ======================================================
            // MEDIA
            // ======================================================

            Positioned.fill(
              child: _buildMedia(),
            ),

            // ======================================================
            // TOP GRADIENT
            // ======================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: .78,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ======================================================
            // DRAWING
            // ======================================================

            if (_drawingMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior:
                      HitTestBehavior.translucent,
                  onPanStart: (details) {
                    setState(() {
                      _drawingPoints.add(
                        StoryDrawingPoint(
                          details.localPosition,
                          _brushColor,
                          _brushSize,
                        ),
                      );
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _drawingPoints.add(
                        StoryDrawingPoint(
                          details.localPosition,
                          _brushColor,
                          _brushSize,
                        ),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _drawingPoints.add(
                        StoryDrawingPoint(
                          null,
                          _brushColor,
                          _brushSize,
                        ),
                      );
                    });
                  },
                  child: CustomPaint(
                    painter:
                        StoryDrawingPainter(
                      _drawingPoints,
                    ),
                  ),
                ),
              ),

            // ======================================================
            // TEXT OVERLAY
            // ======================================================

            if (_textController
                .text
                .trim()
                .isNotEmpty)
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 30,
                  ),
                  child: Text(
                    _textController
                        .text
                        .trim(),
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          _textColor,
                      fontSize:
                          _textSize,
                      fontWeight:
                          FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color:
                              Colors.black,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ======================================================
            // TOP CONTROLS
            // ======================================================

            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _studioButton(
                    Icons.close_rounded,
                    () {
                      Navigator.pop(
                        context,
                      );
                    },
                  ),
                  const Spacer(),
                  _studioButton(
                    Icons.auto_awesome_rounded,
                    _showAiTools,
                  ),
                  const SizedBox(width: 8),
                  _studioButton(
                    Icons.edit_rounded,
                    _openTextEditor,
                  ),
                  const SizedBox(width: 8),
                  _studioButton(
                    Icons.brush_rounded,
                    _toggleDrawing,
                  ),
                  const SizedBox(width: 8),
                  if (widget.mediaType ==
                      'video')
                    _studioButton(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      _toggleMute,
                    ),
                ],
              ),
            ),

            // ======================================================
            // BOTTOM CONTROLS
            // ======================================================

            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  if (_showCaptionEditor)
                    _buildCaptionField(),

                  const SizedBox(
                    height: 10,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _bottomTool(
                          Icons
                              .sentiment_satisfied_alt_rounded,
                          'Emoji',
                          _showEmojiPicker,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                            _bottomTool(
                          Icons.text_fields_rounded,
                          'Text',
                          _openTextEditor,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                            _bottomTool(
                          Icons
                              .format_paint_rounded,
                          'Draw',
                          _toggleDrawing,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                            _bottomTool(
                          Icons
                              .subtitles_rounded,
                          'Caption',
                          () {
                            setState(() {
                              _showCaptionEditor =
                                  !_showCaptionEditor;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              _showPrivacySelector,
                          child: Container(
                            height: 52,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black.withValues(
                                alpha: .62,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                              border:
                                  Border.all(
                                color:
                                    Colors.white12,
                              ),
                            ),
                            child:
                                Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                const Icon(
                                  Icons
                                      .lock_outline_rounded,
                                  color:
                                      Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(
                                  width: 7,
                                ),
                                Text(
                                  _privacy,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        flex: 2,
                        child:
                            SizedBox(
                          height: 52,
                          child:
                              ElevatedButton.icon(
                            onPressed:
                                _postStory,
                            icon:
                                const Icon(
                              Icons
                                  .send_rounded,
                            ),
                            label:
                                const Text(
                              'Post Story',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF7B2FF7,
                              ),
                              foregroundColor:
                                  Colors.white,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ======================================================
            // VIDEO LOADING
            // ======================================================

            if (_loadingVideo)
              const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MEDIA
  // ============================================================

  Widget _buildMedia() {
    if (widget.mediaType ==
        'image') {
      return Image.file(
        widget.file,
        fit: BoxFit.contain,
      );
    }

    final controller =
        _videoController;

    if (controller == null ||
        !controller.value
            .isInitialized) {
      return const ColoredBox(
        color: Colors.black,
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio:
            controller.value
                .aspectRatio,
        child:
            VideoPlayer(
          controller,
        ),
      ),
    );
  }

  // ============================================================
  // STUDIO BUTTON
  // ============================================================

  Widget _studioButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(
          color:
              Colors.black.withValues(
            alpha: .55,
          ),
          shape:
              BoxShape.circle,
          border:
              Border.all(
            color:
                Colors.white12,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM TOOL
  // ============================================================

  Widget _bottomTool(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration:
            BoxDecoration(
          color:
              Colors.black.withValues(
            alpha: .60,
          ),
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color:
                Colors.white12,
          ),
        ),
        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  Colors.white,
              size: 20,
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              title,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize:
                    10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAPTION FIELD
  // ============================================================

  Widget _buildCaptionField() {
    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.black.withValues(
          alpha: .75,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child:
          TextField(
        controller:
            _captionController,
        maxLines: 2,
        style:
            const TextStyle(
          color:
              Colors.white,
        ),
        decoration:
            InputDecoration(
          hintText:
              'Write a caption...',
          hintStyle:
              const TextStyle(
            color:
                Colors.white54,
          ),
          border:
              InputBorder.none,
          contentPadding:
              const EdgeInsets.all(
            15,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT EDITOR
  // ============================================================

  void _openTextEditor() {
    setState(() {
      _showTextEditor = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder:
              (context, modalSetState) {
            return Padding(
              padding:
                  EdgeInsets.only(
                bottom:
                    MediaQuery.of(
                  context,
                ).viewInsets.bottom,
              ),
              child:
                  SafeArea(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Text(
                        'Add Text',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              21,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      TextField(
                        controller:
                            _textController,
                        autofocus:
                            true,
                        maxLines:
                            3,
                        onChanged:
                            (_) {
                          setState(
                            () {},
                          );
                          modalSetState(
                            () {},
                          );
                        },
                        style:
                            TextStyle(
                          color:
                              _textColor,
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight.w700,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Type something...',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          filled:
                              true,
                          fillColor:
                              const Color(
                            0xFF111827,
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
                      const SizedBox(
                        height: 15,
                      ),
                      Row(
                        children: [
                          _colorChoice(
                            Colors.white,
                            modalSetState,
                          ),
                          _colorChoice(
                            const Color(
                              0xFF00D9FF,
                            ),
                            modalSetState,
                          ),
                          _colorChoice(
                            const Color(
                              0xFFB026FF,
                            ),
                            modalSetState,
                          ),
                          _colorChoice(
                            const Color(
                              0xFFFF4D8D,
                            ),
                            modalSetState,
                          ),
                          _colorChoice(
                            const Color(
                              0xFFFFD54F,
                            ),
                            modalSetState,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const Text(
                            'Size',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                          Expanded(
                            child:
                                Slider(
                              min:
                                  16,
                              max:
                                  58,
                              value:
                                  _textSize,
                              onChanged:
                                  (value) {
                                setState(
                                  () {
                                    _textSize =
                                        value;
                                  },
                                );
                                modalSetState(
                                  () {},
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton(
                          onPressed:
                              () {
                            Navigator.pop(
                              context,
                            );
                          },
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF7B2FF7,
                            ),
                            foregroundColor:
                                Colors.white,
                          ),
                          child:
                              const Text(
                            'Done',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // COLOR CHOICE
  // ============================================================

  Widget _colorChoice(
    Color color,
    StateSetter modalSetState,
  ) {
    final selected =
        _textColor == color;

    return GestureDetector(
      onTap: () {
        setState(() {
          _textColor =
              color;
        });

        modalSetState(
          () {},
        );
      },
      child: Container(
        width: 38,
        height: 38,
        margin:
            const EdgeInsets.only(
          right: 10,
        ),
        decoration:
            BoxDecoration(
          color:
              color,
          shape:
              BoxShape.circle,
          border:
              Border.all(
            color:
                selected
                    ? Colors.white
                    : Colors.white24,
            width:
                selected
                    ? 3
                    : 1,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DRAWING
  // ============================================================

  void _toggleDrawing() {
    setState(() {
      _drawingMode =
          !_drawingMode;
    });

    if (_drawingMode) {
      _showDrawingTools();
    }
  }

  void _showDrawingTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      builder: (_) {
        return StatefulBuilder(
          builder:
              (context, modalSetState) {
            return SafeArea(
              child:
                  Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Text(
                      'Drawing Tools',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    Row(
                      children: [
                        _brushColorButton(
                          Colors.white,
                          modalSetState,
                        ),
                        _brushColorButton(
                          const Color(
                            0xFF00D9FF,
                          ),
                          modalSetState,
                        ),
                        _brushColorButton(
                          const Color(
                            0xFFB026FF,
                          ),
                          modalSetState,
                        ),
                        _brushColorButton(
                          const Color(
                            0xFFFF4D8D,
                          ),
                          modalSetState,
                        ),
                        _brushColorButton(
                          const Color(
                            0xFFFFD54F,
                          ),
                          modalSetState,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      children: [
                        const Text(
                          'Brush',
                          style:
                              TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                        Expanded(
                          child:
                              Slider(
                            min:
                                2,
                            max:
                                18,
                            value:
                                _brushSize,
                            onChanged:
                                (value) {
                              setState(
                                () {
                                  _brushSize =
                                      value;
                                },
                              );
                              modalSetState(
                                () {},
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton(
                            onPressed:
                                () {
                              setState(
                                () {
                                  _drawingPoints
                                      .clear();
                                },
                              );
                              Navigator.pop(
                                context,
                              );
                            },
                            style:
                                OutlinedButton
                                    .styleFrom(
                              foregroundColor:
                                  Colors.white,
                            ),
                            child:
                                const Text(
                              'Clear',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child:
                              ElevatedButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                context,
                              );
                            },
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF7B2FF7,
                              ),
                              foregroundColor:
                                  Colors.white,
                            ),
                            child:
                                const Text(
                              'Done',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BRUSH COLOR
  // ============================================================

  Widget _brushColorButton(
    Color color,
    StateSetter modalSetState,
  ) {
    final selected =
        _brushColor == color;

    return GestureDetector(
      onTap: () {
        setState(() {
          _brushColor =
              color;
        });

        modalSetState(
          () {},
        );
      },
      child: Container(
        width: 42,
        height: 42,
        margin:
            const EdgeInsets.only(
          right: 10,
        ),
        decoration:
            BoxDecoration(
          color:
              color,
          shape:
              BoxShape.circle,
          border:
              Border.all(
            color:
                selected
                    ? Colors.white
                    : Colors.white24,
            width:
                selected
                    ? 3
                    : 1,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMOJI
  // ============================================================

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      builder: (_) {
        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child:
                Wrap(
              spacing:
                  18,
              runSpacing:
                  18,
              children:
                  _emojiOptions
                      .map(
                (emoji) {
                  return GestureDetector(
                    onTap: () {
                      _textController
                          .text +=
                          emoji;

                      setState(
                        () {},
                      );

                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        Text(
                      emoji,
                      style:
                          const TextStyle(
                        fontSize:
                            34,
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // AI TOOLS
  // ============================================================

  void _showAiTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'ChattªX AI Studio',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        21,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Smart creative tools for your Story.',
                  style:
                      TextStyle(
                    color:
                        Colors.white54,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _aiOption(
                  Icons.auto_awesome_rounded,
                  'AI Enhance',
                  'Improve your photo automatically.',
                ),
                _aiOption(
                  Icons.edit_note_rounded,
                  'AI Caption',
                  'Generate a caption for your Story.',
                ),
                _aiOption(
                  Icons.local_fire_department_rounded,
                  'AI Effects',
                  'Create a futuristic visual effect.',
                ),
                _aiOption(
                  Icons.music_note_rounded,
                  'AI Music',
                  'Find a matching soundtrack.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // AI OPTION
  // ============================================================

  Widget _aiOption(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      leading:
          Container(
        width: 46,
        height: 46,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              const Color(
            0xFF7B2FF7,
          ).withValues(
            alpha: .16,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              const Color(
            0xFFB026FF,
          ),
        ),
      ),
      title:
          Text(
        title,
        style:
            const TextStyle(
          color:
              Colors.white,
          fontWeight:
              FontWeight.w800,
        ),
      ),
      subtitle:
          Text(
        subtitle,
        style:
            const TextStyle(
          color:
              Colors.white54,
          fontSize:
              12,
        ),
      ),
      onTap: () {
        Navigator.pop(
          context,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content:
                Text(
              'ChattªX AI Studio is ready for the AI integration.',
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MUTE
  // ============================================================

  void _toggleMute() {
    final controller =
        _videoController;

    if (controller == null) {
      return;
    }

    setState(() {
      _muted =
          !_muted;
    });

    controller.setVolume(
      _muted ? 0 : 1,
    );
  }

  // ============================================================
  // PRIVACY
  // ============================================================

  void _showPrivacySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          const Color(0xFF101827),
      builder: (_) {
        return SafeArea(
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Padding(
                padding:
                    EdgeInsets.all(
                  18,
                ),
                child:
                    Align(
                  alignment:
                      Alignment.centerLeft,
                  child:
                      Text(
                    'Who can see this Story?',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _privacyOption(
                'Everyone',
                Icons.public_rounded,
              ),
              _privacyOption(
                'Friends',
                Icons.people_alt_rounded,
              ),
              _privacyOption(
                'Close Friends',
                Icons.favorite_rounded,
              ),
              _privacyOption(
                'Only Me',
                Icons.lock_rounded,
              ),
              const SizedBox(
                height: 12,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PRIVACY OPTION
  // ============================================================

  Widget _privacyOption(
    String title,
    IconData icon,
  ) {
    final selected =
        _privacy == title;

    return ListTile(
      leading:
          Icon(
        icon,
        color: selected
            ? const Color(
                0xFFB026FF,
              )
            : Colors.white54,
      ),
      title:
          Text(
        title,
        style:
            TextStyle(
          color:
              selected
                  ? Colors.white
                  : Colors.white70,
          fontWeight:
              selected
                  ? FontWeight.w800
                  : FontWeight.w500,
        ),
      ),
      trailing:
          selected
              ? const Icon(
                  Icons.check_circle_rounded,
                  color:
                      Color(0xFFB026FF),
                )
              : null,
      onTap: () {
        setState(() {
          _privacy =
              title;
        });

        Navigator.pop(
          context,
        );
      },
    );
  }
}

// ============================================================================
// DRAWING POINT
// ============================================================================

class StoryDrawingPoint {
  final Offset? point;
  final Color color;
  final double size;

  const StoryDrawingPoint(
    this.point,
    this.color,
    this.size,
  );
}

// ============================================================================
// DRAWING PAINTER
// ============================================================================

class StoryDrawingPainter
    extends CustomPainter {
  final List<StoryDrawingPoint>
      points;

  const StoryDrawingPainter(
    this.points,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    for (int i = 0;
        i < points.length - 1;
        i++) {
      final current =
          points[i];

      final next =
          points[i + 1];

      if (current.point ==
              null ||
          next.point ==
              null) {
        continue;
      }

      final paint =
          Paint()
            ..color =
                current.color
            ..strokeWidth =
                current.size
            ..strokeCap =
                StrokeCap.round
            ..strokeJoin =
                StrokeJoin.round;

      canvas.drawLine(
        current.point!,
        next.point!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant StoryDrawingPainter oldDelegate,
  ) {
    return oldDelegate.points !=
        points;
  }
}

// ============================================================================
// STORY VIEWER
// ============================================================================

class StoryViewer
    extends StatefulWidget {
  final List<
      Map<String, dynamic>>
      stories;

  final int initialIndex;

  final String currentUserId;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.currentUserId,
  });

  @override
  State<StoryViewer> createState() =>
      _StoryViewerState();
}

class _StoryViewerState
    extends State<StoryViewer> {
  late PageController
      _pageController;

  late int _currentIndex;

  VideoPlayerController?
      _videoController;

  Timer? _imageTimer;

  bool _loadingVideo = false;

  @override
  void initState() {
    super.initState();

    _currentIndex =
        widget.initialIndex;

    _pageController =
        PageController(
      initialPage:
          _currentIndex,
    );

    _loadCurrentStory();
  }

  @override
  void dispose() {
    _imageTimer?.cancel();

    _videoController
        ?.dispose();

    _pageController
        .dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD STORY
  // ============================================================

  Future<void>
      _loadCurrentStory() async {
    _imageTimer?.cancel();

    await _videoController
        ?.dispose();

    _videoController =
        null;

    if (!mounted) {
      return;
    }

    final story =
        widget.stories[
            _currentIndex];

    final mediaType =
        story['mediaType']
                ?.toString() ??
            'image';

    if (mediaType ==
        'video') {
      setState(() {
        _loadingVideo =
            true;
      });

      final url =
          story['mediaUrl']
                  ?.toString() ??
              '';

      if (url.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingVideo =
                false;
          });
        }
        return;
      }

      final controller =
          VideoPlayerController
              .networkUrl(
        Uri.parse(url),
      );

      try {
        await controller
            .initialize();

        if (!mounted) {
          await controller
              .dispose();
          return;
        }

        _videoController =
            controller;

        controller.setLooping(
          false,
        );

        setState(() {
          _loadingVideo =
              false;
        });

        await controller.play();

        controller.addListener(
          _videoListener,
        );

        _markViewed(
          story,
        );
      } catch (e) {
        await controller
            .dispose();

        if (mounted) {
          setState(() {
            _loadingVideo =
                false;
          });
        }
      }
    } else {
      setState(() {
        _loadingVideo =
            false;
      });

      _markViewed(
        story,
      );

      _imageTimer =
          Timer(
        const Duration(
          seconds: 6,
        ),
        _nextStory,
      );
    }
  }

  // ============================================================
  // VIDEO LISTENER
  // ============================================================

  void _videoListener() {
    final controller =
        _videoController;

    if (controller ==
        null) {
      return;
    }

    if (!controller.value
        .isInitialized) {
      return;
    }

    if (controller.value.position >=
        controller.value.duration) {
      _nextStory();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // MARK VIEWED
  // ============================================================

  Future<void> _markViewed(
    Map<String, dynamic> story,
  ) async {
    final storyId =
        story['_id']?.toString();

    if (storyId == null ||
        storyId.isEmpty ||
        widget.currentUserId
            .isEmpty) {
      return;
    }

    if (story['userId'] ==
        widget.currentUserId) {
      return;
    }

    try {
      await FirebaseFirestore
          .instance
          .collection('stories')
          .doc(storyId)
          .update({
        'viewers':
            FieldValue.arrayUnion([
          widget.currentUserId,
        ]),
        'viewCount':
            FieldValue.increment(
          1,
        ),
      });
    } catch (_) {}
  }

  // ============================================================
  // NEXT
  // ============================================================

  void _nextStory() {
    if (_currentIndex >=
        widget.stories.length -
            1) {
      Navigator.pop(
        context,
      );
      return;
    }

    setState(() {
      _currentIndex++;
    });

    _pageController
        .animateToPage(
      _currentIndex,
      duration:
          const Duration(
        milliseconds: 250,
      ),
      curve:
          Curves.easeOut,
    );

    _loadCurrentStory();
  }

  // ============================================================
  // PREVIOUS
  // ============================================================

  void _previousStory() {
    if (_currentIndex <=
        0) {
      Navigator.pop(
        context,
      );
      return;
    }

    setState(() {
      _currentIndex--;
    });

    _pageController
        .animateToPage(
      _currentIndex,
      duration:
          const Duration(
        milliseconds: 250,
      ),
      curve:
          Curves.easeOut,
    );

    _loadCurrentStory();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final story =
        widget.stories[
            _currentIndex];

    final mediaType =
        story['mediaType']
                ?.toString() ??
            'image';

    final mediaUrl =
        story['mediaUrl']
                ?.toString() ??
            '';

    final username =
        story['username']
                ?.toString() ??
            'ChattªX User';

    final caption =
        story['caption']
                ?.toString() ??
            '';

    final textOverlay =
        story['textOverlay']
                ?.toString() ??
            '';

    return Dialog(
      backgroundColor:
          Colors.transparent,
      insetPadding:
          EdgeInsets.zero,
      child:
          Container(
        width:
            double.infinity,
        height:
            MediaQuery.of(
          context,
        ).size.height,
        color:
            Colors.black,
        child:
            Stack(
          children: [
            Positioned.fill(
              child:
                  mediaType ==
                          'video'
                      ? _buildVideo(
                          mediaUrl,
                        )
                      : _buildImage(
                          mediaUrl,
                        ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 160,
              child:
                  IgnorePointer(
                child:
                    DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.black
                            .withValues(
                          alpha: .75,
                        ),
                        Colors
                            .transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ====================================================
            // PROGRESS
            // ====================================================

            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child:
                  Row(
                children:
                    List.generate(
                  widget.stories.length,
                  (index) {
                    return Expanded(
                      child:
                          Container(
                        height:
                            3,
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              2,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              index <=
                                      _currentIndex
                                  ? Colors
                                      .white
                                  : Colors
                                      .white24,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ====================================================
            // HEADER
            // ====================================================

            Positioned(
              top: 28,
              left: 16,
              right: 8,
              child:
                  Row(
                children: [
                  Container(
                    width:
                        42,
                    height:
                        42,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      gradient:
                          LinearGradient(
                        colors: [
                          Color(
                            0xFF00D9FF,
                          ),
                          Color(
                            0xFF7B2FF7,
                          ),
                        ],
                      ),
                    ),
                    child:
                        ClipOval(
                      child:
                          _viewerProfile(
                        story['userImage']
                                ?.toString() ??
                            '',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width:
                        10,
                  ),
                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          username,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'ChattªX Story',
                          style:
                              TextStyle(
                            color:
                                Colors.white60,
                            fontSize:
                                11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.close_rounded,
                      color:
                          Colors.white,
                      size:
                          30,
                    ),
                  ),
                ],
              ),
            ),

            // ====================================================
            // TEXT OVERLAY
            // ====================================================

            if (textOverlay.isNotEmpty)
              Center(
                child:
                    Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        25,
                  ),
                  child:
                      Text(
                    textOverlay,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          28,
                      fontWeight:
                          FontWeight.w900,
                      shadows: [
                        Shadow(
                          blurRadius:
                              10,
                          color:
                              Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ====================================================
            // LEFT TAP
            // ====================================================

            Positioned(
              left: 0,
              top: 120,
              bottom: 120,
              width:
                  MediaQuery.of(
                        context,
                      ).size.width *
                      .35,
              child:
                  GestureDetector(
                behavior:
                    HitTestBehavior
                        .translucent,
                onTap:
                    _previousStory,
              ),
            ),

            // ====================================================
            // RIGHT TAP
            // ====================================================

            Positioned(
              right: 0,
              top: 120,
              bottom: 120,
              width:
                  MediaQuery.of(
                        context,
                      ).size.width *
                      .65,
              child:
                  GestureDetector(
                behavior:
                    HitTestBehavior
                        .translucent,
                onTap:
                    _nextStory,
              ),
            ),

            // ====================================================
            // CAPTION
            // ====================================================

            if (caption.isNotEmpty)
              Positioned(
                left: 22,
                right: 22,
                bottom: 45,
                child:
                    Text(
                  caption,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        21,
                    fontWeight:
                        FontWeight.w700,
                    shadows: [
                      Shadow(
                        blurRadius:
                            8,
                        color:
                            Colors.black,
                      ),
                    ],
                  ),
                ),
              ),

            if (_loadingVideo)
              const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage(
    String url,
  ) {
    if (url.isEmpty) {
      return Container(
        decoration:
            const BoxDecoration(
          gradient:
              LinearGradient(
            colors: [
              Color(0xFF7B2FF7),
              Color(0xFF050816),
            ],
          ),
        ),
        child:
            const Center(
          child:
              Icon(
            Icons.person_rounded,
            color:
                Colors.white38,
            size:
                120,
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder:
          (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color:
              const Color(
            0xFF050816,
          ),
          child:
              const Center(
            child:
                Icon(
              Icons
                  .broken_image_rounded,
              color:
                  Colors.white38,
              size:
                  80,
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Widget _buildVideo(
    String url,
  ) {
    final controller =
        _videoController;

    if (controller ==
            null ||
        !controller.value
            .isInitialized) {
      return Container(
        color:
            Colors.black,
        child:
            const Center(
          child:
              CircularProgressIndicator(
            color:
                Colors.white,
          ),
        ),
      );
    }

    return Center(
      child:
          AspectRatio(
        aspectRatio:
            controller.value
                .aspectRatio,
        child:
            VideoPlayer(
          controller,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _viewerProfile(
    String url,
  ) {
    if (url.isEmpty) {
      return const Icon(
        Icons.person_rounded,
        color:
            Colors.white,
        size:
            24,
      );
    }

    return Image.network(
      url,
      fit:
          BoxFit.cover,
      errorBuilder:
          (
        context,
        error,
        stackTrace,
      ) {
        return const Icon(
          Icons.person_rounded,
          color:
              Colors.white,
          size:
              24,
        );
      },
    );
  }
}