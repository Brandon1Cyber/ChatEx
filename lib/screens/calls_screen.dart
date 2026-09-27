import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/call_service.dart';
import '../screens/calls/outgoing_voice_call_screen.dart';

// If your video outgoing screen has a different filename/class name,
// we will fix that one import after the first compile check.
// import 'outgoing_video_call_screen.dart';

/// ============================================================================
/// CHATTªX — REAL CALLS SCREEN
/// ============================================================================
///
/// REAL DATA:
///   Firestore
///      /calls/{callId}
///
/// Uses:
///   callerId
///   receiverId
///   type
///   status
///   createdAt
///   connectedAt
///   endedAt
///
/// REAL ACTIONS:
///   • Audio call
///   • Video call
///   • Search contacts
///   • Call history
///   • Missed filter
///   • Incoming filter
///   • Outgoing filter
///   • Video filter
///   • Favorites
///   • Call details
///   • Delete local call-history entry
///
/// ============================================================================

class CallsScreen extends StatefulWidget {
  const CallsScreen({
    super.key,
  });

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  // ==========================================================================
  // FIREBASE
  // ==========================================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ==========================================================================
  // EXACT CHATTªX COLORS
  // ==========================================================================

  static const Color _background =
      Color(0xFF050816);

  static const Color _card =
      Color(0xFF080D1A);

  static const Color _surface =
      Color(0xFF0D1324);

  static const Color _surfaceDark =
      Color(0xFF070B17);

  static const Color _surfaceRaised =
      Color(0xFF10182A);

  static const Color _border =
      Color(0xFF18243A);

  static const Color _borderSoft =
      Color(0xFF202E48);

  static const Color _purple =
      Color(0xFF7B2FF7);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  static const Color _cyan =
      Color(0xFF00D9FF);

  static const Color _brightCyan =
      Color(0xFF00E5FF);

  static const Color _primaryText =
      Color(0xFFF5F7FF);

  static const Color _secondaryText =
      Color(0xFF9AA3B5);

  static const Color _mutedText =
      Color(0xFF68738A);

  static const Color _favoriteYellow =
      Color(0xFFFFC933);

  // ==========================================================================
  // STATE
  // ==========================================================================

  int _selectedFilter = 0;

  bool _loading =
      true;

  String? _error;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _callsSubscription;

  final List<_RealCallItem> _calls = [];

  final Set<String> _favoriteUserIds = {};

  final Set<String> _deletedCallIds = {};

  final List<String> _filters = const [
    'All',
    'Missed',
    'Incoming',
    'Outgoing',
    'Video',
    'Favorites',
  ];

  // User cache.
  //
  // This prevents us from repeatedly requesting the same user profile.
  final Map<String, _CallUser> _userCache = {};

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _loadFavorites();
    _listenToCalls();
  }

  @override
  void dispose() {
    _callsSubscription?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // CURRENT USER
  // ==========================================================================

  String get _currentUid =>
      _auth.currentUser?.uid ?? '';

  // ==========================================================================
  // LOAD FAVORITES
  // ==========================================================================

  Future<void> _loadFavorites() async {
    final uid = _currentUid;

    if (uid.isEmpty) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('call_favorites')
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _favoriteUserIds.clear();

        for (final doc in snapshot.docs) {
          _favoriteUserIds.add(doc.id);
        }
      });
    } catch (e) {
      debugPrint(
        'CHATTªX CALL FAVORITES LOAD ERROR: $e',
      );
    }
  }

  // ==========================================================================
  // REAL CALL LISTENER
  // ==========================================================================

  void _listenToCalls() {
    final uid = _currentUid;

    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to view your calls.';
        });
      }

      return;
    }

    /*
     * We intentionally listen to BOTH sides separately.
     *
     * This works with the current /calls structure and does not require
     * changing your existing call documents.
     */

    _listenToCallSide(
      caller: true,
    );

    _listenToCallSide(
      caller: false,
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _callerSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _receiverSubscription;

  void _listenToCallSide({
    required bool caller,
  }) {
    final uid = _currentUid;

    Query<Map<String, dynamic>> query;

    if (caller) {
      query = _firestore
          .collection('calls')
          .where(
            'callerId',
            isEqualTo: uid,
          )
          .orderBy(
            'createdAt',
            descending: true,
          );
    } else {
      query = _firestore
          .collection('calls')
          .where(
            'receiverId',
            isEqualTo: uid,
          )
          .orderBy(
            'createdAt',
            descending: true,
          );
    }

    final subscription = query.snapshots().listen(
      (snapshot) {
        _mergeCallSnapshot(
          snapshot,
        );
      },
      onError: (Object error) {
        debugPrint(
          'CHATTªX CALL HISTORY ERROR: $error',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
          _error =
              'Unable to load call history.';
        });
      },
    );

    if (caller) {
      _callerSubscription?.cancel();
      _callerSubscription =
          subscription;
    } else {
      _receiverSubscription?.cancel();
      _receiverSubscription =
          subscription;
    }
  }

  // ==========================================================================
  // MERGE FIRESTORE CALLS
  // ==========================================================================

  void _mergeCallSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, _RealCallItem> merged =
        {
      for (final call in _calls)
        call.callId: call,
    };

    for (final doc in snapshot.docs) {
      final item = _convertCallDocument(
        doc,
      );

      if (item == null) {
        continue;
      }

      if (_deletedCallIds.contains(
        item.callId,
      )) {
        continue;
      }

      merged[item.callId] = item;
    }

    final updated =
        merged.values.toList()
          ..sort(
            (
              a,
              b,
            ) =>
                b.createdAt.compareTo(
                  a.createdAt,
                ),
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _calls
        ..clear()
        ..addAll(updated);

      _loading = false;
      _error = null;
    });

    _loadUsersForCalls(
      updated,
    );
  }

  // ==========================================================================
  // CONVERT CALL DOCUMENT
  // ==========================================================================

  _RealCallItem? _convertCallDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final callId =
        doc.id.trim();

    final callerId =
        (data['callerId'] ?? '')
            .toString()
            .trim();

    final receiverId =
        (data['receiverId'] ?? '')
            .toString()
            .trim();

            final callerName =
    _firstNonEmpty([
      data['callerName'],
      data['callerDisplayName'],
    ]) ?? '';

