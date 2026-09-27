import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/call_service.dart';
import 'voice_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/verified_name.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================================
/// CHATTªX — OUTGOING VOICE CALL SCREEN
/// ============================================================================
///
/// REAL CALL FLOW
///
///   Caller
///     │
///     ▼
///   calling
///     │
///     │  receiver acknowledges
///     ▼
///   ringing
///     │
///     │  receiver answers
///     ▼
///   connecting
///     │
///     │  WebRTC actually connects
///     ▼
///   connected
///     │
///     ▼
///   VoiceCallScreen
///
/// IMPORTANT:
/// This screen NEVER assumes that the call is connected based on a timer.
/// ChattaxCallService remains the source of truth.
///
/// This screen listens through:
///
/// 1. callStatusEvents
///    - exact callId
///    - preferred source
///
/// 2. callStatusStream
///    - compatibility/fallback
///
/// 3. getCall(callId)
///    - initial Firestore synchronization
///    - protects against missing a very fast state transition
/// ============================================================================

class OutgoingVoiceCallScreen extends StatefulWidget {
  final String callerName;
  final String? profileImageUrl;
  final String? callId;
  final VoidCallback? onCancel;

  const OutgoingVoiceCallScreen({
    super.key,
    this.callerName = 'Brandon Hotshot',
    this.profileImageUrl,
    this.callId,
    this.onCancel,
  });

  @override
  State<OutgoingVoiceCallScreen> createState() =>
      _OutgoingVoiceCallScreenState();
}

