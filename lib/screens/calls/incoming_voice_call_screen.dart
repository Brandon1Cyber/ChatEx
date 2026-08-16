import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/call_service.dart';
import 'voice_call_screen.dart';

/// ============================================================================
/// CHATTªX — INCOMING VOICE CALL SCREEN
/// ============================================================================
///
/// FLOW:
///
/// Firestore
///     │
///     ▼
/// IncomingVoiceCallScreen
///     │
///     ├── Decline
///     │      └── rejectCall()
///     │
///     └── Accept
///            └── acceptCall()
///                   │
///                   ▼
///             VoiceCallScreen
///                   │
///                   ▼
///             WebRTC connects
///
/// IMPORTANT:
/// - This screen does NOT own WebRTC.
/// - ChattaxCallService owns signaling/WebRTC.
/// - This screen owns the incoming-call UI and ringtone.
/// - When acceptCall() succeeds, we immediately navigate to
///   VoiceCallScreen instead of waiting for a CONNECTED event.
/// ============================================================================

class IncomingVoiceCallScreen extends StatefulWidget {
  final String callId;

  final String callerName;
  final String? callerImageUrl;
  final ImageProvider? callerImage;

  final bool isVerified;

  final VoidCallback? onDecline;
  final VoidCallback? onRemindMe;
  final VoidCallback? onMessage;

  const IncomingVoiceCallScreen({
    super.key,
    required this.callId,
    this.callerName = 'Brandon Hotshot',
    this.callerImageUrl,
    this.callerImage,
    this.isVerified = true,
    this.onDecline,
    this.onRemindMe,
    this.onMessage,
  });

  @override
  State<IncomingVoiceCallScreen> createState() =>
      _IncomingVoiceCallScreenState();
}