final receiverName =
    _firstNonEmpty([
      data['receiverName'],
      data['receiverDisplayName'],
    ]) ?? '';

    if (callId.isEmpty ||
        callerId.isEmpty ||
        receiverId.isEmpty) {
      return null;
    }

    final type =
        (data['type'] ?? 'audio')
            .toString()
            .toLowerCase();

    final status =
        (data['status'] ?? 'ended')
            .toString()
            .toLowerCase();

    final createdAt =
        _readDate(
          data['createdAt'],
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
        );

    final connectedAt =
        _readDate(
          data['connectedAt'],
        );

    final endedAt =
        _readDate(
          data['endedAt'],
        );

    final bool isMeCaller =
        callerId == _currentUid;

    final bool video =
        type == 'video';

    final bool connected =
        status == 'connected' ||
        connectedAt != null ||
        status == 'ended';

    final bool unanswered =
        status == 'rejected' ||
        status == 'failed' ||
        (
          status == 'ended' &&
          connectedAt == null
        );

    int duration =
        _readInt(
          data['duration'],
        );

    if (duration <= 0 &&
        connectedAt != null &&
        endedAt != null) {
      duration =
          endedAt
              .difference(
                connectedAt,
              )
              .inSeconds;
    }

    if (duration < 0) {
      duration = 0;
    }

    /*
     * A call that was rejected/failed before connection
     * is displayed as missed/unanswered.
     */
    final _CallDirection direction;

    if (unanswered &&
        !isMeCaller) {
      direction =
          _CallDirection.missed;
    } else if (isMeCaller) {
      direction =
          _CallDirection.outgoing;
    } else {
      direction =
          _CallDirection.incoming;
    }

    return _RealCallItem(
  callId: callId,
  callerId: callerId,
  receiverId: receiverId,
  type: type,
  status: status,
  createdAt: createdAt,
  connectedAt: connectedAt,
  endedAt: endedAt,
  duration: duration,
  video: video,
  connected: connected,
  unanswered: unanswered,
  direction: direction,
);
  }

  // ==========================================================================
  // LOAD USER PROFILES
  // ==========================================================================

  Future<void> _loadUsersForCalls(
  List<_RealCallItem> calls,
) async {
  final ids = <String>{};

  for (final call in calls) {
    final otherId =
        call.otherUserId(_currentUid);

    if (otherId.isNotEmpty &&
        otherId != _currentUid) {
      ids.add(otherId);
    }
  }

  if (ids.isEmpty) {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
    return;
  }

  try {
    await Future.wait(
      ids.map(
        (id) => _loadUser(id),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  } catch (e) {
    debugPrint(
      'CHATTªX CALL USERS LOAD ERROR: $e',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }
}

  Future<void> _loadUser(
    String uid,
  ) async {
    if (uid.isEmpty ||
        _userCache.containsKey(uid)) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        _userCache[uid] =
            _CallUser(
          uid: uid,
          name: 'ChattªX User',
          photo: '',
        );

        return;
      }

      final data =
          doc.data() ?? {};

      final name =
          _firstNonEmpty([
        data['displayName'],
        data['name'],
        data['username'],
        data['fullName'],
      ]) ??
          'ChattªX User';

      final photo =
          _firstNonEmpty([
        data['photoUrl'],
        data['profileImage'],
        data['profilePhoto'],
        data['photo'],
        data['imageUrl'],
        data['avatar'],
      ]) ??
          '';

      _userCache[uid] =
          _CallUser(
        uid: uid,
        name: name,
        photo: photo,
      );
    } catch (e) {
      debugPrint(
        'CHATTªX CALL USER LOAD ERROR: $e',
      );

      _userCache[uid] =
          _CallUser(
        uid: uid,
        name: 'ChattªX User',
        photo: '',
      );
    }
  }

  String? _firstNonEmpty(
    List<dynamic> values,
  ) {
    for (final value in values) {
      final text =
          value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const _BackgroundGlow(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),

                _buildCallActions(),

                _buildFilters(),

                Expanded(
                  child: _buildCallHistory(),
                ),
              ],
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
      height: 64,
      width: double.infinity,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          10,
          8,
          4,
          8,
        ),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) {
                return const LinearGradient(
                  colors: [
                    _cyan,
                    _brightPurple,
                  ],
                ).createShader(
                  bounds,
                );
              },
              child: const Text(
                'ChattªX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
            ),

            const SizedBox(width: 3),

            const Text(
              'Calls',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight:
                    FontWeight.w500,
              ),
            ),

            const Spacer(),

            _headerButton(
              Icons.search_rounded,
              _showSearch,
            ),

            const SizedBox(width: 4),

            _headerButton(
              Icons.more_vert_rounded,
              _showMore,
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
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 39,
        height: 39,
        decoration:
            BoxDecoration(
          shape: BoxShape.circle,
          color: _surfaceRaised,
          border: Border.all(
            color: _purple.withValues(
              alpha: .50,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(
                alpha: .10,
              ),
              blurRadius: 11,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: _primaryText,
          size: 19,
        ),
      ),
    );
  }

  // ==========================================================================
  // REAL CALL ACTIONS
  // ==========================================================================

  Widget _buildCallActions() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(10),
        decoration:
            BoxDecoration(
          color: _card,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border: Border.all(
            color: _purple.withValues(
              alpha: .75,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(
                alpha: .13,
              ),
              blurRadius: 22,
            ),
            BoxShadow(
              color: _cyan.withValues(
                alpha: .05,
              ),
              blurRadius: 25,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _callAction(
                icon:
                    Icons.call_rounded,
                title: 'Audio call',
                subtitle:
                    'Call a contact',
                color: _cyan,
                onTap:
                    _chooseContactForAudio,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _callAction(
                icon:
                    Icons.videocam_rounded,
                title: 'Video call',
                subtitle:
                    'Call a contact',
                color:
                    _brightPurple,
                onTap:
                    _chooseContactForVideo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 74,
        decoration:
            BoxDecoration(
          color: _surface,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          border: Border.all(
            color: color.withValues(
              alpha: .60,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: .07,
              ),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 11),

            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: color.withValues(
                  alpha: .08,
                ),
                border:
                    Border.all(
                  color:
                      color.withValues(
                    alpha: .38,
                  ),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          _primaryText,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          _secondaryText,
                      fontSize: 9,
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
  // FILTERS
  // ==========================================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 61,
      width: double.infinity,
      child: ListView.separated(
        padding:
            const EdgeInsets.fromLTRB(
          6,
          14,
          6,
          8,
        ),
        scrollDirection:
            Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount:
            _filters.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(
              width: 6,
            ),
        itemBuilder:
            (context, index) {
          final selected =
              _selectedFilter ==
                  index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter =
                    index;
              });
            },
            child: Container(
              height: 35,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          _purple,
                          _brightPurple,
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : _surfaceRaised,
                border:
                    Border.all(
                  color: selected
                      ? _brightPurple
                      : _border,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _filterIcon(
                    index,
                    selected,
                  ),

                  if (index != 0)
                    const SizedBox(
                      width: 5,
                    ),

                  Text(
                    _filters[index],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : _secondaryText,
                      fontSize: 12,
                      fontWeight:
                          selected
                              ? FontWeight
                                  .w600
                              : FontWeight
                                  .w400,
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

  Widget _filterIcon(
    int index,
    bool selected,
  ) {
    switch (index) {
      case 1:
        return const Icon(
          Icons.call_missed_rounded,
          size: 14,
          color: _brightCyan,
        );

      case 2:
        return const Icon(
          Icons.call_received_rounded,
          size: 14,
          color: _brightCyan,
        );

      case 3:
        return const Icon(
          Icons.call_made_rounded,
          size: 14,
          color: _brightPurple,
        );

      case 4:
        return const Icon(
          Icons.videocam_rounded,
          size: 15,
          color: _secondaryText,
        );

      case 5:
        return const Icon(
          Icons.star_rounded,
          size: 15,
          color: _favoriteYellow,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // CALL HISTORY
  // ==========================================================================

  Widget _buildCallHistory() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 25,
          height: 25,
          child:
              CircularProgressIndicator(
            strokeWidth: 2,
            color: _cyan,
          ),
        ),
      );
    }

    if (_error != null &&
        _calls.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.phone_disabled_rounded,
                color: _mutedText,
                size: 40,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      _secondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });

                  _listenToCalls();
                },
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      _cyan,
                  side:
                      const BorderSide(
                    color: _cyan,
                  ),
                ),
                child:
                    const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered =
        _filteredCalls();

    if (filtered.isEmpty) {
      return _buildEmptyHistory();
    }

    final grouped =
        _groupCallsByDate(
      filtered,
    );

    return RefreshIndicator(
      color: _cyan,
      backgroundColor: _surfaceRaised,
      onRefresh: () async {
        await _refreshCalls();
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        padding:
            const EdgeInsets.fromLTRB(
          6,
          2,
          6,
          130,
        ),
        children: [
          for (final group
              in grouped.entries) ...[
            _buildSectionTitle(
              group.key,
            ),
            _buildCallGroup(
              group.value,
            ),
            const SizedBox(
              height: 16,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshCalls() async {
    try {
      final uid = _currentUid;

      if (uid.isEmpty) {
        return;
      }

      final results =
          await Future.wait([
        _firestore
            .collection('calls')
            .where(
              'callerId',
              isEqualTo: uid,
            )
            .get(),
        _firestore
            .collection('calls')
            .where(
              'receiverId',
              isEqualTo: uid,
            )
            .get(),
      ]);

      final merged =
          <String, _RealCallItem>{};

      for (final snapshot
          in results) {
        for (final doc
            in snapshot.docs) {
          final item =
              _convertCallDocument(
            doc,
          );

          if (item != null &&
              !_deletedCallIds.contains(
                item.callId,
              )) {
            merged[item.callId] =
                item;
          }
        }
      }

      final list =
          merged.values.toList()
            ..sort(
              (a, b) =>
                  b.createdAt.compareTo(
                    a.createdAt,
                  ),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _calls
          ..clear()
          ..addAll(list);
      });

      await _loadUsersForCalls(
        list,
      );
    } catch (e) {
      debugPrint(
        'CHATTªX CALL REFRESH ERROR: $e',
      );
    }
  }

  List<_RealCallItem> _filteredCalls() {
    return _calls.where(
      (call) {
        switch (_selectedFilter) {
          case 1:
            return call.direction ==
                _CallDirection.missed;

          case 2:
            return call.direction ==
                _CallDirection.incoming;

          case 3:
            return call.direction ==
                _CallDirection.outgoing;

          case 4:
            return call.video;

          case 5:
            return _favoriteUserIds
                .contains(
              call.otherUserId(
                _currentUid,
              ),
            );

          default:
            return true;
        }
      },
    ).toList();
  }

  Map<String, List<_RealCallItem>>
      _groupCallsByDate(
    List<_RealCallItem> calls,
  ) {
    final result =
        <String, List<_RealCallItem>>{};

    for (final call in calls) {
      final label =
          _dateGroup(
        call.createdAt,
      );

      result
          .putIfAbsent(
            label,
            () => [],
          )
          .add(call);
    }

    return result;
  }

  String _dateGroup(
    DateTime date,
  ) {
    final now =
        DateTime.now();

    final today =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final callDay =
        DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference =
        today
            .difference(
              callDay,
            )
            .inDays;

    if (difference == 0) {
      return 'TODAY';
    }

    if (difference == 1) {
      return 'YESTERDAY';
    }

    if (difference <= 7) {
      return 'THIS WEEK';
    }

    return 'OLDER';
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    _surfaceRaised,
                border:
                    Border.all(
                  color:
                      _borderSoft,
                ),
              ),
              child:
                  const Icon(
                Icons.call_rounded,
                color: _mutedText,
                size: 31,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            const Text(
              'No calls yet',
              style:
                  TextStyle(
                color:
                    _primaryText,
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              'Your ChattªX calls will appear here.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    _secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION
  // ==========================================================================

  Widget _buildSectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        2,
        0,
        8,
      ),
      child: Text(
        title,
        style:
            const TextStyle(
          color: _secondaryText,
          fontSize: 11,
          fontWeight:
              FontWeight.w500,
          letterSpacing: .8,
        ),
      ),
    );
  }

  // ==========================================================================
  // CALL GROUP
  // ==========================================================================

  Widget _buildCallGroup(
    List<_RealCallItem> calls,
  ) {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        color:
            _card.withValues(
          alpha: .92,
        ),
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              _border.withValues(
            alpha: .65,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children:
            List.generate(
          calls.length,
          (index) {
            final call =
                calls[index];

            return Column(
              children: [
                _buildCallTile(
                  call,
                ),
                if (index !=
                    calls.length - 1)
                  Container(
                    height: 1,
                    color:
                        _border.withValues(
                      alpha: .45,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // CALL TILE
  // ==========================================================================

  Widget _buildCallTile(
    _RealCallItem call,
  ) {
    final otherId =
        call.otherUserId(
      _currentUid,
    );

    final user = _userCache[otherId];

final displayName =
    user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'ChattªX User';

    final favorite =
        _favoriteUserIds
            .contains(
      otherId,
    );

    final accent =
        _callColor(
      call,
    );

    return InkWell(
      onTap: () =>
          _showCallOptions(
        call,
      ),
      child: SizedBox(
        height: 83,
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 11,
          ),
          child: Row(
            children: [
              _buildAvatar(
                call,
                user,
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
  displayName,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            _primaryText,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        Icon(
                          _directionIcon(
                            call,
                          ),
                          size: 14,
                          color:
                              accent,
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Flexible(
                          child: Text(
                            _callDescription(
                              call,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  accent,
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _formatCallTime(
                        call.createdAt,
                      ),
                      style:
                          const TextStyle(
                        color:
                            _mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              if (call.duration >
                  0)
                Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    right: 8,
                  ),
                  child: Text(
                    _formatDuration(
                      call.duration,
                    ),
                    style:
                        const TextStyle(
                      color:
                          _mutedText,
                      fontSize: 10,
                    ),
                  ),
                ),

              _smallActionButton(
                call.video
                    ? Icons
                        .videocam_rounded
                    : Icons
                        .call_rounded,
                call.video
                    ? _brightPurple
                    : _brightCyan,
                () =>
                    _callUser(
  otherId,
  displayName,
  user?.photo ?? '',
  video: call.video,
),
              ),

              if (favorite)
                const Padding(
                  padding:
                      EdgeInsets.only(
                    left: 5,
                  ),
                  child:
                      Icon(
                    Icons.star_rounded,
                    color:
                        _favoriteYellow,
                    size: 17,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================

  Widget _buildAvatar(
    _RealCallItem call,
    _CallUser? user,
  ) {
    final photo =
        user?.photo ?? '';

    final missed =
        call.direction ==
            _CallDirection.missed;

    return Container(
      width: 54,
      height: 54,
      padding:
          const EdgeInsets.all(
        2,
      ),
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            SweepGradient(
          colors: [
            missed
                ? _cyan
                : _cyan,
            _purple,
            _brightCyan,
          ],
        ),
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          1.5,
        ),
        decoration:
            const BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              _surfaceDark,
        ),
        child: ClipOval(
          child: photo.isNotEmpty
              ? Image.network(
                  photo,
                  fit:
                      BoxFit.cover,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _avatarFallback(
                      user?.name ??
                          'User',
                    );
                  },
                )
              : _avatarFallback(
                  user?.name ??
                      'User',
                ),
        ),
      ),
    );
  }

  Widget _avatarFallback(
    String name,
  ) {
    return Container(
      color: _surfaceRaised,
      alignment:
          Alignment.center,
      child: Text(
        _initials(name),
        style:
            const TextStyle(
          color: _primaryText,
          fontSize: 16,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  String _initials(
    String name,
  ) {
    final parts = name
        .trim()
        .split(
          RegExp(r'\s+'),
        )
        .where(
          (e) =>
              e.isNotEmpty,
        )
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      final value =
          parts.first;

      return value
          .substring(
            0,
            value.length > 2
                ? 2
                : value.length,
          )
          .toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }

  // ==========================================================================
  // CALL DESCRIPTION
  // ==========================================================================

  String _callDescription(
    _RealCallItem call,
  ) {
    if (call.unanswered) {
      return call.direction ==
              _CallDirection
                  .outgoing
          ? 'No answer'
          : 'Missed call';
    }

    if (call.direction ==
        _CallDirection.incoming) {
      return call.video
          ? 'Incoming video call'
          : 'Incoming audio call';
    }

    return call.video
        ? 'Outgoing video call'
        : 'Outgoing audio call';
  }

  IconData _directionIcon(
    _RealCallItem call,
  ) {
    if (call.unanswered) {
      return Icons.call_missed_rounded;
    }

    if (call.direction ==
        _CallDirection.incoming) {
      return Icons
          .call_received_rounded;
    }

    return Icons.call_made_rounded;
  }

  Color _callColor(
    _RealCallItem call,
  ) {
    if (call.unanswered) {
      /*
       * We intentionally do NOT use red for missed calls.
       * ChattªX communicates the state with the missed-call icon/text.
       */
      return call.direction ==
              _CallDirection
                  .outgoing
          ? _brightPurple
          : _brightCyan;
    }

    return call.direction ==
            _CallDirection.incoming
        ? _brightCyan
        : _brightPurple;
  }

  // ==========================================================================
  // SMALL ACTION
  // ==========================================================================

  Widget _smallActionButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              color.withValues(
            alpha: .055,
          ),
          border:
              Border.all(
            color:
                color.withValues(
              alpha: .65,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
    );
  }

  // ==========================================================================
  // CONTACT PICKER
  // ==========================================================================

  Future<List<_CallUser>>
      _loadContacts() async {
    final uid = _currentUid;

    if (uid.isEmpty) {
      return [];
    }

    try {
      final snapshot =
          await _firestore
              .collection('users')
              .limit(100)
              .get();

      final contacts =
          <_CallUser>[];

      for (final doc
          in snapshot.docs) {
        if (doc.id == uid) {
          continue;
        }

        final data =
            doc.data();

        final name =
            _firstNonEmpty([
          data['displayName'],
          data['name'],
          data['username'],
          data['fullName'],
        ]) ??
                'ChattªX User';

        final photo =
            _firstNonEmpty([
          data['photoUrl'],
          data['profileImage'],
          data['profilePhoto'],
          data['photo'],
          data['imageUrl'],
          data['avatar'],
        ]) ??
                '';

        contacts.add(
          _CallUser(
            uid: doc.id,
            name: name,
            photo: photo,
          ),
        );

        _userCache[doc.id] =
            contacts.last;
      }

      contacts.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(
              b.name
                  .toLowerCase(),
            ),
      );

      return contacts;
    } catch (e) {
      debugPrint(
        'CHATTªX CONTACT LOAD ERROR: $e',
      );

      return [];
    }
  }

  Future<void>
      _chooseContactForAudio() async {
    final contact =
        await _showContactPicker();

    if (contact == null) {
      return;
    }

    await _callUser(
      contact.uid,
      contact.name,
      contact.photo,
      video: false,
    );
  }

  Future<void>
      _chooseContactForVideo() async {
    final contact =
        await _showContactPicker();

    if (contact == null) {
      return;
    }

    await _callUser(
      contact.uid,
      contact.name,
      contact.photo,
      video: true,
    );
  }

  Future<_CallUser?>
      _showContactPicker() async {
    final contacts =
        await _loadContacts();

    if (!mounted) {
      return null;
    }

    if (contacts.isEmpty) {
      _showSnack(
        'No ChattªX contacts found.',
      );

      return null;
    }

    return showModalBottomSheet<
        _CallUser>(
      context: context,
      backgroundColor:
          _surfaceDark,
      isScrollControlled:
          true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            25,
          ),
        ),
      ),
      builder:
          (sheetContext) {
        String search = '';

        return StatefulBuilder(
          builder:
              (
            context,
            setSheetState,
          ) {
            final filtered =
                contacts.where(
              (user) {
                if (search
                    .trim()
                    .isEmpty) {
                  return true;
                }

                return user.name
                    .toLowerCase()
                    .contains(
                      search
                          .trim()
                          .toLowerCase(),
                    );
              },
            ).toList();

            return SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.of(
                          context,
                        ).size.height *
                        .72,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 12,
                    ),

                    _sheetHandle(),

                    const SizedBox(
                      height: 14,
                    ),

                    const Text(
                      'Choose a contact',
                      style:
                          TextStyle(
                        color:
                            _primaryText,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 15,
                      ),
                      child:
                          TextField(
                        onChanged:
                            (value) {
                          setSheetState(
                            () {
                              search =
                                  value;
                            },
                          );
                        },
                        style:
                            const TextStyle(
                          color:
                              _primaryText,
                        ),
                        decoration:
                            InputDecoration(
                          prefixIcon:
                              const Icon(
                            Icons
                                .search_rounded,
                            color:
                                _secondaryText,
                          ),
                          hintText:
                              'Search contacts',
                          hintStyle:
                              const TextStyle(
                            color:
                                _mutedText,
                          ),
                          filled: true,
                          fillColor:
                              _surface,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  _border,
                            ),
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  _border,
                            ),
                          ),
                          focusedBorder:
                              const OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .all(
                              Radius.circular(
                                14,
                              ),
                            ),
                            borderSide:
                                BorderSide(
                              color:
                                  _cyan,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Expanded(
                      child:
                          filtered.isEmpty
                              ? const Center(
                                  child:
                                      Text(
                                    'No contacts found',
                                    style:
                                        TextStyle(
                                      color:
                                          _mutedText,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      filtered.length,
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final user =
                                        filtered[
                                            index];

                                    return ListTile(
                                      onTap: () {
                                        Navigator.pop(
                                          sheetContext,
                                          user,
                                        );
                                      },
                                      leading:
                                          _pickerAvatar(
                                        user,
                                      ),
                                      title:
                                          Text(
                                        user.name,
                                        style:
                                            const TextStyle(
                                          color:
                                              _primaryText,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      subtitle:
                                          const Text(
                                        'ChattªX contact',
                                        style:
                                            TextStyle(
                                          color:
                                              _secondaryText,
                                          fontSize:
                                              11,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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

  Widget _pickerAvatar(
    _CallUser user,
  ) {
    return CircleAvatar(
      radius: 24,
      backgroundColor:
          _surfaceRaised,
      backgroundImage:
          user.photo.isNotEmpty
              ? NetworkImage(
                  user.photo,
                )
              : null,
      child:
          user.photo.isEmpty
              ? Text(
                  _initials(
                    user.name,
                  ),
                  style:
                      const TextStyle(
                    color:
                        _primaryText,
                    fontWeight:
                        FontWeight.bold,
                  ),
                )
              : null,
    );
  }

  // ==========================================================================
  // START REAL CALL
  // ==========================================================================

  Future<void> _callUser(
    String receiverId,
    String receiverName,
    String receiverPhoto, {
    required bool video,
  }) async {
    final cleanReceiver =
        receiverId.trim();

    if (cleanReceiver.isEmpty) {
      _showSnack(
        'Unable to start this call.',
      );
      return;
    }

    if (cleanReceiver ==
        _currentUid) {
      _showSnack(
        'You cannot call yourself.',
      );
      return;
    }

    try {
      _showSnack(
        video
            ? 'Starting video call with $receiverName...'
            : 'Starting audio call with $receiverName...',
      );

      final ChattaxCall? call =
          video
              ? await ChattaxCallService
                  .instance
                  .startVideoCall(
                    cleanReceiver,
                  )
              : await ChattaxCallService
                  .instance
                  .startAudioCall(
                    cleanReceiver,
                  );

      if (call == null) {
        throw Exception(
          'Call could not be created.',
        );
      }

      if (!mounted) {
        return;
      }

      if (!video) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OutgoingVoiceCallScreen(
              callerName:
                  receiverName,
              profileImageUrl:
                  receiverPhoto,
              callId:
                  call.callId,
            ),
          ),
        );

        return;
      }

      /*
       * Video-call navigation is intentionally kept separate because the
       * current project may have a different video-screen constructor.
       *
       * The actual WebRTC call has already been created above.
       */
      _showSnack(
        'Video call created. Connect the existing video call screen next.',
      );
    } catch (e) {
      debugPrint(
        'CHATTªX CALL START ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      _showSnack(
        'Unable to start the call.',
      );
    }
  }

  // ==========================================================================
  // CALL OPTIONS
  // ==========================================================================

  void _showCallOptions(
    _RealCallItem call,
  ) {
    final otherId =
        call.otherUserId(
      _currentUid,
    );

    final user =
        _userCache[otherId];

    final name =
        user?.name ??
        'ChattªX User';

    final favorite =
        _favoriteUserIds.contains(
      otherId,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            25,
          ),
        ),
      ),
      builder:
          (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const SizedBox(
                height: 10,
              ),

              _sheetHandle(),

              const SizedBox(
                height: 8,
              ),

              ListTile(
                leading:
                    Icon(
                  call.video
                      ? Icons
                          .videocam_rounded
                      : Icons
                          .call_rounded,
                  color:
                      call.video
                          ? _brightPurple
                          : _brightCyan,
                ),
                title: Text(
                  call.video
                      ? 'Video call $name'
                      : 'Call $name',
                  style:
                      const TextStyle(
                    color:
                        _primaryText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _callUser(
                    otherId,
                    name,
                    user?.photo ?? '',
                    video:
                        call.video,
                  );
                },
              ),

              if (!call.video)
                ListTile(
                  leading:
                      const Icon(
                    Icons
                        .videocam_rounded,
                    color:
                        _brightPurple,
                  ),
                  title:
                      Text(
                    'Video call $name',
                    style:
                        const TextStyle(
                      color:
                          _primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _callUser(
                      otherId,
                      name,
                      user?.photo ?? '',
                      video: true,
                    );
                  },
                ),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .info_outline_rounded,
                  color: _cyan,
                ),
                title:
                    const Text(
                  'Call details',
                  style:
                      TextStyle(
                    color:
                        _primaryText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _showCallDetails(
                    call,
                  );
                },
              ),

              ListTile(
                leading:
                    Icon(
                  favorite
                      ? Icons
                          .star_rounded
                      : Icons
                          .star_outline_rounded,
                  color:
                      _favoriteYellow,
                ),
                title: Text(
                  favorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  style:
                      const TextStyle(
                    color:
                        _primaryText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _toggleFavorite(
                    otherId,
                  );
                },
              ),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .delete_outline_rounded,
                  color:
                      _secondaryText,
                ),
                title:
                    const Text(
                  'Delete from call history',
                  style:
                      TextStyle(
                    color:
                        _primaryText,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _deleteCall(
                    call,
                  );
                },
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }
// ==========================================================================
// CALL DETAILS
// ==========================================================================

void _showCallDetails(_RealCallItem call) {
  final String otherUserId = call.otherUserId(_currentUid);

  final user = _userCache[otherUserId];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080D1A),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFF18243A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFF10182A),
                  backgroundImage:
                      user != null && user.photo.isNotEmpty
                          ? NetworkImage(user.photo)
                          : null,
                  child:
                      user == null || user.photo.isEmpty
                          ? Text(
                              _initials(
                                user?.name ?? 'ChattªX User',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFF5F7FF),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'ChattªX User',
                  style: const TextStyle(
                    color: Color(0xFFF5F7FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  call.video ? 'Video call' : 'Audio call',
                  style: const TextStyle(
                    color: Color(0xFF9AA3B5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Color(0xFF0D1324),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF18243A),
                    ),
                  ),
                  child: Column(
                    children: [
                      _callDetailRow(
                        'Date',
                        _formatDate(call.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _callDetailRow(
                        'Type',
                        call.video
                            ? 'Video call'
                            : 'Audio call',
                      ),
                      const SizedBox(height: 12),
                      _callDetailRow(
                        'Status',
                        call.status,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}
String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}


Widget _callDetailRow(
  String title,
  String value,
) {
  return Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF68738A),
            fontSize: 13,
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFFF5F7FF),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

  // ==========================================================================
  // FAVORITES
  // ==========================================================================

  Future<void> _toggleFavorite(
    String userId,
  ) async {
    if (userId.isEmpty) {
      return;
    }

    final uid =
        _currentUid;

    if (uid.isEmpty) {
      return;
    }

    final currentlyFavorite =
        _favoriteUserIds
            .contains(
      userId,
    );

    try {
      final ref =
          _firestore
              .collection('users')
              .doc(uid)
              .collection(
                'call_favorites',
              )
              .doc(userId);

      if (currentlyFavorite) {
        await ref.delete();

        if (mounted) {
          setState(() {
            _favoriteUserIds
                .remove(
              userId,
            );
          });
        }
      } else {
        await ref.set({
          'userId': userId,
          'createdAt':
              FieldValue
                  .serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _favoriteUserIds
                .add(
              userId,
            );
          });
        }
      }
    } catch (e) {
      debugPrint(
        'CHATTªX FAVORITE ERROR: $e',
      );

      _showSnack(
        'Unable to update favorite.',
      );
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  Future<void> _deleteCall(
    _RealCallItem call,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
              _card,
          title:
              const Text(
            'Delete call history?',
            style:
                TextStyle(
              color:
                  _primaryText,
            ),
          ),
          content:
              const Text(
            'This removes the call from your Calls screen.',
            style:
                TextStyle(
              color:
                  _secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
                style:
                    TextStyle(
                  color:
                      _secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'Delete',
                style:
                    TextStyle(
                  color:
                      _cyan,
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

    /*
     * We do NOT delete /calls/{callId}.
     *
     * That document is the call's source of truth and is needed for
     * synchronization/debugging.
     *
     * This screen instead hides the call locally.
     *
     * Later, we can add a per-user deletedAt field to the call document
     * without destroying the shared call record.
     */

    if (!mounted) {
      return;
    }

    setState(() {
      _deletedCallIds.add(
        call.callId,
      );

      _calls.removeWhere(
        (item) =>
            item.callId ==
            call.callId,
      );
    });

    _showSnack(
      'Call removed from your history.',
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void _showSearch() {
    showSearch(
      context: context,
      delegate:
          _RealCallSearchDelegate(
        calls: _calls,
        users: _userCache,
        currentUid:
            _currentUid,
      ),
    );
  }

  // ==========================================================================
  // MORE
  // ==========================================================================

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            25,
          ),
        ),
      ),
      builder:
          (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const SizedBox(
                height: 12,
              ),

              _sheetHandle(),

              const SizedBox(
                height: 15,
              ),

              _sheetItem(
                Icons.history_rounded,
                'All calls',
                () {
                  Navigator.pop(
                    sheetContext,
                  );

                  setState(() {
                    _selectedFilter =
                        0;
                  });
                },
              ),

              _sheetItem(
                Icons.call_missed_rounded,
                'Missed calls',
                () {
                  Navigator.pop(
                    sheetContext,
                  );

                  setState(() {
                    _selectedFilter =
                        1;
                  });
                },
              ),

              _sheetItem(
                Icons.star_outline_rounded,
                'Favorites',
                () {
                  Navigator.pop(
                    sheetContext,
                  );

                  setState(() {
                    _selectedFilter =
                        5;
                  });
                },
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

  Widget _sheetHandle() {
    return Container(
      width: 45,
      height: 4,
      decoration:
          BoxDecoration(
        color: _mutedText,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
    );
  }

  Widget _sheetItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: _cyan,
      ),
      title: Text(
        title,
        style:
            const TextStyle(
          color: _primaryText,
        ),
      ),
      onTap: onTap,
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  DateTime? _readDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  int _readInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatDuration(
    int seconds,
  ) {
    if (seconds < 0) {
      seconds = 0;
    }

    final minutes =
        seconds ~/ 60;

    final remaining =
        seconds % 60;

    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String _formatCallTime(
    DateTime date,
  ) {
    final now =
        DateTime.now();

    final today =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final day =
        DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference =
        today
            .difference(day)
            .inDays;

    final time =
        TimeOfDay.fromDateTime(
      date,
    ).format(context);

    if (difference == 0) {
      return time;
    }

    if (difference == 1) {
      return 'Yesterday, $time';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _showSnack(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style:
                const TextStyle(
              color:
                  _primaryText,
            ),
          ),
          behavior:
              SnackBarBehavior
                  .floating,
          backgroundColor:
              _surfaceRaised,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            side:
                const BorderSide(
              color: _border,
            ),
          ),
        ),
      );
  }
}

// ============================================================================
// BACKGROUND
// ============================================================================

class _BackgroundGlow
    extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(
    BuildContext context,
  ) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: -130,
            child: _glow(
              _CallsScreenState
                  ._purple,
              260,
            ),
          ),
          Positioned(
            top: 420,
            right: -150,
            child: _glow(
              _CallsScreenState
                  ._brightPurple,
              300,
            ),
          ),
          Positioned(
            bottom: 180,
            left: -100,
            child: _glow(
              _CallsScreenState
                  ._cyan,
              250,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(
    Color color,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            RadialGradient(
          colors: [
            color.withValues(
              alpha: .12,
            ),
            color.withValues(
              alpha: .025,
            ),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CALL USER
// ============================================================================

class _CallUser {
  final String uid;
  final String name;
  final String photo;

  const _CallUser({
    required this.uid,
    required this.name,
    required this.photo,
  });
}

// ============================================================================
// REAL CALL ITEM
// ============================================================================

class _RealCallItem {
  final String callId;
  final String callerId;
  final String receiverId;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int duration;
  final bool video;
  final bool connected;
  final bool unanswered;
  final _CallDirection direction;

  const _RealCallItem({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.connectedAt,
    required this.endedAt,
    required this.duration,
    required this.video,
    required this.connected,
    required this.unanswered,
    required this.direction,
  });

  String otherUserId(
    String currentUid,
  ) {
    if (callerId ==
        currentUid) {
      return receiverId;
    }

    return callerId;
  }
}

// ============================================================================
// DIRECTION
// ============================================================================

enum _CallDirection {
  incoming,
  outgoing,
  missed,
}

// ============================================================================
// SEARCH
// ============================================================================

class _RealCallSearchDelegate
    extends SearchDelegate<String> {
  final List<_RealCallItem> calls;

  final Map<String, _CallUser> users;

  final String currentUid;

  _RealCallSearchDelegate({
    required this.calls,
    required this.users,
    required this.currentUid,
  });

  static const Color background =
      Color(0xFF050816);

  static const Color card =
      Color(0xFF080D1A);

  static const Color primaryText =
      Color(0xFFF5F7FF);

  static const Color secondaryText =
      Color(0xFF9AA3B5);

  static const Color mutedText =
      Color(0xFF68738A);

  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(
      context,
    ).copyWith(
      scaffoldBackgroundColor:
          background,
      appBarTheme:
          const AppBarTheme(
        backgroundColor:
            background,
        elevation: 0,
      ),
      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle:
            TextStyle(
          color: mutedText,
        ),
        border:
            InputBorder.none,
      ),
      textTheme:
          const TextTheme(
        titleLarge:
            TextStyle(
          color:
              primaryText,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>?
      buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon:
              const Icon(
            Icons.clear_rounded,
            color:
                secondaryText,
          ),
        ),
    ];
  }

  @override
  Widget buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(
          context,
          '',
        );
      },
      icon:
          const Icon(
        Icons.arrow_back_rounded,
        color:
            primaryText,
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildResults();
  }
Widget _buildResults() {
  final String search = query.trim().toLowerCase();

  final results = calls.where((call) {
    final String otherUserId = call.otherUserId(currentUid);
    final user = users[otherUserId];

    final String name =
        user?.name.toLowerCase() ?? '';

    final String type =
        call.video ? 'video call' : 'audio call';

    final String status =
        call.status.toLowerCase();

    return search.isEmpty ||
        name.contains(search) ||
        type.contains(search) ||
        status.contains(search);
  }).toList();

  if (results.isEmpty) {
    return Container(
      color: background,
      alignment: Alignment.center,
      child: const Text(
        'No calls found',
        style: TextStyle(
          color: mutedText,
          fontSize: 15,
        ),
      ),
    );
  }

  return Container(
    color: background,
    child: ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: results.length,
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final call = results[index];

        final String otherUserId =
            call.otherUserId(currentUid);

        final user = users[otherUserId];

        final String displayName =
            user?.name.isNotEmpty == true
                ? user!.name
                : 'ChattªX User';

        final String photo =
            user?.photo ?? '';

        return Container(
          margin: const EdgeInsets.only(
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: card,
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF18243A),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor:
                  const Color(0xFF10182A),
              backgroundImage:
                  photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
              child: photo.isEmpty
                  ? Text(
                      _initials(displayName),
                      style:
                          const TextStyle(
                        color: primaryText,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            title: Text(
              displayName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: primaryText,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            subtitle: Text(
              call.video
                  ? 'Video call'
                  : 'Audio call',
              style: const TextStyle(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
            trailing: Text(
              _formatDate(call.createdAt),
              style: const TextStyle(
                color: mutedText,
                fontSize: 11,
              ),
            ),
          ),
        );
      },
    ),
  );
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _initials(String name) {
  final String cleaned = name.trim();

  if (cleaned.isEmpty) {
    return '?';
  }

  final List<String> parts =
      cleaned.split(RegExp(r'\s+'));

  if (parts.length == 1) {
    final String value = parts.first;

    return value.substring(
      0,
      value.length > 2
          ? 2
          : value.length,
    ).toUpperCase();
  }

  return '${parts[0][0]}${parts[1][0]}'
      .toUpperCase();
}
}