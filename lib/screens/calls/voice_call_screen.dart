import 'dart:async'; 
import 'dart:math' as math; 
 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter/material.dart'; 
 
import '../../services/call_service.dart'; 
import '../../widgets/verified_name.dart'; 
 
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
  // CHATTªX COLORS 
  // ========================================================================== 
 
  static const Color backgroundColor = Color(0xFF02050D); 
  static const Color panelColor = Color(0xFF07101D); 
  static const Color cyanColor = Color(0xFF20F5E1); 
  static const Color purpleColor = Color(0xFFB33DFF); 
  static const Color blueColor = Color(0xFF4CCEFF); 
  static const Color greenColor = Color(0xFF20EFAF); 
  static const Color redColor = Color(0xFFF3323C); 
 
  // ========================================================================== 
  // SERVICE 
  // ========================================================================== 
 
  final ChattaxCallService _callService = 
      ChattaxCallService.instance; 
 
  StreamSubscription<ChattaxCallStatusEvent>? 
      _callStatusSubscription; 
 
  // ========================================================================== 
  // ANIMATIONS 
  // ========================================================================== 
 
  late final AnimationController _pulseController; 
  late final AnimationController _ringController; 
  late final AnimationController _glowController; 
  late final AnimationController _reactionController; 
 
  // ========================================================================== 
  // CALL STATE 
  // ========================================================================== 
 
  bool isMuted = false; 
  bool isSpeakerOn = true; 
  bool isOnHold = false; 
 
  bool isCallMemoryOn = true; 
  bool isVoicePulseActive = true; 
  bool isCallShieldOn = true; 
 
  bool isNoiseCancellationOn = true; 
  bool isVoiceEnhancementOn = true; 
  bool isLowDataModeOn = false; 
 
  bool _showDetails = false; 
  bool _isEndingCall = false; 
  bool _hasPopped = false; 
  bool _isLoadingCallState = false; 
 
  bool _callHasConnected = false; 
 
  bool _isVerified = false; 
 
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? 
    _reactionSubscription; 
 
String? _currentReactionId; 
 
  Duration callDuration = Duration.zero; 
 
  String connectionStatus = 'Calling...'; 
 
  String selectedAtmosphere = 'Cafe'; 
  String selectedAudioRoute = 'Speaker'; 
 
  String selectedReaction = ''; 
  String? floatingReaction; 
 
  Timer? _callTimer; 
  Timer? _reactionClearTimer; 
 
  // ========================================================================== 
  // REACTIONS 
  // ========================================================================== 
 
  final List<String> _quickReactions = <String>[ 
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
      duration: const Duration(milliseconds: 1800), 
    )..repeat(); 
 
    _ringController = AnimationController( 
      vsync: this, 
      duration: const Duration(milliseconds: 2200), 
    )..repeat(); 
 
    _glowController = AnimationController( 
      vsync: this, 
      duration: const Duration(milliseconds: 1600), 
    )..repeat(reverse: true); 
 
    _reactionController = AnimationController( 
      vsync: this, 
      duration: const Duration(milliseconds: 700), 
    ); 
 
    isMuted = _callService.isMicrophoneMuted; 
    isSpeakerOn = _callService.isSpeakerEnabled; 
 
   _listenToCallStatus();
_loadVerificationStatus();
_listenForLiveReactions(); 
  } 

 
  // ========================================================================== 
  // CALL STATUS 
  // ========================================================================== 
 
  void _listenToCallStatus() { 
  final String? expectedCallId = widget.callId?.trim(); 
 
  if (expectedCallId == null || expectedCallId.isEmpty) { 
    connectionStatus = 'Connecting...'; 
    return; 
  } 
 
  _callStatusSubscription = 
      _callService.callStatusEvents.listen( 
    (ChattaxCallStatusEvent event) { 
      if (!mounted) { 
        return; 
      } 
 
      // Only react to this exact call. 
      if (event.callId != expectedCallId) { 
        return; 
      } 
 
      _handleCallStatus(event.status); 
    }, 
    onError: (Object error, StackTrace stackTrace) { 
      debugPrint( 
        'ChattªX VoiceCallScreen status error: $error', 
      ); 
    }, 
  ); 
 
  // IMPORTANT: 
  // The connecting event may have happened before this screen 
  // subscribed. Read the current Firestore state immediately. 
  _synchronizeCallState(expectedCallId); 
} 


 
// ========================================================================== 
// VERIFICATION 
// ========================================================================== 
 
Future<void> _loadVerificationStatus() async { 
  try { 
    final String name = widget.callerName.trim(); 
 
    if (name.isEmpty) { 
      return; 
    } 
 
    final QuerySnapshot<Map<String, dynamic>> result = 
        await FirebaseFirestore.instance 
            .collection('users') 
            .where( 
              'displayName', 
              isEqualTo: name, 
            ) 
            .limit(1) 
            .get(); 
 
    if (!mounted || result.docs.isEmpty) { 
      return; 
    } 
 
    final Map<String, dynamic> data = 
        result.docs.first.data(); 
 
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
      'ChattªX verification lookup error: $error', 
    ); 
  } 
} 

// ==========================================================================
// LIVE REACTION LISTENER
// ==========================================================================