class _OutgoingVoiceCallScreenState
    extends State<OutgoingVoiceCallScreen>
    with TickerProviderStateMixin {
  // ==========================================================================
  // CALL SERVICE
  // ==========================================================================

  final ChattaxCallService _callService =
      ChattaxCallService.instance;

  /// Compatibility status listener.
  StreamSubscription<ChattaxCallStatus>? _statusSubscription;

  /// Preferred exact-call listener.
  StreamSubscription<ChattaxCallStatusEvent>? _statusEventSubscription;

  String? _activeCallId;

  ChattaxCallStatus _status =
      ChattaxCallStatus.calling;

  // ==========================================================================
  // AUDIO
  // ==========================================================================

  final AudioPlayer _outgoingRingtonePlayer =
      AudioPlayer();

  bool _ringtoneReady = false;
  bool _ringtoneLoading = false;
  bool _ringtoneStarting = false;

  // ==========================================================================
  // STATE
  // ==========================================================================

  bool _isCancelling = false;
  bool _hasFinished = false;

  /// Prevents VoiceCallScreen from being pushed more than once.
  bool _hasOpenedConnectedScreen = false;

  /// Prevents competing finish operations.
  bool _isFinishing = false;

  bool _isVerified = false;

  // ==========================================================================
  // ANIMATIONS
  // ==========================================================================

  late final AnimationController _ringController;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

   _activeCallId = widget.callId?.trim().isNotEmpty == true
    ? widget.callId!.trim()
    : _callService.activeCallId;

    _initializeAnimations();
_setSystemUi();

// Load the real ChattªX verification status.
unawaited(
  _loadVerificationStatus(),
);

// Prepare ringtone.
unawaited(
  _prepareOutgoingRingtone(),
);

    // Listen for the real call state.
    _listenForCallStatus();
  }

  // ==========================================================================
  // ANIMATIONS
  // ==========================================================================

  void _initializeAnimations() {
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  // ==========================================================================
  // RINGTONE
  // ==========================================================================

  Future<void> _prepareOutgoingRingtone() async {
    if (_ringtoneReady || _ringtoneLoading) {
      return;
    }

    _ringtoneLoading = true;

    try {
      await _outgoingRingtonePlayer.setAsset(
        'assets/audio/outgoing_ringtone.mp3',
      );

      await _outgoingRingtonePlayer.setLoopMode(
        LoopMode.one,
      );

      _ringtoneReady = true;

      if (!mounted ||
          _hasFinished ||
          _isCancelling ||
          _isFinishing) {
        return;
      }

      if (_shouldPlayRingtone(_status)) {
        await _startOutgoingRingtone();
      }
    } catch (error) {
      debugPrint(
        'ChattªX outgoing ringtone error: $error',
      );
    } finally {
      _ringtoneLoading = false;
    }
  }

  bool _shouldPlayRingtone(
    ChattaxCallStatus status,
  ) {
    return status == ChattaxCallStatus.calling ||
        status == ChattaxCallStatus.ringing;
  }

  Future<void> _startOutgoingRingtone() async {
    if (!_ringtoneReady ||
        _ringtoneStarting ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing) {
      return;
    }

    if (!_shouldPlayRingtone(_status)) {
      return;
    }

    if (_outgoingRingtonePlayer.playing) {
      return;
    }

    _ringtoneStarting = true;

    try {
      await _outgoingRingtonePlayer.play();
    } catch (error) {
      debugPrint(
        'ChattªX unable to start outgoing ringtone: $error',
      );
    } finally {
      _ringtoneStarting = false;
    }
  }

  Future<void> _stopOutgoingRingtone() async {
    try {
      if (_outgoingRingtonePlayer.playing) {
        await _outgoingRingtonePlayer.stop();
      }
    } catch (error) {
      debugPrint(
        'ChattªX unable to stop outgoing ringtone: $error',
      );
    }
  }

  // ==========================================================================
  // SYSTEM UI
  // ==========================================================================

  void _setSystemUi() {
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
  // CALL STATUS LISTENERS
  // ==========================================================================

  void _listenForCallStatus() {
    // ------------------------------------------------------------------------
    // EXACT CALL EVENT LISTENER
    // ------------------------------------------------------------------------
    //
    // This is the primary listener because every event carries its callId.
    //

    _statusEventSubscription =
        _callService.callStatusEvents.listen(
      (event) {
        if (!mounted ||
            _hasFinished ||
            _isCancelling ||
            _isFinishing ||
            _hasOpenedConnectedScreen) {
          return;
        }

        final String? activeId = _activeCallId;

        if (activeId == null ||
            activeId.isEmpty) {
          debugPrint(
            'ChattªX outgoing call event ignored: '
            'missing active callId',
          );
          return;
        }

        // Never react to another call's status.
        if (event.callId != activeId) {
          return;
        }

        debugPrint(
          'ChattªX outgoing call event: '
          '$activeId → ${event.status}',
        );

        unawaited(
          _applyCallStatus(event.status),
        );
      },
      onError: (Object error) {
        debugPrint(
          'ChattªX outgoing call event error: $error',
        );
      },
    );

    // ------------------------------------------------------------------------
    // GENERIC STATUS LISTENER
    // ------------------------------------------------------------------------
    //
    // Kept as a fallback because the service exposes callStatusStream.
    //

    _statusSubscription =
    _callService.callStatusStream.listen(
  (status) {
    if (!mounted ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    final String? activeId = _activeCallId;
    final String? serviceCallId =
        _callService.activeCallId;

    if (activeId == null ||
        activeId.isEmpty ||
        serviceCallId == null ||
        serviceCallId != activeId) {
      return;
    }

    debugPrint(
      'ChattªX outgoing generic status: $status',
    );

    unawaited(
      _applyCallStatus(status),
    );
  },
  onError: (Object error) {
    debugPrint(
      'ChattªX outgoing call status error: $error',
    );
  },
);

    // ------------------------------------------------------------------------
    // FIRESTORE SYNCHRONIZATION
    // ------------------------------------------------------------------------
    //
    // This is important.
    //
    // If the receiver answers extremely quickly and the service reaches
    // connected before this widget processes its stream event, getCall()
    // catches the current Firestore state.
    //

    unawaited(
      _synchronizeCurrentCall(),
    );
  }

  // ==========================================================================
  // INITIAL CALL SYNCHRONIZATION
  // ==========================================================================

  Future<void> _synchronizeCurrentCall() async {
    final String? callId = _activeCallId;

    if (callId == null ||
        callId.isEmpty ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      debugPrint(
        'ChattªX cannot synchronize outgoing call: '
        'missing callId',
      );
      return;
    }

    try {
      final call =
          await _callService.getCall(callId);

      if (!mounted ||
          _hasFinished ||
          _isCancelling ||
          _isFinishing ||
          _hasOpenedConnectedScreen) {
        return;
      }

      if (call == null) {
        debugPrint(
          'ChattªX outgoing call not found: $callId',
        );
        return;
      }

      debugPrint(
        'ChattªX outgoing call synchronized: '
        '$callId → ${call.status}',
      );

      await _applyCallStatus(
        call.status,
      );
    } catch (error) {
      debugPrint(
        'ChattªX outgoing call synchronization error: '
        '$error',
      );
    }
  }

  // ==========================================================================
  // APPLY STATUS
  // ==========================================================================

  Future<void> _applyCallStatus(
    ChattaxCallStatus status,
  ) async {
    if (!mounted ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }
    // ========================================================================
// IMPORTANT STATE PROTECTION
// ========================================================================
// Prevent stale/late Firestore or stream events from moving the call
// backwards after it has already progressed.

if (_status == ChattaxCallStatus.connecting &&
    (status == ChattaxCallStatus.calling ||
     status == ChattaxCallStatus.ringing)) {
  return;
}

if (_status == ChattaxCallStatus.ringing &&
    status == ChattaxCallStatus.calling) {
  return;
}

if (_status == ChattaxCallStatus.connected &&
    status != ChattaxCallStatus.connected) {
  return;
}

    if (_status != status) {
      setState(() {
        _status = status;
      });
    }

    await _handleStatusChange(
      status,
    );
  }

  // ==========================================================================
  // HANDLE STATUS
  // ==========================================================================

  Future<void> _handleStatusChange(
    ChattaxCallStatus status,
  ) async {
    if (!mounted ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    switch (status) {
      // ======================================================================
      // CALLING
      // ======================================================================

      case ChattaxCallStatus.calling:
        await _prepareOutgoingRingtone();

        if (!mounted ||
            _hasFinished ||
            _isCancelling ||
            _isFinishing) {
          return;
        }

        await _startOutgoingRingtone();
        break;

      // ======================================================================
      // RINGING
      // ======================================================================

      case ChattaxCallStatus.ringing:
        HapticFeedback.lightImpact();

        await _prepareOutgoingRingtone();

        if (!mounted ||
            _hasFinished ||
            _isCancelling ||
            _isFinishing) {
          return;
        }

        await _startOutgoingRingtone();
        break;

      // ======================================================================
      // CONNECTING
      // ======================================================================

      case ChattaxCallStatus.connecting:
  HapticFeedback.selectionClick();

  unawaited(_stopOutgoingRingtone());

  if (!mounted ||
      _hasFinished ||
      _isCancelling ||
      _isFinishing ||
      _hasOpenedConnectedScreen) {
    return;
  }

  // The receiver has answered.
  // Move immediately into the real active call screen.
  _openConnectedCall();
  break;

      // ======================================================================
      // CONNECTED
      // ======================================================================

      case ChattaxCallStatus.connected:
        HapticFeedback.mediumImpact();

        await _stopOutgoingRingtone();

        if (!mounted ||
            _hasFinished ||
            _isCancelling ||
            _isFinishing ||
            _hasOpenedConnectedScreen) {
          return;
        }

        _openConnectedCall();
        break;

      // ======================================================================
      // REJECTED
      // ======================================================================

      case ChattaxCallStatus.rejected:
        await _stopOutgoingRingtone();

        await _finishCall(
          '${_displayName()} declined the call',
        );
        break;

      // ======================================================================
      // ENDED
      // ======================================================================

      case ChattaxCallStatus.ended:
        await _stopOutgoingRingtone();

        await _finishCall(
          'Call ended',
        );
        break;

      // ======================================================================
      // FAILED
      // ======================================================================

      case ChattaxCallStatus.failed:
        await _stopOutgoingRingtone();

        await _finishCall(
          'Call connection failed',
        );
        break;
    }
  }

  // ==========================================================================
// LOAD VERIFICATION STATUS
// ==========================================================================

Future<void> _loadVerificationStatus() async {
  try {
    final String name = widget.callerName.trim();

    if (name.isEmpty) {
      return;
    }

    // We first try to find the user by the same profile data
    // used by the calling screen.
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('displayName', isEqualTo: name)
            .limit(1)
            .get();

    if (!mounted || snapshot.docs.isEmpty) {
      return;
    }

    final Map<String, dynamic> data =
        snapshot.docs.first.data();

    final bool verified =
        data['verified'] == true ||
        data['isVerified'] == true;

    if (!mounted) {
      return;
    }

    setState(() {
      _isVerified = verified;
    });
  } catch (error) {
    debugPrint(
      'ChattªX verification status error: $error',
    );
  }
}

  // ==========================================================================
  // DISPLAY NAME
  // ==========================================================================

  String _displayName() {
    final String name =
        widget.callerName.trim();

    if (name.isEmpty) {
      return 'Unknown user';
    }

    return name;
  }

  // ==========================================================================
  // OPEN CONNECTED CALL
  // ==========================================================================

  void _openConnectedCall() {
    if (!mounted ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    final String? callId = _activeCallId;

    // ------------------------------------------------------------------------
    // Never open VoiceCallScreen without the actual callId.
    // ------------------------------------------------------------------------

    if (callId == null ||
        callId.isEmpty) {
      debugPrint(
        'ChattªX cannot open VoiceCallScreen: '
        'missing callId',
      );

      unawaited(
        _finishCall(
          'Call ID is missing',
        ),
      );

      return;
    }

    // ------------------------------------------------------------------------
    // Lock navigation BEFORE pushing.
    // ------------------------------------------------------------------------

    _hasOpenedConnectedScreen = true;

    // ------------------------------------------------------------------------
    // Stop both listeners.
    // ------------------------------------------------------------------------

    unawaited(
      _statusSubscription?.cancel(),
    );

    unawaited(
      _statusEventSubscription?.cancel(),
    );

    _statusSubscription = null;
    _statusEventSubscription = null;

    // ------------------------------------------------------------------------
    // Make absolutely sure outgoing ringtone is stopped.
    // ------------------------------------------------------------------------

    unawaited(
      _stopOutgoingRingtone(),
    );

    debugPrint(
  'ChattªX opening VoiceCallScreen '
  'for active call: $callId',
);

    // ------------------------------------------------------------------------
    // Replace outgoing screen with the real active call screen.
    // ------------------------------------------------------------------------

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 320),
        reverseTransitionDuration:
            const Duration(milliseconds: 220),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return VoiceCallScreen(
            callerName: _displayName(),
            profileImageUrl:
                widget.profileImageUrl,
            callId: callId,
          );
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final CurvedAnimation curved =
              CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  // ==========================================================================
  // CANCEL CALL
  // ==========================================================================

  Future<void> _cancelCall() async {
    if (_isCancelling ||
        _hasFinished ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCancelling = true;
      });
    } else {
      _isCancelling = true;
    }

    HapticFeedback.mediumImpact();

    // Immediately stop ringtone.
    await _stopOutgoingRingtone();

    try {
      // ----------------------------------------------------------------------
      // Let the service update Firestore and clean up WebRTC.
      // ----------------------------------------------------------------------

      await _callService.cancelCall();

      _hasFinished = true;

      await _statusSubscription?.cancel();
      await _statusEventSubscription?.cancel();

      _statusSubscription = null;
      _statusEventSubscription = null;

      widget.onCancel?.call();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      debugPrint(
        'ChattªX cancel call error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCancelling = false;
      });

      if (_shouldPlayRingtone(_status)) {
        await _startOutgoingRingtone();
      }

      _showSnackBar(
        'Unable to cancel call',
      );
    }
  }

  // ==========================================================================
  // FINISH CALL
  // ==========================================================================

  Future<void> _finishCall(
    String message,
  ) async {
    if (_hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    _isFinishing = true;
    _hasFinished = true;

    await _stopOutgoingRingtone();

    await _statusSubscription?.cancel();
    await _statusEventSubscription?.cancel();

    _statusSubscription = null;
    _statusEventSubscription = null;

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        behavior:
            SnackBarBehavior.floating,
        duration:
            const Duration(milliseconds: 900),
      ),
    );

    await Future<void>.delayed(
      const Duration(milliseconds: 850),
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ==========================================================================
  // SNACKBAR
  // ==========================================================================

  void _showSnackBar(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================================
  // ADD CALL
  // ==========================================================================

  Future<void> _addCall() async {
  if (_isCancelling ||
      _hasFinished ||
      _isFinishing) {
    return;
  }

  HapticFeedback.lightImpact();

  final selectedFriendIds = await _showAddCallPicker();

  if (!mounted ||
      selectedFriendIds == null ||
      selectedFriendIds.isEmpty) {
    return;
  }

  // We now have the real friend IDs selected by the user.
  //
  // Example:
  // [
  //   "friendUid1",
  //   "friendUid2",
  // ]
  //
  // The next step is passing these IDs into ChattaxCallService
  // for the actual multi-person call.

try {
  await _callService.addParticipantsToCall(
    selectedFriendIds,
  );

  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${selectedFriendIds.length} '
        '${selectedFriendIds.length == 1 ? 'person' : 'people'} '
        'added to the call.',
      ),
      backgroundColor:
          const Color(0xFF111827),
      behavior:
          SnackBarBehavior.floating,
    ),
  );
} catch (error) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      ),
      backgroundColor:
          const Color(0xFF111827),
      behavior:
          SnackBarBehavior.floating,
    ),
  );
}
}

