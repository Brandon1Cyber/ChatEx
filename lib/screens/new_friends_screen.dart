import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';

class NewFriendsScreen extends StatefulWidget {
  const NewFriendsScreen({super.key});

  @override
  State<NewFriendsScreen> createState() =>
      _NewFriendsScreenState();
}

class _NewFriendsScreenState extends State<NewFriendsScreen> {
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

  final LocationService _locationService =
      LocationService();

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchTimer;

  String _searchQuery = '';

  bool _loadingSearch = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _searchResults = [];

  // ============================================================
  // LOCATION
  // ============================================================

  double? _myLatitude;

  double? _myLongitude;

  bool _locationLoading = true;

  bool _locationEnabled = false;

  double _nearbyRadiusKm = 25.0;

  // ============================================================
  // THEME
  // ============================================================

  static const Color background =
      Color(0xFF050816);

  static const Color card =
      Color(0xFF0B1220);

  static const Color card2 =
      Color(0xFF111827);

  static const Color cyan =
      Color(0xFF00D9FF);

  static const Color purple =
      Color(0xFF8B2CF8);

  static const Color green =
      Color(0xFF34F58A);

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get myUid =>
      _auth.currentUser?.uid ?? '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadMyLocation();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD MY LOCATION
  // ============================================================

  Future<void> _loadMyLocation() async {
    try {
      final position =
          await _locationService.getCurrentLocation();

      if (!mounted) return;

      if (position == null) {
        setState(() {
          _locationLoading = false;
          _locationEnabled = false;
        });

        return;
      }

      setState(() {
        _myLatitude = position.latitude;
        _myLongitude = position.longitude;
        _locationLoading = false;
        _locationEnabled = true;
      });

      await _locationService.saveLocation();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _locationLoading = false;
        _locationEnabled = false;
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    final query = value.trim();

    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _loadingSearch = false;
      });