void _listenForLiveReactions() {
  final String? callId = widget.callId?.trim();

  if (callId == null || callId.isEmpty) {
    return;
  }

  _reactionSubscription = FirebaseFirestore.instance
      .collection('calls')
      .doc(callId)
      .collection('reactions')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .listen(
    (QuerySnapshot<Map<String, dynamic>> snapshot) {
      if (!mounted || snapshot.docs.isEmpty) {
        return;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>> doc =
          snapshot.docs.first;

      final String reactionId = doc.id;

      // Prevent the same reaction from being displayed repeatedly.
      if (_currentReactionId == reactionId) {
        return;
      }

      _currentReactionId = reactionId;

      final Map<String, dynamic> data = doc.data();

      final String emoji =
          data['emoji']?.toString() ?? '';

      final String senderUid =
          data['senderUid']?.toString() ?? '';

      final String? myUid =
          FirebaseAuth.instance.currentUser?.uid;

      // We already show our own reaction locally,
      // so don't show it again when Firestore sends it back.
      if (myUid != null &&
          senderUid.isNotEmpty &&
          senderUid == myUid) {
        return;
      }

      if (emoji.isEmpty) {
        return;
      }

      _showRemoteReaction(emoji);
    },
    onError: (Object error) {
      debugPrint(
        'ChattªX live reaction listener error: $error',
      );
    },
  );
}

void _showRemoteReaction(String emoji) {
  if (!mounted) {
    return;
  }

  _reactionClearTimer?.cancel();

  setState(() {
    floatingReaction = emoji;
  });

  _reactionController.forward(from: 0);

  _reactionClearTimer = Timer(
    const Duration(milliseconds: 1500),
    () {
      if (!mounted) {
        return;
      }

      setState(() {
        floatingReaction = null;
      });
    },
  );
}
 
Future<void> _synchronizeCallState(String callId) async { 
  if (_isLoadingCallState) { 
    return; 
  } 
 
  _isLoadingCallState = true; 
 
  try { 
    final ChattaxCall? call = 
        await _callService.getCall(callId); 
 
    if (!mounted || call == null) { 
      return; 
    } 
 
    // The call may already have moved to connecting or connected 
    // before VoiceCallScreen was pushed. 
    _handleCallStatus(call.status); 
  } catch (error) { 
    debugPrint( 
      'ChattªX VoiceCallScreen state sync error: $error', 
    ); 
  } finally { 
    _isLoadingCallState = false; 
  } 
} 
 
  void _handleCallStatus( 
  ChattaxCallStatus status, 
) { 
  if (!mounted || _hasPopped) { 
    return; 
  } 
 
  switch (status) { 
    case ChattaxCallStatus.calling: 
      if (!_callHasConnected) { 
        _setConnectionStatus('Calling...'); 
      } 
      break; 
 
    case ChattaxCallStatus.ringing: 
      if (!_callHasConnected) { 
        _setConnectionStatus('Ringing...'); 
      } 
      break; 
 
    case ChattaxCallStatus.connecting: 
      if (!_callHasConnected) { 
        _setConnectionStatus('Connecting...'); 
      } 
      break; 
 
    case ChattaxCallStatus.connected: 
      _handleConnected(); 
      break; 
 
    case ChattaxCallStatus.rejected: 
      _setConnectionStatus('Call Rejected'); 
      _stopCallTimer(); 
 
      if (!_isEndingCall) { 
        _closeAfterRemoteEnd(); 
      } 
      break; 
 
    case ChattaxCallStatus.ended: 
      _setConnectionStatus('Call Ended'); 
      _stopCallTimer(); 
 
      if (!_isEndingCall) { 
        _closeAfterRemoteEnd(); 
      } 
      break; 
 
    case ChattaxCallStatus.failed: 
      _setConnectionStatus('Connection Failed'); 
      _stopCallTimer(); 
 
      if (!_isEndingCall) { 
        _closeAfterRemoteEnd(); 
      } 
      break; 
  } 
} 
 
  void _setConnectionStatus(String value) { 
    if (!mounted) { 
      return; 
    } 
 
    setState(() { 
      connectionStatus = value; 
    }); 
  } 
 
  // ========================================================================== 
  // CONNECTED 
  // ========================================================================== 
 
  void _handleConnected() { 
    if (!mounted) { 
      return; 
    } 
 
    if (!_callHasConnected) { 
      _callHasConnected = true; 
 
      setState(() { 
        connectionStatus = 'Excellent Connection'; 
      }); 
 
      _startCallTimer(); 
 
      _pulseController.repeat(); 
      _ringController.repeat(); 
      _glowController.repeat(reverse: true); 
    } else { 
      setState(() { 
        connectionStatus = 'Excellent Connection'; 
      }); 
    } 
  } 
 
  // ========================================================================== 
  // CALL TIMER 
  // ========================================================================== 
 
  void _startCallTimer() { 
    if (_callTimer != null) { 
      return; 
    } 
 
    _callTimer = Timer.periodic( 
      const Duration(seconds: 1), 
      (_) { 
        if (!mounted || !_callHasConnected) { 
          return; 
        } 
 
        setState(() { 
          callDuration += const Duration(seconds: 1); 
        }); 
      }, 
    ); 
  } 
 
  void _stopCallTimer() { 
    _callTimer?.cancel(); 
    _callTimer = null; 
  } 
 
  // ========================================================================== 
  // REMOTE END 
  // ========================================================================== 
 
  void _closeAfterRemoteEnd() { 
    if (_hasPopped) { 
      return; 
    } 
 
    Future<void>.delayed( 
      const Duration(milliseconds: 450), 
      () { 
        if (!mounted || _hasPopped) { 
          return; 
        } 
 
        _hasPopped = true; 
        Navigator.of(context).pop(); 
      }, 
    ); 
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
      builder: (BuildContext context) { 
        return AlertDialog( 
          backgroundColor: panelColor, 
          shape: RoundedRectangleBorder( 
            borderRadius: BorderRadius.circular(24), 
          ), 
          title: const Text( 
            'End call?', 
            style: TextStyle( 
              color: Colors.white, 
              fontWeight: FontWeight.w700, 
            ), 
          ), 
          content: const Text( 
            'Are you sure you want to end this call?', 
            style: TextStyle( 
              color: Color(0xFFB8C1D1), 
            ), 
          ), 
          actions: <Widget>[ 
            TextButton( 
              onPressed: () { 
                Navigator.of(context).pop(false); 
              }, 
              child: const Text( 
                'Cancel', 
                style: TextStyle( 
                  color: cyanColor, 
                ), 
              ), 
            ), 
            TextButton( 
              onPressed: () { 
                Navigator.of(context).pop(true); 
              }, 
              child: const Text( 
                'End Call', 
                style: TextStyle( 
                  color: redColor, 
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
    _stopCallTimer(); 
 
    try { 
      await _callService.endCall(); 
    } catch (error) { 
      debugPrint( 
        'ChattªX end call error: $error', 
      ); 
    } 
 
    if (!mounted || _hasPopped) { 
      return; 
    } 
 
    _hasPopped = true; 
    Navigator.of(context).pop(); 
  } 
 
  // ========================================================================== 
  // MICROPHONE 
  // ========================================================================== 
 
  Future<void> _toggleMute() async { 
  try { 
    final bool newMutedState = 
        !_callService.isMicrophoneMuted; 
 
    await _callService.setMicrophoneMuted( 
      newMutedState, 
    ); 
 
    if (!mounted) { 
      return; 
    } 
 
    setState(() { 
      isMuted = _callService.isMicrophoneMuted; 
    }); 
  } catch (error) { 
    debugPrint( 
      'ChattªX microphone error: $error', 
    ); 
  } 
} 
  // ========================================================================== 
  // SPEAKER 
  // ========================================================================== 
 
  Future<void> _toggleSpeaker() async { 
    try { 
      final enabled = 
          await _callService.toggleSpeaker(); 
 
      if (!mounted) { 
        return; 
      } 
 
      setState(() { 
        isSpeakerOn = enabled; 
        selectedAudioRoute = 
            enabled ? 'Speaker' : 'Phone'; 
      }); 
    } catch (error) { 
      debugPrint( 
        'ChattªX speaker error: $error', 
      ); 
    } 
  } 
 
  // ========================================================================== 
  // HOLD 
  // ========================================================================== 
 
  Future<void> _toggleHold() async { 
    final newHoldValue = !isOnHold; 
 
    try { 
      await _callService.setMicrophoneMuted( 
        newHoldValue, 
      ); 
 
      if (!mounted) { 
        return; 
      } 
 
      setState(() { 
  isOnHold = newHoldValue; 
  isMuted = _callService.isMicrophoneMuted; 
}); 
    } catch (error) { 
      debugPrint( 
        'ChattªX hold error: $error', 
      ); 
    } 
  } 
 
  // ========================================================================== 
  // AUDIO ROUTES 
  // ========================================================================== 
 
  void _showAudioRoutes() { 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              24, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 18), 
                const Align( 
                  alignment: Alignment.centerLeft, 
                  child: Text( 
                    'Audio route', 
                    style: TextStyle( 
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w800, 
                    ), 
                  ), 
                ), 
                const SizedBox(height: 14), 
                _audioRouteTile( 
                  icon: Icons.volume_up_rounded, 
                  title: 'Speaker', 
                  selected: 
                      selectedAudioRoute == 'Speaker', 
                  onTap: () async { 
                    await _callService.setSpeaker(true); 
 
                    if (!mounted) { 
                      return; 
                    } 
 
                    setState(() { 
                      selectedAudioRoute = 'Speaker'; 
                      isSpeakerOn = true; 
                    }); 
 
                    Navigator.of(context).pop(); 
                  }, 
                ), 
                _audioRouteTile( 
                  icon: Icons.phone_in_talk_rounded, 
                  title: 'Phone', 
                  selected: 
                      selectedAudioRoute == 'Phone', 
                  onTap: () async { 
                    await _callService.setSpeaker(false); 
 
                    if (!mounted) { 
                      return; 
                    } 
 
                    setState(() { 
                      selectedAudioRoute = 'Phone'; 
                      isSpeakerOn = false; 
                    }); 
 
                    Navigator.of(context).pop(); 
                  }, 
                ), 
                _audioRouteTile( 
                  icon: Icons.bluetooth_rounded, 
                  title: 'Bluetooth', 
                  selected: 
                      selectedAudioRoute == 'Bluetooth', 
                  onTap: () { 
                    ScaffoldMessenger.of(context) 
                        .showSnackBar( 
                      const SnackBar( 
                        content: Text( 
                          'Bluetooth audio routing requires platform audio-device support.', 
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
 
  Widget _audioRouteTile({ 
    required IconData icon, 
    required String title, 
    required bool selected, 
    required VoidCallback onTap, 
  }) { 
    return ListTile( 
      onTap: onTap, 
      shape: RoundedRectangleBorder( 
        borderRadius: BorderRadius.circular(16), 
      ), 
      leading: Container( 
        width: 44, 
        height: 44, 
        decoration: BoxDecoration( 
          shape: BoxShape.circle, 
          color: selected 
              ? cyanColor.withAlpha(35) 
              : Colors.white.withAlpha(12), 
        ), 
        child: Icon( 
          icon, 
          color: 
              selected ? cyanColor : Colors.white70, 
        ), 
      ), 
      title: Text( 
        title, 
        style: TextStyle( 
          color: 
              selected ? Colors.white : Colors.white70, 
          fontWeight: 
              selected ? FontWeight.w700 : FontWeight.w500, 
        ), 
      ), 
      trailing: selected 
          ? const Icon( 
              Icons.check_circle_rounded, 
              color: cyanColor, 
            ) 
          : null, 
    ); 
  } 
 
  // ========================================================================== 
  // KEYPAD 
  // ========================================================================== 
 
  void _showKeypad() { 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return const _KeypadSheet(); 
      }, 
    ); 
  } 
 
  // ========================================================================== 
  // ADD CALL 
  // ========================================================================== 
 
  void _addCall() { 
    ScaffoldMessenger.of(context).showSnackBar( 
      const SnackBar( 
        content: Text( 
          'Multi-participant calling can be connected to the ChattªX call service next.', 
        ), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // MORE 
  // ========================================================================== 
 
  void _showMore() { 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              24, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 12), 
                _actionTile( 
                  Icons.person_add_alt_1_rounded, 
                  'Add Participant', 
                  _addCall, 
                ), 
                _actionTile( 
                  Icons.chat_bubble_outline_rounded, 
                  'Open Chat', 
                  () { 
                    Navigator.of(context).pop(); 
                  }, 
                ), 
                _actionTile( 
                  Icons.security_rounded, 
                  'Security', 
                  () { 
                    Navigator.of(context).pop(); 
                    _showSecurityInformation(); 
                  }, 
                ), 
                _actionTile( 
                  Icons.tune_rounded, 
                  'Audio Settings', 
                  () { 
                    Navigator.of(context).pop(); 
                    _showAudioSettings(); 
                  }, 
                ), 
                _actionTile( 
                  Icons.location_on_outlined, 
                  'Share Location', 
                  () { 
                    Navigator.of(context).pop(); 
                    _showSimpleMessage( 
                      'Location sharing is available from the chat location tools.', 
                    ); 
                  }, 
                ), 
                _actionTile( 
                  Icons.history_rounded, 
                  'Call Memory', 
                  () { 
                    Navigator.of(context).pop(); 
                    _showSimpleMessage( 
                      'Call Memory is currently a ChattªX UI preference.', 
                    ); 
                  }, 
                ), 
                _actionTile( 
                  Icons.flag_outlined, 
                  'Report Call', 
                  () { 
                    Navigator.of(context).pop(); 
                    _showSimpleMessage( 
                      'Report Call is ready to connect to your reporting system.', 
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
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return StatefulBuilder( 
          builder: ( 
            BuildContext context, 
            StateSetter setSheetState, 
          ) { 
            return SafeArea( 
              child: Padding( 
                padding: const EdgeInsets.fromLTRB( 
                  20, 
                  12, 
                  20, 
                  24, 
                ), 
                child: Column( 
                  mainAxisSize: MainAxisSize.min, 
                  children: <Widget>[ 
                    _sheetHandle(), 
                    const SizedBox(height: 14), 
                    const Align( 
                      alignment: Alignment.centerLeft, 
                      child: Text( 
                        'Audio Settings', 
                        style: TextStyle( 
                          color: Colors.white, 
                          fontSize: 20, 
                          fontWeight: FontWeight.w800, 
                        ), 
                      ), 
                    ), 
                    const SizedBox(height: 12), 
                    _settingSwitch( 
                      title: 'Noise Cancellation', 
                      subtitle: 
                          'Reduce background noise', 
                      value: isNoiseCancellationOn, 
                      onChanged: (bool value) { 
                        setSheetState(() { 
                          isNoiseCancellationOn = 
                              value; 
                        }); 
 
                        setState(() {}); 
                      }, 
                    ), 
                    _settingSwitch( 
                      title: 'Voice Enhancement', 
                      subtitle: 
                          'Improve speech clarity', 
                      value: isVoiceEnhancementOn, 
                      onChanged: (bool value) { 
                        setSheetState(() { 
                          isVoiceEnhancementOn = 
                              value; 
                        }); 
 
                        setState(() {}); 
                      }, 
                    ), 
                    _settingSwitch( 
                      title: 'Low Data Mode', 
                      subtitle: 
                          'Reduce network usage', 
                      value: isLowDataModeOn, 
                      onChanged: (bool value) { 
                        setSheetState(() { 
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
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              28, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 18), 
                Container( 
                  width: 70, 
                  height: 70, 
                  decoration: BoxDecoration( 
                    shape: BoxShape.circle, 
                    color: greenColor.withAlpha(25), 
                  ), 
                  child: const Icon( 
                    Icons.shield_rounded, 
                    color: greenColor, 
                    size: 36, 
                  ), 
                ), 
                const SizedBox(height: 14), 
                const Text( 
                  'Call Security', 
                  style: TextStyle( 
                    color: Colors.white, 
                    fontSize: 21, 
                    fontWeight: FontWeight.w800, 
                  ), 
                ), 
                const SizedBox(height: 8), 
                const Text( 
                  'ChattªX uses secure signaling and WebRTC transport for this call.', 
                  textAlign: TextAlign.center, 
                  style: TextStyle( 
                    color: Color(0xFFB8C1D1), 
                    height: 1.4, 
                  ), 
                ), 
                const SizedBox(height: 20), 
                _securityRow( 
                  Icons.verified_user_rounded, 
                  'Secure Signaling', 
                  'Active', 
                  greenColor, 
                ), 
                _securityRow( 
                  Icons.shield_rounded, 
                  'Call Shield', 
                  isCallShieldOn 
                      ? 'Enabled' 
                      : 'Disabled', 
                  isCallShieldOn 
                      ? greenColor 
                      : Colors.white54, 
                ), 
                _securityRow( 
                  Icons.lock_outline_rounded, 
                  'WebRTC Session', 
                  'Active', 
                  greenColor, 
                ), 
              ], 
            ), 
          ), 
        ); 
      }, 
    ); 
  } 
 
  // ========================================================================== 
  // SIMPLE MESSAGE 
  // ========================================================================== 
 
  void _showSimpleMessage(String message) { 
    if (!mounted) { 
      return; 
    } 
 
    ScaffoldMessenger.of(context).showSnackBar( 
      SnackBar( 
        content: Text(message), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // ATMOSPHERE 
  // ========================================================================== 
 
  void _showAtmosphere() { 
    const atmospheres = <String>[ 
      'Cafe', 
      'Lo-Fi', 
      'Rain', 
      'None', 
    ]; 
 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              24, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 14), 
                const Align( 
                  alignment: Alignment.centerLeft, 
                  child: Text( 
                    'Call Atmosphere', 
                    style: TextStyle( 
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w800, 
                    ), 
                  ), 
                ), 
                const SizedBox(height: 12), 
                ...atmospheres.map( 
                  (String atmosphere) { 
                    final selected = 
                        selectedAtmosphere == 
                            atmosphere; 
 
                    return ListTile( 
                      onTap: () { 
                        setState(() { 
                          selectedAtmosphere = 
                              atmosphere; 
                        }); 
 
                        Navigator.of(context).pop(); 
                      }, 
                      leading: Icon( 
                        atmosphere == 'Cafe' 
                            ? Icons.coffee_rounded 
                            : atmosphere == 'Lo-Fi' 
                                ? Icons.music_note_rounded 
                                : atmosphere == 
                                        'Rain' 
                                    ? Icons.water_drop_rounded 
                                    : Icons.volume_off_rounded, 
                        color: selected 
                            ? purpleColor 
                            : Colors.white70, 
                      ), 
                      title: Text( 
                        atmosphere, 
                        style: TextStyle( 
                          color: selected 
                              ? Colors.white 
                              : Colors.white70, 
                          fontWeight: selected 
                              ? FontWeight.w700 
                              : FontWeight.w500, 
                        ), 
                      ), 
                      trailing: selected 
                          ? const Icon( 
                              Icons.check_circle_rounded, 
                              color: purpleColor, 
                            ) 
                          : null, 
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
  // PARTICIPANTS 
  // ========================================================================== 
 
  void _showParticipants() { 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              24, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 14), 
                const Align( 
                  alignment: Alignment.centerLeft, 
                  child: Text( 
                    'Participants', 
                    style: TextStyle( 
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w800, 
                    ), 
                  ), 
                ), 
                const SizedBox(height: 18), 
                ListTile( 
                  leading: _smallAvatar( 
                    widget.profileImageUrl, 
                  ), 
                  title: Text( 
                    widget.callerName, 
                    style: const TextStyle( 
                      color: Colors.white, 
                      fontWeight: FontWeight.w700, 
                    ), 
                  ), 
                  subtitle: const Text( 
                    'Other participant', 
                    style: TextStyle( 
                      color: Colors.white54, 
                    ), 
                  ), 
                ), 
                ListTile( 
                  leading: _smallAvatar(null), 
                  title: const Text( 
                    'You', 
                    style: TextStyle( 
                      color: Colors.white, 
                      fontWeight: FontWeight.w700, 
                    ), 
                  ), 
                  subtitle: const Text( 
                    'ChattªX', 
                    style: TextStyle( 
                      color: Colors.white54, 
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
 
  Widget _smallAvatar(String? imageUrl) { 
    return Container( 
      width: 48, 
      height: 48, 
      decoration: BoxDecoration( 
        shape: BoxShape.circle, 
        border: Border.all( 
          color: cyanColor.withAlpha(80), 
          width: 1, 
        ), 
      ), 
      child: ClipOval( 
        child: imageUrl != null && 
                imageUrl.trim().isNotEmpty 
            ? Image.network( 
                imageUrl, 
                fit: BoxFit.cover, 
                errorBuilder: 
                    ( 
                  BuildContext context, 
                  Object error, 
                  StackTrace? stackTrace, 
                ) { 
                  return _defaultProfile( 
                    size: 48, 
                  ); 
                }, 
              ) 
            : _defaultProfile( 
                size: 48, 
              ), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // REACTIONS 
  // ========================================================================== 
 
  Future<void> _sendLiveReaction(String reaction) async {
  if (!mounted) {
    return;
  }

  final String? callId = widget.callId?.trim();

  if (callId == null || callId.isEmpty) {
    debugPrint(
      'ChattªX reaction error: missing callId',
    );
    return;
  }

  final User? user =
      FirebaseAuth.instance.currentUser;

  if (user == null) {
    debugPrint(
      'ChattªX reaction error: no authenticated user',
    );
    return;
  }

  _reactionClearTimer?.cancel();

  // Show immediately on our own screen.
  setState(() {
    selectedReaction = reaction;
    floatingReaction = reaction;
  });

  _reactionController.forward(from: 0);

  try {
    final DocumentReference<Map<String, dynamic>>
        reactionRef = FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .collection('reactions')
            .doc();

    await reactionRef.set({
      'emoji': reaction,
      'senderUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Keep the reaction document around briefly so
    // the other participant has time to receive it.
    await Future<void>.delayed(
      const Duration(seconds: 3),
    );

    try {
      await reactionRef.delete();
    } catch (_) {
      // It may already have been removed.
    }
  } catch (error) {
    debugPrint(
      'ChattªX live reaction send error: $error',
    );
  }

  _reactionClearTimer = Timer(
    const Duration(milliseconds: 1500),
    () {
      if (!mounted) {
        return;
      }

      setState(() {
        floatingReaction = null;
      });
    },
  );
}
 
  void _showReactionPicker() { 
    showModalBottomSheet<void>( 
      context: context, 
      backgroundColor: panelColor, 
      shape: const RoundedRectangleBorder( 
        borderRadius: BorderRadius.vertical( 
          top: Radius.circular(28), 
        ), 
      ), 
      builder: (BuildContext context) { 
        return SafeArea( 
          child: Padding( 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              12, 
              20, 
              26, 
            ), 
            child: Column( 
              mainAxisSize: MainAxisSize.min, 
              children: <Widget>[ 
                _sheetHandle(), 
                const SizedBox(height: 18), 
                const Text( 
                  'Send a reaction', 
                  style: TextStyle( 
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.w800, 
                  ), 
                ), 
                const SizedBox(height: 20), 
                Wrap( 
                  spacing: 18, 
                  runSpacing: 18, 
                  alignment: WrapAlignment.center, 
                  children: 
                      _quickReactions.map( 
                    (String emoji) { 
                      return GestureDetector( 
                        onTap: () { 
                          Navigator.of(context).pop(); 
                          _sendLiveReaction(emoji); 
                        }, 
                        child: Container( 
                          width: 62, 
                          height: 62, 
                          decoration: BoxDecoration( 
                            shape: BoxShape.circle, 
                            color: Colors.white 
                                .withAlpha(12), 
                            border: Border.all( 
                              color: Colors.white 
                                  .withAlpha(18), 
                            ), 
                          ), 
                          alignment: Alignment.center, 
                          child: Text( 
                            emoji, 
                            style: const TextStyle( 
                              fontSize: 30, 
                            ), 
                          ), 
                        ), 
                      ); 
                    }, 
                  ).toList(), 
                ), 
              ], 
            ), 
          ), 
        ); 
      }, 
    ); 
  } 
 
  // ========================================================================== 
  // BUILD 
  // ========================================================================== 
 
  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      backgroundColor: backgroundColor, 
      body: SafeArea( 
        child: Stack( 
          children: <Widget>[ 
            Positioned.fill( 
              child: _buildBackground(), 
            ), 
            AnimatedSwitcher( 
              duration: const Duration( 
                milliseconds: 300, 
              ), 
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
  // BACKGROUND 
  // ========================================================================== 
 
  Widget _buildBackground() { 
    return AnimatedBuilder( 
      animation: Listenable.merge( 
        <Listenable>[ 
          _pulseController, 
          _glowController, 
        ], 
      ), 
      builder: ( 
        BuildContext context, 
        Widget? child, 
      ) { 
        final pulse = 
            (math.sin( 
                      _pulseController.value * 
                          math.pi * 
                          2, 
                    ) + 
                    1) / 
                2; 
 
        final glow = 0.35 + (_glowController.value * 0.25); 
 
        return Stack( 
          children: <Widget>[ 
            Positioned( 
              top: -130, 
              left: -100, 
              child: Container( 
                width: 320, 
                height: 320, 
                decoration: BoxDecoration( 
                  shape: BoxShape.circle, 
                  boxShadow: <BoxShadow>[ 
                    BoxShadow( 
                      color: purpleColor.withAlpha( 
                        (40 + (pulse * 35)).round(), 
                      ), 
                      blurRadius: 120, 
                      spreadRadius: 20, 
                    ), 
                  ], 
                ), 
              ), 
            ), 
            Positioned( 
              bottom: -160, 
              right: -120, 
              child: Container( 
                width: 360, 
                height: 360, 
                decoration: BoxDecoration( 
                  shape: BoxShape.circle, 
                  boxShadow: <BoxShadow>[ 
                    BoxShadow( 
                      color: cyanColor.withAlpha( 
                        (25 + (glow * 35)).round(), 
                      ), 
                      blurRadius: 140, 
                      spreadRadius: 20, 
                    ), 
                  ], 
                ), 
              ), 
            ), 
          ], 
        ); 
      }, 
    ); 
  } 
 
// ==========================================================================
// MAIN CALL VIEW
// ==========================================================================

Widget _buildMainCallView() {
  return Column(
    key: const ValueKey<String>('main'),
    children: <Widget>[
      _buildHeader(),

      Expanded(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),

            // ================================================================
            // CALLER
            // ================================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: _buildCallerSection(
                compact: false,
              ),
            ),

            const SizedBox(height: 12),

            // ================================================================
            // EVERYTHING BELOW — FIXED + ALMOST EDGE TO EDGE
            // ================================================================

            Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
    Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: _buildInfoCards(),
    ),

    const SizedBox(height: 16),

    Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: _buildLiveReactions(),
    ),

    const SizedBox(height: 20),

    // ================================================================
    // CALL CONTROLS — TRUE EDGE TO EDGE
    // ================================================================

    _buildCallControls(),
  ],
),
          ],
        ),
      ),
    ],
  );
}
 
  // ========================================================================== 
  // HEADER 
  // ========================================================================== 
 
  Widget _buildHeader() { 
    return Padding( 
      padding: const EdgeInsets.fromLTRB( 
        18, 
        10, 
        18, 
        8, 
      ), 
      child: Row( 
        children: <Widget>[ 
          _circleButton( 
            icon: Icons.keyboard_arrow_down_rounded, 
            onTap: () { 
              if (_hasPopped) { 
                return; 
              } 
 
              _hasPopped = true; 
              Navigator.of(context).pop(); 
            }, 
          ), 
          const Spacer(), 
          Column( 
            children: <Widget>[ 
              const Text( 
                'CHATTªX', 
                style: TextStyle( 
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 3, 
                ), 
              ), 
              const SizedBox(height: 3), 
              Text( 
                _callHasConnected 
                    ? 'VOICE CALL' 
                    : 'SECURE CALL', 
                style: const TextStyle( 
                  color: cyanColor, 
                  fontSize: 9, 
                  fontWeight: FontWeight.w700, 
                  letterSpacing: 2, 
                ), 
              ), 
            ], 
          ), 
          const Spacer(), 
          _circleButton( 
            icon: Icons.more_horiz_rounded, 
            onTap: _showMore, 
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
    final avatarSize = compact ? 120.0 : 164.0; 
 
    return Column( 
      children: <Widget>[ 
        SizedBox( 
          width: avatarSize + 42, 
          height: avatarSize + 42, 
          child: Stack( 
            alignment: Alignment.center, 
            children: <Widget>[ 
              AnimatedBuilder( 
                animation: _ringController, 
                builder: ( 
                  BuildContext context, 
                  Widget? child, 
                ) { 
                  final progress = 
                      _ringController.value; 
 
                  return Transform.scale( 
                    scale: 1.0 + (progress * 0.12), 
                    child: Container( 
                      width: avatarSize + 26, 
                      height: avatarSize + 26, 
                      decoration: BoxDecoration( 
                        shape: BoxShape.circle, 
                        border: Border.all( 
                          color: cyanColor.withAlpha( 
                            ((1 - progress) * 80) 
                                .round(), 
                          ), 
                          width: 2, 
                        ), 
                      ), 
                    ), 
                  ); 
                }, 
              ), 
              AnimatedBuilder( 
                animation: _glowController, 
                builder: ( 
                  BuildContext context, 
                  Widget? child, 
                ) { 
                  return Container( 
                    width: avatarSize + 12, 
                    height: avatarSize + 12, 
                    decoration: BoxDecoration( 
                      shape: BoxShape.circle, 
                      boxShadow: <BoxShadow>[ 
                        BoxShadow( 
                          color: purpleColor.withAlpha( 
                            (55 + 
                                    (_glowController 
                                            .value * 
                                        35)) 
                                .round(), 
                          ), 
                          blurRadius: 32, 
                          spreadRadius: 3, 
                        ), 
                      ], 
                    ), 
                  ); 
                }, 
              ), 
              Container( 
                width: avatarSize, 
                height: avatarSize, 
                padding: const EdgeInsets.all(4), 
                decoration: BoxDecoration( 
                  shape: BoxShape.circle, 
                  gradient: const LinearGradient( 
                    begin: Alignment.topLeft, 
                    end: Alignment.bottomRight, 
                    colors: <Color>[ 
                      cyanColor, 
                      purpleColor, 
                    ], 
                  ), 
                ), 
                child: Container( 
                  decoration: const BoxDecoration( 
                    shape: BoxShape.circle, 
                    color: backgroundColor, 
                  ), 
                  padding: const EdgeInsets.all(4), 
                  child: ClipOval( 
                    child: _buildProfileImage(), 
                  ), 
                ), 
              ), 
            ], 
          ), 
        ), 
        const SizedBox(height: 22), 
       Padding( 
  padding: const EdgeInsets.symmetric( 
    horizontal: 18, 
  ), 
  child: VerifiedName( 
    name: widget.callerName, 
    verified: _isVerified, 
    fontSize: 28, 
    fontWeight: FontWeight.w800, 
    textColor: Colors.white, 
  ), 
), 
        const SizedBox(height: 8), 
        AnimatedSwitcher( 
          duration: const Duration( 
            milliseconds: 250, 
          ), 
          child: Text( 
            _callHasConnected 
                ? _formatDuration(callDuration) 
                : connectionStatus, 
            key: ValueKey<String>( 
              '${connectionStatus}_${callDuration.inSeconds}', 
            ), 
            style: TextStyle( 
              color: _callHasConnected 
                  ? cyanColor 
                  : Colors.white70, 
              fontSize: 15, 
              fontWeight: FontWeight.w700, 
              letterSpacing: 1.2, 
            ), 
          ), 
        ), 
        const SizedBox(height: 12), 
        _connectionIndicator(), 
      ], 
    ); 
  } 
 
  Widget _buildProfileImage() { 
    final url = widget.profileImageUrl; 
 
    if (url == null || url.trim().isEmpty) { 
      return _defaultProfile( 
        size: 164, 
      ); 
    } 
 
    return Image.network( 
      url, 
      fit: BoxFit.cover, 
      errorBuilder: ( 
        BuildContext context, 
        Object error, 
        StackTrace? stackTrace, 
      ) { 
        return _defaultProfile( 
          size: 164, 
        ); 
      }, 
      loadingBuilder: ( 
        BuildContext context, 
        Widget child, 
        ImageChunkEvent? progress, 
      ) { 
        if (progress == null) { 
          return child; 
        } 
 
        return _defaultProfile( 
          size: 164, 
        ); 
      }, 
    ); 
  } 
 
  Widget _defaultProfile({ 
    required double size, 
  }) { 
    return Container( 
      width: size, 
      height: size, 
      color: panelColor, 
      alignment: Alignment.center, 
      child: Icon( 
        Icons.person_rounded, 
        color: Colors.white.withAlpha(75), 
        size: size * 0.45, 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // CONNECTION INDICATOR 
  // ========================================================================== 
 
  Widget _connectionIndicator() { 
    final bool excellent = 
        connectionStatus == 'Excellent Connection'; 
 
    final bool connecting = 
        connectionStatus == 'Calling...' || 
        connectionStatus == 'Ringing...' || 
        connectionStatus == 'Connecting...'; 
 
    final Color color = excellent 
        ? greenColor 
        : connecting 
            ? cyanColor 
            : redColor; 
 
    final IconData icon = excellent 
        ? Icons.signal_cellular_alt_rounded 
        : connecting 
            ? Icons.sync_rounded 
            : Icons.error_outline_rounded; 
 
    return Container( 
      padding: const EdgeInsets.symmetric( 
        horizontal: 14, 
        vertical: 8, 
      ), 
      decoration: BoxDecoration( 
        color: color.withAlpha(18), 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all( 
          color: color.withAlpha(50), 
        ), 
      ), 
      child: Row( 
        mainAxisSize: MainAxisSize.min, 
        children: <Widget>[ 
          Icon( 
            icon, 
            color: color, 
            size: 15, 
          ), 
          const SizedBox(width: 7), 
          Text( 
            connectionStatus, 
            style: TextStyle( 
              color: color, 
              fontSize: 11, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 0.4, 
            ), 
          ), 
        ], 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // INFO CARDS 
  // ========================================================================== 
 
  Widget _buildInfoCards() { 
    return Row( 
      children: <Widget>[ 
        Expanded( 
          child: _infoCard( 
            icon: Icons.graphic_eq_rounded, 
            title: 'Voice Pulse', 
            value: isVoicePulseActive 
                ? 'Active' 
                : 'Off', 
            color: cyanColor, 
            onTap: () { 
              setState(() { 
                isVoicePulseActive = 
                    !isVoicePulseActive; 
              }); 
            }, 
          ), 
        ), 
        const SizedBox(width: 10), 
        Expanded( 
          child: _infoCard( 
            icon: Icons.spa_rounded, 
            title: 'Atmosphere', 
            value: selectedAtmosphere, 
            color: purpleColor, 
            onTap: _showAtmosphere, 
          ), 
        ), 
        const SizedBox(width: 10), 
        Expanded( 
          child: _infoCard( 
            icon: Icons.shield_rounded, 
            title: 'Shield', 
            value: isCallShieldOn 
                ? 'On' 
                : 'Off', 
            color: greenColor, 
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
          child: _infoCard( 
            icon: Icons.people_alt_rounded, 
            title: 'People', 
            value: '2', 
            color: blueColor, 
            onTap: _showParticipants, 
          ), 
        ), 
      ], 
    ); 
  } 
 
  Widget _infoCard({ 
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color, 
    required VoidCallback onTap, 
  }) { 
    return GestureDetector( 
      onTap: onTap, 
      child: Container( 
        constraints: const BoxConstraints( 
          minHeight: 94, 
        ), 
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration( 
          color: Colors.white.withAlpha(7), 
          borderRadius: BorderRadius.circular(18), 
          border: Border.all( 
            color: Colors.white.withAlpha(12), 
          ), 
        ), 
        child: Column( 
          mainAxisAlignment: 
              MainAxisAlignment.center, 
          children: <Widget>[ 
            Icon( 
              icon, 
              color: color, 
              size: 21, 
            ), 
            const SizedBox(height: 8), 
            Text( 
              title, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: const TextStyle( 
                color: Colors.white54, 
                fontSize: 9, 
                fontWeight: FontWeight.w600, 
              ), 
            ), 
            const SizedBox(height: 3), 
            Text( 
              value, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: TextStyle( 
                color: color, 
                fontSize: 10, 
                fontWeight: FontWeight.w800, 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // REACTIONS 
  // ========================================================================== 
 
  Widget _buildLiveReactions() { 
    return Container( 
      width: double.infinity, 
      padding: const EdgeInsets.fromLTRB( 
        16, 
        14, 
        16, 
        14, 
      ), 
      decoration: BoxDecoration( 
        color: Colors.white.withAlpha(7), 
        borderRadius: BorderRadius.circular(22), 
        border: Border.all( 
          color: Colors.white.withAlpha(12), 
        ), 
      ), 
      child: Row( 
        children: <Widget>[ 
          const Icon( 
            Icons.favorite_rounded, 
            color: purpleColor, 
            size: 19, 
          ), 
          const SizedBox(width: 8), 
          const Expanded( 
            child: Text( 
              'Live reactions', 
              style: TextStyle( 
                color: Colors.white70, 
                fontSize: 12, 
                fontWeight: FontWeight.w700, 
              ), 
            ), 
          ), 
          ..._quickReactions.take(5).map( 
            (String emoji) { 
              return GestureDetector( 
                onTap: () { 
                  _sendLiveReaction(emoji); 
                }, 
                child: Padding( 
                  padding: 
                      const EdgeInsets.symmetric( 
                    horizontal: 5, 
                  ), 
                  child: Text( 
                    emoji, 
                    style: const TextStyle( 
                      fontSize: 20, 
                    ), 
                  ), 
                ), 
              ); 
            }, 
          ), 
          const SizedBox(width: 4), 
          GestureDetector( 
            onTap: _showReactionPicker, 
            child: Container( 
              width: 30, 
              height: 30, 
              decoration: BoxDecoration( 
                shape: BoxShape.circle, 
                color: purpleColor.withAlpha(22), 
              ), 
              child: const Icon( 
                Icons.add_rounded, 
                color: purpleColor, 
                size: 18, 
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
      top: 180, 
      right: 45, 
      child: AnimatedBuilder( 
        animation: _reactionController, 
        builder: ( 
          BuildContext context, 
          Widget? child, 
        ) { 
          final value = 
              Curves.easeOut.transform( 
            _reactionController.value, 
          ); 
 
          return Opacity( 
            opacity: 1 - value, 
            child: Transform.translate( 
              offset: Offset( 
                0, 
                -80 * value, 
              ), 
              child: Transform.scale( 
                scale: 0.8 + (value * 0.5), 
                child: Text( 
                  floatingReaction ?? '', 
                  style: const TextStyle( 
                    fontSize: 42, 
                  ), 
                ), 
              ), 
            ), 
          ); 
        }, 
      ), 
    ); 
  } 
 
// ==========================================================================
// CALL CONTROLS
// ==========================================================================

Widget _buildCallControls() {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 2,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _callControl(
                icon: isMuted
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
                label: isMuted ? 'Unmute' : 'Mute',
                active: isMuted,
                onTap: _toggleMute,
              ),
            ),
            Expanded(
              child: _callControl(
                icon: isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.phone_in_talk_rounded,
                label: isSpeakerOn ? 'Speaker' : 'Phone',
                active: isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
            ),
            Expanded(
              child: _callControl(
                icon: Icons.dialpad_rounded,
                label: 'Keypad',
                onTap: _showKeypad,
              ),
            ),
            Expanded(
              child: _callControl(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add',
                onTap: _addCall,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          children: <Widget>[
            Expanded(
              child: _callControl(
                icon: isOnHold
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: isOnHold ? 'Resume' : 'Hold',
                active: isOnHold,
                onTap: _toggleHold,
              ),
            ),
            Expanded(
              child: _callControl(
                icon: Icons.headset_mic_rounded,
                label: 'Audio',
                onTap: _showAudioRoutes,
              ),
            ),
            Expanded(
              child: _callControl(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: _showMore,
              ),
            ),
            Expanded(
              child: _endCallControl(),
            ),
          ],
        ),
      ],
    ),
  );
}
 
  Widget _callControl({ 
    required IconData icon, 
    required String label, 
    required VoidCallback onTap, 
    bool active = false, 
  }) { 
    final Color iconColor = 
        active ? cyanColor : Colors.white; 
 
    return GestureDetector( 
      onTap: onTap, 
      child: SizedBox(
  width: double.infinity,
  child: Column( 
          children: <Widget>[ 
            Container( 
              width: 58, 
              height: 58, 
              decoration: BoxDecoration( 
                shape: BoxShape.circle, 
                color: active 
                    ? cyanColor.withAlpha(24) 
                    : Colors.white.withAlpha(9), 
                border: Border.all( 
                  color: active 
                      ? cyanColor.withAlpha(70) 
                      : Colors.white.withAlpha(15), 
                ), 
              ), 
              child: Icon( 
                icon, 
                color: iconColor, 
                size: 23, 
              ), 
            ), 
            const SizedBox(height: 7), 
            Text( 
              label, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              textAlign: TextAlign.center, 
              style: const TextStyle( 
                color: Colors.white54, 
                fontSize: 9, 
                fontWeight: FontWeight.w600, 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
 
  Widget _endCallControl() { 
    return GestureDetector( 
      onTap: _endCall, 
      child: SizedBox(
  width: double.infinity,
  child: Column( 
          children: <Widget>[ 
            Container( 
              width: 62, 
              height: 62, 
              decoration: BoxDecoration( 
                shape: BoxShape.circle, 
                color: redColor, 
                boxShadow: <BoxShadow>[ 
                  BoxShadow( 
                    color: redColor.withAlpha(65), 
                    blurRadius: 22, 
                    spreadRadius: 2, 
                  ), 
                ], 
              ), 
              child: const Icon( 
                Icons.call_end_rounded, 
                color: Colors.white, 
                size: 27, 
              ), 
            ), 
            const SizedBox(height: 7), 
            const Text( 
              'End', 
              style: TextStyle( 
                color: Colors.white54, 
                fontSize: 9, 
                fontWeight: FontWeight.w600, 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // MORE DETAILS 
  // ========================================================================== 
 
  Widget _buildMoreDetailsButton() { 
    return GestureDetector( 
      onTap: _toggleMoreDetails, 
      child: Container( 
        padding: const EdgeInsets.symmetric( 
          horizontal: 18, 
          vertical: 12, 
        ), 
        decoration: BoxDecoration( 
          color: Colors.white.withAlpha(7), 
          borderRadius: BorderRadius.circular(30), 
          border: Border.all( 
            color: Colors.white.withAlpha(14), 
          ), 
        ), 
        child: Row( 
          mainAxisSize: MainAxisSize.min, 
          children: <Widget>[ 
            const Icon( 
              Icons.keyboard_arrow_up_rounded, 
              color: cyanColor, 
              size: 18, 
            ), 
            const SizedBox(width: 6), 
            Text( 
              _showDetails 
                  ? 'Hide Details' 
                  : 'Call Details', 
              style: const TextStyle( 
                color: Colors.white70, 
                fontSize: 11, 
                fontWeight: FontWeight.w700, 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
 
  void _toggleMoreDetails() { 
    setState(() { 
      _showDetails = !_showDetails; 
    }); 
  } 
 
  // ========================================================================== 
  // DETAILS VIEW 
  // ========================================================================== 
 
  Widget _buildDetailsView() { 
    return Column( 
      key: const ValueKey<String>('details'), 
      children: <Widget>[ 
        _buildDetailsHeader(), 
        Expanded( 
          child: SingleChildScrollView( 
            physics: const BouncingScrollPhysics(), 
            padding: const EdgeInsets.fromLTRB( 
              20, 
              10, 
              20, 
              30, 
            ), 
            child: Column( 
              children: <Widget>[ 
                _buildDetailsSummary(), 
                const SizedBox(height: 18), 
                _buildDetailsGrid(), 
                const SizedBox(height: 24), 
                _buildBackToCallButton(), 
              ], 
            ), 
          ), 
        ), 
      ], 
    ); 
  } 
 
  Widget _buildDetailsHeader() { 
    return Padding( 
      padding: const EdgeInsets.fromLTRB( 
        18, 
        10, 
        18, 
        10, 
      ), 
      child: Row( 
        children: <Widget>[ 
          _circleButton( 
            icon: Icons.arrow_back_rounded, 
            onTap: () { 
              setState(() { 
                _showDetails = false; 
              }); 
            }, 
          ), 
          const Expanded( 
            child: Center( 
              child: Text( 
                'Call Details', 
                style: TextStyle( 
                  color: Colors.white, 
                  fontSize: 17, 
                  fontWeight: FontWeight.w800, 
                ), 
              ), 
            ), 
          ), 
          const SizedBox(width: 44), 
        ], 
      ), 
    ); 
  } 
 
  Widget _buildDetailsSummary() { 
    return Container( 
      width: double.infinity, 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration( 
        color: Colors.white.withAlpha(7), 
        borderRadius: BorderRadius.circular(26), 
        border: Border.all( 
          color: Colors.white.withAlpha(12), 
        ), 
      ), 
      child: Row( 
        children: <Widget>[ 
          _smallAvatar(widget.profileImageUrl), 
          const SizedBox(width: 14), 
          Expanded( 
            child: Column( 
              crossAxisAlignment: 
                  CrossAxisAlignment.start, 
              children: <Widget>[ 
                Text( 
                  widget.callerName, 
                  style: const TextStyle( 
                    color: Colors.white, 
                    fontSize: 17, 
                    fontWeight: FontWeight.w800, 
                  ), 
                ), 
                const SizedBox(height: 5), 
                Text( 
                  _callHasConnected 
                      ? 'Connected for ${_formatDuration(callDuration)}' 
                      : connectionStatus, 
                  style: const TextStyle( 
                    color: Colors.white54, 
                    fontSize: 11, 
                  ), 
                ), 
              ], 
            ), 
          ), 
          _connectionIndicator(), 
        ], 
      ), 
    ); 
  } 
 
  Widget _buildDetailsGrid() { 
    return GridView.count( 
      crossAxisCount: 2, 
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
      mainAxisSpacing: 12, 
      crossAxisSpacing: 12, 
      childAspectRatio: 1.45, 
      children: <Widget>[ 
        _detailCard( 
          icon: Icons.mic_rounded, 
          title: 'Microphone', 
          value: isMuted 
              ? 'Muted' 
              : 'Active', 
          color: isMuted 
              ? redColor 
              : greenColor, 
        ), 
        _detailCard( 
          icon: Icons.volume_up_rounded, 
          title: 'Audio Route', 
          value: selectedAudioRoute, 
          color: cyanColor, 
        ), 
        _detailCard( 
          icon: Icons.shield_rounded, 
          title: 'Call Shield', 
          value: isCallShieldOn 
              ? 'Enabled' 
              : 'Disabled', 
          color: greenColor, 
        ), 
        _detailCard( 
          icon: Icons.graphic_eq_rounded, 
          title: 'Voice Pulse', 
          value: isVoicePulseActive 
              ? 'Active' 
              : 'Disabled', 
          color: purpleColor, 
        ), 
        _detailCard( 
          icon: Icons.spa_rounded, 
          title: 'Atmosphere', 
          value: selectedAtmosphere, 
          color: purpleColor, 
        ), 
        _detailCard( 
          icon: Icons.history_rounded, 
          title: 'Call Memory', 
          value: isCallMemoryOn 
              ? 'Enabled' 
              : 'Disabled', 
          color: blueColor, 
        ), 
      ], 
    ); 
  } 
 
  Widget _detailCard({ 
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color, 
  }) { 
    return Container( 
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration( 
        color: Colors.white.withAlpha(7), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all( 
          color: Colors.white.withAlpha(12), 
        ), 
      ), 
      child: Column( 
        crossAxisAlignment: 
            CrossAxisAlignment.start, 
        mainAxisAlignment: 
            MainAxisAlignment.center, 
        children: <Widget>[ 
          Icon( 
            icon, 
            color: color, 
            size: 22, 
          ), 
          const SizedBox(height: 10), 
          Text( 
            title, 
            style: const TextStyle( 
              color: Colors.white54, 
              fontSize: 10, 
            ), 
          ), 
          const SizedBox(height: 3), 
          Text( 
            value, 
            style: TextStyle( 
              color: color, 
              fontSize: 12, 
              fontWeight: FontWeight.w800, 
            ), 
          ), 
        ], 
      ), 
    ); 
  } 
 
  Widget _buildBackToCallButton() { 
    return GestureDetector( 
      onTap: () { 
        setState(() { 
          _showDetails = false; 
        }); 
      }, 
      child: Container( 
        width: double.infinity, 
        padding: const EdgeInsets.symmetric( 
          vertical: 16, 
        ), 
        decoration: BoxDecoration( 
          borderRadius: BorderRadius.circular(20), 
          gradient: const LinearGradient( 
            colors: <Color>[ 
              purpleColor, 
              blueColor, 
            ], 
          ), 
        ), 
        child: const Row( 
          mainAxisAlignment: 
              MainAxisAlignment.center, 
          children: <Widget>[ 
            Icon( 
              Icons.call_rounded, 
              color: Colors.white, 
              size: 20, 
            ), 
            SizedBox(width: 8), 
            Text( 
              'Back to Call', 
              style: TextStyle( 
                color: Colors.white, 
                fontSize: 14, 
                fontWeight: FontWeight.w800, 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // COMMON UI 
  // ========================================================================== 
 
  Widget _circleButton({ 
    required IconData icon, 
    required VoidCallback onTap, 
  }) { 
    return GestureDetector( 
      onTap: onTap, 
      child: Container( 
        width: 44, 
        height: 44, 
        decoration: BoxDecoration( 
          shape: BoxShape.circle, 
          color: Colors.white.withAlpha(9), 
          border: Border.all( 
            color: Colors.white.withAlpha(14), 
          ), 
        ), 
        child: Icon( 
          icon, 
          color: Colors.white70, 
          size: 21, 
        ), 
      ), 
    ); 
  } 
 
  Widget _sheetHandle() { 
    return Container( 
      width: 42, 
      height: 4, 
      decoration: BoxDecoration( 
        color: Colors.white.withAlpha(45), 
        borderRadius: BorderRadius.circular(10), 
      ), 
    ); 
  } 
 
  Widget _actionTile( 
    IconData icon, 
    String title, 
    VoidCallback onTap, 
  ) { 
    return ListTile( 
      onTap: onTap, 
      leading: Container( 
        width: 42, 
        height: 42, 
        decoration: BoxDecoration( 
          shape: BoxShape.circle, 
          color: Colors.white.withAlpha(10), 
        ), 
        child: Icon( 
          icon, 
          color: cyanColor, 
          size: 20, 
        ), 
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
 
  Widget _settingSwitch({ 
    required String title, 
    required String subtitle, 
    required bool value, 
    required ValueChanged<bool> onChanged, 
  }) { 
    return SwitchListTile( 
      contentPadding: EdgeInsets.zero, 
      title: Text( 
        title, 
        style: const TextStyle( 
          color: Colors.white, 
          fontWeight: FontWeight.w700, 
        ), 
      ), 
      subtitle: Text( 
        subtitle, 
        style: const TextStyle( 
          color: Colors.white54, 
          fontSize: 11, 
        ), 
      ), 
      value: value, 
      activeThumbColor: cyanColor, 
      activeTrackColor: cyanColor.withAlpha(65), 
      inactiveThumbColor: Colors.white54, 
      inactiveTrackColor: Colors.white.withAlpha(20), 
      onChanged: onChanged, 
    ); 
  } 
 
  Widget _securityRow( 
    IconData icon, 
    String title, 
    String value, 
    Color color, 
  ) { 
    return Padding( 
      padding: const EdgeInsets.symmetric( 
        vertical: 8, 
      ), 
      child: Row( 
        children: <Widget>[ 
          Icon( 
            icon, 
            color: color, 
            size: 19, 
          ), 
          const SizedBox(width: 10), 
          Expanded( 
            child: Text( 
              title, 
              style: const TextStyle( 
                color: Colors.white70, 
                fontSize: 12, 
              ), 
            ), 
          ), 
          Text( 
            value, 
            style: TextStyle( 
              color: color, 
              fontSize: 11, 
              fontWeight: FontWeight.w800, 
            ), 
          ), 
        ], 
      ), 
    ); 
  } 
 
  // ========================================================================== 
  // DURATION 
  // ========================================================================== 
 
  String _formatDuration(Duration duration) { 
    final hours = duration.inHours; 
    final minutes = 
        duration.inMinutes.remainder(60); 
    final seconds = 
        duration.inSeconds.remainder(60); 
 
    final hh = hours.toString().padLeft(2, '0'); 
    final mm = minutes.toString().padLeft(2, '0'); 
    final ss = seconds.toString().padLeft(2, '0'); 
 
    if (hours > 0) { 
      return '$hh:$mm:$ss'; 
    } 
 
    return '$mm:$ss'; 
  } 
 
  // ========================================================================== 
  // DISPOSE 
  // ========================================================================== 
 
  @override
void dispose() {
  _callStatusSubscription?.cancel();
  _reactionSubscription?.cancel();

  _callTimer?.cancel();
  _reactionClearTimer?.cancel();

  _pulseController.dispose();
  _ringController.dispose();
  _glowController.dispose();
  _reactionController.dispose();

  super.dispose();
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
  String _digits = ''; 
 
  final List<String> _keys = <String>[ 
    '1', 
    '2', 
    '3', 
    '4', 
    '5', 
    '6', 
    '7', 
    '8', 
    '9', 
    '*', 
    '0', 
    '#', 
  ]; 
 
  @override 
  Widget build(BuildContext context) { 
    return SafeArea( 
      child: Padding( 
        padding: const EdgeInsets.fromLTRB( 
          24, 
          12, 
          24, 
          28, 
        ), 
        child: Column( 
          mainAxisSize: MainAxisSize.min, 
          children: <Widget>[ 
            Container( 
              width: 42, 
              height: 4, 
              decoration: BoxDecoration( 
                color: Colors.white.withAlpha(45), 
                borderRadius: 
                    BorderRadius.circular(10), 
              ), 
            ), 
            const SizedBox(height: 18), 
            Container( 
              width: double.infinity, 
              padding: 
                  const EdgeInsets.symmetric( 
                vertical: 16, 
              ), 
              decoration: BoxDecoration( 
                color: Colors.white.withAlpha(7), 
                borderRadius: 
                    BorderRadius.circular(18), 
              ), 
              child: Text( 
                _digits.isEmpty 
                    ? 'Enter number' 
                    : _digits, 
                textAlign: TextAlign.center, 
                style: TextStyle( 
                  color: _digits.isEmpty 
                      ? Colors.white38 
                      : Colors.white, 
                  fontSize: 22, 
                  fontWeight: FontWeight.w700, 
                  letterSpacing: 3, 
                ), 
              ), 
            ), 
            const SizedBox(height: 18), 
            GridView.builder( 
              shrinkWrap: true, 
              itemCount: _keys.length, 
              gridDelegate: 
                  const SliverGridDelegateWithFixedCrossAxisCount( 
                crossAxisCount: 3, 
                mainAxisSpacing: 10, 
                crossAxisSpacing: 10, 
                childAspectRatio: 1.3, 
              ), 
              itemBuilder: ( 
                BuildContext context, 
                int index, 
              ) { 
                final key = _keys[index]; 
 
                return GestureDetector( 
                  onTap: () { 
                    setState(() { 
                      _digits += key; 
                    }); 
                  }, 
                  child: Container( 
                    decoration: BoxDecoration( 
                      shape: BoxShape.circle, 
                      color: 
                          Colors.white.withAlpha(8), 
                      border: Border.all( 
                        color: 
                            Colors.white.withAlpha(12), 
                      ), 
                    ), 
                    alignment: Alignment.center, 
                    child: Text( 
                      key, 
                      style: const TextStyle( 
                        color: Colors.white, 
                        fontSize: 21, 
                        fontWeight: FontWeight.w700, 
                      ), 
                    ), 
                  ), 
                ); 
              }, 
            ), 
            const SizedBox(height: 16), 
            GestureDetector( 
              onTap: () { 
                if (_digits.isEmpty) { 
                  return; 
                } 
 
                setState(() { 
                  _digits = _digits.substring( 
                    0, 
                    _digits.length - 1, 
                  ); 
                }); 
              }, 
              child: Container( 
                width: 58, 
                height: 58, 
                decoration: BoxDecoration( 
                  shape: BoxShape.circle, 
                  color: Colors.white.withAlpha(9), 
                ), 
                child: const Icon( 
                  Icons.backspace_outlined, 
                  color: Colors.white70, 
                ), 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
}