import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/call_service.dart';
import 'voice_call_screen.dart';

/// ============================================================================
/// CHATTªX — OUTGOING VOICE CALL SCREEN
/// ============================================================================
///
/// REAL CALL FLOW
///
///   OutgoingVoiceCallScreen
///             │
///             ▼
///      ChattaxCallService
///             │
///       ┌─────┼──────────────┐
///       ▼     ▼              ▼
///    calling ringing      connecting
///                              │
///                              ▼
///                          connected
///                              │
///                              ▼
///                       VoiceCallScreen
///
/// This screen does NOT connect using a timer.
/// ChattaxCallService remains the source of truth.
///
/// RINGTONE:
/// assets/audio/outgoing_ringtone.mp3
///
/// Plays:
///   calling
///   ringing
///
/// Stops:
///   connecting
///   connected
///   rejected
///   ended
///   failed
///   cancelling
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

  StreamSubscription<ChattaxCallStatus>? _statusSubscription;

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
  bool _hasOpenedConnectedScreen = false;

  // Prevent multiple finish operations from
  // competing with each other.
  bool _isFinishing = false;

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

    _activeCallId = widget.callId;

    _initializeAnimations();
    _setSystemUi();

    // Prepare ringtone immediately.
    unawaited(_prepareOutgoingRingtone());

    // Start listening to the real call service.
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
          _isCancelling) {
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
        _isCancelling) {
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
  // CALL STATUS
  // ==========================================================================

  void _listenForCallStatus() {
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

        // Ignore duplicate states.
        if (_status == status) {
          return;
        }

        setState(() {
          _status = status;
        });

        unawaited(
          _handleStatusChange(status),
        );
      },
      onError: (Object error) {
        debugPrint(
          'ChattªX call status error: $error',
        );

        if (!mounted ||
            _hasFinished ||
            _isCancelling ||
            _isFinishing) {
          return;
        }

        unawaited(
          _finishCall(
            'Call connection failed',
          ),
        );
      },
    );
  }

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

        await _stopOutgoingRingtone();
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
            _isFinishing) {
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
  // DISPLAY NAME
  // ==========================================================================

  String _displayName() {
    final name = widget.callerName.trim();

    if (name.isEmpty) {
      return 'Unknown user';
    }

    return name;
  }

  // ==========================================================================
  // CONNECTED CALL
  // ==========================================================================

  void _openConnectedCall() {
    if (!mounted ||
        _hasFinished ||
        _isCancelling ||
        _isFinishing ||
        _hasOpenedConnectedScreen) {
      return;
    }

    _hasOpenedConnectedScreen = true;

    // Stop listening before replacing this route.
    unawaited(
      _statusSubscription?.cancel(),
    );

    _statusSubscription = null;

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
            callId: _activeCallId,
          );
        },
        transitionsBuilder: (
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
        _isFinishing) {
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

    // Immediately stop the ringtone.
    await _stopOutgoingRingtone();

    try {
      // Cancel the real call through the service.
      //
      // The service remains responsible for changing
      // Firestore state.
      await _callService.cancelCall();

      _hasFinished = true;

      await _statusSubscription?.cancel();
      _statusSubscription = null;

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

      // Only restart if the call is still in a
      // state where ringing should continue.
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
        _isFinishing) {
      return;
    }

    _isFinishing = true;
    _hasFinished = true;

    await _stopOutgoingRingtone();

    await _statusSubscription?.cancel();
    _statusSubscription = null;

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

  void _addCall() {
    if (_isCancelling ||
        _hasFinished ||
        _isFinishing) {
      return;
    }

    HapticFeedback.lightImpact();

    _showSnackBar(
      'Add participant is available after the call connects.',
    );
  }

  // ==========================================================================
  // MORE
  // ==========================================================================

  void _showMore() {
    if (_isCancelling ||
        _hasFinished ||
        _isFinishing) {
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
      // IMPORTANT:
      //
      // Never allow the route to pop directly while
      // an outgoing call is active.
      //
      // This guarantees Android back / system back
      // goes through _cancelCall().
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop ||
            _isCancelling ||
            _hasFinished ||
            _isFinishing) {
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
                  // HOME INDICATOR
                  // ==========================================================

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 7,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 115,
                          height: 4,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ),
                    ),
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
        final value =
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
    final screenHeight =
        constraints.maxHeight;
    final screenWidth =
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
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child:
              _buildWaitingCard(
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
          padding:
              const EdgeInsets.symmetric(
            horizontal: 6,
          ),
          child:
              _buildControls(
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
                  _isFinishing
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
              // ==============================================================
              // WAVE
              // ==============================================================

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

              // ==============================================================
              // PULSE
              // ==============================================================

              AnimatedBuilder(
                animation:
                    _pulseController,
                builder:
                    (context, child) {
                  final pulse =
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

              // ==============================================================
              // ROTATING RING + AVATAR
              // ==============================================================

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

        // ====================================================================
        // NAME
        // ====================================================================

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _displayName(),
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
                        FontWeight.w600,
                    letterSpacing:
                        -0.6,
                  ),
                ),
              ),

              const SizedBox(width: 7),

              // ==============================================================
              // VERIFIED BADGE
              // ==============================================================

              Container(
                width:
                    verySmall
                        ? 23
                        : compact
                            ? 26
                            : 29,
                height:
                    verySmall
                        ? 23
                        : compact
                            ? 26
                            : 29,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      Color(
                        0xFFB34BFF,
                      ),
                      Color(
                        0xFF7131FF,
                      ),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color:
                      Colors.white,
                  size:
                      verySmall
                          ? 15
                          : 18,
                ),
              ),
            ],
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
        text = 'Ringing...';
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
        text = 'Connected';
        color =
            const Color(0xFF17EFAF);
        icon =
            Icons.call_rounded;
        break;

      case ChattaxCallStatus.rejected:
        text = 'Call declined';
        color =
            const Color(0xFFFF4752);
        icon =
            Icons.call_end_rounded;
        break;

      case ChattaxCallStatus.ended:
        text = 'Call ended';
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
            label: 'Mute',
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
            label: 'Speaker',
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
            label: 'Add Call',
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
            label: 'Cancel',
            buttonSize:
                buttonSize,
            isEnd: true,
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
                      _isFinishing
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