      return;
    }

    _searchTimer = Timer(
      const Duration(milliseconds: 450),
      () => _searchUsers(query),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;

    setState(() {
      _loadingSearch = true;
    });

    try {
      final lowerQuery =
          query.toLowerCase();

      final snapshot = await _firestore
          .collection('users')
          .get();

      final results = snapshot.docs
          .where((doc) {
            if (doc.id == myUid) {
              return false;
            }

            final data = doc.data();

            final name =
                (data['name'] ?? '')
                    .toString()
                    .toLowerCase();

            final displayName =
                (data['displayName'] ?? '')
                    .toString()
                    .toLowerCase();

            final username =
                (data['username'] ?? '')
                    .toString()
                    .toLowerCase();

            final email =
                (data['email'] ?? '')
                    .toString()
                    .toLowerCase();

            return name.contains(lowerQuery) ||
                displayName.contains(lowerQuery) ||
                username.contains(lowerQuery) ||
                email.contains(lowerQuery);
          })
          .take(30)
          .toList();

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _loadingSearch = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _loadingSearch = false;
      });
    }
  }

  // ============================================================
  // SEND FRIEND REQUEST
  // ============================================================

  Future<void> _sendFriendRequest(
    String receiverId,
  ) async {
    if (myUid.isEmpty ||
        receiverId.isEmpty ||
        receiverId == myUid) {
      return;
    }

    try {
      // Check if I already sent a request.
      final sent = await _firestore
          .collection('friend_requests')
          .where(
            'senderId',
            isEqualTo: myUid,
          )
          .where(
            'receiverId',
            isEqualTo: receiverId,
          )
          .limit(1)
          .get();

      if (sent.docs.isNotEmpty) {
        _showMessage(
          'Friend request already sent',
        );

        return;
      }

      // Check if the other person already
      // sent me a request.
      final received = await _firestore
          .collection('friend_requests')
          .where(
            'senderId',
            isEqualTo: receiverId,
          )
          .where(
            'receiverId',
            isEqualTo: myUid,
          )
          .limit(1)
          .get();

      if (received.docs.isNotEmpty) {
        _showMessage(
          'This person already sent you a request',
        );

        return;
      }

      await _firestore
          .collection('friend_requests')
          .add({
        'senderId': myUid,
        'receiverId': receiverId,
        'status': 'pending',
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Friend request sent',
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showMessage(
        'Could not send friend_requests',
      );
    }
  }

  // ============================================================
  // REQUEST STATUS
  // ============================================================

  Future<String> _getRequestStatus(
    String otherUserId,
  ) async {
    if (myUid.isEmpty) {
      return 'none';
    }

    try {
      final sent = await _firestore
          .collection('friend_requests')
          .where(
            'senderId',
            isEqualTo: myUid,
          )
          .where(
            'receiverId',
            isEqualTo: otherUserId,
          )
          .limit(1)
          .get();

      if (sent.docs.isNotEmpty) {
        return sent.docs.first
                .data()['status']
                ?.toString() ??
            'pending';
      }

      final received = await _firestore
          .collection('friend_requests')
          .where(
            'senderId',
            isEqualTo: otherUserId,
          )
          .where(
            'receiverId',
            isEqualTo: myUid,
          )
          .limit(1)
          .get();

      if (received.docs.isNotEmpty) {
        return 'received';
      }

      return 'none';
    } catch (_) {
      return 'none';
    }
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double? _userDistance(
    Map<String, dynamic> data,
  ) {
    if (_myLatitude == null ||
        _myLongitude == null) {
      return null;
    }

    final latitude =
        _toDouble(data['latitude']);

    final longitude =
        _toDouble(data['longitude']);

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return _calculateDistance(
      _myLatitude!,
      _myLongitude!,
      latitude,
      longitude,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat =
        _degreesToRadians(lat2 - lat1);

    final dLon =
        _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) *
                math.sin(dLat / 2) +
            math.cos(
                  _degreesToRadians(lat1),
                ) *
                math.cos(
                  _degreesToRadians(lat2),
                ) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c =
        2 * math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees *
        math.pi /
        180;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor: card2,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            SliverToBoxAdapter(
              child:
                  _buildFriendRequestTopButton(),
            ),

            SliverToBoxAdapter(
              child: _buildSearchBar(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 10),
            ),

            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child:
                    _buildSearchSection(),
              )
            else ...[
              SliverToBoxAdapter(
                child:
                    _buildFriendRequestsSection(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'People Near You',
                  Icons.location_on_outlined,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildPeopleSection(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'People You May Know',
                  Icons.people_outline,
                ),
              ),

              SliverToBoxAdapter(
                child:
                    _buildPeopleMayKnow(),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  'Recently Joined',
                  Icons.auto_awesome_outlined,
                ),
              ),

              SliverToBoxAdapter(
                child:
                    _buildRecentlyJoined(),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        16,
        8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: card2,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'New Friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Discover people on ChattªX',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: _showFriendSettings,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: card2,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FRIEND REQUESTS TOP BUTTON
  // ============================================================

  Widget _buildFriendRequestTopButton() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('friend_requests')
          .where(
            'receiverId',
            isEqualTo: myUid,
          )
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;

        if (snapshot.hasData) {
          count =
              snapshot.data!.docs.length;
        }

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            10,
            4,
            10,
            8,
          ),
          child: GestureDetector(
            onTap: _showAllFriendRequests,
            child: Container(
              height: 58,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF17152E),
                    Color(0xFF10182B),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(
                      color: purple.withValues(
                        alpha: .18,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons
                          .person_add_alt_1_rounded,
                      color: purple,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 11),

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
                          'Friend Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'See who wants to connect with you',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (count > 0)
                    Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 27,
                      ),
                      height: 27,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 7,
                      ),
                      decoration:
                          BoxDecoration(
                        color: purple,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      alignment:
                          Alignment.center,
                      child: Text(
                        count > 99
                            ? '99+'
                            : '$count',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                      color: Colors.white38,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: card2,
          borderRadius:
              BorderRadius.circular(27),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: TextField(
          controller:
              _searchController,
          onChanged:
              _onSearchChanged,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          textInputAction:
              TextInputAction.search,
          decoration:
              InputDecoration(
            border: InputBorder.none,
            prefixIcon:
                const Icon(
              Icons.search_rounded,
              color: Colors.white54,
            ),
            hintText:
                'Search people on ChattªX',
            hintStyle:
                const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController
                              .clear();

                          setState(() {
                            _searchQuery =
                                '';
                            _searchResults =
                                [];
                            _loadingSearch =
                                false;
                          });
                        },
                        icon:
                            const Icon(
                          Icons
                              .close_rounded,
                          color:
                              Colors.white54,
                        ),
                      )
                    : const Icon(
                        Icons
                            .person_search_rounded,
                        color:
                            Colors.white38,
                      ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  Widget _buildSearchSection() {
    if (_loadingSearch) {
      return const Padding(
        padding:
            EdgeInsets.only(top: 50),
        child: Center(
          child:
              CircularProgressIndicator(
            color: purple,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.only(
          top: 55,
          left: 30,
          right: 30,
        ),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration:
                  BoxDecoration(
                color: card2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: const Icon(
                Icons
                    .person_search_rounded,
                color: Colors.white38,
                size: 36,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No ChattªX users found',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Try searching by name, username or email.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.white
                    .withValues(
                  alpha: .55,
                ),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Search Results',
          Icons.search_rounded,
        ),

        ..._searchResults.map(
          (doc) => _buildUserTile(
            doc.id,
            doc.data(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        18,
        14,
        8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: cyan,
            size: 18,
          ),

          const SizedBox(width: 7),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FRIEND REQUESTS SECTION
  // ============================================================

  Widget _buildFriendRequestsSection() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('friend_requests')
          .where(
            'receiverId',
            isEqualTo: myUid,
          )
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox();
        }

        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final requests =
            snapshot.data!.docs;

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Friend Requests',
              Icons
                  .person_add_alt_1_rounded,
            ),

            ...requests.map(
              (request) {
                final data =
                    request.data();

                final senderId =
                    data['senderId']
                        ?.toString() ??
                    '';

                if (senderId.isEmpty) {
                  return const SizedBox();
                }

                return _friendRequestTile(
                  request.id,
                  senderId,
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FRIEND REQUEST USER TILE
  // ============================================================

  Widget _friendRequestTile(
    String requestId,
    String senderId,
  ) {
    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future: _firestore
          .collection('users')
          .doc(senderId)
          .get(),
      builder:
          (context, snapshot) {
        if (!snapshot.hasData ||
            !snapshot.data!.exists) {
          return const SizedBox();
        }

        final data =
            snapshot.data!.data();

        if (data == null) {
          return const SizedBox();
        }

        return _buildUserTile(
          senderId,
          data,
          requestId: requestId,
          incomingRequest: true,
        );
      },
    );
  }

  // ============================================================
  // PEOPLE NEAR YOU
  // ============================================================

  Widget _buildPeopleSection() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .where(
            'isOnline',
            isEqualTo: true,
          )
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptySection(
            'Unable to load nearby people',
            Icons
                .location_off_outlined,
          );
        }

        if (!snapshot.hasData) {
          return _loadingList();
        }

        final users = snapshot
            .data!
            .docs
            .where(
              (doc) =>
                  doc.id != myUid,
            )
            .toList();

        final nearbyUsers =
            users.where((doc) {
          final distance =
              _userDistance(
            doc.data(),
          );

          if (distance == null) {
            return false;
          }

          return distance <=
              _nearbyRadiusKm;
        }).toList();

        nearbyUsers.sort(
          (a, b) {
            final distanceA =
                _userDistance(
                      a.data(),
                    ) ??
                    double.infinity;

            final distanceB =
                _userDistance(
                      b.data(),
                    ) ??
                    double.infinity;

            return distanceA.compareTo(
              distanceB,
            );
          },
        );

        if (nearbyUsers.isEmpty) {
          if (_locationLoading) {
            return _loadingList();
          }

          return _emptySection(
            _locationEnabled
                ? 'No people found within ${_nearbyRadiusKm.toInt()} km'
                : 'Turn on location to find people nearby',
            _locationEnabled
                ? Icons
                    .location_off_outlined
                : Icons
                    .location_disabled_outlined,
          );
        }

        return Column(
          children: nearbyUsers
              .take(15)
              .map(
                (doc) =>
                    _buildUserTile(
                  doc.id,
                  doc.data(),
                  showLocation: true,
                  showDistance: true,
                ),
              )
              .toList(),
        );
      },
    );
  }

  // ============================================================
  // PEOPLE YOU MAY KNOW
  // ============================================================

  Widget _buildPeopleMayKnow() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptySection(
            'Unable to load suggestions',
            Icons.people_outline,
          );
        }

        if (!snapshot.hasData) {
          return _loadingList();
        }

        final docs = snapshot
            .data!
            .docs
            .where(
              (doc) =>
                  doc.id != myUid,
            )
            .take(8)
            .toList();

        if (docs.isEmpty) {
          return _emptySection(
            'No suggestions yet',
            Icons.people_outline,
          );
        }

        return Column(
          children: docs
              .map(
                (doc) =>
                    _buildUserTile(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // ============================================================
  // RECENTLY JOINED
  // ============================================================

  Widget _buildRecentlyJoined() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .orderBy(
            'createdAt',
            descending: true,
          )
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptySection(
            'Recently joined users will appear here',
            Icons
                .auto_awesome_outlined,
          );
        }

        if (!snapshot.hasData) {
          return _loadingList();
        }

        final docs = snapshot
            .data!
            .docs
            .where(
              (doc) =>
                  doc.id != myUid,
            )
            .toList();

        if (docs.isEmpty) {
          return _emptySection(
            'No new users yet',
            Icons
                .auto_awesome_outlined,
          );
        }

        return Column(
          children: docs
              .map(
                (doc) =>
                    _buildUserTile(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
      },
    );
  }
  // ============================================================
  // USER TILE
  // ============================================================

  Widget _buildUserTile(
    String userId,
    Map<String, dynamic> data, {
    bool showLocation = false,
    bool showDistance = false,
    String? requestId,
    bool incomingRequest = false,
  }) {
    final rawName =
        data['name']?.toString().trim();

    final displayName =
        data['displayName']?.toString().trim();

    final name =
        rawName != null && rawName.isNotEmpty
            ? rawName
            : displayName != null &&
                    displayName.isNotEmpty
                ? displayName
                : 'ChattªX User';

    final username =
        data['username']
                ?.toString()
                .trim() ??
            '';

    final photo =
        data['photoUrl']
                ?.toString()
                .trim() ??
            '';

    final online =
        data['isOnline'] == true;

    final verified =
        data['verified'] == true;

    final city =
        data['city']
                ?.toString()
                .trim() ??
            '';

    final province =
        data['province']
                ?.toString()
                .trim() ??
            '';

    final distance =
        _userDistance(data);

    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 3,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // ------------------------------------------------------
          // PROFILE PHOTO
          // ------------------------------------------------------

          Stack(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: card2,
                child: ClipOval(
                  child: photo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photo,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  const Icon(
                            Icons.person,
                            color:
                                Colors.white54,
                          ),
                          errorWidget:
                              (context, url, error) =>
                                  const Icon(
                            Icons.person,
                            color:
                                Colors.white54,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color:
                              Colors.white54,
                          size: 25,
                        ),
                ),
              ),

              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration:
                        BoxDecoration(
                      color: green,
                      shape:
                          BoxShape.circle,
                      border: Border.all(
                        color: card,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 11),

          // ------------------------------------------------------
          // USER INFORMATION
          // ------------------------------------------------------

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
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    if (verified)
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          left: 4,
                        ),
                        child: Icon(
                          Icons
                              .verified_rounded,
                          color: cyan,
                          size: 15,
                        ),
                      ),
                  ],
                ),

                if (username.isNotEmpty)
                  Text(
                    username
                            .startsWith('@')
                        ? username
                        : '@$username',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 11,
                    ),
                  ),

                if (showLocation &&
                    (city.isNotEmpty ||
                        province
                            .isNotEmpty))
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          color:
                              Colors.white38,
                          size: 12,
                        ),

                        const SizedBox(
                          width: 3,
                        ),

                        Flexible(
                          child: Text(
                            [
                              if (city
                                  .isNotEmpty)
                                city,
                              if (province
                                  .isNotEmpty)
                                province,
                            ].join(', '),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (showDistance &&
                    distance != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .near_me_rounded,
                          color: cyan,
                          size: 11,
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        Text(
                          _formatDistance(
                            distance,
                          ),
                          style:
                              const TextStyle(
                            color: cyan,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // ------------------------------------------------------
          // ACTION BUTTON
          // ------------------------------------------------------

          if (incomingRequest)
            _requestButtons(
              requestId!,
              userId,
            )
          else
            _friendButton(userId),
        ],
      ),
    );
  }

  // ============================================================
  // DISTANCE FORMAT
  // ============================================================

  String _formatDistance(
    double distance,
  ) {
    if (distance < 1) {
      return '${(distance * 1000).round()} m away';
    }

    return '${distance.toStringAsFixed(1)} km away';
  }

  // ============================================================
  // FRIEND BUTTON
  // ============================================================

  Widget _friendButton(
    String userId,
  ) {
    return FutureBuilder<String>(
      future:
          _getRequestStatus(userId),
      builder:
          (context, snapshot) {
        final status =
            snapshot.data ??
                'loading';

        if (status == 'loading') {
          return Container(
            width: 34,
            height: 34,
            alignment:
                Alignment.center,
            child:
                const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: purple,
              ),
            ),
          );
        }

        if (status == 'pending') {
          return _smallButton(
            'Sent',
            Icons.check_rounded,
            Colors.white24,
            null,
          );
        }

        if (status == 'accepted') {
          return _smallButton(
            'Friends',
            Icons.people_alt_rounded,
            const Color(0xFF00A878),
            null,
          );
        }

        if (status == 'received') {
          return _smallButton(
            'Respond',
            Icons.reply_rounded,
            purple,
            () =>
                _showAllFriendRequests(),
          );
        }

        return _smallButton(
          'Add',
          Icons
              .person_add_alt_1_rounded,
          purple,
          () =>
              _sendFriendRequest(
            userId,
          ),
        );
      },
    );
  }

  // ============================================================
  // REQUEST BUTTONS
  // ============================================================

  Widget _requestButtons(
    String requestId,
    String senderId,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () =>
              _acceptRequest(
            requestId,
            senderId,
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration:
                const BoxDecoration(
              color: purple,
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),

        const SizedBox(width: 6),

        GestureDetector(
          onTap: () =>
              _declineRequest(
            requestId,
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color: Colors.white10,
              shape:
                  BoxShape.circle,
              border: Border.all(
                color: Colors.white10,
              ),
            ),
            child: const Icon(
              Icons.close_rounded,
              color:
                  Colors.white70,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCEPT REQUEST
  // ============================================================

  Future<void> _acceptRequest(
    String requestId,
    String senderId,
  ) async {
    try {
      await _firestore
          .collection(
              'friend_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedAt':
            FieldValue
                .serverTimestamp(),
      });

      _showMessage(
        'Friend request accepted',
      );
    } catch (_) {
      _showMessage(
        'Could not accept request',
      );
    }
  }

  // ============================================================
  // DECLINE REQUEST
  // ============================================================

  Future<void> _declineRequest(
    String requestId,
  ) async {
    try {
      await _firestore
          .collection(
              'friend_requests')
          .doc(requestId)
          .delete();

      _showMessage(
        'Friend request removed',
      );
    } catch (_) {
      _showMessage(
        'Could not remove request',
      );
    }
  }

  // ============================================================
  // SHOW ALL FRIEND REQUESTS
  // ============================================================

  void _showAllFriendRequests() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  .78,
          decoration:
              const BoxDecoration(
            color: background,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
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

              const SizedBox(height: 18),

              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .person_add_alt_1_rounded,
                      color: purple,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Friend Requests',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child:
                    StreamBuilder<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>(
                  stream: _firestore
                      .collection(
                          'friend_requests')
                      .where(
                        'receiverId',
                        isEqualTo: myUid,
                      )
                      .where(
                        'status',
                        isEqualTo:
                            'pending',
                      )
                      .snapshots(),
                  builder:
                      (context, snapshot) {
                    if (snapshot
                        .hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load friend_requests',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      );
                    }

                    if (!snapshot
                        .hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(
                          color: purple,
                        ),
                      );
                    }

                    final requests =
                        snapshot
                            .data!
                            .docs;

                    if (requests
                        .isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize
                                  .min,
                          children: [
                            Icon(
                              Icons
                                  .people_outline,
                              color: Colors
                                  .white24,
                              size: 52,
                            ),
                            SizedBox(
                              height: 12,
                            ),
                            Text(
                              'No friend_requests',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white54,
                                fontSize:
                                    15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView
                        .builder(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        10,
                        8,
                        10,
                        20,
                      ),
                      itemCount:
                          requests.length,
                      itemBuilder:
                          (context, index) {
                        final request =
                            requests[index];

                        final data =
                            request
                                .data();

                        final senderId =
                            data[
                                    'senderId']
                                ?.toString();

                        if (senderId ==
                                null ||
                            senderId
                                .isEmpty) {
                          return const SizedBox();
                        }

                        return _friendRequestTile(
                          request.id,
                          senderId,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FRIEND SETTINGS
  // ============================================================

  void _showFriendSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: card2,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white24,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Friend Discovery',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                ListTile(
                  leading:
                      const Icon(
                    Icons
                        .location_on_rounded,
                    color: cyan,
                  ),
                  title: const Text(
                    'Nearby radius',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_nearbyRadiusKm.toInt()} km',
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                  trailing:
                      DropdownButton<double>(
                    value:
                        _nearbyRadiusKm,
                    dropdownColor:
                        card2,
                    underline:
                        const SizedBox(),
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 5,
                        child:
                            Text('5 km'),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child:
                            Text('10 km'),
                      ),
                      DropdownMenuItem(
                        value: 25,
                        child:
                            Text('25 km'),
                      ),
                      DropdownMenuItem(
                        value: 50,
                        child:
                            Text('50 km'),
                      ),
                      DropdownMenuItem(
                        value: 100,
                        child:
                            Text('100 km'),
                      ),
                    ],
                    onChanged:
                        (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setState(() {
                        _nearbyRadiusKm =
                            value;
                      });

                      Navigator.pop(
                          context);
                    },
                  ),
                ),

                ListTile(
                  leading:
                      const Icon(
                    Icons
                        .my_location_rounded,
                    color: green,
                  ),
                  title: const Text(
                    'Refresh location',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _locationEnabled
                        ? 'Location is enabled'
                        : 'Location is unavailable',
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(
                        context);

                    await _loadMyLocation();

                    if (mounted) {
                      _showMessage(
                        _locationEnabled
                            ? 'Location updated'
                            : 'Could not get your location',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SMALL BUTTON
  // ============================================================

  Widget _smallButton(
    String text,
    IconData icon,
    Color background,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
        ),
        decoration:
            BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(
            17,
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 15,
            ),

            const SizedBox(width: 4),

            Text(
              text,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingList() {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 20,
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child:
              CircularProgressIndicator(
            strokeWidth: 2,
            color: purple,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY SECTION
  // ============================================================

  Widget _emptySection(
    String text,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white24,
            size: 22,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                color:
                    Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}