Future<List<String>?> _showAddCallPicker() async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return null;
  }

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) {
      return _AddCallFriendPicker(
        currentUserId: currentUser.uid,
      );
    },
  );
}

  // ==========================================================================
  // MORE
  // ==========================================================================

  void _showMore() {
    if (_isCancelling ||
        _hasFinished ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF070A16),
      isScrollControlled: false,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
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
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Call Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _optionTile(
                  icon:
                      Icons.security_rounded,
                  color:
                      const Color(0xFF2BEFCB),
                  title:
                      'Security Information',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _showSecurityInformation();
                  },
                ),
                _optionTile(
                  icon:
                      Icons.report_outlined,
                  color:
                      const Color(0xFFFF4752),
                  title:
                      'Report Call',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _showSnackBar(
                      'Call report submitted.',
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

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(
            alpha: 0.10,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight:
              FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white30,
      ),
      onTap: onTap,
    );
  }

  // ==========================================================================
  // SECURITY
  // ==========================================================================

  void _showSecurityInformation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF090D18),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color:
                    Color(0xFF2BEFCB),
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Call Security',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Text(
            'ChattªX uses secure signaling and '
            'WebRTC media transport for voice calls.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _statusSubscription = null;

    _statusEventSubscription?.cancel();
    _statusEventSubscription = null;

    unawaited(
      _stopOutgoingRingtone(),
    );

    _outgoingRingtonePlayer.dispose();

    _ringController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _glowController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop ||
            _isCancelling ||
            _hasFinished ||
            _isFinishing ||
            _hasOpenedConnectedScreen) {
          return;
        }

        unawaited(
          _cancelCall(),
        );
      },
      child: Scaffold(
        backgroundColor:
            const Color(0xFF02050D),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder:
                (context, constraints) {
              return Stack(
                children: [
                  // ==========================================================
                  // BACKGROUND
                  // ==========================================================

                  Positioned.fill(
                    child: Image.asset(
                      'assets/outgoing_voice_call_background.png',
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const DecoratedBox(
                          decoration:
                              BoxDecoration(
                            gradient:
                                LinearGradient(
                              begin:
                                  Alignment.topCenter,
                              end:
                                  Alignment.bottomCenter,
                              colors: [
                                Color(
                                  0xFF09172B,
                                ),
                                Color(
                                  0xFF02050D,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ==========================================================
                  // DARK OVERLAY
                  // ==========================================================

                  const Positioned.fill(
                    child: ColoredBox(
                      color:
                          Color(0xA802050D),
                    ),
                  ),

                  // ==========================================================
                  // GLOW
                  // ==========================================================

                  Positioned.fill(
                    child:
                        _buildBackgroundGlow(),
                  ),

                  // ==========================================================
                  // CONTENT
                  // ==========================================================

                  Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child:
                            _buildMainContent(
                          constraints,
                        ),
                      ),
                    ],
                  ),

                  // ==========================================================
                  // CANCELLING OVERLAY
                  // ==========================================================

                  if (_isCancelling)
                    Positioned.fill(
                      child: Container(
                        color:
                            Colors.black.withValues(
                          alpha: 0.24,
                        ),
                        alignment:
                            Alignment.center,
                        child:
                            _buildEndingOverlay(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ENDING OVERLAY
  // ==========================================================================

  Widget _buildEndingOverlay() {
    return Container(
      width: 132,
      height: 132,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF080C16)
                .withValues(
          alpha: 0.96,
        ),
        borderRadius:
            BorderRadius.circular(26),
        border:
            Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.35,
            ),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                Color(0xFFB044FF),
              ),
            ),
          ),
          SizedBox(height: 13),
          Text(
            'Ending call...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BACKGROUND GLOW
  // ==========================================================================

  Widget _buildBackgroundGlow() {
    return AnimatedBuilder(
      animation: _glowController,
      builder:
          (context, child) {
        final double value =
            _glowController.value;

        return DecoratedBox(
          decoration:
              BoxDecoration(
            gradient:
                RadialGradient(
              center:
                  const Alignment(
                0,
                -0.28,
              ),
              radius: 1.12,
              colors: [
                Color(0xFF7028B7)
                    .withValues(
                  alpha:
                      0.035 +
                      (value * 0.035),
                ),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // MAIN CONTENT
  // ==========================================================================

  Widget _buildMainContent(
    BoxConstraints constraints,
  ) {
    final double screenHeight =
        constraints.maxHeight;
    final double screenWidth =
        constraints.maxWidth;

    final bool verySmall =
        screenHeight < 680;

    final bool compact =
        screenHeight < 760;

    final double avatarSize =
        verySmall
            ? math.min(
                screenWidth * 0.42,
                155.0,
              )
            : compact
                ? math.min(
                    screenWidth * 0.46,
                    175.0,
                  )
                : math.min(
                    screenWidth * 0.50,
                    200.0,
                  );

    return Column(
      children: [
        // ====================================================================
        // PROFILE
        // ====================================================================

        Expanded(
          child: Center(
            child:
                _buildOutgoingProfile(
              avatarSize: avatarSize,
              compact: compact,
              verySmall: verySmall,
            ),
          ),
        ),

        // ====================================================================
        // STATUS
        // ====================================================================

        _buildConnectionStatus(
          _status,
        ),

        SizedBox(
          height:
              verySmall
                  ? 6
                  : compact
                      ? 9
                      : 12,
        ),

        // ====================================================================
        // WAITING CARD
        // ====================================================================

        Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 4,
  ),
  child: _buildWaitingCard(
    _status,
    compact: compact,
  ),
),

        SizedBox(
          height:
              verySmall
                  ? 8
                  : compact
                      ? 12
                      : 16,
        ),

        // ====================================================================
        // CONTROLS
        // ====================================================================

        Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 2,
  ),
  child: _buildControls(
    compact: compact,
    verySmall: verySmall,
  ),
),

        SizedBox(
          height:
              verySmall
                  ? 10
                  : compact
                      ? 14
                      : 20,
        ),
      ],
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 7,
            top: 7,
            child:
                _roundHeaderButton(
              icon:
                  Icons.arrow_back_ios_new_rounded,
              onTap:
                  _cancelCall,
            ),
          ),
          Positioned(
            top: 5,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                RichText(
                  text:
                      const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Chatt',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: 'ªX',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFFB653FF,
                          ),
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' Call',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFFB653FF,
                          ),
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color:
                          Colors.white38,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'End-to-end encrypted',
                      style:
                          TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 7,
            top: 7,
            child:
                _roundHeaderButton(
              icon:
                  Icons.more_vert_rounded,
              onTap:
                  _showMore,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER BUTTON
  // ==========================================================================

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap:
          _isCancelling ||
                  _hasFinished ||
                  _isFinishing ||
                  _hasOpenedConnectedScreen
              ? null
              : onTap,
      behavior:
          HitTestBehavior.opaque,
      child: Container(
        width: 39,
        height: 39,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              const Color(
            0xFF08111F,
          ).withValues(
            alpha: 0.84,
          ),
          border:
              Border.all(
            color:
                Colors.white.withValues(
              alpha: 0.075,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFILE
  // ==========================================================================

  Widget _buildOutgoingProfile({
    required double avatarSize,
    required bool compact,
    required bool verySmall,
  }) {
    final double nameSize =
        verySmall
            ? 22.0
            : compact
                ? 26.0
                : 29.0;

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        SizedBox(
          width:
              avatarSize + 42,
          height:
              avatarSize + 42,
          child: Stack(
            alignment:
                Alignment.center,
            children: [
              Positioned.fill(
                child:
                    AnimatedBuilder(
                  animation:
                      _waveController,
                  builder:
                      (context, child) {
                    return CustomPaint(
                      painter:
                          _OutgoingWavePainter(
                        progress:
                            _waveController
                                .value,
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation:
                    _pulseController,
                builder:
                    (context, child) {
                  final double pulse =
                      _pulseController.value;

                  return Container(
                    width:
                        avatarSize +
                        pulse * 11,
                    height:
                        avatarSize +
                        pulse * 11,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFB03DFF,
                        ).withValues(
                          alpha:
                              0.035 +
                              pulse * 0.045,
                        ),
                        width: 1,
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation:
                    _ringController,
                builder:
                    (context, child) {
                  return Transform.rotate(
                    angle:
                        _ringController.value *
                        math.pi *
                        2,
                    child:
                        Container(
                      width:
                          avatarSize,
                      height:
                          avatarSize,
                      padding:
                          const EdgeInsets.all(
                        3,
                      ),
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            SweepGradient(
                          colors: [
                            Color(
                              0xFF20E8F5,
                            ),
                            Color(
                              0xFF697CFF,
                            ),
                            Color(
                              0xFFC139FF,
                            ),
                            Color(
                              0xFF20E8F5,
                            ),
                          ],
                        ),
                      ),
                      child:
                          Container(
                        padding:
                            const EdgeInsets.all(
                          2,
                        ),
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              Color(
                            0xFF02050D,
                          ),
                        ),
                        child:
                            ClipOval(
                          child:
                              _buildProfileImage(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height:
              verySmall
                  ? 4
                  : compact
                      ? 6
                      : 8,
        ),
        Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 18,
  ),
  child: VerifiedName(
    name: _displayName(),
    verified: _isVerified,
    fontSize: nameSize,
    fontWeight: FontWeight.w600,
    textColor: Colors.white,
  ),
),
        const SizedBox(height: 4),
        const Text(
          'Outgoing Voice Call',
          style:
              TextStyle(
            color:
                Colors.white60,
            fontSize: 13,
            fontWeight:
                FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PROFILE IMAGE
  // ==========================================================================

  Widget _buildProfileImage() {
    final String? url =
        widget.profileImageUrl?.trim();

    if (url == null ||
        url.isEmpty) {
      return _defaultProfile();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return _defaultProfile();
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress ==
            null) {
          return child;
        }

        return _defaultProfile(
          loading: true,
        );
      },
    );
  }

  // ==========================================================================
  // DEFAULT PROFILE
  // ==========================================================================

  Widget _defaultProfile({
    bool loading = false,
  }) {
    return Container(
      color:
          const Color(0xFF121B2B),
      alignment:
          Alignment.center,
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                  Color(0xFFB044FF),
                ),
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color:
                  Colors.white38,
              size: 68,
            ),
    );
  }

  // ==========================================================================
  // CONNECTION STATUS
  // ==========================================================================

  Widget _buildConnectionStatus(
    ChattaxCallStatus status,
  ) {
    late String text;
    late Color color;
    late IconData icon;

    switch (status) {
      case ChattaxCallStatus.calling:
        text =
            'Starting secure call...';
        color =
            const Color(0xFFB044FF);
        icon =
            Icons.phone_in_talk_rounded;
        break;

      case ChattaxCallStatus.ringing:
        text =
            'Ringing...';
        color =
            const Color(0xFF17EFAF);
        icon =
            Icons.notifications_active_rounded;
        break;

      case ChattaxCallStatus.connecting:
        text =
            'Connecting securely...';
        color =
            const Color(0xFF00D9FF);
        icon =
            Icons.sync_rounded;
        break;

      case ChattaxCallStatus.connected:
        text =
            'Connected';
        color =
            const Color(0xFF17EFAF);
        icon =
            Icons.call_rounded;
        break;

      case ChattaxCallStatus.rejected:
        text =
            'Call declined';
        color =
            const Color(0xFFFF4752);
        icon =
            Icons.call_end_rounded;
        break;

      case ChattaxCallStatus.ended:
        text =
            'Call ended';
        color =
            Colors.white54;
        icon =
            Icons.call_end_rounded;
        break;

      case ChattaxCallStatus.failed:
        text =
            'Connection failed';
        color =
            const Color(0xFFFF4752);
        icon =
            Icons.error_outline_rounded;
        break;
    }

    return AnimatedSwitcher(
      duration:
          const Duration(milliseconds: 220),
      child: Row(
        key:
            ValueKey(status),
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style:
                TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WAITING CARD
  // ==========================================================================

  Widget _buildWaitingCard(
    ChattaxCallStatus status, {
    required bool compact,
  }) {
    late String title;
    late String subtitle;
    late IconData icon;

    switch (status) {
      case ChattaxCallStatus.calling:
        title =
            'Preparing secure call...';
        subtitle =
            'Establishing the connection';
        icon =
            Icons.security_rounded;
        break;

      case ChattaxCallStatus.ringing:
        title =
            'Waiting for ${_displayName()}...';
        subtitle =
            'Their device is ringing';
        icon =
            Icons.notifications_active_rounded;
        break;

      case ChattaxCallStatus.connecting:
        title =
            'Connecting to ${_displayName()}...';
        subtitle =
            'Negotiating the voice connection';
        icon =
            Icons.sync_rounded;
        break;

      case ChattaxCallStatus.connected:
        title =
            'Call connected';
        subtitle =
            'Opening voice call...';
        icon =
            Icons.call_rounded;
        break;

      case ChattaxCallStatus.rejected:
        title =
            'Call declined';
        subtitle =
            '${_displayName()} declined the call';
        icon =
            Icons.call_end_rounded;
        break;

      case ChattaxCallStatus.ended:
        title =
            'Call ended';
        subtitle =
            'The call has ended';
        icon =
            Icons.call_end_rounded;
        break;

      case ChattaxCallStatus.failed:
        title =
            'Connection failed';
        subtitle =
            'Unable to establish the call';
        icon =
            Icons.error_outline_rounded;
        break;
    }

    final bool loading =
        status ==
                ChattaxCallStatus.calling ||
            status ==
                ChattaxCallStatus.ringing ||
            status ==
                ChattaxCallStatus.connecting;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 220),
      width:
          double.infinity,
      height:
          compact ? 67 : 73,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF07101D)
                .withValues(
          alpha: 0.96,
        ),
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.16,
            ),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:
                compact ? 41 : 45,
            height:
                compact ? 41 : 45,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  const Color(0xFF6516B2)
                      .withValues(
                alpha: 0.13,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(
                0xFFA443FF,
              ),
              size:
                  compact ? 21 : 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            child: loading
                ? const SizedBox(
                    key:
                        ValueKey(
                      'loading',
                    ),
                    width: 14,
                    height: 14,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        Color(
                          0xFFA946FF,
                        ),
                      ),
                    ),
                  )
                : Container(
                    key:
                        const ValueKey(
                      'done',
                    ),
                    width: 8,
                    height: 8,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(
                        0xFFA946FF,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONTROLS
  // ==========================================================================

  Widget _buildControls({
    required bool compact,
    required bool verySmall,
  }) {
    final double buttonSize =
        verySmall
            ? 53.0
            : compact
                ? 57.0
                : 61.0;

    return Row(
      children: [
        Expanded(
          child: _control(
            icon:
                Icons.mic_rounded,
            label:
                'Mute',
            buttonSize:
                buttonSize,
            onTap: () {
              _showSnackBar(
                'Mute is available after the call connects.',
              );
            },
          ),
        ),
        Expanded(
          child: _control(
            icon:
                Icons.volume_up_rounded,
            label:
                'Speaker',
            buttonSize:
                buttonSize,
            onTap: () {
              _showSnackBar(
                'Speaker is available after the call connects.',
              );
            },
          ),
        ),
        Expanded(
          child: _control(
            icon:
                Icons.person_add_alt_1_rounded,
            label:
                'Add Call',
            buttonSize:
                buttonSize,
            activeColor:
                const Color(
              0xFFB044FF,
            ),
            onTap:
                _addCall,
          ),
        ),
        Expanded(
          child: _control(
            icon:
                Icons.call_end_rounded,
            label:
                'Cancel',
            buttonSize:
                buttonSize,
            isEnd:
                true,
            onTap:
                _cancelCall,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CONTROL BUTTON
  // ==========================================================================

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double buttonSize,
    bool active = false,
    bool isEnd = false,
    Color activeColor = Colors.white,
  }) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        GestureDetector(
          onTap:
              _isCancelling ||
                      _hasFinished ||
                      _isFinishing ||
                      _hasOpenedConnectedScreen
                  ? null
                  : onTap,
          behavior:
              HitTestBehavior.opaque,
          child:
              AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            width:
                buttonSize,
            height:
                buttonSize,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  isEnd
                      ? const Color(
                          0xFFF2343E,
                        )
                      : active
                          ? activeColor
                              .withValues(
                              alpha: 0.10,
                            )
                          : const Color(
                              0xFF091320,
                            ),
              border:
                  Border.all(
                color:
                    isEnd
                        ? const Color(
                            0xFFFF454E,
                          )
                        : Colors.white
                            .withValues(
                            alpha: 0.10,
                          ),
              ),
              boxShadow:
                  isEnd
                      ? [
                          BoxShadow(
                            color:
                                const Color(
                              0xFFFF3040,
                            ).withValues(
                              alpha: 0.20,
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
            ),
            child: Icon(
              icon,
              color:
                  Colors.white,
              size:
                  isEnd
                      ? buttonSize * 0.45
                      : buttonSize * 0.39,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            color:
                Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// OUTGOING VOICE WAVE PAINTER
// ============================================================================

class _OutgoingWavePainter
    extends CustomPainter {
  final double progress;

  const _OutgoingWavePainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final double centerX =
        size.width / 2;

    final double centerY =
        size.height / 2;

    const int barCount = 43;

    final Paint paint = Paint()
      ..strokeWidth = 2
      ..strokeCap =
          StrokeCap.round;

    final double usableWidth =
        math.min(
      size.width - 20,
      310.0,
    );

    final double startX =
        centerX -
        usableWidth / 2;

    final double spacing =
        usableWidth /
        (barCount - 1);

    for (int i = 0;
        i < barCount;
        i++) {
      final double position =
          i / (barCount - 1);

      final double distance =
          (position - 0.5).abs();

      final double envelope =
          math.max(
        0.0,
        1.0 -
            (distance * 1.65),
      );

      final double wave =
          math.sin(
        i * 0.72 +
            progress *
                math.pi *
                2,
      );

      final double wave2 =
          math.sin(
        i * 0.31 +
            progress *
                math.pi *
                4,
      );

      final double barHeight =
          4 +
          wave.abs() *
              23 *
              envelope +
          wave2.abs() *
              8 *
              envelope;

      final double x =
          startX +
          i * spacing;

      paint.color =
          Color.lerp(
            const Color(
              0xFF19E8F5,
            ),
            const Color(
              0xFFC23BFF,
            ),
            position,
          )!.withValues(
        alpha:
            0.08 +
            envelope * 0.25,
      );

      canvas.drawLine(
        Offset(
          x,
          centerY -
              barHeight / 2,
        ),
        Offset(
          x,
          centerY +
              barHeight / 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _OutgoingWavePainter
            oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}

class _AddCallFriendPicker extends StatefulWidget {
  const _AddCallFriendPicker({
    required this.currentUserId,
  });

  final String currentUserId;

  @override
  State<_AddCallFriendPicker> createState() =>
      _AddCallFriendPickerState();
}

class _AddCallFriendPickerState
    extends State<_AddCallFriendPicker> {
  static const Color background = Color(0xFF050816);
  static const Color surface = Color(0xFF0D1528);
  static const Color surfaceRaised = Color(0xFF111827);
  static const Color border = Color(0xFF18243A);
  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFF8B2CF8);
  static const Color primaryText = Color(0xFFF5F7FF);

  final TextEditingController _searchController =
      TextEditingController();

  final Set<String> _selectedIds = <String>{};

  String _search = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_CallFriend>> _loadFriends() async {
    final friendsSnapshot = await FirebaseFirestore.instance
        .collection('friends')
        .doc(widget.currentUserId)
        .collection('contacts')
        .get();

    if (friendsSnapshot.docs.isEmpty) {
      return <_CallFriend>[];
    }

    final List<_CallFriend> friends = [];

    for (final friendDoc in friendsSnapshot.docs) {
      final friendId = friendDoc.id;

      try {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();

        if (!userSnapshot.exists) {
          continue;
        }

        final data =
            userSnapshot.data() as Map<String, dynamic>?;

        if (data == null) {
          continue;
        }

        final String name =
            (data['displayName'] ?? 'Unknown').toString();

        final String username =
            (data['username'] ?? '').toString();

        final String photo =
            (data['photoUrl'] ?? '').toString();

        final bool verified =
            data['verified'] == true ||
            data['isVerified'] == true;

        friends.add(
          _CallFriend(
            id: friendId,
            name: name,
            username: username,
            photoUrl: photo,
            verified: verified,
          ),
        );
      } catch (_) {
        // Ignore a friend whose profile cannot currently
        // be loaded.
      }
    }

    friends.sort((a, b) {
      return a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );
    });

    return friends;
  }

  bool _matchesSearch(_CallFriend friend) {
    if (_search.isEmpty) {
      return true;
    }

    return friend.name.toLowerCase().contains(_search) ||
        friend.username.toLowerCase().contains(_search);
  }

  void _toggleFriend(String friendId) {
    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedIds.contains(friendId)) {
        _selectedIds.remove(friendId);
      } else {
        _selectedIds.add(friendId);
      }
    });
  }

  void _addSelected() {
    if (_selectedIds.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      List<String>.from(_selectedIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        padding: EdgeInsets.only(
          bottom: bottomInset,
        ),
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          border: Border(
            top: BorderSide(
              color: border,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: cyan,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add people',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose friends to add to this call',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: purple.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        '${_selectedIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  cursorColor: cyan,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                    ),
                    hintText: 'Search friends',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<List<_CallFriend>>(
                future: _loadFriends(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cyan,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load friends',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  final allFriends =
                      snapshot.data ?? <_CallFriend>[];

                  final friends = allFriends
                      .where(_matchesSearch)
                      .toList();

                  if (allFriends.isEmpty) {
                    return const Center(
                      child: Text(
                        'No friends yet',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  if (friends.isEmpty) {
                    return const Center(
                      child: Text(
                        'No friends found',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      4,
                      18,
                      110,
                    ),
                    itemCount: friends.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final selected =
                          _selectedIds.contains(friend.id);

                      return _buildFriendTile(
                        friend,
                        selected,
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                14,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _selectedIds.isEmpty ? null : _addSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyan,
                    disabledBackgroundColor:
                        surfaceRaised,
                    foregroundColor: Colors.black,
                    disabledForegroundColor:
                        Colors.white30,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Select friends'
                        : 'Add ${_selectedIds.length} '
                          '${_selectedIds.length == 1 ? 'person' : 'people'} '
                          'to call',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
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

  Widget _buildFriendTile(
    _CallFriend friend,
    bool selected,
  ) {
    return InkWell(
      onTap: () => _toggleFriend(friend.id),
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? cyan.withValues(alpha: 0.08)
              : surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? cyan.withValues(alpha: 0.48)
                : border,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: surfaceRaised,
                  backgroundImage:
                      friend.photoUrl.isNotEmpty
                          ? NetworkImage(friend.photoUrl)
                          : null,
                  child: friend.photoUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white54,
                        )
                      : null,
                ),

                if (selected)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cyan,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: background,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          friend.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      if (friend.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF2196F3),
                          size: 16,
                        ),
                      ],
                    ],
                  ),

                  if (friend.username.isNotEmpty)
                    Text(
                      '@${friend.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? cyan : Colors.white24,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }
}

class _CallFriend {
  const _CallFriend({
    required this.id,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.verified,
  });

  final String id;
  final String name;
  final String username;
  final String photoUrl;
  final bool verified;
}