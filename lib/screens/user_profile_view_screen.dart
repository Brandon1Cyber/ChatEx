import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userImage;

  const UserProfileViewScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userImage,
  });

  @override
  State<UserProfileViewScreen> createState() =>
      _UserProfileViewScreenState();
}

class _UserProfileViewScreenState
    extends State<UserProfileViewScreen> {
  // ===========================================================================
  // CHATTªX COLORS
  // ===========================================================================

  static const Color background = Color(0xFF050816);
  static const Color header = Color(0xFF0A1022);
  static const Color card = Color(0xFF0C1428);
  static const Color button = Color(0xFF141F39);

  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color purpleBright = Color(0xFFB026FF);
  static const Color pink = Color(0xFFD764FF);
  static const Color onlineColor = Color(0xFF39FF88);

  // ===========================================================================
  // FIREBASE
  // ===========================================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ===========================================================================
  // PROFILE
  // ===========================================================================

  bool loading = true;
  bool relationshipLoading = true;
  bool followLoading = false;

  String name = "";
  String username = "";
  String bio = "";
  String about = "";
  String location = "";
  String profileImage = "";

  bool isOnline = false;
  bool verified = false;

  DateTime? lastSeen;
  DateTime? joinedDate;

  // ===========================================================================
  // REAL-TIME SOCIAL COUNTS
  // ===========================================================================

  int followersCount = 0;
  int followingCount = 0;
  int friendsCount = 0;

  // ===========================================================================
  // RELATIONSHIP
  // ===========================================================================

  bool isFollowing = false;
  bool isFollowedBy = false;
  bool isFriend = false;

  // ===========================================================================
  // OTHER PROFILE DATA
  // ===========================================================================

  int sharedMediaCount = 0;
  int sharedFilesCount = 0;
  int sharedLinksCount = 0;

  bool notificationsMuted = false;
  bool disappearingMessages = false;
  bool dualLockEnabled = false;

  // ===========================================================================
  // STREAMS
  // ===========================================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
      _profileStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
      _myFollowingStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
      _theirFollowingStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
      _friendStream;

  // ===========================================================================
  // CURRENT USER
  // ===========================================================================

  String? get currentUserId =>
      _auth.currentUser?.uid;

  bool get isOwnProfile =>
      currentUserId == widget.userId;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    name = widget.userName;
    profileImage = widget.userImage ?? "";

    _loadProfile();

    if (!isOwnProfile) {
      _setupRelationshipStreams();
    }
  }

  // ===========================================================================
  // LOAD PROFILE
  // ===========================================================================

  Future<void> _loadProfile() async {
    try {
      final snapshot = await _firestore
          .collection("users")
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      if (!snapshot.exists) {
        setState(() {
          loading = false;
        });
        return;
      }

      _applyProfileData(snapshot.data() ?? {});

      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint("Profile error: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ===========================================================================
  // APPLY PROFILE DATA
  // ===========================================================================

  void _applyProfileData(
    Map<String, dynamic> data,
  ) {
    name = _stringValue(
      data["name"],
      widget.userName,
    );

    username = _stringValue(
      data["username"],
      data["userName"],
    );

    bio = _stringValue(
      data["bio"],
      "",
    );

    about = _stringValue(
      data["about"],
      "",
    );

    location = _stringValue(
      data["locationText"],
      data["location"],
    );

    final image = _stringValue(
      data["profileImage"],
      data["photoURL"],
    );

    if (image.isNotEmpty) {
      profileImage = image;
    }

    isOnline = data["isOnline"] == true;

    verified =
        data["verified"] == true ||
        data["isVerified"] == true;

    notificationsMuted =
        data["notificationsMuted"] == true;

    disappearingMessages =
        data["disappearingMessages"] == true;

    dualLockEnabled =
        data["dualLockEnabled"] == true;

    lastSeen = _dateValue(
      data["lastSeen"],
    );

    joinedDate = _dateValue(
      data["createdAt"],
    );

    // ========================================================================
    // COUNTERS
    // ========================================================================

    followersCount = _intValue(
      data["followersCount"],
    );

    followingCount = _intValue(
      data["followingCount"],
    );

    friendsCount = _intValue(
      data["friendsCount"],
    );

    sharedMediaCount = _intValue(
      data["sharedMediaCount"],
    );

    sharedFilesCount = _intValue(
      data["sharedFilesCount"],
    );

    sharedLinksCount = _intValue(
      data["sharedLinksCount"],
    );
  }

  // ===========================================================================
  // REAL-TIME PROFILE LISTENER
  // ===========================================================================

  void _setupRelationshipStreams() {
    final myUid = currentUserId;

    if (myUid == null) {
      relationshipLoading = false;
      return;
    }

    _profileStream = _firestore
        .collection("users")
        .doc(widget.userId)
        .snapshots();

    _myFollowingStream = _firestore
        .collection("users")
        .doc(myUid)
        .collection("following")
        .doc(widget.userId)
        .snapshots();

    _theirFollowingStream = _firestore
        .collection("users")
        .doc(widget.userId)
        .collection("following")
        .doc(myUid)
        .snapshots();

    _friendStream = _firestore
        .collection("users")
        .doc(myUid)
        .collection("friends")
        .doc(widget.userId)
        .snapshots();

    _listenToRelationshipStreams();
  }

  // ===========================================================================
  // RELATIONSHIP LISTENERS
  // ===========================================================================

  void _listenToRelationshipStreams() {
    _profileStream?.listen((snapshot) {
      if (!mounted) return;

      final data = snapshot.data();

      if (data == null) return;

      setState(() {
        _applyProfileData(data);
      });
    });

    _myFollowingStream?.listen((snapshot) {
      if (!mounted) return;

      setState(() {
        isFollowing = snapshot.exists;
        relationshipLoading = false;
      });
    });

    _theirFollowingStream?.listen((snapshot) {
      if (!mounted) return;

      setState(() {
        isFollowedBy = snapshot.exists;
      });
    });

    _friendStream?.listen((snapshot) {
      if (!mounted) return;

      setState(() {
        isFriend = snapshot.exists;
      });
    });
  }

  // ===========================================================================
  // FOLLOW / UNFOLLOW
  // ===========================================================================

  Future<void> _toggleFollow() async {
    final myUid = currentUserId;

    if (myUid == null ||
        isOwnProfile ||
        followLoading) {
      return;
    }

    setState(() {
      followLoading = true;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          // ================================================================
          // DOCUMENT REFERENCES
          // ================================================================

          final myUserRef = _firestore
              .collection("users")
              .doc(myUid);

          final targetUserRef = _firestore
              .collection("users")
              .doc(widget.userId);

          final myFollowingRef = myUserRef
              .collection("following")
              .doc(widget.userId);

          final targetFollowersRef = targetUserRef
              .collection("followers")
              .doc(myUid);

          final targetFollowingMeRef = targetUserRef
              .collection("following")
              .doc(myUid);

          final myFriendRef = myUserRef
              .collection("friends")
              .doc(widget.userId);

          final targetFriendRef = targetUserRef
              .collection("friends")
              .doc(myUid);

          // ================================================================
          // READ
          // ================================================================

          final myUserSnapshot =
              await transaction.get(myUserRef);

          final targetUserSnapshot =
              await transaction.get(targetUserRef);

          final myFollowingSnapshot =
              await transaction.get(myFollowingRef);

          final targetFollowingMeSnapshot =
              await transaction.get(
            targetFollowingMeRef,
          );

          final myFriendSnapshot =
              await transaction.get(myFriendRef);

          final targetFriendSnapshot =
              await transaction.get(targetFriendRef);

          if (!targetUserSnapshot.exists) {
            throw Exception(
              "User no longer exists.",
            );
          }

          final myData =
              myUserSnapshot.data() ??
                  <String, dynamic>{};

          final targetData =
              targetUserSnapshot.data() ??
                  <String, dynamic>{};

          int currentFollowingCount =
              _intValue(
            myData["followingCount"],
          );

          int targetFollowersCount =
              _intValue(
            targetData["followersCount"],
          );

          int currentFriendsCount =
              _intValue(
            myData["friendsCount"],
          );

          int targetFriendsCount =
              _intValue(
            targetData["friendsCount"],
          );

          // ================================================================
          // UNFOLLOW
          // ================================================================

          if (myFollowingSnapshot.exists) {
            transaction.delete(
              myFollowingRef,
            );

            transaction.delete(
              targetFollowersRef,
            );

            currentFollowingCount =
                currentFollowingCount > 0
                    ? currentFollowingCount - 1
                    : 0;

            targetFollowersCount =
                targetFollowersCount > 0
                    ? targetFollowersCount - 1
                    : 0;

            // ------------------------------------------------------------
            // REMOVE FRIENDSHIP
            // ------------------------------------------------------------

            if (myFriendSnapshot.exists ||
                targetFriendSnapshot.exists) {
              transaction.delete(
                myFriendRef,
              );

              transaction.delete(
                targetFriendRef,
              );

              currentFriendsCount =
                  currentFriendsCount > 0
                      ? currentFriendsCount - 1
                      : 0;

              targetFriendsCount =
                  targetFriendsCount > 0
                      ? targetFriendsCount - 1
                      : 0;
            }

            transaction.update(
              myUserRef,
              {
                "followingCount":
                    currentFollowingCount,
                "friendsCount":
                    currentFriendsCount,
              },
            );

            transaction.update(
              targetUserRef,
              {
                "followersCount":
                    targetFollowersCount,
                "friendsCount":
                    targetFriendsCount,
              },
            );
          }

          // ================================================================
          // FOLLOW
          // ================================================================

          else {
            transaction.set(
              myFollowingRef,
              {
                "userId": widget.userId,
                "createdAt":
                    FieldValue.serverTimestamp(),
              },
            );

            transaction.set(
              targetFollowersRef,
              {
                "userId": myUid,
                "createdAt":
                    FieldValue.serverTimestamp(),
              },
            );

            currentFollowingCount++;

            targetFollowersCount++;

            // ------------------------------------------------------------
            // AUTOMATIC FRIEND DETECTION
            // ------------------------------------------------------------

            final becomesFriend =
                targetFollowingMeSnapshot.exists;

            if (becomesFriend &&
                !myFriendSnapshot.exists &&
                !targetFriendSnapshot.exists) {
              final now =
                  FieldValue.serverTimestamp();

              transaction.set(
                myFriendRef,
                {
                  "userId": widget.userId,
                  "createdAt": now,
                },
              );

              transaction.set(
                targetFriendRef,
                {
                  "userId": myUid,
                  "createdAt": now,
                },
              );

              currentFriendsCount++;
              targetFriendsCount++;
            }

            transaction.update(
              myUserRef,
              {
                "followingCount":
                    currentFollowingCount,
                "friendsCount":
                    currentFriendsCount,
              },
            );

            transaction.update(
              targetUserRef,
              {
                "followersCount":
                    targetFollowersCount,
                "friendsCount":
                    targetFriendsCount,
              },
            );
          }
        },
      );

      if (!mounted) return;

      setState(() {
        isFollowing = !isFollowing;
      });
    } catch (e) {
      debugPrint(
        "Follow/unfollow error: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Could not update follow status.",
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        followLoading = false;
      });
    }
  }

  // ===========================================================================
  // IMAGE PROVIDER
  // ===========================================================================

  ImageProvider? get imageProvider {
    if (profileImage.trim().isEmpty) {
      return null;
    }

    if (profileImage.startsWith("http://") ||
        profileImage.startsWith("https://")) {
      return NetworkImage(profileImage);
    }

    return AssetImage(profileImage);
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  String get statusText {
    if (isOnline) {
      return "Online";
    }

    if (lastSeen == null) {
      return "Offline";
    }

    final time =
        TimeOfDay.fromDateTime(
      lastSeen!,
    ).format(context);

    return "Last seen today at $time";
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: loading
            ? _buildLoading()
            : _buildProfile(),
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cyan,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PROFILE
  // ===========================================================================

  Widget _buildProfile() {
    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: background,
          surfaceTintColor:
              Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: () =>
                Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          title: const Text(
            "Profile",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _showMoreMenu,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 14),

              GestureDetector(
                onTap: _openProfilePhoto,
                child: _buildProfilePhoto(),
              ),

              const SizedBox(height: 16),

              _buildName(),

              const SizedBox(height: 8),

              _buildStatus(),

              const SizedBox(height: 18),

              // ============================================================
              // LIVE SOCIAL COUNTERS
              // ============================================================

              _buildSocialStats(),

              const SizedBox(height: 18),

              if (bio.isNotEmpty ||
                  about.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 34,
                  ),
                  child: Text(
                    bio.isNotEmpty
                        ? bio
                        : about,
                    textAlign:
                        TextAlign.center,
                    maxLines: 4,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),

              const SizedBox(height: 22),

              // ============================================================
              // FOLLOW BUTTON
              // ============================================================

              if (!isOwnProfile)
                _buildFollowButton(),

              const SizedBox(height: 10),

              // ============================================================
              // MESSAGE / CALL / VIDEO
              // ============================================================

              _buildActionButtons(),

              const SizedBox(height: 22),

              if (isFriend && !isOwnProfile)
                _buildFriendBanner(),

              if (about.isNotEmpty)
                _buildAboutCard(),

              _buildInformationCard(),

              _buildSharedContent(),

              _buildChatSettings(),

              _buildPrivacyCard(),

              _buildDangerZone(),

              const SizedBox(height: 35),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // NAME
  // ===========================================================================

  Widget _buildName() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              name.isEmpty
                  ? widget.userName
                  : name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 7),
            _verifiedBadge(),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  Widget _buildStatus() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isOnline
                ? onlineColor
                : Colors.white24,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FOLLOW BUTTON
  // ===========================================================================

  Widget _buildFollowButton() {
    final friend = isFriend;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: followLoading
                ? null
                : _toggleFollow,
            borderRadius:
                BorderRadius.circular(16),
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 220,
              ),
              decoration: BoxDecoration(
                gradient: isFollowing
                    ? null
                    : const LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          cyan,
                          purple,
                        ],
                      ),
                color: isFollowing
                    ? button
                    : null,
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: isFollowing
                      ? friend
                          ? pink.withValues(
                              alpha: .35,
                            )
                          : cyan.withValues(
                              alpha: .2,
                            )
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: followLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            friend
                                ? Icons
                                    .handshake_rounded
                                : isFollowing
                                    ? Icons
                                        .check_rounded
                                    : Icons
                                        .person_add_alt_1_rounded,
                            color:
                                Colors.white,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            friend
                                ? "Friends"
                                : isFollowing
                                    ? "Following"
                                    : "Follow",
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FRIEND BANNER
  // ===========================================================================

  Widget _buildFriendBanner() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        12,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            purple.withValues(alpha: .15),
            pink.withValues(alpha: .10),
          ],
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              purple.withValues(alpha: .18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.handshake_rounded,
            color: pink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You and $name are friends",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: cyan,
            size: 18,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SOCIAL STATS
  // ===========================================================================

  Widget _buildSocialStats() {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      padding:
          const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              cyan.withValues(alpha: .08),
        ),
        boxShadow: [
          BoxShadow(
            color:
                purple.withValues(alpha: .07),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _socialStat(
              value: followersCount,
              label: "Followers",
              icon:
                  Icons.people_alt_rounded,
              color: cyan,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _socialStat(
              value: followingCount,
              label: "Following",
              icon:
                  Icons.person_add_alt_1_rounded,
              color: purpleBright,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _socialStat(
              value: friendsCount,
              label: "Friends",
              icon:
                  Icons.handshake_rounded,
              color: pink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialStat({
    required int value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(height: 6),
        Text(
          _formatCount(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 38,
      color: Colors.white10,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M";
    }

    if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K";
    }

    return count.toString();
  }

  // ===========================================================================
  // ACTION BUTTONS
  // ===========================================================================

  Widget _buildActionButtons() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              Icons.chat_bubble_rounded,
              "Message",
              cyan,
              () {
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              Icons.call_rounded,
              "Call",
              Colors.white,
              () {},
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              Icons.videocam_rounded,
              "Video",
              purpleBright,
              () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: card,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  color.withValues(alpha: .15),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PROFILE PHOTO
  // ===========================================================================

  Widget _buildProfilePhoto() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 148,
          height: 148,
          decoration:
              const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cyan,
                purple,
                pink,
              ],
            ),
          ),
        ),
        Container(
          width: 141,
          height: 141,
          decoration:
              const BoxDecoration(
            shape: BoxShape.circle,
            color: background,
          ),
        ),
        Hero(
          tag:
              "profile_${widget.userId}",
          child: CircleAvatar(
            radius: 65,
            backgroundColor: button,
            backgroundImage:
                imageProvider,
            child: imageProvider == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white38,
                    size: 60,
                  )
                : null,
          ),
        ),
        Positioned(
          right: 9,
          bottom: 9,
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: isOnline
                  ? onlineColor
                  : Colors.white24,
              shape: BoxShape.circle,
              border: Border.all(
                color: background,
                width: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // VERIFIED
  // ===========================================================================

  Widget _verifiedBadge() {
    return Container(
      width: 21,
      height: 21,
      decoration:
          const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            cyan,
            purple,
          ],
        ),
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  // ===========================================================================
  // ABOUT
  // ===========================================================================

  Widget _buildAboutCard() {
    return _sectionCard(
      title: "About",
      icon: Icons.info_outline_rounded,
      iconColor: purpleBright,
      children: [
        Text(
          about,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // INFORMATION
  // ===========================================================================

  Widget _buildInformationCard() {
    return _sectionCard(
      title: "Information",
      icon:
          Icons.person_outline_rounded,
      children: [
        _informationRow(
          Icons.location_on_rounded,
          "Location",
          location.isEmpty
              ? "Not available"
              : location,
        ),
        _divider(),
        _informationRow(
          Icons.calendar_month_rounded,
          "Joined ChattªX",
          joinedDate == null
              ? "Unknown"
              : _formatJoinedDate(
                  joinedDate!,
                ),
        ),
        _divider(),
        _informationRow(
          Icons.fingerprint_rounded,
          "ChattªX ID",
          widget.userId,
          trailing: Icons.copy_rounded,
          onTap: _copyUserId,
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED CONTENT
  // ===========================================================================

  Widget _buildSharedContent() {
    return _sectionCard(
      title: "Shared content",
      icon:
          Icons.folder_copy_rounded,
      iconColor: purpleBright,
      children: [
        _featureRow(
          Icons.photo_library_rounded,
          "Media",
          sharedMediaCount == 0
              ? "Photos and videos"
              : "$sharedMediaCount items",
          () {},
        ),
        _divider(),
        _featureRow(
          Icons.insert_drive_file_rounded,
          "Files",
          sharedFilesCount == 0
              ? "Shared documents and files"
              : "$sharedFilesCount files",
          () {},
        ),
        _divider(),
        _featureRow(
          Icons.link_rounded,
          "Links",
          sharedLinksCount == 0
              ? "Shared links"
              : "$sharedLinksCount links",
          () {},
        ),
      ],
    );
  }

  // ===========================================================================
  // CHAT SETTINGS
  // ===========================================================================

  Widget _buildChatSettings() {
    return _sectionCard(
      title: "Chat settings",
      icon: Icons.tune_rounded,
      iconColor: cyan,
      children: [
        _switchRow(
          Icons.notifications_rounded,
          "Mute notifications",
          "Stop notifications from this chat",
          notificationsMuted,
          (value) {
            setState(() {
              notificationsMuted =
                  value;
            });
          },
        ),
        _divider(),
        _featureRow(
          Icons.search_rounded,
          "Search in conversation",
          "Find messages quickly",
          () {},
        ),
        _divider(),
        _featureRow(
          Icons.auto_delete_rounded,
          "Disappearing messages",
          disappearingMessages
              ? "Enabled"
              : "Disabled",
          _showDisappearingMessages,
        ),
      ],
    );
  }

  // ===========================================================================
  // PRIVACY
  // ===========================================================================

  Widget _buildPrivacyCard() {
    return _sectionCard(
      title: "Privacy & security",
      icon: Icons.security_rounded,
      iconColor: cyan,
      children: [
        _featureRow(
          Icons.lock_outline_rounded,
          "Encryption",
          "Messages are protected",
          _showEncryptionInfo,
        ),
        _divider(),
        _featureRow(
          Icons.verified_user_rounded,
          "Security verification",
          "Verify this contact",
          _showSecurityVerification,
        ),
      ],
    );
  }

  // ===========================================================================
  // DANGER
  // ===========================================================================

  Widget _buildDangerZone() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        0,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent
              .withValues(alpha: .12),
        ),
      ),
      child: Column(
        children: [
          _dangerRow(
            Icons.block_rounded,
            "Block ${name.isEmpty ? widget.userName : name}",
            _confirmBlock,
          ),
          const Divider(
            color: Colors.white10,
            height: 1,
          ),
          _dangerRow(
            Icons.flag_rounded,
            "Report user",
            _reportUser,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION CARD
  // ===========================================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color iconColor = cyan,
  }) {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        14,
        7,
        14,
        7,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: .045,
          ),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          15,
          14,
          15,
          8,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(
                    color:
                        iconColor.withValues(
                      alpha: .12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INFORMATION ROW
  // ===========================================================================

  Widget _informationRow(
    IconData icon,
    String title,
    String value, {
    IconData? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: cyan,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Icon(
                trailing,
                color: Colors.white38,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FEATURE ROW
  // ===========================================================================

  Widget _featureRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(13),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                color: button,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color: cyan,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SWITCH
  // ===========================================================================

  Widget _switchRow(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: button,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color: cyan,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cyan,
            activeTrackColor:
                cyan.withValues(
              alpha: .22,
            ),
            inactiveThumbColor:
                Colors.white38,
            inactiveTrackColor:
                Colors.white10,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DANGER ROW
  // ===========================================================================

  Widget _dangerRow(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.redAccent,
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIVIDER
  // ===========================================================================

  Widget _divider() {
    return const Divider(
      color: Colors.white10,
      height: 1,
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================

  Widget _buildTopBar() {
    return Container(
      height: 56,
      color: background,
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const Text(
            "Profile",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROFILE PHOTO
  // ===========================================================================

  void _openProfilePhoto() {
    final provider = imageProvider;

    if (provider == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration:
            const Duration(
          milliseconds: 300,
        ),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return ProfilePhotoViewer(
            image: provider,
            name: name,
            heroTag:
                "profile_${widget.userId}",
          );
        },
      ),
    );
  }

  // ===========================================================================
  // COPY ID
  // ===========================================================================

  Future<void> _copyUserId() async {
    await Clipboard.setData(
      ClipboardData(
        text: widget.userId,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text("ChattªX ID copied"),
      ),
    );
  }

  // ===========================================================================
  // JOINED DATE
  // ===========================================================================

  String _formatJoinedDate(
    DateTime date,
  ) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return "${months[date.month - 1]} ${date.year}";
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _stringValue(
    dynamic first,
    dynamic second,
  ) {
    if (first is String &&
        first.trim().isNotEmpty) {
      return first.trim();
    }

    if (second is String &&
        second.trim().isNotEmpty) {
      return second.trim();
    }

    return "";
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // ===========================================================================
  // MORE MENU
  // ===========================================================================

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          decoration:
              const BoxDecoration(
            color: header,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                _bottomMenuItem(
                  Icons.share_rounded,
                  "Share profile",
                  () =>
                      Navigator.pop(context),
                ),
                _bottomMenuItem(
                  Icons.flag_rounded,
                  "Report user",
                  () {
                    Navigator.pop(context);
                    _reportUser();
                  },
                  danger: true,
                ),
                _bottomMenuItem(
                  Icons.block_rounded,
                  "Block user",
                  () {
                    Navigator.pop(context);
                    _confirmBlock();
                  },
                  danger: true,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color:
            danger ? Colors.redAccent : cyan,
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              danger
                  ? Colors.redAccent
                  : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===========================================================================
  // DISAPPEARING
  // ===========================================================================

  void _showDisappearingMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          decoration:
              const BoxDecoration(
            color: header,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text(
                  "Disappearing messages",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _durationOption(
                  "Off",
                  false,
                ),
                _durationOption(
                  "24 hours",
                  true,
                ),
                _durationOption(
                  "7 days",
                  true,
                ),
                _durationOption(
                  "30 days",
                  true,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _durationOption(
    String title,
    bool enabled,
  ) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);

        setState(() {
          disappearingMessages =
              enabled;
        });
      },
      leading: Icon(
        enabled
            ? Icons.timer_rounded
            : Icons.timer_off_rounded,
        color: cyan,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===========================================================================
  // ENCRYPTION
  // ===========================================================================

  void _showEncryptionInfo() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: header,
          title: const Text(
            "Encryption",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            "Messages and calls in this conversation are protected by ChattªX security.",
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
                  const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SECURITY
  // ===========================================================================

  void _showSecurityVerification() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          padding:
              const EdgeInsets.all(22),
          decoration:
              const BoxDecoration(
            color: header,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: cyan,
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Security verification",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child:
                      ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          purple,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    child:
                        const Text(
                      "Verify",
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BLOCK
  // ===========================================================================

  Future<void> _confirmBlock() async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: header,
          title: const Text(
            "Block user?",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: Text(
            "You won't receive messages or calls from $name.",
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text("Cancel"),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text(
                "Block",
                style: TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final uid = currentUserId;

    if (uid == null) return;

    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .set(
        {
          "blockedUsers":
              FieldValue.arrayUnion([
            widget.userId,
          ]),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("User blocked"),
        ),
      );
    } catch (e) {
      debugPrint(
        "Block error: $e",
      );
    }
  }

  // ===========================================================================
  // REPORT
  // ===========================================================================

  Future<void> _reportUser() async {
    final uid = currentUserId;

    if (uid == null) return;

    final reason =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return Container(
          decoration:
              const BoxDecoration(
            color: header,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                const Text(
                  "Report user",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                _reportReason("Spam"),
                _reportReason(
                  "Harassment",
                ),
                _reportReason(
                  "Scam or fraud",
                ),
                _reportReason(
                  "Inappropriate content",
                ),
                _reportReason("Other"),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    if (reason == null) return;

    try {
      await _firestore
          .collection("reports")
          .add({
        "type": "user",
        "reason": reason,
        "reportedUserId":
            widget.userId,
        "reportedBy": uid,
        "timestamp":
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Report submitted"),
        ),
      );
    } catch (e) {
      debugPrint(
        "Report error: $e",
      );
    }
  }

  Widget _reportReason(
    String title,
  ) {
    return ListTile(
      onTap: () =>
          Navigator.pop(
        context,
        title,
      ),
      leading: const Icon(
        Icons.flag_outlined,
        color: Colors.redAccent,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE PHOTO VIEWER
// ============================================================================

class ProfilePhotoViewer
    extends StatelessWidget {
  final ImageProvider image;
  final String name;
  final String heroTag;

  const ProfilePhotoViewer({
    super.key,
    required this.image,
    required this.name,
    required this.heroTag,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child:
                  InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top:
                MediaQuery.of(context)
                        .padding
                        .top +
                    8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  child: BackdropFilter(
                    filter:
                        ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                    ),
                    child: Container(
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.black45,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            Navigator.pop(
                          context,
                        ),
                        icon: const Icon(
                          Icons
                              .arrow_back_rounded,
                          color:
                              Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(
                        sigmaX: 12,
                        sigmaY: 12,
                      ),
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.black45,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom:
                MediaQuery.of(context)
                        .padding
                        .bottom +
                    20,
            left: 0,
            right: 0,
            child: const IgnorePointer(
              child: Center(
                child: Text(
                  "Pinch to zoom",
                  style: TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}