class _IncomingVoiceCallScreenState
    extends State<IncomingVoiceCallScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // CALL SERVICE
  // ==========================================================================

  final ChattaxCallService _callService =
      ChattaxCallService.instance;

  StreamSubscription<ChattaxCallStatus>?
      _callStatusSubscription;

  // ==========================================================================
  // RINGTONE
  // ==========================================================================

  late final AudioPlayer _ringtonePlayer;

  bool _ringtoneStarting = false;
  bool _ringtoneDisposed = false;

  // ==========================================================================
  // ANIMATION
  // ==========================================================================

  late final AnimationController _pulseController;

  late final Animation<double> _pulseAnimation;

  // ==========================================================================
  // STATE
  // ==========================================================================

  bool _isProcessing = false;

  bool _hasOpenedCall = false;

  bool _hasClosed = false;

  // ==========================================================================
  // SWIPE
  // ==========================================================================

  bool _isSwipeTracking = false;

  double _swipeDistance = 0.0;

  static const double _swipeThreshold = 100.0;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _ringtonePlayer = AudioPlayer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1500,
      ),
    )..repeat(
        reverse: true,
      );

    _pulseAnimation = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _setSystemUi();

    _listenToCallStatus();

    unawaited(
      _startIncomingRingtone(),
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _hasClosed = true;

    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    _stopAndDisposeRingtone();

    _pulseController.dispose();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
    );

    super.dispose();
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
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
    );
  }

  // ==========================================================================
  // RINGTONE
  // ==========================================================================

  Future<void> _startIncomingRingtone() async {
    if (_ringtoneStarting ||
        _ringtoneDisposed ||
        _hasClosed) {
      return;
    }

    _ringtoneStarting = true;

    try {
      debugPrint(
        'ChattªX: starting incoming ringtone',
      );

      await _ringtonePlayer.setAsset(
        'assets/audio/incoming_ringtone.mp3',
      );

      if (_hasClosed ||
          _ringtoneDisposed) {
        return;
      }

      await _ringtonePlayer.setLoopMode(
        LoopMode.one,
      );

      await _ringtonePlayer.setVolume(1.0);

      if (_hasClosed ||
          _ringtoneDisposed) {
        return;
      }

      await _ringtonePlayer.play();

      debugPrint(
        'ChattªX: incoming ringtone playing',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ChattªX ringtone error: '
        '$error\n$stackTrace',
      );
    } finally {
      _ringtoneStarting = false;
    }
  }

  Future<void> _stopRingtone() async {
    if (_ringtoneDisposed) {
      return;
    }

    try {
      if (_ringtonePlayer.playing) {
        await _ringtonePlayer.stop();
      }
    } catch (error) {
      debugPrint(
        'ChattªX ringtone stop error: $error',
      );
    }
  }

  void _stopAndDisposeRingtone() {
    if (_ringtoneDisposed) {
      return;
    }

    _ringtoneDisposed = true;

    unawaited(
      _ringtonePlayer.stop().catchError(
        (Object error) {
          debugPrint(
            'ChattªX ringtone stop error: $error',
          );
        },
      ),
    );

    unawaited(
      _ringtonePlayer.dispose().catchError(
        (Object error) {
          debugPrint(
            'ChattªX ringtone dispose error: $error',
          );
        },
      ),
    );
  }

  // ==========================================================================
  // CALL STATUS
  // ==========================================================================

  void _listenToCallStatus() {
    _callStatusSubscription =
        _callService.callStatusStream.listen(
      _handleCallStatus,
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'ChattªX incoming status error: '
          '$error',
        );
      },
    );
  }

  void _handleCallStatus(
    ChattaxCallStatus status,
  ) {
    if (!mounted || _hasClosed) {
      return;
    }

    debugPrint(
      'ChattªX incoming call '
      '${widget.callId} status: $status',
    );

    switch (status) {
      // ======================================================================
      // RINGING
      // ======================================================================

      case ChattaxCallStatus.ringing:
        if (!_isProcessing) {
          unawaited(
            _startIncomingRingtone(),
          );
        }
        break;

      // ======================================================================
      // CALLING
      // ======================================================================

      case ChattaxCallStatus.calling:
        break;

      // ======================================================================
      // CONNECTING
      // ======================================================================

      case ChattaxCallStatus.connecting:
        unawaited(
          _stopRingtone(),
        );

        if (mounted &&
            !_hasClosed &&
            !_hasOpenedCall) {
          setState(() {
            _isProcessing = true;
          });
        }
        break;

      // ======================================================================
      // CONNECTED
      // ======================================================================
      //
      // Normally VoiceCallScreen is already open because we navigate
      // immediately after acceptCall().
      //
      // This remains as a safety fallback in case the service reports
      // connected before navigation finishes.
      // ======================================================================

      case ChattaxCallStatus.connected:
        if (!_hasOpenedCall) {
          _openConnectedCall();
        }
        break;

      // ======================================================================
      // REJECTED
      // ======================================================================

      case ChattaxCallStatus.rejected:
        unawaited(
          _stopRingtone(),
        );

        if (!_hasOpenedCall) {
          _closeIncomingScreen();
        }
        break;

      // ======================================================================
      // ENDED
      // ======================================================================

      case ChattaxCallStatus.ended:
        unawaited(
          _stopRingtone(),
        );

        if (!_hasOpenedCall) {
          _closeIncomingScreen();
        }
        break;

      // ======================================================================
      // FAILED
      // ======================================================================

      case ChattaxCallStatus.failed:
        unawaited(
          _stopRingtone(),
        );

        if (!_hasOpenedCall &&
            mounted &&
            !_hasClosed) {
          setState(() {
            _isProcessing = false;
          });

          _showCallError(
            'The call could not be connected.',
          );
        }
        break;
    }
  }

  // ==========================================================================
  // ACCEPT CALL
  // ==========================================================================
  //
  // IMPORTANT CHANGE:
  //
  // OLD:
  //
  //   await acceptCall()
  //   wait for connected
  //   open VoiceCallScreen
  //
  // NEW:
  //
  //   await acceptCall()
  //   immediately open VoiceCallScreen
  //
  // VoiceCallScreen then owns the connected-call UI while the service
  // continues handling WebRTC.
  // ==========================================================================

  Future<void> _acceptCall() async {
    if (_isProcessing ||
        _hasClosed ||
        _hasOpenedCall) {
      return;
    }

    final callId = widget.callId.trim();

    if (callId.isEmpty) {
      _showCallError(
        'Invalid call ID.',
      );
      return;
    }

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    await _stopRingtone();

    try {
      debugPrint(
        '════════════════════════════════════',
      );

      debugPrint(
        'ChattªX: ACCEPTING INCOMING CALL',
      );

      debugPrint(
        'callId: $callId',
      );

      debugPrint(
        'caller: ${widget.callerName}',
      );

      debugPrint(
        '════════════════════════════════════',
      );

      // ======================================================================
      // ACCEPT CALL IN SERVICE
      // ======================================================================

      await _callService.acceptCall(
        callId,
      );

      if (!mounted ||
          _hasClosed ||
          _hasOpenedCall) {
        return;
      }

      debugPrint(
        'ChattªX: acceptCall() completed.',
      );

      debugPrint(
        'ChattªX: opening VoiceCallScreen...',
      );

      // ======================================================================
      // OPEN REAL CALL SCREEN IMMEDIATELY
      // ======================================================================

      _openVoiceCallScreen();

    } catch (error, stackTrace) {
      debugPrint(
        '════════════════════════════════════',
      );

      debugPrint(
        'ChattªX: ACCEPT FAILED',
      );

      debugPrint(
        '$error',
      );

      debugPrint(
        '$stackTrace',
      );

      debugPrint(
        '════════════════════════════════════',
      );

      if (!mounted ||
          _hasClosed) {
        return;
      }

      setState(() {
        _isProcessing = false;
      });

      unawaited(
        _startIncomingRingtone(),
      );

      _showCallError(
        _friendlyAcceptError(error),
      );
    }
  }

  // ==========================================================================
  // OPEN VOICE CALL SCREEN
  // ==========================================================================

  void _openVoiceCallScreen() {
    if (!mounted ||
        _hasClosed ||
        _hasOpenedCall) {
      return;
    }

    _hasOpenedCall = true;
    _hasClosed = true;

    unawaited(
      _stopRingtone(),
    );

    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    debugPrint(
      '════════════════════════════════════',
    );

    debugPrint(
      'ChattªX: OPENING VOICE CALL SCREEN',
    );

    debugPrint(
      'callId: ${widget.callId}',
    );

    debugPrint(
      'caller: ${widget.callerName}',
    );

    debugPrint(
      '════════════════════════════════════',
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
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
          Animation<double> secondaryAnimation,
        ) {
          return VoiceCallScreen(
            callerName:
                widget.callerName,
            profileImageUrl:
                widget.callerImageUrl,
            callId:
                widget.callId,
          );
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final curvedAnimation =
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
  }

  // ==========================================================================
  // CONNECTED FALLBACK
  // ==========================================================================

  void _openConnectedCall() {
    if (!mounted ||
        _hasOpenedCall ||
        _hasClosed) {
      return;
    }

    _openVoiceCallScreen();
  }

  // ==========================================================================
  // ACCEPT ERROR
  // ==========================================================================

  String _friendlyAcceptError(
    Object error,
  ) {
    final message = error.toString();

    if (message.contains(
      'permission-denied',
    )) {
      return 'ChattªX cannot update the call. '
          'Check your Firestore rules.';
    }

    if (message.toLowerCase().contains(
      'microphone',
    )) {
      return 'Microphone permission is required '
          'to answer the call.';
    }

    if (message.toLowerCase().contains(
      'receiver mismatch',
    )) {
      return 'This call belongs to another account.';
    }

    if (message.toLowerCase().contains(
      'no longer available',
    )) {
      return 'This call is no longer available.';
    }

    if (message.toLowerCase().contains(
      'offer',
    )) {
      return 'The caller connection could not be established.';
    }

    return 'Unable to answer call.\n$message';
  }

  // ==========================================================================
  // DECLINE
  // ==========================================================================

  Future<void> _declineCall() async {
    if (_isProcessing ||
        _hasClosed) {
      return;
    }

    final callId = widget.callId.trim();

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    await _stopRingtone();

    if (callId.isEmpty) {
      widget.onDecline?.call();

      _closeIncomingScreen();

      return;
    }

    try {
      debugPrint(
        'ChattªX: declining call $callId',
      );

      await _callService.rejectCall(
        callId,
      );

      if (!mounted ||
          _hasClosed) {
        return;
      }

      widget.onDecline?.call();

      _closeIncomingScreen();
    } catch (error, stackTrace) {
      debugPrint(
        'ChattªX decline error: '
        '$error\n$stackTrace',
      );

      if (!mounted ||
          _hasClosed) {
        return;
      }

      setState(() {
        _isProcessing = false;
      });

      unawaited(
        _startIncomingRingtone(),
      );

      _showCallError(
        'Unable to decline call.',
      );
    }
  }

  // ==========================================================================
  // CLOSE
  // ==========================================================================

  void _closeIncomingScreen() {
    if (!mounted ||
        _hasClosed) {
      return;
    }

    _hasClosed = true;

    unawaited(
      _stopRingtone(),
    );

    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    Navigator.of(context).pop();
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showCallError(
    String message,
  ) {
    if (!mounted ||
        _hasClosed) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(
            seconds: 5,
          ),
        ),
      );
  }

  // ==========================================================================
  // REMIND ME
  // ==========================================================================

  void _remindMe() {
    if (_isProcessing ||
        _hasClosed) {
      return;
    }

    HapticFeedback.lightImpact();

    widget.onRemindMe?.call();
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _message() {
    if (_isProcessing ||
        _hasClosed) {
      return;
    }

    HapticFeedback.lightImpact();

    widget.onMessage?.call();
  }

  // ==========================================================================
  // SWIPE START
  // ==========================================================================

  void _onSwipeStart(
    DragStartDetails details,
  ) {
    if (_isProcessing ||
        _hasClosed) {
      return;
    }

    setState(() {
      _isSwipeTracking = true;
      _swipeDistance = 0.0;
    });
  }

  // ==========================================================================
  // SWIPE UPDATE
  // ==========================================================================

  void _onSwipeUpdate(
    DragUpdateDetails details,
  ) {
    if (_isProcessing ||
        !_isSwipeTracking ||
        _hasClosed) {
      return;
    }

    if (details.delta.dy >= 0) {
      return;
    }

    final movement =
        -details.delta.dy;

    final nextDistance =
        (_swipeDistance + movement)
            .clamp(
      0.0,
      _swipeThreshold,
    );

    setState(() {
      _swipeDistance =
          nextDistance;
    });

    if (_swipeDistance >=
        _swipeThreshold) {
      _finishSwipeAccept();
    }
  }

  // ==========================================================================
  // SWIPE ACCEPT
  // ==========================================================================

  void _finishSwipeAccept() {
    if (_isProcessing ||
        _hasClosed) {
      return;
    }

    _isSwipeTracking = false;

    HapticFeedback.mediumImpact();

    unawaited(
      _acceptCall(),
    );
  }

  // ==========================================================================
  // SWIPE END
  // ==========================================================================

  void _onSwipeEnd(
    DragEndDetails details,
  ) {
    if (!mounted ||
        _isProcessing ||
        _hasClosed) {
      return;
    }

    setState(() {
      _isSwipeTracking = false;
      _swipeDistance = 0.0;
    });
  }

  // ==========================================================================
  // SWIPE CANCEL
  // ==========================================================================

  void _onSwipeCancel() {
    if (!mounted ||
        _isProcessing ||
        _hasClosed) {
      return;
    }

    setState(() {
      _isSwipeTracking = false;
      _swipeDistance = 0.0;
    });
  }

  // ==========================================================================
  // CALLER IMAGE
  // ==========================================================================

  ImageProvider _getCallerImage() {
    if (widget.callerImage != null) {
      return widget.callerImage!;
    }

    final url =
        widget.callerImageUrl?.trim();

    if (url != null &&
        url.isNotEmpty) {
      return NetworkImage(url);
    }

    return const AssetImage(
      'assets/default_profile.png',
    );
  }

  // ==========================================================================
  // CALLER NAME
  // ==========================================================================

  String get _displayCallerName {
    final name =
        widget.callerName.trim();

    if (name.isEmpty) {
      return 'Unknown caller';
    }

    return name;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnnotatedRegion<
        SystemUiOverlayStyle>(
      value:
          const SystemUiOverlayStyle(
        statusBarColor:
            Colors.transparent,
        systemNavigationBarColor:
            Colors.transparent,
        statusBarIconBrightness:
            Brightness.light,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
      child: Scaffold(
        backgroundColor:
            const Color(0xFF02000D),
        body: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final width =
                constraints.maxWidth;

            final height =
                constraints.maxHeight;

            final avatarSize =
                (width * 0.50).clamp(
              170.0,
              330.0,
            );

            final buttonSize =
                (width * 0.145).clamp(
              64.0,
              92.0,
            );

            final horizontalPadding =
                (width * 0.07).clamp(
              20.0,
              55.0,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                _buildBackground(),

                _buildBackgroundOverlay(),

                SafeArea(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal:
                          horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height:
                              (height * 0.035)
                                  .clamp(
                            12.0,
                            42.0,
                          ),
                        ),

                        _buildHeader(),

                        SizedBox(
                          height:
                              (height * 0.018)
                                  .clamp(
                            8.0,
                            22.0,
                          ),
                        ),

                        Expanded(
                          flex: 5,
                          child: Center(
                            child:
                                _buildCallerArea(
                              avatarSize,
                              width,
                            ),
                          ),
                        ),

                        _buildSecondaryActions(),

                        SizedBox(
                          height:
                              (height * 0.028)
                                  .clamp(
                            12.0,
                            30.0,
                          ),
                        ),

                        _buildCallButtons(
                          buttonSize,
                        ),

                        SizedBox(
                          height:
                              (height * 0.020)
                                  .clamp(
                            8.0,
                            22.0,
                          ),
                        ),

                        _buildSwipeGestureArea(),

                        SizedBox(
                          height:
                              (height * 0.010)
                                  .clamp(
                            5.0,
                            12.0,
                          ),
                        ),
                      ],
                    ),
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
  // BACKGROUND
  // ==========================================================================

  Widget _buildBackground() {
    return Image.asset(
      'assets/outgoing_voice_call_background.png',
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const ColoredBox(
          color: Color(0xFF02000D),
        );
      },
    );
  }

  // ==========================================================================
  // OVERLAY
  // ==========================================================================

  Widget _buildBackgroundOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(
                alpha: 0.14,
              ),
              Colors.black.withValues(
                alpha: 0.06,
              ),
              Colors.black.withValues(
                alpha: 0.20,
              ),
              Colors.black.withValues(
                alpha: 0.58,
              ),
            ],
            stops: const [
              0.0,
              0.32,
              0.68,
              1.0,
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        const Icon(
          Icons.phone_in_talk_rounded,
          color: Color(0xFFBE7CFF),
          size: 27,
        ),

        const SizedBox(
          height: 8,
        ),

        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    'Incoming Voice ',
                style: TextStyle(
                  color:
                      Color(0xFFD39AFF),
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'Call',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w400,
                ),
              ),
            ],
          ),
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 8,
        ),

        Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 15,
              color:
                  Colors.white.withValues(
                alpha: 0.42,
              ),
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              'End-to-end encrypted',
              style: TextStyle(
                color:
                    Colors.white.withValues(
                  alpha: 0.45,
                ),
                fontSize: 14,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // CALLER AREA
  // ==========================================================================

  Widget _buildCallerArea(
    double avatarSize,
    double width,
  ) {
    final nameSize =
        (width * 0.064).clamp(
      22.0,
      31.0,
    );

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        SizedBox(
          width:
              double.infinity,
          height: 28,
          child:
              const CustomPaint(
            painter:
                _WaveformPainter(),
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        AnimatedBuilder(
          animation:
              _pulseAnimation,
          builder: (
            BuildContext context,
            Widget? child,
          ) {
            return Transform.scale(
              scale:
                  _pulseAnimation.value,
              child: child,
            );
          },
          child:
              _buildAvatar(
            avatarSize,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        _buildCallerName(
          nameSize,
        ),

        const SizedBox(
          height: 7,
        ),

        AnimatedSwitcher(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          child: Text(
            _isProcessing
                ? 'Connecting...'
                : 'is calling you...',
            key: ValueKey(
              _isProcessing,
            ),
            style: TextStyle(
              color:
                  Colors.white.withValues(
                alpha: 0.62,
              ),
              fontSize: 17,
              fontWeight:
                  FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================

  Widget _buildAvatar(
    double avatarSize,
  ) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      padding:
          const EdgeInsets.all(4),
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFA855FF),
            Color(0xFF763BFF),
            Color(0xFF00B7FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(
              0xFF803CFF,
            ).withValues(
              alpha: 0.42,
            ),
            blurRadius: 32,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Container(
        padding:
            const EdgeInsets.all(3),
        decoration:
            const BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              Color(0xFF080313),
        ),
        child:
            ClipOval(
          child: Image(
            image:
                _getCallerImage(),
            fit:
                BoxFit.cover,
            filterQuality:
                FilterQuality.high,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return _buildFallbackAvatar(
                avatarSize,
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FALLBACK AVATAR
  // ==========================================================================

  Widget _buildFallbackAvatar(
    double avatarSize,
  ) {
    return Container(
      color:
          const Color(0xFF20132F),
      alignment:
          Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color:
            Colors.white.withValues(
          alpha: 0.75,
        ),
        size:
            avatarSize * 0.32,
      ),
    );
  }

  // ==========================================================================
  // CALLER NAME
  // ==========================================================================

  Widget _buildCallerName(
    double nameSize,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Flexible(
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 280,
              ),
              child: Text(
                _displayCallerName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      nameSize,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing:
                      -0.6,
                ),
              ),
            ),
          ),

          if (widget.isVerified) ...[
            const SizedBox(
              width: 8,
            ),
            _buildVerifiedBadge(),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // VERIFIED BADGE
  // ==========================================================================

  Widget _buildVerifiedBadge() {
    return Semantics(
      label: 'Verified',
      child: Container(
        width: 31,
        height: 31,
        decoration:
            const BoxDecoration(
          shape:
              BoxShape.circle,
          gradient:
              LinearGradient(
            colors: [
              Color(0xFFB34BFF),
              Color(0xFF7131FF),
            ],
          ),
        ),
        child:
            const Icon(
          Icons.check_rounded,
          color:
              Colors.white,
          size: 21,
        ),
      ),
    );
  }

  // ==========================================================================
  // SECONDARY ACTIONS
  // ==========================================================================

  Widget _buildSecondaryActions() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceAround,
      children: [
        _SecondaryCallAction(
          icon:
              Icons.alarm_rounded,
          title:
              'Remind Me',
          onTap:
              _remindMe,
          enabled:
              !_isProcessing,
        ),
        _SecondaryCallAction(
          icon:
              Icons.chat_bubble_rounded,
          title:
              'Message',
          onTap:
              _message,
          enabled:
              !_isProcessing,
        ),
      ],
    );
  }

  // ==========================================================================
  // MAIN BUTTONS
  // ==========================================================================

  Widget _buildCallButtons(
    double buttonSize,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceAround,
      children: [
        _CallActionButton(
          size:
              buttonSize,
          backgroundColor:
              const Color(
            0xFFFF3038,
          ),
          icon:
              Icons.call_end_rounded,
          label:
              'Decline',
          enabled:
              !_isProcessing,
          onTap:
              _declineCall,
        ),
        _CallActionButton(
          size:
              buttonSize,
          backgroundColor:
              const Color(
            0xFF35D875,
          ),
          icon:
              Icons.call_rounded,
          label:
              'Accept',
          enabled:
              !_isProcessing,
          onTap:
              _acceptCall,
        ),
      ],
    );
  }

  // ==========================================================================
  // SWIPE AREA
  // ==========================================================================

  Widget _buildSwipeGestureArea() {
    final progress =
        (_swipeDistance /
                _swipeThreshold)
            .clamp(
      0.0,
      1.0,
    );

    final progressColor =
        Color.lerp(
      const Color(0xFF7B2FF7),
      const Color(0xFF00D9FF),
      progress,
    )!;

    return Semantics(
      label:
          'Swipe up to answer incoming call',
      child:
          GestureDetector(
        behavior:
            HitTestBehavior.opaque,
        onVerticalDragStart:
            _onSwipeStart,
        onVerticalDragUpdate:
            _onSwipeUpdate,
        onVerticalDragEnd:
            _onSwipeEnd,
        onVerticalDragCancel:
            _onSwipeCancel,
        child: SizedBox(
          width:
              double.infinity,
          height: 58,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset:
                    Offset(
                  0,
                  -progress * 7,
                ),
                child:
                    Icon(
                  Icons
                      .keyboard_arrow_up_rounded,
                  size: 28,
                  color:
                      Color.lerp(
                    const Color(
                      0xFF9D4DFF,
                    ),
                    const Color(
                      0xFF00D9FF,
                    ),
                    progress,
                  ),
                ),
              ),

              Text(
                progress >= 0.75
                    ? 'Keep swiping up...'
                    : 'Swipe up to answer',
                style:
                    TextStyle(
                  color:
                      Colors.white.withValues(
                    alpha:
                        progress > 0.7
                            ? 0.85
                            : 0.62,
                  ),
                  fontSize:
                      15,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              SizedBox(
                width: 100,
                height: 3,
                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  child:
                      LinearProgressIndicator(
                    value:
                        progress,
                    backgroundColor:
                        Colors.white
                            .withValues(
                      alpha: 0.10,
                    ),
                    valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                      progressColor,
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
}

// ============================================================================
// SECONDARY CALL ACTION
// ============================================================================

class _SecondaryCallAction
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final VoidCallback onTap;

  final bool enabled;

  const _SecondaryCallAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      child:
          GestureDetector(
        onTap:
            enabled
                ? onTap
                : null,
        behavior:
            HitTestBehavior.opaque,
        child:
            AnimatedOpacity(
          duration:
              const Duration(
            milliseconds: 150,
          ),
          opacity:
              enabled
                  ? 1.0
                  : 0.40,
          child:
              SizedBox(
            width: 120,
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color:
                      Colors.white,
                  size: 31,
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  title,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.70,
                    ),
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w500,
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

// ============================================================================
// MAIN CALL BUTTON
// ============================================================================

class _CallActionButton
    extends StatelessWidget {
  final double size;

  final Color backgroundColor;

  final IconData icon;

  final String label;

  final VoidCallback onTap;

  final bool enabled;

  const _CallActionButton({
    required this.size,
    required this.backgroundColor,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child:
          GestureDetector(
        onTap:
            enabled
                ? onTap
                : null,
        behavior:
            HitTestBehavior.opaque,
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            AnimatedScale(
              scale:
                  enabled
                      ? 1.0
                      : 0.94,
              duration:
                  const Duration(
                milliseconds: 150,
              ),
              child:
                  AnimatedOpacity(
                duration:
                    const Duration(
                  milliseconds: 150,
                ),
                opacity:
                    enabled
                        ? 1.0
                        : 0.45,
                child:
                    Container(
                  width:
                      size,
                  height:
                      size,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color:
                            backgroundColor
                                .withValues(
                          alpha:
                              0.30,
                        ),
                        blurRadius:
                            22,
                        spreadRadius:
                            2,
                      ),
                    ],
                  ),
                  child:
                      Icon(
                    icon,
                    color:
                        Colors.white,
                    size:
                        size * 0.48,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              label,
              style:
                  TextStyle(
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.70,
                ),
                fontSize:
                    15,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WAVEFORM
// ============================================================================

class _WaveformPainter
    extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const int barCount = 55;

    final double centerY =
        size.height / 2;

    final double spacing =
        size.width / barCount;

    final Paint paint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap =
          StrokeCap.round;

    for (int i = 0;
        i < barCount;
        i++) {
      final double x =
          (i + 0.5) * spacing;

      final double centerDistance =
          (i - barCount / 2).abs() /
              (barCount / 2);

      final double baseHeight =
          4 +
          (1 - centerDistance) *
              18;

      final double variation =
          ((i * 37) % 11) / 11;

      final double barHeight =
          baseHeight *
              (0.55 +
                  variation *
                      0.45);

      if (i <
          barCount / 2) {
        paint.color =
            Color.lerp(
          const Color(
            0xFF00A8FF,
          ),
          const Color(
            0xFF7D35FF,
          ),
          i /
              (barCount / 2),
        )!;
      } else {
        paint.color =
            Color.lerp(
          const Color(
            0xFF7D35FF,
          ),
          const Color(
            0xFF00A8FF,
          ),
          (i -
                  barCount / 2) /
              (barCount / 2),
        )!;
      }

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
        _WaveformPainter oldDelegate,
  ) {
    return false;
  }
}