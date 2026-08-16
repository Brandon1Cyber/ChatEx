import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/call_service.dart';

import 'home_screen.dart';
import 'feed_screen.dart';
import 'calls_screen.dart';
import 'discover_screen.dart';
import 'reels/reels_screen.dart';
import 'calls/incoming_voice_call_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  int _selectedIndex = 0;

  // ==========================================================================
  // CALL SERVICE
  // ==========================================================================

  final ChattaxCallService _callService =
      ChattaxCallService.instance;

  StreamSubscription<ChattaxCall>?
      _incomingCallSubscription;

  // ==========================================================================
  // CALL UI STATE
  // ==========================================================================

  bool _incomingCallOpening = false;

  bool _incomingCallScreenOpen = false;

  String? _currentlyShowingCallId;

  // ==========================================================================
  // MAIN SCREENS
  // ==========================================================================
  //
  // 0 = Chats
  // 1 = Feed
  // 2 = Calls
  // 3 = Discover
  // 4 = Reels
  //
  // Stories has been completely replaced by Feed.
  // ==========================================================================

  final List<Widget> _screens = const [
    HomeScreen(),
    FeedScreen(),
    CallsScreen(),
    DiscoverScreen(),
    ReelsScreen(),
  ];

  // ==========================================================================
  // NAVIGATION ICONS
  // ==========================================================================

  final List<IconData> icons = [
    Icons.chat_bubble_rounded,
    Icons.dynamic_feed_rounded,
    Icons.call_rounded,
    Icons.explore_rounded,
    Icons.play_circle_fill_rounded,
  ];

  // ==========================================================================
  // NAVIGATION LABELS
  // ==========================================================================

  final List<String> labels = [
    'Chats',
    'Feed',
    'Calls',
    'Discover',
    'Reels',
  ];

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _startIncomingCallSystem();
    });
  }

  // ==========================================================================
  // START INCOMING CALL SYSTEM
  // ==========================================================================

  void _startIncomingCallSystem() {
    if (!mounted) {
      return;
    }

    debugPrint(
      '==================================================',
    );

    debugPrint(
      'CHATTªX CALL: starting incoming call system',
    );

    debugPrint(
      'CHATTªX CALL: currentUserId='
      '${_callService.currentUserId}',
    );

    debugPrint(
      '==================================================',
    );

    // Prevent duplicate subscriptions.
    if (_incomingCallSubscription != null) {
      debugPrint(
        'CHATTªX CALL: incomingCalls subscription already exists',
      );

      return;
    }

    try {
      // ======================================================================
      // SUBSCRIBE FIRST
      // ======================================================================

      _incomingCallSubscription =
          _callService.incomingCalls.listen(
        (ChattaxCall call) {
          debugPrint(
            '==================================================',
          );

          debugPrint(
            'CHATTªX CALL: 🔔 INCOMING CALL EVENT',
          );

          debugPrint(
            'CHATTªX CALL: callId=${call.callId}',
          );

          debugPrint(
            'CHATTªX CALL: callerId=${call.callerId}',
          );

          debugPrint(
            'CHATTªX CALL: receiverId=${call.receiverId}',
          );

          debugPrint(
            'CHATTªX CALL: type=${call.type}',
          );

          debugPrint(
            'CHATTªX CALL: status=${call.status}',
          );

          debugPrint(
            'CHATTªX CALL: currentUserId='
            '${_callService.currentUserId}',
          );

          debugPrint(
            '==================================================',
          );

          _handleIncomingCall(call);
        },
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(
            'CHATTªX CALL: ❌ incomingCalls stream error',
          );

          debugPrint(
            'CHATTªX CALL: $error',
          );

          debugPrint(
            '$stackTrace',
          );
        },
        cancelOnError: false,
      );

      // ======================================================================
      // START FIRESTORE LISTENER
      // ======================================================================

      _callService.listenForIncomingCalls();

      debugPrint(
        'CHATTªX CALL: ✅ incoming call system started',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX CALL: ❌ failed to start incoming call system',
      );

      debugPrint(
        'CHATTªX CALL: $error',
      );

      debugPrint(
        '$stackTrace',
      );

      _incomingCallSubscription?.cancel();

      _incomingCallSubscription = null;
    }
  }

  // ==========================================================================
  // HANDLE INCOMING CALL
  // ==========================================================================

  void _handleIncomingCall(
    ChattaxCall call,
  ) {
    if (!mounted) {
      return;
    }

    // Only ringing calls.
    if (call.status != ChattaxCallStatus.ringing) {
      debugPrint(
        'CHATTªX CALL: ignoring call because status is '
        '${call.status}',
      );

      return;
    }

    // ==========================================================================
    // CURRENT USER
    // ==========================================================================

    final String? currentUid =
        _callService.currentUserId;

    if (currentUid == null ||
        currentUid.trim().isEmpty) {
      debugPrint(
        'CHATTªX CALL: ❌ no authenticated user',
      );

      return;
    }

    // ==========================================================================
    // RECEIVER CHECK
    // ==========================================================================

    if (call.receiverId.trim() !=
        currentUid.trim()) {
      debugPrint(
        'CHATTªX CALL: ignoring call - receiver mismatch',
      );

      return;
    }

    // ==========================================================================
    // OWN CALL CHECK
    // ==========================================================================

    if (call.callerId.trim() ==
        currentUid.trim()) {
      debugPrint(
        'CHATTªX CALL: ignoring own outgoing call',
      );

      return;
    }

    // ==========================================================================
    // SCREEN LOCK
    // ==========================================================================

    if (_incomingCallOpening ||
        _incomingCallScreenOpen) {
      debugPrint(
        'CHATTªX CALL: another incoming call screen '
        'is already active',
      );

      return;
    }

    // ==========================================================================
    // DUPLICATE CALL CHECK
    // ==========================================================================

    if (_currentlyShowingCallId ==
        call.callId) {
      debugPrint(
        'CHATTªX CALL: call already queued '
        '${call.callId}',
      );

      return;
    }

    // Remember immediately.
    _currentlyShowingCallId =
        call.callId;

    debugPrint(
      'CHATTªX CALL: preparing incoming screen '
      '${call.callId}',
    );

    // ==========================================================================
    // OPEN NEXT FRAME
    // ==========================================================================

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          _currentlyShowingCallId = null;
          return;
        }

        unawaited(
          _openIncomingCallScreen(call),
        );
      },
    );
  }

  // ==========================================================================
  // OPEN INCOMING CALL SCREEN
  // ==========================================================================

  Future<void> _openIncomingCallScreen(
    ChattaxCall call,
  ) async {
    if (!mounted) {
      _currentlyShowingCallId = null;
      return;
    }

    // Lock immediately.
    if (_incomingCallOpening ||
        _incomingCallScreenOpen) {
      return;
    }

    _incomingCallOpening = true;

    try {
      debugPrint(
        'CHATTªX CALL: opening incoming call '
        '${call.callId}',
      );

      // ==========================================================================
      // CURRENT USER
      // ==========================================================================

      final String? currentUid =
          _callService.currentUserId;

      if (currentUid == null ||
          currentUid.trim().isEmpty) {
        debugPrint(
          'CHATTªX CALL: user logged out before '
          'incoming screen opened',
        );

        return;
      }

      // ==========================================================================
      // VERIFY RECEIVER
      // ==========================================================================

      if (call.receiverId.trim() !=
          currentUid.trim()) {
        debugPrint(
          'CHATTªX CALL: receiver changed before '
          'incoming screen opened',
        );

        return;
      }

      // ==========================================================================
      // VERIFY CALL IS STILL ACTIVE
      // ==========================================================================

      final bool stillActive =
          await _callService.isCallStillActive(
        call.callId,
      );

      if (!mounted) {
        return;
      }

      if (!stillActive) {
        debugPrint(
          'CHATTªX CALL: call is no longer active '
          '${call.callId}',
        );

        return;
      }

      // ==========================================================================
      // GET LATEST CALL
      // ==========================================================================

      final ChattaxCall? latestCall =
          await _callService.getCall(
        call.callId,
      );

      if (!mounted) {
        return;
      }

      if (latestCall == null) {
        debugPrint(
          'CHATTªX CALL: latest call document not found',
        );

        return;
      }

      // ==========================================================================
      // VERIFY STATUS
      // ==========================================================================

      if (latestCall.status !=
          ChattaxCallStatus.ringing) {
        debugPrint(
          'CHATTªX CALL: call is no longer ringing: '
          '${latestCall.status}',
        );

        return;
      }

      // ==========================================================================
      // VERIFY RECEIVER
      // ==========================================================================

      if (latestCall.receiverId.trim() !=
          currentUid.trim()) {
        debugPrint(
          'CHATTªX CALL: latest call receiver mismatch',
        );

        return;
      }

      // ==========================================================================
      // VERIFY CALLER
      // ==========================================================================

      if (latestCall.callerId.trim() ==
          currentUid.trim()) {
        debugPrint(
          'CHATTªX CALL: latest call belongs to current user',
        );

        return;
      }

      // ==========================================================================
      // AUDIO CALL ONLY
      // ==========================================================================

      if (latestCall.type !=
          ChattaxCallType.audio) {
        debugPrint(
          'CHATTªX CALL: received non-audio call '
          '${latestCall.type}',
        );

        return;
      }

      // ==========================================================================
      // MARK UI OPEN
      // ==========================================================================

      _incomingCallScreenOpen = true;

      // ==========================================================================
      // LOAD CALLER PROFILE
      // ==========================================================================

      final CallerProfile callerProfile =
          await _loadCallerProfile(
        latestCall.callerId,
      );

      if (!mounted) {
        return;
      }

      debugPrint(
        'CHATTªX CALL: caller name='
        '${callerProfile.name}',
      );

      debugPrint(
        'CHATTªX CALL: caller image='
        '${callerProfile.imageUrl}',
      );

      // ==========================================================================
      // OPEN INCOMING VOICE CALL SCREEN
      // ==========================================================================

      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration:
              const Duration(
            milliseconds: 350,
          ),
          reverseTransitionDuration:
              const Duration(
            milliseconds: 250,
          ),
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double>
                secondaryAnimation,
          ) {
            return IncomingVoiceCallScreen(
              callId: latestCall.callId,
              callerName: callerProfile.name,
              callerImageUrl:
                  callerProfile.imageUrl,
              isVerified:
                  callerProfile.isVerified,
            );
          },
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double>
                secondaryAnimation,
            Widget child,
          ) {
            final Animation<double>
                curvedAnimation =
                CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        ),
      );

      debugPrint(
        'CHATTªX CALL: incoming call screen closed',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX CALL: ❌ error opening incoming call',
      );

      debugPrint(
        'CHATTªX CALL: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    } finally {
      // ==========================================================================
      // RESET LOCKS
      // ==========================================================================

      _incomingCallOpening = false;

      _incomingCallScreenOpen = false;

      if (_currentlyShowingCallId ==
          call.callId) {
        _currentlyShowingCallId = null;
      }

      debugPrint(
        'CHATTªX CALL: incoming call UI state reset',
      );
    }
  }

  // ==========================================================================
  // LOAD CALLER PROFILE
  // ==========================================================================

  Future<CallerProfile> _loadCallerProfile(
    String callerId,
  ) async {
    final String cleanedId =
        callerId.trim();

    if (cleanedId.isEmpty) {
      return const CallerProfile(
        name: 'Unknown caller',
        imageUrl: null,
        isVerified: false,
      );
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cleanedId)
              .get();

      if (!snapshot.exists) {
        debugPrint(
          'CHATTªX CALL: caller profile not found '
          '$cleanedId',
        );

        return const CallerProfile(
          name: 'ChattªX user',
          imageUrl: null,
          isVerified: false,
        );
      }

      final Map<String, dynamic>? data =
          snapshot.data();

      if (data == null) {
        return const CallerProfile(
          name: 'ChattªX user',
          imageUrl: null,
          isVerified: false,
        );
      }

      // ==========================================================================
      // NAME
      // ==========================================================================

      final String name =
          _firstNonEmptyString([
                data['displayName'],
                data['name'],
                data['username'],
                data['fullName'],
              ]) ??
              'ChattªX user';

      // ==========================================================================
      // PROFILE IMAGE
      // ==========================================================================

      final String? imageUrl =
          _firstNonEmptyString([
        data['photoUrl'],
        data['photoURL'],
        data['profileImageUrl'],
        data['profilePicture'],
        data['imageUrl'],
      ]);

      // ==========================================================================
      // VERIFIED
      // ==========================================================================

      final bool isVerified =
          data['isVerified'] == true ||
          data['verified'] == true;

      return CallerProfile(
        name: name,
        imageUrl: imageUrl,
        isVerified: isVerified,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX CALL: caller profile error',
      );

      debugPrint(
        'CHATTªX CALL: $error',
      );

      debugPrint(
        '$stackTrace',
      );

      return const CallerProfile(
        name: 'ChattªX user',
        imageUrl: null,
        isVerified: false,
      );
    }
  }

  // ==========================================================================
  // STRING HELPER
  // ==========================================================================

  String? _firstNonEmptyString(
    List<dynamic> values,
  ) {
    for (final dynamic value in values) {
      if (value == null) {
        continue;
      }

      final String text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    debugPrint(
      'CHATTªX CALL: disposing MainNavigationScreen',
    );

    _incomingCallSubscription?.cancel();

    _incomingCallSubscription = null;

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor:
          const Color(0xFF050816),

      // ==========================================================================
      // PAGE
      // ==========================================================================

      body: AnimatedSwitcher(
        duration:
            const Duration(
          milliseconds: 300,
        ),
        transitionBuilder: (
          Widget child,
          Animation<double> animation,
        ) {
          return SlideTransition(
            position: Tween<Offset>(
              begin:
                  const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
            ),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(
            _selectedIndex,
          ),
          child:
              _screens[_selectedIndex],
        ),
      ),

// ==========================================================================
// BOTTOM NAVIGATION
// ==========================================================================
//
// The navigation itself remains EXACTLY 66px tall.
//
// The extra bottom inset is filled with the same gradient so:
//   • the navigation moves slightly upward
//   • the navigation size does NOT change
//   • there is NO empty space underneath
//   • the system navigation area visually blends into ChattªX
//
// ==========================================================================

bottomNavigationBar: Builder(
  builder: (context) {
    final double bottomInset =
        MediaQuery.of(context).viewPadding.bottom;

    return SizedBox(
      width: double.infinity,

      // 66px navigation + system bottom area.
      height: 66 + bottomInset,

      child: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0A1020),
              Color(0xFF101827),
              Color(0xFF151032),
            ],
          ),
        ),

        child: Align(
          alignment: Alignment.topCenter,

          // ================================================================
          // ACTUAL NAVIGATION
          //
          // STILL EXACTLY 66px.
          // ================================================================

          child: SizedBox(
            width: double.infinity,
            height: 66,

            child: Row(
              children: List.generate(
                icons.length,
                (index) {
                  final bool selected =
                      _selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior:
                          HitTestBehavior.opaque,

                      onTap: () {
                        if (!mounted) {
                          return;
                        }

                        if (_selectedIndex == index) {
                          return;
                        }

                        setState(() {
                          _selectedIndex = index;
                        });
                      },

                      child: AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 280,
                        ),
                        curve: Curves.easeOut,

                        margin:
                            const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),

                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            26,
                          ),

                          color: selected
                              ? const Color(
                                  0x221A2347,
                                )
                              : Colors.transparent,

                          border: selected
                              ? Border.all(
                                  color:
                                      const Color(
                                    0xFF7B2FF7,
                                  ),
                                  width: 1.2,
                                )
                              : null,

                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color:
                                        const Color(
                                      0xFF7B2FF7,
                                    ).withValues(
                                      alpha: .45,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),

                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,

                          children: [
                            AnimatedContainer(
                              duration:
                                  const Duration(
                                milliseconds: 280,
                              ),

                              width: 32,
                              height: 32,

                              decoration: selected
                                  ? const BoxDecoration(
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
                                    )
                                  : null,

                              child: Icon(
                                icons[index],
                                size: 19,
                                color: selected
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            AnimatedDefaultTextStyle(
                              duration:
                                  const Duration(
                                milliseconds: 250,
                              ),

                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w600,
                              ),

                              child: Text(
                                labels[index],
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  },
),
    );
  }
}

// ============================================================================
// CALLER PROFILE
// ============================================================================

class CallerProfile {
  final String name;

  final String? imageUrl;

  final bool isVerified;

  const CallerProfile({
    required this.name,
    required this.imageUrl,
    required this.isVerified,
  });
}