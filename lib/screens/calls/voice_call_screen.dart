import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callerName;
  final String? profileImageUrl;
  final String? callId;

  const VoiceCallScreen({
    super.key,
    this.callerName = 'Sarah Johnson',
    this.profileImageUrl,
    this.callId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  // ==========================================================================
  // COLORS
  // ==========================================================================

  static const Color background = Color(0xFF02050D);
  static const Color panel = Color(0xFF07101D);

  static const Color cyan = Color(0xFF20F5E1);
  static const Color purple = Color(0xFFB33DFF);
  static const Color blue = Color(0xFF4CCEFF);
  static const Color green = Color(0xFF20EFAF);
  static const Color red = Color(0xFFF3323C);

  // ==========================================================================
  // ANIMATION CONTROLLERS
  // ==========================================================================

  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _waveController;
  late final AnimationController _glowController;
  late final AnimationController _reactionController;
  late final AnimationController _detailsController;

  // ==========================================================================
  // CALL SERVICE
  // ==========================================================================

  final ChattaxCallService _callService = ChattaxCallService.instance;

  StreamSubscription<ChattaxCallStatus>? _callStatusSubscription;

  // ==========================================================================
  // CALL STATE
  // ==========================================================================

  bool isMuted = false;
  bool isSpeakerOn = true;
  bool isOnHold = false;

  bool isLocationSharing = true;
  bool isCallMemoryOn = true;
  bool isVoicePulseActive = true;
  bool isCallShieldOn = true;

  bool isNoiseCancellationOn = true;
  bool isVoiceEnhancementOn = true;
  bool isLowDataModeOn = false;

  bool _showDetails = false;
  bool _isEndingCall = false;

  int participants = 2;

  Duration callDuration = Duration.zero;

  String connectionStatus = 'Connecting';

  String selectedAtmosphere = 'Cafe';
  String selectedAudioRoute = 'Speaker';

  String selectedReaction = '';
  String? floatingReaction;

  Timer? _callTimer;
  Timer? _reactionClearTimer;

  // ==========================================================================
  // QUICK REACTIONS
  // ==========================================================================

  final List<String> _quickReactions = const [
    '❤️',
    '😂',
    '🔥',
    '👏',
    '👀',
    '💯',
  ];

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _detailsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    isMuted = _callService.isMicrophoneMuted;

    _listenToCallStatus();
    _startCallTimer();
  }

  // ==========================================================================
  // CALL STATUS
  // ==========================================================================

  void _listenToCallStatus() {
    _callStatusSubscription = _callService.callStatus.listen(
      (status) {
        if (!mounted) {
          return;
        }

        String newStatus;

        switch (status) {
          case ChattaxCallStatus.calling:
            newStatus = 'Calling';
            break;

          case ChattaxCallStatus.ringing:
            newStatus = 'Ringing';
            break;

          case ChattaxCallStatus.connecting:
            newStatus = 'Connecting';
            break;

          case ChattaxCallStatus.connected:
            newStatus = 'Excellent Connection';
            break;

          case ChattaxCallStatus.rejected:
            newStatus = 'Call Rejected';
            break;

          case ChattaxCallStatus.ended:
            newStatus = 'Call Ended';
            break;

          case ChattaxCallStatus.failed:
            newStatus = 'Connection Failed';
            break;
        }

        setState(() {
          connectionStatus = newStatus;
        });

        if (status == ChattaxCallStatus.ended ||
            status == ChattaxCallStatus.rejected ||
            status == ChattaxCallStatus.failed) {
          _callTimer?.cancel();

          if (_isEndingCall) {
            return;
          }

          Future.delayed(
            const Duration(milliseconds: 500),
            () {
              if (!mounted) {
                return;
              }

              Navigator.of(context).pop();
            },
          );
        }
      },
    );
  }

  // ==========================================================================
  // CALL TIMER
  // ==========================================================================

  void _startCallTimer() {
    _callTimer?.cancel();

    _callTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || isOnHold) {
          return;
        }

        setState(() {
          callDuration += const Duration(seconds: 1);
        });
      },
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _callTimer?.cancel();
    _reactionClearTimer?.cancel();
    _callStatusSubscription?.cancel();

    _pulseController.dispose();
    _ringController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _reactionController.dispose();
    _detailsController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // FORMAT DURATION
  // ==========================================================================

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // MORE DETAILS
  // ==========================================================================

  void _toggleMoreDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });

    if (_showDetails) {
      _detailsController.forward();
    } else {
      _detailsController.reverse();
    }
  }

  // ==========================================================================
  // END CALL
  // ==========================================================================

  Future<void> _endCall() async {
    if (_isEndingCall) {
      return;
    }

    final shouldEnd = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A111F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'End ChattªX Call?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to end this call?',
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'End Call',
                style: TextStyle(
                  color: red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldEnd != true) {
      return;
    }

    _isEndingCall = true;
    _callTimer?.cancel();

    try {
      await _callService.endCall();
    } catch (_) {
      // The call service owns WebRTC cleanup.
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ==========================================================================
  // MUTE
  // ==========================================================================

  Future<void> _toggleMute() async {
    try {
      await _callService.toggleMicrophone();

      if (!mounted) {
        return;
      }

      setState(() {
        isMuted = _callService.isMicrophoneMuted;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Unable to change microphone state.',
      );
    }
  }

  // ==========================================================================
  // SPEAKER
  // ==========================================================================

  Future<void> _toggleSpeaker() async {
    final newValue = !isSpeakerOn;

    try {
      await _callService.setSpeaker(newValue);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Unable to change audio output.',
      );

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isSpeakerOn = newValue;
      selectedAudioRoute = newValue ? 'Speaker' : 'Phone';
    });
  }

  // ==========================================================================
  // HOLD
  // ==========================================================================

  void _toggleHold() {
    setState(() {
      isOnHold = !isOnHold;
    });

    _showSnackBar(
      isOnHold
          ? 'Call placed on hold'
          : 'Call resumed',
    );
  }

  // ==========================================================================
  // AUDIO ROUTES
  // ==========================================================================

  void _showAudioRoutes() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        final routes = <_AudioRouteOption>[
          _AudioRouteOption(
            'Speaker',
            Icons.volume_up_rounded,
            cyan,
          ),
          _AudioRouteOption(
            'Phone',
            Icons.phone_in_talk_rounded,
            Colors.white,
          ),
          _AudioRouteOption(
            'Bluetooth',
            Icons.bluetooth_audio_rounded,
            blue,
          ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Text(
                  'Audio Output',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ...routes.map(
                  (route) {
                    final selected =
                        selectedAudioRoute == route.title;

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: route.color.withValues(
                            alpha: 0.10,
                          ),
                        ),
                        child: Icon(
                          route.icon,
                          color: route.color,
                        ),
                      ),
                      title: Text(
                        route.title,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      trailing: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected
                            ? route.color
                            : Colors.white24,
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);

                        if (route.title == 'Bluetooth') {
                          _showSnackBar(
                            'Bluetooth routing will follow the connected device.',
                          );
                        } else {
                          try {
                            await _callService.setSpeaker(
                              route.title == 'Speaker',
                            );
                          } catch (_) {
                            if (mounted) {
                              _showSnackBar(
                                'Unable to change audio output.',
                              );
                            }
                            return;
                          }
                        }

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          selectedAudioRoute =
                              route.title;
                          isSpeakerOn =
                              route.title == 'Speaker';
                        });
                      },
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
  // KEYPAD
  // ==========================================================================

  void _showKeypad() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) {
        return const _KeypadSheet();
      },
    );
  }

  // ==========================================================================
  // ADD CALL
  // ==========================================================================

  void _addCall() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Text(
                  'Add Participant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _actionTile(
                  icon: Icons.contacts_rounded,
                  title: 'Choose from Contacts',
                  subtitle:
                      'Invite someone from ChattªX',
                  color: purple,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showSnackBar(
                      'Contact selection will connect here.',
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.link_rounded,
                  title: 'Invite with ChattªX Link',
                  subtitle:
                      'Create a secure call invitation',
                  color: cyan,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showSnackBar(
                      'Call invitation link ready.',
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
  // MORE MENU
  // ==========================================================================

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Text(
                  'More Call Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _actionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Add Participant',
                  subtitle:
                      'Bring another person into the call',
                  color: purple,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    Future.delayed(
                      const Duration(milliseconds: 200),
                      _addCall,
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.message_rounded,
                  title: 'Open Chat',
                  subtitle:
                      'Continue chatting while calling',
                  color: cyan,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showSnackBar(
                      'Chat integration ready.',
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.security_rounded,
                  title: 'Security Information',
                  subtitle:
                      'View encryption and call security',
                  color: green,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    Future.delayed(
                      const Duration(milliseconds: 200),
                      _showSecurityInformation,
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Audio Settings',
                  subtitle:
                      'Noise cancellation and voice enhancement',
                  color: blue,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    Future.delayed(
                      const Duration(milliseconds: 200),
                      _showAudioSettings,
                    );
                  },
                ),
                _actionTile(
                  icon: Icons.location_on_rounded,
                  title: 'Share Location',
                  subtitle: isLocationSharing
                      ? 'Currently sharing live location'
                      : 'Location sharing is off',
                  color: Colors.tealAccent,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    setState(() {
                      isLocationSharing =
                          !isLocationSharing;
                    });
                  },
                ),
                _actionTile(
                  icon: Icons.bookmark_rounded,
                  title: 'Call Memory',
                  subtitle:
                      isCallMemoryOn
                          ? 'Enabled'
                          : 'Disabled',
                  color: purple,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    setState(() {
                      isCallMemoryOn =
                          !isCallMemoryOn;
                    });
                  },
                ),
                _actionTile(
                  icon: Icons.flag_outlined,
                  title: 'Report Call',
                  subtitle:
                      'Report an issue with this call',
                  color: red,
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _showSnackBar(
                      'Report options will connect here.',
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
  // AUDIO SETTINGS
  // ==========================================================================

  void _showAudioSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (modalContext, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 22),
                    const Text(
                      'Voice Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _settingSwitch(
                      icon: Icons.noise_aware_rounded,
                      title: 'Noise Cancellation',
                      subtitle:
                          'Reduce background noise',
                      value:
                          isNoiseCancellationOn,
                      color: cyan,
                      onChanged: (value) {
                        modalSetState(() {
                          isNoiseCancellationOn =
                              value;
                        });

                        setState(() {});
                      },
                    ),
                    _settingSwitch(
                      icon:
                          Icons.record_voice_over_rounded,
                      title: 'Voice Enhancement',
                      subtitle:
                          'Make speech clearer',
                      value:
                          isVoiceEnhancementOn,
                      color: purple,
                      onChanged: (value) {
                        modalSetState(() {
                          isVoiceEnhancementOn =
                              value;
                        });

                        setState(() {});
                      },
                    ),
                    _settingSwitch(
                      icon:
                          Icons.data_saver_on_rounded,
                      title: 'Low Data Mode',
                      subtitle:
                          'Reduce call bandwidth',
                      value: isLowDataModeOn,
                      color: green,
                      onChanged: (value) {
                        modalSetState(() {
                          isLowDataModeOn = value;
                        });

                        setState(() {});
                      },
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

  // ==========================================================================
  // SECURITY
  // ==========================================================================

  void _showSecurityInformation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green.withValues(
                      alpha: 0.10,
                    ),
                    border: Border.all(
                      color: green.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: green,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Call is Protected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ChattªX security information',
                  style: TextStyle(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),
                _securityRow(
                  Icons.lock_rounded,
                  'End-to-end encryption',
                  'Active',
                  green,
                ),
                _securityRow(
                  Icons.shield_rounded,
                  'Call Shield',
                  isCallShieldOn
                      ? 'Active'
                      : 'Off',
                  isCallShieldOn
                      ? green
                      : Colors.white38,
                ),
                _securityRow(
                  Icons.key_rounded,
                  'Secure session',
                  'Verified',
                  purple,
                ),
                _securityRow(
                  Icons.visibility_off_rounded,
                  'Recording protection',
                  'Enabled',
                  cyan,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // ATMOSPHERE
  // ==========================================================================

  void _showAtmosphere() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Text(
                  'Call Atmosphere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _atmosphereOption(
                  'Cafe',
                  Icons.coffee_rounded,
                  Colors.greenAccent,
                ),
                _atmosphereOption(
                  'Lo-Fi',
                  Icons.music_note_rounded,
                  purple,
                ),
                _atmosphereOption(
                  'Rain',
                  Icons.water_drop_rounded,
                  cyan,
                ),
                _atmosphereOption(
                  'None',
                  Icons.volume_off_rounded,
                  Colors.white70,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _atmosphereOption(
    String title,
    IconData icon,
    Color color,
  ) {
    final selected =
        selectedAtmosphere == title;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.10),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.chevron_right_rounded,
        color:
            selected ? color : Colors.white38,
      ),
      onTap: () {
        setState(() {
          selectedAtmosphere = title;
        });

        Navigator.pop(context);
      },
    );
  }

  // ==========================================================================
  // PARTICIPANTS
  // ==========================================================================

  void _showParticipants() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Call Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: purple.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$participants',
                        style: const TextStyle(
                          color: purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _participantTile(
                  widget.callerName,
                  widget.profileImageUrl,
                  'Connected',
                  green,
                ),
                _participantTile(
                  'You',
                  null,
                  isMuted
                      ? 'Muted'
                      : 'Connected',
                  isMuted ? red : green,
                ),
                const SizedBox(height: 8),
                _actionTile(
                  icon:
                      Icons.person_add_alt_1_rounded,
                  title: 'Add Participant',
                  subtitle:
                      'Invite someone else',
                  color: purple,
                  onTap: () {
                    Navigator.pop(context);
                    _addCall();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _participantTile(
    String name,
    String? imageUrl,
    String status,
    Color statusColor,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 2),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: statusColor.withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: ClipOval(
          child: imageUrl != null &&
                  imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) {
                    return _smallDefaultAvatar();
                  },
                )
              : _smallDefaultAvatar(),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.graphic_eq_rounded,
        color: statusColor,
      ),
    );
  }

  Widget _smallDefaultAvatar() {
    return Container(
      color: const Color(0xFF151B2B),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white38,
      ),
    );
  }

  // ==========================================================================
  // LIVE REACTIONS
  // ==========================================================================

  void _sendLiveReaction(String emoji) {
    _reactionClearTimer?.cancel();

    setState(() {
      selectedReaction = emoji;
      floatingReaction = emoji;
    });

    _reactionController.forward(from: 0);

    _reactionClearTimer = Timer(
      const Duration(milliseconds: 1400),
      () {
        if (!mounted) {
          return;
        }

        if (floatingReaction == emoji) {
          setState(() {
            floatingReaction = null;
          });
        }
      },
    );

    /*
     * IMPORTANT:
     *
     * The visual reaction is local here.
     *
     * The next service-layer step is to broadcast this emoji
     * through the active ChattªX WebRTC/Firebase call session
     * so the other participant sees the same floating reaction.
     *
     * We intentionally do not invent a method on
     * ChattaxCallService that does not currently exist.
     */
  }

  void _showReactionPicker() {
    const emojis = [
      '❤️',
      '😂',
      '🔥',
      '👏',
      '😍',
      '🎉',
      '😮',
      '👍',
      '👎',
      '💯',
      '🥳',
      '🚀',
      '🤣',
      '😘',
      '😎',
      '🙌',
      '✨',
      '💜',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF070A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Text(
                  'Send a Live Reaction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                GridView.builder(
                  shrinkWrap: true,
                  itemCount: emojis.length,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (_, index) {
                    final emoji = emojis[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _sendLiveReaction(emoji);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF101827),
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                        alignment:
                            Alignment.center,
                        child: Text(
                          emoji,
                          style:
                              const TextStyle(
                            fontSize: 26,
                          ),
                        ),
                      ),
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
  // SNACKBAR
  // ==========================================================================

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFF111A2C),
          behavior:
              SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildBackground(),
            ),

            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 280),
              child: _showDetails
                  ? _buildDetailsView()
                  : _buildMainCallView(),
            ),

            if (floatingReaction != null)
              _buildFloatingReaction(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN CALL VIEW
  // ==========================================================================

  Widget _buildMainCallView() {
    return Column(
      key: const ValueKey('mainCall'),
      children: [
        _buildHeader(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight =
                  constraints.maxHeight;

              final compact =
                  availableHeight < 700;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  compact ? 0 : 2,
                  18,
                  0,
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: compact ? 29 : 31,
                      child:
                          _buildCallerSection(
                        compact: compact,
                      ),
                    ),
                    SizedBox(
                      height:
                          compact ? 10 : 14,
                    ),
                    _buildCallInfoCards(
                      compact: compact,
                    ),
                    SizedBox(
                      height:
                          compact ? 10 : 14,
                    ),
                    _buildLiveReactions(
                      compact: compact,
                    ),
                    SizedBox(
                      height:
                          compact ? 12 : 18,
                    ),
                    Expanded(
                      flex: compact ? 27 : 25,
                      child:
                          _buildCallControls(
                        compact: compact,
                      ),
                    ),
                    _buildMoreDetailsButton(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MORE DETAILS BUTTON
  // ==========================================================================

  Widget _buildMoreDetailsButton() {
    return SizedBox(
      height: 50,
      child: GestureDetector(
        onTap: _toggleMoreDetails,
        behavior:
            HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    const Color(0xFF0B1423),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'More Details',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white38,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DETAILS VIEW
  // ==========================================================================

  Widget _buildDetailsView() {
    return Column(
      key: const ValueKey('details'),
      children: [
        _buildDetailsHeader(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  0,
                ),
                child: Column(
                  children: [
                    _buildDetailsSummary(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildDetailsGrid(
                        constraints.maxHeight,
                      ),
                    ),
                    _buildBackToCallButton(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // DETAILS HEADER
  // ==========================================================================

  Widget _buildDetailsHeader() {
    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            top: 12,
            child: _circleButton(
              icon:
                  Icons.keyboard_arrow_down_rounded,
              onTap: _toggleMoreDetails,
            ),
          ),
          Positioned(
            top: 10,
            child: Column(
              children: [
                const Text(
                  'Call Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(
                        callDuration,
                      ),
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 12,
            child: _circleButton(
              icon: Icons.more_vert_rounded,
              onTap: _showMore,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DETAILS SUMMARY
  // ==========================================================================

  Widget _buildDetailsSummary() {
    return Container(
      height: 92,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(
          alpha: 0.90,
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    green.withValues(
                  alpha: 0.30,
                ),
              ),
            ),
            child: ClipOval(
              child: _buildProfileImage(),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.callerName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: green,
                      size: 8,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        connectionStatus,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: green,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              const Text(
                'Duration',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(
                  callDuration,
                ),
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DETAILS GRID
  // ==========================================================================

  Widget _buildDetailsGrid(
    double availableHeight,
  ) {
    final compact =
        availableHeight < 570;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.bookmark_rounded,
                  title: 'Call Memory',
                  subtitle:
                      isCallMemoryOn
                          ? 'Enabled'
                          : 'Disabled',
                  color: purple,
                  trailing: Switch(
                    value:
                        isCallMemoryOn,
                    onChanged: (value) {
                      setState(() {
                        isCallMemoryOn =
                            value;
                      });
                    },
                    activeThumbColor: purple,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.music_note_rounded,
                  title: 'Atmosphere',
                  subtitle:
                      selectedAtmosphere,
                  color:
                      Colors.greenAccent,
                  onTap:
                      _showAtmosphere,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: compact ? 10 : 12,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _detailCard(
                  icon: isLocationSharing
                      ? Icons
                          .location_on_rounded
                      : Icons
                          .location_off_rounded,
                  title: 'Location',
                  subtitle:
                      isLocationSharing
                          ? 'Live Sharing'
                          : 'Off',
                  color: green,
                  onTap: () {
                    setState(() {
                      isLocationSharing =
                          !isLocationSharing;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.speed_rounded,
                  title: 'Call Quality',
                  subtitle:
                      connectionStatus ==
                              'Excellent Connection'
                          ? 'Excellent'
                          : 'Checking',
                  color:
                      connectionStatus ==
                              'Excellent Connection'
                          ? green
                          : Colors
                              .orangeAccent,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: compact ? 10 : 12,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.shield_rounded,
                  title: 'Call Shield',
                  subtitle:
                      isCallShieldOn
                          ? 'Protected'
                          : 'Off',
                  color:
                      isCallShieldOn
                          ? cyan
                          : Colors.white38,
                  onTap: () {
                    setState(() {
                      isCallShieldOn =
                          !isCallShieldOn;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.graphic_eq_rounded,
                  title: 'Voice Pulse',
                  subtitle:
                      isVoicePulseActive
                          ? 'Active'
                          : 'Off',
                  color: blue,
                  onTap: () {
                    setState(() {
                      isVoicePulseActive =
                          !isVoicePulseActive;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: compact ? 10 : 12,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.noise_aware_rounded,
                  title: 'Noise Control',
                  subtitle:
                      isNoiseCancellationOn
                          ? 'Enabled'
                          : 'Off',
                  color: cyan,
                  onTap:
                      _showAudioSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _detailCard(
                  icon:
                      Icons.lock_rounded,
                  title: 'Security',
                  subtitle: 'Encrypted',
                  color: green,
                  onTap:
                      _showSecurityInformation,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // DETAIL CARD
  // ==========================================================================

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: panel.withValues(
            alpha: 0.90,
          ),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color:
                Colors.white.withValues(
              alpha: 0.07,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    color.withValues(
                  alpha: 0.09,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
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
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BACK TO CALL
  // ==========================================================================

  Widget _buildBackToCallButton() {
    return SizedBox(
      height: 50,
      child: GestureDetector(
        onTap: _toggleMoreDetails,
        behavior:
            HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Back to Call',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BACKGROUND
  // ==========================================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration:
              const BoxDecoration(
            gradient:
                RadialGradient(
              center:
                  Alignment(0, -0.42),
              radius: 1.15,
              colors: [
                Color(0xFF09162B),
                Color(0xFF02050D),
                Color(0xFF010309),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, _) {
            final value =
                _glowController.value;

            return Container(
              decoration:
                  BoxDecoration(
                gradient:
                    RadialGradient(
                  center:
                      const Alignment(
                    0,
                    -0.22,
                  ),
                  radius: 0.75,
                  colors: [
                    purple.withValues(
                      alpha:
                          0.025 +
                              (value *
                                  0.025),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            top: 12,
            child: _circleButton(
              icon:
                  Icons.keyboard_arrow_down_rounded,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            top: 10,
            child: Column(
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'ChattªX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' Call',
                        style: TextStyle(
                          color:
                              Color(0xFFB75CFF),
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 15,
                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.55,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'End-to-end Encrypted',
                      style: TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 12,
            child: _circleButton(
              icon:
                  Icons.more_vert_rounded,
              onTap: _showMore,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CALLER
  // ==========================================================================

  Widget _buildCallerSection({
    required bool compact,
  }) {
    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation:
                      _waveController,
                  builder: (_, _) {
                    return CustomPaint(
                      painter:
                          _VoiceWavePainter(
                        animation:
                            _waveController
                                .value,
                        active:
                            isVoicePulseActive &&
                                !isOnHold,
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation:
                    _ringController,
                builder: (_, child) {
                  final avatarSize =
                      compact
                          ? 175.0
                          : 205.0;

                  return Transform.rotate(
                    angle:
                        _ringController
                                .value *
                            math.pi *
                            2,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            const SweepGradient(
                          colors: [
                            cyan,
                            Color(
                              0xFF716BFF,
                            ),
                            Color(
                              0xFFC33EFF,
                            ),
                            cyan,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                cyan.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 32,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color:
                                purple.withValues(
                              alpha: 0.16,
                            ),
                            blurRadius: 38,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(5),
                        child: Container(
                          decoration:
                              const BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                background,
                          ),
                          padding:
                              const EdgeInsets
                                  .all(5),
                          child: ClipOval(
                            child:
                                _buildProfileImage(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: compact ? 35 : 54,
                bottom: compact ? 8 : 17,
                child: AnimatedBuilder(
                  animation:
                      _pulseController,
                  builder: (_, _) {
                    return Container(
                      width:
                          compact ? 48 : 55,
                      height:
                          compact ? 48 : 55,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            const Color(
                          0xFF061421,
                        ),
                        border:
                            Border.all(
                          color:
                              cyan.withValues(
                            alpha: 0.7,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                cyan.withValues(
                              alpha:
                                  0.12 +
                                      (_pulseController
                                              .value *
                                          0.20),
                            ),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        isOnHold
                            ? Icons
                                .pause_rounded
                            : Icons
                                .graphic_eq_rounded,
                        color: cyan,
                        size: compact
                            ? 24
                            : 28,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.callerName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize:
                      compact ? 27 : 31,
                  fontWeight:
                      FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width:
                  compact ? 27 : 30,
              height:
                  compact ? 27 : 30,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFF983DFF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size:
                    compact ? 17 : 19,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          isOnHold
              ? 'On Hold'
              : _formatDuration(
                  callDuration,
                ),
          style: TextStyle(
            color: isOnHold
                ? Colors.orangeAccent
                : Colors.white54,
            fontSize:
                compact ? 17 : 19,
          ),
        ),
        const SizedBox(height: 5),
        _connectionIndicator(),
      ],
    );
  }

  // ==========================================================================
  // CONNECTION INDICATOR
  // ==========================================================================

  Widget _connectionIndicator() {
    final excellent =
        connectionStatus ==
            'Excellent Connection';

    final connecting =
        connectionStatus ==
                'Connecting' ||
            connectionStatus == 'Calling' ||
            connectionStatus == 'Ringing';

    final color = excellent
        ? green
        : connecting
            ? Colors.orangeAccent
            : red;

    final icon = excellent
        ? Icons.signal_cellular_alt_rounded
        : connecting
            ? Icons.sync_rounded
            : Icons.error_outline_rounded;

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          connectionStatus,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PROFILE IMAGE
  // ==========================================================================

  Widget _buildProfileImage() {
    if (widget.profileImageUrl != null &&
        widget.profileImageUrl!.isNotEmpty) {
      return Image.network(
        widget.profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _defaultProfile();
        },
      );
    }

    return _defaultProfile();
  }

  Widget _defaultProfile() {
    return Container(
      color: const Color(0xFF151B2B),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white38,
          size: 90,
        ),
      ),
    );
  }

  // ==========================================================================
  // INFO CARDS
  // ==========================================================================

  Widget _buildCallInfoCards({
    required bool compact,
  }) {
    return Container(
      height: compact ? 82 : 90,
      decoration: BoxDecoration(
        color: panel.withValues(
          alpha: 0.90,
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _infoCard(
              icon:
                  Icons.graphic_eq_rounded,
              iconColor: blue,
              title: 'Voice Pulse',
              subtitle:
                  isVoicePulseActive
                      ? 'Active'
                      : 'Off',
              subtitleColor: blue,
              onTap: () {
                setState(() {
                  isVoicePulseActive =
                      !isVoicePulseActive;
                });
              },
            ),
          ),
          Expanded(
            child: _infoCard(
              icon:
                  Icons.eco_rounded,
              iconColor:
                  Colors.greenAccent,
              title: 'Atmosphere',
              subtitle:
                  selectedAtmosphere,
              subtitleColor:
                  Colors.greenAccent,
              trailing:
                  Icons.keyboard_arrow_down_rounded,
              onTap:
                  _showAtmosphere,
            ),
          ),
          Expanded(
            child: _infoCard(
              icon:
                  Icons.shield_outlined,
              iconColor: cyan,
              title: 'Shield',
              subtitle:
                  isCallShieldOn
                      ? 'On'
                      : 'Off',
              subtitleColor:
                  isCallShieldOn
                      ? cyan
                      : Colors.white38,
              onTap: () {
                setState(() {
                  isCallShieldOn =
                      !isCallShieldOn;
                });
              },
            ),
          ),
          Expanded(
            child: _infoCard(
              icon: Icons.group_rounded,
              iconColor: purple,
              title: 'People',
              subtitle:
                  '$participants',
              subtitleColor: purple,
              trailing:
                  Icons.keyboard_arrow_down_rounded,
              onTap:
                  _showParticipants,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 7,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration:
                      BoxDecoration(
                    color:
                        iconColor.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 18,
                  ),
                ),
                if (trailing != null)
                  Icon(
                    trailing,
                    color:
                        Colors.white38,
                    size: 13,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 10,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LIVE REACTIONS PANEL
  // ==========================================================================

  Widget _buildLiveReactions({
    required bool compact,
  }) {
    return Container(
      height: compact ? 78 : 84,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: panel.withValues(
          alpha: 0.90,
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding:
                EdgeInsets.only(left: 5),
            child: Text(
              'Reactions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji
                    in _quickReactions)
                  Flexible(
                    child:
                        GestureDetector(
                      onTap: () {
                        _sendLiveReaction(
                          emoji,
                        );
                      },
                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds:
                              180,
                        ),
                        width:
                            compact ? 39 : 43,
                        height:
                            compact ? 39 : 43,
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              selectedReaction ==
                                      emoji
                                  ? const Color(
                                      0xFF351160,
                                    )
                                  : const Color(
                                      0xFF10192A,
                                    ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                          border:
                              Border.all(
                            color:
                                selectedReaction ==
                                        emoji
                                    ? purple
                                    : Colors
                                        .transparent,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child: Text(
                          emoji,
                          style:
                              TextStyle(
                            fontSize:
                                compact
                                    ? 20
                                    : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap:
                _showReactionPicker,
            child: Container(
              width:
                  compact ? 40 : 44,
              height:
                  compact ? 40 : 44,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    const Color(
                  0xFF0D1424,
                ),
                border:
                    Border.all(
                  color: purple,
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: purple,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FLOATING REACTION
  // ==========================================================================

  Widget _buildFloatingReaction() {
    return Positioned(
      right: 35,
      top: 135,
      child: AnimatedBuilder(
        animation:
            _reactionController,
        builder: (_, child) {
          final progress =
              _reactionController.value;

          return Opacity(
            opacity:
                1.0 -
                (progress * 0.85),
            child: Transform.translate(
              offset: Offset(
                math.sin(
                      progress *
                          math.pi *
                          2,
                    ) *
                    15,
                -progress * 120,
              ),
              child: Transform.scale(
                scale:
                    0.75 +
                    (progress * 0.55),
                child: child,
              ),
            ),
          );
        },
        child: Text(
          floatingReaction!,
          style:
              const TextStyle(
            fontSize: 54,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CALL CONTROLS
  // ==========================================================================

  Widget _buildCallControls({
    required bool compact,
  }) {
    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: [
            _callControl(
              icon: isMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_none_rounded,
              label: 'Mute',
              active: isMuted,
              activeColor: red,
              onTap: _toggleMute,
              compact: compact,
            ),
            _callControl(
              icon: isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              label: 'Speaker',
              active: isSpeakerOn,
              activeColor: cyan,
              onTap: _toggleSpeaker,
              compact: compact,
            ),
            _callControl(
              icon:
                  Icons.dialpad_rounded,
              label: 'Keypad',
              onTap: _showKeypad,
              compact: compact,
            ),
            _callControl(
              icon: Icons.add_call,
              label: 'Add Call',
              activeColor: purple,
              onTap: _addCall,
              compact: compact,
            ),
          ],
        ),
        SizedBox(
          height: compact ? 13 : 18,
        ),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: [
            _callControl(
              icon: isOnHold
                  ? Icons
                      .play_arrow_rounded
                  : Icons.pause_rounded,
              label: 'Hold',
              active: isOnHold,
              activeColor:
                  Colors.orangeAccent,
              onTap: _toggleHold,
              compact: compact,
            ),
            _callControl(
              icon:
                  Icons.call_end_rounded,
              label: 'End Call',
              isEndCall: true,
              onTap: _endCall,
              compact: compact,
            ),
            _callControl(
              icon: Icons.hearing_rounded,
              label: 'Audio',
              activeColor: cyan,
              onTap:
                  _showAudioRoutes,
              compact: compact,
            ),
            _callControl(
              icon:
                  Icons.more_horiz_rounded,
              label: 'More',
              onTap: _showMore,
              compact: compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _callControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool isEndCall = false,
    Color activeColor = Colors.white,
    bool compact = false,
  }) {
    final size =
        compact ? 56.0 : 62.0;

    final iconSize =
        compact ? 23.0 : 26.0;

    return SizedBox(
      width:
          compact ? 64 : 70,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape:
                    BoxShape.circle,
                color: isEndCall
                    ? red
                    : active
                        ? activeColor
                            .withValues(
                            alpha: 0.10,
                          )
                        : const Color(
                            0xFF0A1321,
                          ),
                border:
                    Border.all(
                  color: isEndCall
                      ? red
                      : active
                          ? activeColor
                              .withValues(
                              alpha:
                                  0.45,
                            )
                          : Colors.white
                              .withValues(
                              alpha:
                                  0.10,
                            ),
                  width: 1.2,
                ),
                boxShadow:
                    isEndCall
                        ? [
                            BoxShadow(
                              color:
                                  red.withValues(
                                alpha:
                                    0.38,
                              ),
                              blurRadius:
                                  25,
                              spreadRadius:
                                  2,
                            ),
                          ]
                        : active
                            ? [
                                BoxShadow(
                                  color:
                                      activeColor.withValues(
                                    alpha:
                                        0.14,
                                  ),
                                  blurRadius:
                                      18,
                                ),
                              ]
                            : [],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isEndCall
                    ? iconSize + 3
                    : iconSize,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: isEndCall
                  ? Colors.white
                  : Colors.white70,
              fontSize:
                  compact ? 10 : 11,
              fontWeight:
                  isEndCall
                      ? FontWeight.w500
                      : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMMON WIDGETS
  // ==========================================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 49,
        height: 49,
        decoration:
            BoxDecoration(
          shape: BoxShape.circle,
          color:
              const Color(0xFF0A111F),
          border: Border.all(
            color:
                Colors.white.withValues(
              alpha: 0.08,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.30,
              ),
              blurRadius: 18,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius:
            BorderRadius.circular(10),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              color.withValues(
            alpha: 0.09,
          ),
          border: Border.all(
            color:
                color.withValues(
              alpha: 0.18,
            ),
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
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white30,
      ),
      onTap: onTap,
    );
  }

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF0D1424),
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              shape: BoxShape.circle,
              color:
                  color.withValues(
                alpha: 0.08,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
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
                        Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Widget _securityRow(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AUDIO ROUTE MODEL
// ============================================================================

class _AudioRouteOption {
  final String title;
  final IconData icon;
  final Color color;

  const _AudioRouteOption(
    this.title,
    this.icon,
    this.color,
  );
}

// ============================================================================
// VOICE WAVE PAINTER
// ============================================================================

class _VoiceWavePainter extends CustomPainter {
  final double animation;
  final bool active;

  _VoiceWavePainter({
    required this.animation,
    required this.active,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (!active) {
      return;
    }

    final centerX =
        size.width / 2;
    final centerY =
        size.height / 2;

    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap =
          StrokeCap.round;

    const int numberOfBars = 45;

    for (int i = 0;
        i < numberOfBars;
        i++) {
      final normalized =
          i / (numberOfBars - 1);

      final distance =
          (normalized - 0.5).abs();

      final envelope = math.max(
        0.0,
        1 - distance * 1.65,
      );

      final wave = math.sin(
        (i * 0.72) +
            (animation *
                math.pi *
                2),
      );

      final height =
          7 +
          (wave.abs() *
              42 *
              envelope);

      final x =
          centerX -
          330 +
          (i * 15);

      paint.color =
          Color.lerp(
            const Color(
              0xFF17E7F4,
            ),
            const Color(
              0xFFC035FF,
            ),
            normalized,
          )!.withValues(
            alpha:
                0.22 +
                (0.62 * envelope),
          );

      canvas.drawLine(
        Offset(
          x,
          centerY -
              height / 2,
        ),
        Offset(
          x,
          centerY +
              height / 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _VoiceWavePainter oldDelegate,
  ) {
    return oldDelegate.animation !=
            animation ||
        oldDelegate.active != active;
  }
}

// ============================================================================
// KEYPAD
// ============================================================================

class _KeypadSheet extends StatefulWidget {
  const _KeypadSheet();

  @override
  State<_KeypadSheet> createState() =>
      _KeypadSheetState();
}

class _KeypadSheetState
    extends State<_KeypadSheet> {
  String enteredNumber = '';

  final List<List<String>> keys = const [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          30,
          18,
          30,
          30,
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
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              enteredNumber.isEmpty
                  ? 'Keypad'
                  : enteredNumber,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount: keys.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder:
                  (_, index) {
                final key =
                    keys[index];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      enteredNumber +=
                          key[0];
                    });
                  },
                  child: Container(
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          const Color(
                        0xFF101827,
                      ),
                      border:
                          Border.all(
                        color: Colors
                            .white
                            .withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Text(
                          key[0],
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                25,
                          ),
                        ),
                        if (key[1]
                            .isNotEmpty)
                          Text(
                            key[1],
                            style:
                                const TextStyle(
                              color:
                                  Colors.white38,
                              fontSize:
                                  8,
                              letterSpacing:
                                  1,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (enteredNumber
                        .isEmpty) {
                      return;
                    }

                    setState(() {
                      enteredNumber =
                          enteredNumber
                              .substring(
                        0,
                        enteredNumber
                                .length -
                            1,
                      );
                    });
                  },
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(0xFF101827),
                    ),
                    child: const Icon(
                      Icons
                          .backspace_outlined,
                      color:
                          Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 20,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(0xFF19DDBF),
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color:
                          Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}