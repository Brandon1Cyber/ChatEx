import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

/// ============================================================================
/// CHATTªX CALL TYPES
/// ============================================================================

enum ChattaxCallType {
  audio,
  video,
}

/// ============================================================================
/// CHATTªX CALL STATUS
/// ============================================================================

enum ChattaxCallStatus {
  calling,
  ringing,
  connecting,
  connected,
  rejected,
  ended,
  failed,
}

/// ============================================================================
/// CALL STATUS EVENT
/// ============================================================================

class ChattaxCallStatusEvent {
  final String callId;
  final ChattaxCallStatus status;

  const ChattaxCallStatusEvent({
    required this.callId,
    required this.status,
  });
}

/// ============================================================================
/// CHATTªX CALL MODEL
/// ============================================================================

class ChattaxCall {
  final String callId;
  final String callerId;
  final String receiverId;
  final ChattaxCallType type;
  final ChattaxCallStatus status;
  final DateTime? createdAt;

  const ChattaxCall({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    this.createdAt,
  });

  bool get isAudio => type == ChattaxCallType.audio;

  bool get isVideo => type == ChattaxCallType.video;

  factory ChattaxCall.fromFirestore(
    String callId,
    Map<String, dynamic> data,
  ) {
    final typeString =
        (data['type'] ?? 'audio').toString().toLowerCase();

    final statusString =
        (data['status'] ?? 'calling').toString().toLowerCase();

    DateTime? createdAt;

    final createdValue = data['createdAt'];

    if (createdValue is Timestamp) {
      createdAt = createdValue.toDate();
    } else {
      final clientCreatedValue = data['clientCreatedAt'];

      if (clientCreatedValue is Timestamp) {
        createdAt = clientCreatedValue.toDate();
      }
    }

    return ChattaxCall(
      callId: callId,
      callerId: (data['callerId'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      type: typeString == 'video'
          ? ChattaxCallType.video
          : ChattaxCallType.audio,
      status: _statusFromString(statusString),
      createdAt: createdAt,
    );
  }

  static ChattaxCallStatus _statusFromString(
    String value,
  ) {
    switch (value) {
      case 'ringing':
        return ChattaxCallStatus.ringing;

      case 'connecting':
        return ChattaxCallStatus.connecting;

      case 'connected':
        return ChattaxCallStatus.connected;

      case 'rejected':
        return ChattaxCallStatus.rejected;

      case 'ended':
        return ChattaxCallStatus.ended;

      case 'failed':
        return ChattaxCallStatus.failed;

      case 'calling':
      default:
        return ChattaxCallStatus.calling;
    }
  }
}

/// ============================================================================
/// TURN CONFIG
/// ============================================================================

class ChattaxTurnConfig {
  final String username;
  final String credential;
  final List<String> urls;

  const ChattaxTurnConfig({
    required this.username,
    required this.credential,
    required this.urls,
  });

  Map<String, dynamic> toIceServer() {
    return <String, dynamic>{
      'urls': urls,
      'username': username,
      'credential': credential,
    };
  }
}

/// ============================================================================
/// CHATTªX CALL SERVICE
///
/// Firestore signaling:
///
/// CALLER
///   calling
///      ↓
/// RECEIVER DETECTS
///   ringing
///      ↓
/// RECEIVER ACCEPTS
///   connecting
///      ↓
/// BOTH PEERS NEGOTIATE
///      ↓
///   connected
///
/// WebRTC peer connections are owned ONLY by this singleton.
/// UI screens never create their own peer connection.
/// ============================================================================

class ChattaxCallService {
  ChattaxCallService._() {
  _configureMeteredTurn();
  _startAuthListener();
}

  static final ChattaxCallService instance =
      ChattaxCallService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
    FirebaseAuth.instance;

/// ==========================================================================
/// CURRENT USER
/// ==========================================================================

String get currentUserId {
  return _auth.currentUser?.uid ?? '';
}

void _configureMeteredTurn() {
  configureTurn(
    username: '078a4ea70c8bf425cc275690',
    credential: 'qPiPTZcJrzOAevMm',
    urls: <String>[
      'turn:global.relay.metered.ca:80',
      'turn:global.relay.metered.ca:80?transport=tcp',
      'turn:global.relay.metered.ca:443',
      'turns:global.relay.metered.ca:443?transport=tcp',
    ],
  );
}

final Uuid _uuid =
    const Uuid();

  /// ==========================================================================
  /// TIMING
  /// ==========================================================================

  static const Duration outgoingCallTimeout =
      Duration(seconds: 60);

  static const Duration incomingCallMaxAge =
      Duration(seconds: 60);

  static const Duration connectionTimeout =
      Duration(seconds: 45);

  static const Duration disconnectGracePeriod =
      Duration(seconds: 12);

  /// ==========================================================================
  /// WEBRTC
  /// ==========================================================================

  RTCPeerConnection? _peerConnection;

  MediaStream? _localStream;

  MediaStream? _remoteStream;

// ==========================================================================
// GROUP CALL STATE
// ==========================================================================

final Map<String, RTCPeerConnection> _groupPeerConnections =
    <String, RTCPeerConnection>{};

final Map<String, MediaStream> _groupRemoteStreams =
    <String, MediaStream>{};

final Set<String> _groupParticipantIds =
    <String>{};

String? _groupCallId;

bool _isGroupCall = false;

  String? _activeCallId;

  ChattaxCallType? _activeCallType;

  bool _isCaller = false;

  bool _microphoneMuted = false;

  bool _cameraEnabled = true;

  bool _speakerEnabled = true;

  bool _remoteDescriptionSet = false;

  bool _answerApplied = false;

  bool _connectedReported = false;

  bool _signalingReady = false;

  bool _isDisposed = false;

  bool _cleanupInProgress = false;

  bool _endingCall = false;

  bool _failureHandling = false;

  bool _answerApplying = false;

  bool _acceptInProgress = false;

  bool _connectionTimerStarted = false;

  /// ==========================================================================
  /// TURN
  /// ==========================================================================

  ChattaxTurnConfig? turnConfig;

  /// ==========================================================================
  /// TIMERS
  /// ==========================================================================

  Timer? _outgoingCallTimer;

  Timer? _connectionTimer;

  Timer? _disconnectTimer;

  /// ==========================================================================
  /// AUTH
  /// ==========================================================================

  StreamSubscription<User?>? _authSubscription;

  /// ==========================================================================
  /// INCOMING CALL
  /// ==========================================================================

  StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>?
      _incomingCallsSubscription;

  bool _incomingListenerStarted = false;

  String? _incomingListenerUid;

  final Set<String> _announcedIncomingCalls =
      <String>{};

  /// ==========================================================================
  /// FIRESTORE SIGNALING LISTENERS
  /// ==========================================================================

  StreamSubscription<
      DocumentSnapshot<Map<String, dynamic>>>?
      _callSubscription;

  StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>?
      _callerCandidatesSubscription;

  StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>?
      _receiverCandidatesSubscription;

  /// ==========================================================================
  /// ICE
  /// ==========================================================================

  final List<RTCIceCandidate>
      _pendingLocalCandidates =
      <RTCIceCandidate>[];

  final List<RTCIceCandidate>
      _pendingRemoteCandidates =
      <RTCIceCandidate>[];

  final Set<String>
      _receivedRemoteCandidateIds =
      <String>{};

  final Set<String>
      _sentLocalCandidateKeys =
      <String>{};

  /// ==========================================================================
  /// STREAM CONTROLLERS
  /// ==========================================================================

  final StreamController<ChattaxCall>
      _incomingCallController =
      StreamController<ChattaxCall>.broadcast();

  final StreamController<ChattaxCallStatus>
      _callStatusController =
      StreamController<ChattaxCallStatus>.broadcast();

  final StreamController<ChattaxCallStatusEvent>
      _callStatusEventController =
      StreamController<ChattaxCallStatusEvent>.broadcast();

  final StreamController<MediaStream?>
      _remoteStreamController =
      StreamController<MediaStream?>.broadcast();

  final StreamController<MediaStream?>
      _localStreamController =
      StreamController<MediaStream?>.broadcast();

  /// ==========================================================================
  /// PUBLIC STREAMS
  /// ==========================================================================

  Stream<ChattaxCall> get incomingCalls {
    _ensureNotDisposed();

    _ensureIncomingListener();

    return _incomingCallController.stream;
  }

  Stream<ChattaxCallStatus> get callStatusStream =>
      _callStatusController.stream;

  Stream<ChattaxCallStatus> get callStatus =>
      _callStatusController.stream;

  Stream<ChattaxCallStatusEvent>
      get callStatusEvents =>
          _callStatusEventController.stream;

  Stream<MediaStream?> get remoteStream =>
      _remoteStreamController.stream;

  Stream<MediaStream?> get localStream =>
      _localStreamController.stream;

  /// ==========================================================================
  /// PUBLIC STATE
  /// ==========================================================================

  String? get activeCallId =>
      _activeCallId;

  ChattaxCallType? get activeCallType =>
      _activeCallType;

  bool get isInCall =>
      _activeCallId != null;

bool get isGroupCall =>
    _isGroupCall;

String? get groupCallId =>
    _groupCallId;

Map<String, MediaStream> get groupRemoteStreams =>
    Map.unmodifiable(
      _groupRemoteStreams,
    );

  bool get isCaller =>
      _isCaller;

  bool get isMicrophoneMuted =>
      _microphoneMuted;

  bool get isSpeakerEnabled =>
      _speakerEnabled;

  bool get isCameraEnabled =>
      _cameraEnabled;

  MediaStream? get currentRemoteStream =>
      _remoteStream;

  MediaStream? get currentLocalStream =>
      _localStream;

  RTCPeerConnection? get peerConnection =>
      _peerConnection;

  /// ==========================================================================
  /// AUTH LISTENER
  /// ==========================================================================

  void _startAuthListener() {
    _authSubscription =
        _auth.authStateChanges().listen(
      (User? user) {
        final uid = user?.uid;

        if (uid == null || uid.isEmpty) {
          unawaited(
            _stopIncomingListener(),
          );

          return;
        }

        if (_incomingListenerUid == uid &&
            _incomingListenerStarted) {
          return;
        }

        _incomingListenerUid = uid;

        _ensureIncomingListener();
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'AUTH LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );
  }

  /// ==========================================================================
  /// INCOMING LISTENER
  /// ==========================================================================

  void _ensureIncomingListener() {
    if (_isDisposed) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final uid = user.uid;

    if (_incomingListenerStarted &&
        _incomingListenerUid == uid) {
      return;
    }

    unawaited(
      _stopIncomingListener(),
    );

    _incomingListenerUid = uid;
    _incomingListenerStarted = true;

    _log(
      'INCOMING LISTENER STARTED | uid=$uid',
    );

    _incomingCallsSubscription =
        _firestore
            .collection('calls')
            .where(
              'receiverId',
              isEqualTo: uid,
            )
            .where(
              'status',
              isEqualTo: 'calling',
            )
            .snapshots()
            .listen(
      (snapshot) {
        for (final doc in snapshot.docs) {
          unawaited(
            _handleIncomingCallDocument(
              doc,
            ),
          );
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'INCOMING CALL LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );
  }

  Future<void> _stopIncomingListener() async {
    await _incomingCallsSubscription?.cancel();

    _incomingCallsSubscription = null;

    _incomingListenerStarted = false;

    _incomingListenerUid = null;
  }

  /// ==========================================================================
  /// PUBLIC INCOMING LISTENER
  /// ==========================================================================

  StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>?
      listenForIncomingCalls() {
    _ensureIncomingListener();

    return _incomingCallsSubscription;
  }

  /// ==========================================================================
  /// HANDLE INCOMING CALL
  /// ==========================================================================

  Future<void> _handleIncomingCallDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_isDisposed) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final data = doc.data();

    final callId = doc.id;

    final receiverId =
        (data['receiverId'] ?? '').toString();

    final callerId =
        (data['callerId'] ?? '').toString();

    final status =
        (data['status'] ?? '')
            .toString()
            .toLowerCase();

    if (receiverId != user.uid) {
      return;
    }

    if (callerId.isEmpty ||
        callerId == user.uid) {
      return;
    }

    if (status != 'calling') {
      return;
    }

    if (_activeCallId != null &&
        _activeCallId != callId) {
      _log(
        'INCOMING CALL IGNORED | active call exists | $callId',
      );

      return;
    }

    if (_announcedIncomingCalls.contains(callId)) {
      return;
    }

    final offer = data['offer'];

    if (offer is! Map) {
      _log(
        'INCOMING CALL IGNORED | missing offer | $callId',
      );

      return;
    }

    final offerSdp =
        offer['sdp']?.toString();

    if (offerSdp == null ||
        offerSdp.isEmpty) {
      _log(
        'INCOMING CALL IGNORED | empty offer | $callId',
      );

      return;
    }

    final createdAt =
        _getCallCreatedTime(data);

    if (createdAt != null) {
      final age =
          DateTime.now().difference(
        createdAt,
      );

      if (age > incomingCallMaxAge) {
        await _safeMarkCallEnded(
          callId,
        );

        return;
      }
    }

    final acknowledged =
        await _acknowledgeIncomingCall(
      doc.reference,
      user.uid,
    );

    if (!acknowledged) {
      return;
    }

    _announcedIncomingCalls.add(
      callId,
    );

    final call =
        ChattaxCall.fromFirestore(
      callId,
      <String, dynamic>{
        ...data,
        'status': 'ringing',
      },
    );

    _emitStatus(
      ChattaxCallStatus.ringing,
      callId: callId,
    );

    if (!_incomingCallController.isClosed) {
      _incomingCallController.add(
        call,
      );
    }

    _log(
      'INCOMING CALL READY | $callId',
    );
  }

  /// ==========================================================================
  /// ACKNOWLEDGE INCOMING CALL
  /// ==========================================================================

  Future<bool> _acknowledgeIncomingCall(
    DocumentReference<Map<String, dynamic>>
        callRef,
    String receiverId,
  ) async {
    try {
      return await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            callRef,
          );

          if (!snapshot.exists) {
            return false;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return false;
          }

          final currentReceiver =
              (data['receiverId'] ?? '')
                  .toString();

          final currentStatus =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (currentReceiver != receiverId) {
            return false;
          }

          if (currentStatus != 'calling') {
            return false;
          }

          transaction.update(
            callRef,
            <String, dynamic>{
              'status': 'ringing',
              'ringingAt':
                  FieldValue.serverTimestamp(),
            },
          );

          return true;
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'ACKNOWLEDGE INCOMING CALL FAILED',
        error,
        stackTrace,
      );

      return false;
    }
  }

  /// ==========================================================================
  /// START AUDIO CALL
  /// ==========================================================================

  Future<ChattaxCall?> startAudioCall(
    String receiverId,
  ) {
    return startCall(
      receiverId,
      type: ChattaxCallType.audio,
    );
  }

  /// ==========================================================================
  /// START VIDEO CALL
  /// ==========================================================================

  Future<ChattaxCall?> startVideoCall(
    String receiverId,
  ) {
    return startCall(
      receiverId,
      type: ChattaxCallType.video,
    );
  }

  /// ==========================================================================
  /// START CALL
  /// ==========================================================================

  Future<ChattaxCall?> startCall(
    String receiverId, {
    ChattaxCallType type =
        ChattaxCallType.audio,
  }) async {
    _ensureNotDisposed();

    final user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to make a call.',
      );
    }

    final callerId =
        user.uid;

    final cleanedReceiverId =
        receiverId.trim();

    if (cleanedReceiverId.isEmpty) {
      throw Exception(
        'Receiver ID is empty.',
      );
    }

    if (cleanedReceiverId == callerId) {
      throw Exception(
        'You cannot call yourself.',
      );
    }

    if (_activeCallId != null) {
      throw Exception(
        'You already have an active call.',
      );
    }

    await _requestPermissions(
      type,
    );

    await _prepareForNewCall();

    final callId =
        _uuid.v4();

    _activeCallId =
        callId;

    _activeCallType =
        type;

    _isCaller =
        true;

    _connectedReported =
        false;

    _signalingReady =
        false;

    _answerApplied =
        false;

    _remoteDescriptionSet =
        false;

    final callRef =
        _firestore
            .collection('calls')
            .doc(callId);

    try {
      _log(
        '==================================================',
      );

      _log(
        '📞 STARTING CHATTªX CALL',
      );

      _log(
        'callId=$callId',
      );

      _log(
        'caller=$callerId',
      );

      _log(
        'receiver=$cleanedReceiverId',
      );

      _log(
        'type=$type',
      );

      _log(
        '==================================================',
      );

      /// ----------------------------------------------------------------------
      /// PEER CONNECTION
      /// ----------------------------------------------------------------------

      await _createPeerConnection();

      /// ----------------------------------------------------------------------
      /// MICROPHONE
      /// ----------------------------------------------------------------------

      await _createLocalStream(
        type,
      );

      final pc =
          _peerConnection;

      if (pc == null) {
        throw Exception(
          'PeerConnection unavailable.',
        );
      }

      /// ----------------------------------------------------------------------
      /// OFFER
      /// ----------------------------------------------------------------------

      _log(
        'CALLER: creating offer',
      );

      final offer =
          await pc.createOffer(
        <String, dynamic>{
          'offerToReceiveAudio': true,
          'offerToReceiveVideo':
              type == ChattaxCallType.video,
        },
      );

      await pc.setLocalDescription(
        offer,
      );

      _log(
        'CALLER: local offer applied',
      );

      /// ----------------------------------------------------------------------
      /// CREATE FIRESTORE CALL
      /// ----------------------------------------------------------------------

      await callRef.set(
        <String, dynamic>{
          'callerId': callerId,
          'receiverId': cleanedReceiverId,
          'type': type ==
                  ChattaxCallType.video
              ? 'video'
              : 'audio',
          'status': 'calling',
          'createdAt':
              FieldValue.serverTimestamp(),
          'clientCreatedAt':
              Timestamp.now(),
          'offer': <String, dynamic>{
            'type': offer.type,
            'sdp': offer.sdp,
          },
        },
      );

      try {
  await _createCallHistoryMessage(
    callId: callId,
    callerId: callerId,
    receiverId: cleanedReceiverId,
    type: type,
  );
} catch (e) {
  debugPrint(
    'CHATTªX call history create failed: $e',
  );
}

      _log(
        'CALL DOCUMENT CREATED',
      );

      /// ----------------------------------------------------------------------
      /// SIGNALING
      /// ----------------------------------------------------------------------

      _signalingReady =
          true;

      await _flushPendingLocalCandidates();

      _listenToCallDocument(
        callId,
      );

      _listenForReceiverCandidates(
        callId,
      );

      _startOutgoingCallTimeout(
        callId,
      );

      _startConnectionTimeout(
        callId,
      );

      _emitStatus(
        ChattaxCallStatus.calling,
        callId: callId,
      );

      return ChattaxCall(
        callId: callId,
        callerId: callerId,
        receiverId: cleanedReceiverId,
        type: type,
        status: ChattaxCallStatus.calling,
        createdAt: DateTime.now(),
      );
    } catch (error, stackTrace) {
      _logError(
        'START CALL FAILED',
        error,
        stackTrace,
      );

      await _safeMarkCallFailed(
  callId,
);

try {
  await _updateCallHistoryMessage(
    callId: callId,
    callStatus: 'unanswered',
  );
} catch (e) {
  debugPrint(
    'CHATTªX call history failure update failed: $e',
  );
}

_emitStatus(
  ChattaxCallStatus.failed,
  callId: callId,
);

      await _cleanupCall();

      rethrow;
    }
  }

/// ==========================================================================
/// ADD PARTICIPANTS TO CURRENT CALL
/// ==========================================================================
///
/// Adds one or more people to the existing call.
///
/// IMPORTANT:
/// This is separate from startCall(), so the existing 1-to-1
/// calling system remains untouched.
///

Future<void> addParticipantsToCall(
  List<String> participantIds,
) async {
  _ensureNotDisposed();

  final user = _auth.currentUser;

  if (user == null) {
    throw Exception(
      'You must be logged in to add people to a call.',
    );
  }

  if (_activeCallId == null) {
    throw Exception(
      'There is no active call to add people to.',
    );
  }

  final cleanIds = participantIds
      .map((String id) => id.trim())
      .where((String id) => id.isNotEmpty)
      .where((String id) => id != user.uid)
      .toSet()
      .toList();

  if (cleanIds.isEmpty) {
    return;
  }

  final callId = _activeCallId!;

  _log(
    '==================================================',
  );

  _log(
    '👥 CHATTªX ADDING PEOPLE TO CALL',
  );

  _log(
    'callId=$callId',
  );

  _log(
    'participants=$cleanIds',
  );

  _log(
    '==================================================',
  );

  // Mark this as a group call.
  _isGroupCall = true;
  _groupCallId = callId;

  // Add the selected people to our local participant set.
  _groupParticipantIds.addAll(cleanIds);

  final callRef =
      _firestore
          .collection('calls')
          .doc(callId);

  try {
    await callRef.update(
      <String, dynamic>{
        'isGroupCall': true,
        'type': _activeCallType ==
                ChattaxCallType.video
            ? 'group_video'
            : 'group_audio',
        'participants':
            FieldValue.arrayUnion(cleanIds),
      },
    );

    for (final participantId in cleanIds) {
      await callRef
          .collection('participants')
          .doc(participantId)
          .set(
        <String, dynamic>{
          'userId': participantId,
          'status': 'invited',
          'invitedBy': user.uid,
          'invitedAt':
              FieldValue.serverTimestamp(),
        },
      );
    }

    // ==========================================================================
// CREATE WEBRTC PEER + OFFER FOR EACH NEW PARTICIPANT
// ==========================================================================

for (final participantId in cleanIds) {
  try {
    await _createGroupPeerConnection(
      participantId,
    );

    await _createGroupOffer(
      participantId,
    );

    _log(
      'GROUP INVITATION READY | '
      'participant=$participantId',
    );
  } catch (error, stackTrace) {
    _logError(
      'GROUP PEER/OFFER CREATION FAILED | '
      'participant=$participantId',
      error,
      stackTrace,
    );

    rethrow;
  }
}

    _log(
      'GROUP PARTICIPANTS ADDED SUCCESSFULLY',
    );
  } catch (error, stackTrace) {
    _logError(
      'ADDING GROUP PARTICIPANTS FAILED',
      error,
      stackTrace,
    );

    rethrow;
  }
}

  /// ==========================================================================
  /// ACCEPT CALL
  /// ==========================================================================

  Future<void> acceptCall(
    String callId,
  ) async {
    if (_acceptInProgress) {
      return;
    }

    _acceptInProgress =
        true;

    try {
      _ensureNotDisposed();

      final user =
          _auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be logged in to answer a call.',
        );
      }

      final uid =
          user.uid;

      if (_activeCallId != null) {
        throw Exception(
          'Another call is already active.',
        );
      }

      final cleanCallId =
          callId.trim();

      if (cleanCallId.isEmpty) {
        throw Exception(
          'Call ID is empty.',
        );
      }

      final callRef =
          _firestore
              .collection('calls')
              .doc(cleanCallId);

      /// ----------------------------------------------------------------------
      /// READ CALL
      /// ----------------------------------------------------------------------

      final snapshot =
          await callRef.get();

      if (!snapshot.exists) {
        throw Exception(
          'Call no longer exists.',
        );
      }

      final data =
          snapshot.data();

      if (data == null) {
        throw Exception(
          'Call data is unavailable.',
        );
      }

      final callerId =
          (data['callerId'] ?? '')
              .toString();

      final receiverId =
          (data['receiverId'] ?? '')
              .toString();

      final status =
          (data['status'] ?? '')
              .toString()
              .toLowerCase();

      if (receiverId != uid) {
        throw Exception(
          'Receiver mismatch.',
        );
      }

      if (callerId.isEmpty) {
        throw Exception(
          'Caller ID is missing.',
        );
      }

      if (status != 'ringing') {
        throw Exception(
          'This call is no longer ringing.',
        );
      }

      final offer =
          data['offer'];

      if (offer is! Map) {
        throw Exception(
          'Caller offer is missing.',
        );
      }

      final offerSdp =
          offer['sdp']?.toString();

      if (offerSdp == null ||
          offerSdp.isEmpty) {
        throw Exception(
          'Caller offer SDP is missing.',
        );
      }

      final createdAt =
          _getCallCreatedTime(data);

      if (createdAt != null) {
        final age =
            DateTime.now().difference(
          createdAt,
        );

        if (age > incomingCallMaxAge) {
          await _safeMarkCallEnded(
            cleanCallId,
          );

          throw Exception(
            'This call has expired.',
          );
        }
      }

      final typeString =
          (data['type'] ?? 'audio')
              .toString()
              .toLowerCase();

      final type =
          typeString == 'video'
              ? ChattaxCallType.video
              : ChattaxCallType.audio;

      /// ----------------------------------------------------------------------
      /// PERMISSIONS
      /// ----------------------------------------------------------------------

      await _requestPermissions(
        type,
      );

      /// ----------------------------------------------------------------------
      /// CLAIM CALL
      /// ----------------------------------------------------------------------

      final claimed =
          await _claimIncomingCall(
        callRef,
        uid,
      );

      if (!claimed) {
        throw Exception(
          'This call was already answered or ended.',
        );
      }

      /// ----------------------------------------------------------------------
      /// PREPARE
      /// ----------------------------------------------------------------------

      await _prepareForNewCall();

      _activeCallId =
          cleanCallId;

      _activeCallType =
          type;

      _isCaller =
          false;

      _connectedReported =
          false;

      _signalingReady =
          false;

      _remoteDescriptionSet =
          false;

      _answerApplied =
          false;

      _log(
        '==================================================',
      );

      _log(
        '📲 ACCEPTING CHATTªX CALL',
      );

      _log(
        'callId=$cleanCallId',
      );

      _log(
        'caller=$callerId',
      );

      _log(
        '==================================================',
      );

      /// ----------------------------------------------------------------------
      /// PEER
      /// ----------------------------------------------------------------------

      await _createPeerConnection();

      /// ----------------------------------------------------------------------
      /// CALLER ICE LISTENER
      /// ----------------------------------------------------------------------

      _listenForCallerCandidates(
        cleanCallId,
      );

      /// ----------------------------------------------------------------------
      /// LOCAL MICROPHONE
      /// ----------------------------------------------------------------------

      await _createLocalStream(
        type,
      );

      /// ----------------------------------------------------------------------
      /// REMOTE OFFER
      /// ----------------------------------------------------------------------

      await _applyRemoteOffer(
        data,
      );

      /// ----------------------------------------------------------------------
      /// ANSWER
      /// ----------------------------------------------------------------------

      final pc =
          _peerConnection;

      if (pc == null) {
        throw Exception(
          'PeerConnection unavailable.',
        );
      }

      _log(
        'RECEIVER: creating answer',
      );

      final answer =
          await pc.createAnswer(
        <String, dynamic>{
          'offerToReceiveAudio': true,
          'offerToReceiveVideo':
              type == ChattaxCallType.video,
        },
      );

      await pc.setLocalDescription(
        answer,
      );

      _log(
        'RECEIVER: local answer applied',
      );

      /// ----------------------------------------------------------------------
      /// WRITE ANSWER
      /// ----------------------------------------------------------------------

      await callRef.update(
        <String, dynamic>{
          'status': 'connecting',
          'answer': <String, dynamic>{
            'type': answer.type,
            'sdp': answer.sdp,
          },
          'answeredAt':
              FieldValue.serverTimestamp(),
        },
      );

      _log(
        'RECEIVER: ANSWER WRITTEN',
      );

      _signalingReady =
          true;

      await _flushPendingLocalCandidates();

      _startConnectionTimeout(
        cleanCallId,
      );

      _emitStatus(
        ChattaxCallStatus.connecting,
        callId: cleanCallId,
      );

      _log(
        'RECEIVER: WebRTC negotiation active',
      );
    } catch (error, stackTrace) {
      _logError(
        'ACCEPT CALL FAILED',
        error,
        stackTrace,
      );

      final currentCallId =
          _activeCallId;

      if (currentCallId != null) {
        await _safeMarkCallFailed(
          currentCallId,
        );

        _emitStatus(
          ChattaxCallStatus.failed,
          callId: currentCallId,
        );
      }

      await _cleanupCall();

      rethrow;
    } finally {
      _acceptInProgress =
          false;
    }
  }

  /// ==========================================================================
  /// CLAIM INCOMING CALL
  /// ==========================================================================

  Future<bool> _claimIncomingCall(
    DocumentReference<Map<String, dynamic>>
        callRef,
    String receiverId,
  ) async {
    try {
      return await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            callRef,
          );

          if (!snapshot.exists) {
            return false;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return false;
          }

          final currentReceiver =
              (data['receiverId'] ?? '')
                  .toString();

          final currentStatus =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (currentReceiver != receiverId) {
            return false;
          }

          if (currentStatus != 'ringing') {
            return false;
          }

          transaction.update(
            callRef,
            <String, dynamic>{
              'status': 'connecting',
              'acceptedBy':
                  receiverId,
              'acceptedAt':
                  FieldValue.serverTimestamp(),
            },
          );

          return true;
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'CLAIM CALL FAILED',
        error,
        stackTrace,
      );

      return false;
    }
  }

  /// ==========================================================================
  /// CREATE PEER CONNECTION
  /// ==========================================================================

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) {
      return;
    }

    _log(
      'WEBRTC: creating peer connection',
    );

    final configuration =
        <String, dynamic>{
      'iceServers': _buildIceServers(),

      'sdpSemantics': 'unified-plan',

      'bundlePolicy': 'max-bundle',

      'rtcpMuxPolicy': 'require',

      'iceCandidatePoolSize': 10,
    };

    final pc =
        await createPeerConnection(
      configuration,
    );

    _peerConnection =
        pc;

    /// ------------------------------------------------------------------------
    /// LOCAL ICE
    /// ------------------------------------------------------------------------

    pc.onIceCandidate =
        (RTCIceCandidate candidate) {
      final value =
          candidate.candidate;

      if (value == null ||
          value.isEmpty) {
        return;
      }

      _log(
        'LOCAL ICE | '
        '${_candidateSummary(candidate)}',
      );

      unawaited(
        _handleLocalIceCandidate(
          candidate,
        ),
      );
    };

    /// ------------------------------------------------------------------------
    /// ICE GATHERING
    /// ------------------------------------------------------------------------

    pc.onIceGatheringState =
        (RTCIceGatheringState state) {
      _log(
        'ICE GATHERING = $state',
      );
    };

    /// ------------------------------------------------------------------------
    /// REMOTE TRACK
    ///
    /// IMPORTANT:
    /// Do NOT assume event.streams is non-empty.
    /// Some WebRTC implementations can deliver a track without
    /// an attached stream.
    /// ------------------------------------------------------------------------

    pc.onTrack =
        (RTCTrackEvent event) async {
      _log(
        'REMOTE TRACK | '
        'kind=${event.track.kind} '
        'streams=${event.streams.length}',
      );

      try {
        event.track.enabled =
            true;
      } catch (_) {}

      if (event.streams.isNotEmpty) {
        _setRemoteStream(
          event.streams.first,
        );

        return;
      }

      /// ----------------------------------------------------------------------
      /// STREAMLESS TRACK
      /// ----------------------------------------------------------------------

      try {
        final existing =
            _remoteStream;

        if (existing != null) {
          await existing.addTrack(
            event.track,
          );

          _setRemoteStream(
            existing,
          );

          _log(
            'REMOTE TRACK ATTACHED TO EXISTING STREAM',
          );

          return;
        }

        final created =
            await createLocalMediaStream(
          'chattax-remote-${_activeCallId ?? _uuid.v4()}',
        );

        await created.addTrack(
          event.track,
        );

        _setRemoteStream(
          created,
        );

        _log(
          'REMOTE STREAM CREATED FOR STREAMLESS TRACK',
        );
      } catch (error, stackTrace) {
        _logError(
          'REMOTE TRACK STREAM CREATION FAILED',
          error,
          stackTrace,
        );
      }
    };

    /// ------------------------------------------------------------------------
    /// LEGACY REMOTE STREAM
    /// ------------------------------------------------------------------------

    pc.onAddStream =
        (MediaStream stream) {
      _log(
        'REMOTE STREAM RECEIVED',
      );

      _setRemoteStream(
        stream,
      );
    };

    /// ------------------------------------------------------------------------
    /// ICE CONNECTION STATE
    /// ------------------------------------------------------------------------

    pc.onIceConnectionState =
        (RTCIceConnectionState state) {
      _log(
        'ICE CONNECTION STATE = $state',
      );

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          _emitStatus(
            ChattaxCallStatus.connecting,
            callId: _activeCallId,
          );

          _cancelDisconnectTimer();

          break;

        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _cancelDisconnectTimer();

          _log(
            '✅ ICE TRANSPORT CONNECTED',
          );

          unawaited(
            _markConnected(),
          );

          break;

        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _log(
            '⚠️ ICE DISCONNECTED',
          );

          _startDisconnectGracePeriod();

          break;

        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _cancelDisconnectTimer();

          _log(
            '❌ ICE CONNECTION FAILED',
          );

          unawaited(
            _handleConnectionFailure(),
          );

          break;

        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _cancelDisconnectTimer();

          break;

        case RTCIceConnectionState.RTCIceConnectionStateNew:
          break;
          case RTCIceConnectionState.RTCIceConnectionStateCount:
  break;
      }
    };

    /// ------------------------------------------------------------------------
    /// PEER CONNECTION STATE
    /// ------------------------------------------------------------------------

    pc.onConnectionState =
        (RTCPeerConnectionState state) {
      _log(
        'PEER CONNECTION STATE = $state',
      );

      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          _cancelDisconnectTimer();

          _emitStatus(
            ChattaxCallStatus.connecting,
            callId: _activeCallId,
          );

          break;

        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _cancelDisconnectTimer();

          _log(
            '✅ PEER CONNECTION CONNECTED',
          );

          unawaited(
            _markConnected(),
          );

          break;

        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _startDisconnectGracePeriod();

          break;

        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _cancelDisconnectTimer();

          _log(
            '❌ PEER CONNECTION FAILED',
          );

          unawaited(
            _handleConnectionFailure(),
          );

          break;

        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _cancelDisconnectTimer();

          break;

        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          break;
      }
    };

    /// ------------------------------------------------------------------------
    /// SIGNALING STATE
    /// ------------------------------------------------------------------------

    pc.onSignalingState =
        (RTCSignalingState state) {
      _log(
        'SIGNALING STATE = $state',
      );
    };

    /// ------------------------------------------------------------------------
    /// ICE CANDIDATE ERROR
    /// ------------------------------------------------------------------------

    /// ------------------------------------------------------------------------
/// ICE CANDIDATE ERROR MONITORING
/// ------------------------------------------------------------------------
///
/// This flutter_webrtc version does not expose an
/// `onIceCandidateError` setter.
///
/// We therefore monitor ICE failures through the
/// ICE connection-state callback above.

_log(
  'WEBRTC: ICE candidate error callback '
  'not exposed by current flutter_webrtc API',
);

        _log(
      'WEBRTC: peer connection ready',
    );
  }

  /// ==========================================================================
  /// CREATE GROUP PEER CONNECTION
  /// ==========================================================================

  Future<RTCPeerConnection> _createGroupPeerConnection(
    String participantId,
  ) async {
    final existing =
        _groupPeerConnections[participantId];

    if (existing != null) {
      return existing;
    }

    _log(
      'GROUP WEBRTC: creating peer connection '
      'for $participantId',
    );

    final configuration =
        <String, dynamic>{
      'iceServers': _buildIceServers(),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 10,
    };

    final pc =
    await createPeerConnection(
  configuration,
);

_groupPeerConnections[participantId] =
    pc;

// ==========================================================================
// ADD LOCAL MICROPHONE / CAMERA TO THIS GROUP PEER
// ==========================================================================

final localStream = _localStream;

if (localStream != null) {
  for (final track in localStream.getTracks()) {
    try {
      track.enabled = true;

      await pc.addTrack(
        track,
        localStream,
      );

      _log(
        'GROUP LOCAL TRACK ADDED | '
        'participant=$participantId | '
        'kind=${track.kind}',
      );
    } catch (error, stackTrace) {
      _logError(
        'GROUP LOCAL TRACK ADD FAILED',
        error,
        stackTrace,
      );
    }
  }
}

pc.onIceCandidate =
    (RTCIceCandidate candidate) { 
      final value =
          candidate.candidate;

      if (value == null ||
          value.isEmpty) {
        return;
      }

      _log(
        'GROUP LOCAL ICE | '
        'participant=$participantId',
      );

      unawaited(
        _sendGroupIceCandidate(
          participantId,
          candidate,
        ),
      );
    };

    pc.onIceConnectionState =
        (RTCIceConnectionState state) {
      _log(
        'GROUP ICE STATE | '
        'participant=$participantId | $state',
      );
    };

    pc.onConnectionState =
        (RTCPeerConnectionState state) {
      _log(
        'GROUP PEER STATE | '
        'participant=$participantId | $state',
      );
    };

        pc.onTrack =
        (RTCTrackEvent event) async {
      _log(
        'GROUP REMOTE TRACK | '
        'participant=$participantId | '
        'kind=${event.track.kind}',
      );

      try {
        event.track.enabled = true;
      } catch (_) {}

      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[participantId] =
            event.streams.first;

        _log(
          'GROUP REMOTE STREAM RECEIVED | '
          'participant=$participantId',
        );

        return;
      }

      try {
        MediaStream? stream =
            _groupRemoteStreams[participantId];

        if (stream == null) {
          stream =
              await createLocalMediaStream(
            'chattax-group-remote-$participantId',
          );

          _groupRemoteStreams[participantId] =
              stream;
        }

        await stream.addTrack(
          event.track,
        );

        _log(
          'GROUP REMOTE TRACK ATTACHED | '
          'participant=$participantId',
        );
      } catch (error, stackTrace) {
        _logError(
          'GROUP REMOTE TRACK FAILED',
          error,
          stackTrace,
        );
      }
    };

    _log(
      'GROUP WEBRTC: peer connection ready '
      'for $participantId',
    );

        return pc;
  }

  /// ==========================================================================
/// CREATE GROUP OFFER
/// ==========================================================================

Future<void> _createGroupOffer(
  String participantId,
) async {
  final callId = _groupCallId;

  if (callId == null ||
      callId.isEmpty) {
    throw Exception(
      'Group call ID is unavailable.',
    );
  }

  final pc =
      _groupPeerConnections[participantId];

  if (pc == null) {
    throw Exception(
      'Group peer connection unavailable.',
    );
  }

  _log(
    '==================================================',
  );

  _log(
    'GROUP CALLER: creating offer',
  );

  _log(
    'callId=$callId',
  );

  _log(
    'participant=$participantId',
  );

  _log(
    '==================================================',
  );

  try {
    final offer =
        await pc.createOffer(
      <String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo':
            _activeCallType ==
                ChattaxCallType.video,
      },
    );

    await pc.setLocalDescription(
      offer,
    );

    _log(
      'GROUP CALLER: local offer applied | '
      'participant=$participantId',
    );

    final peerRef = _firestore
        .collection('calls')
        .doc(callId)
        .collection('peers')
        .doc(participantId);

    await peerRef.set(
      <String, dynamic>{
        'callerId': currentUserId,
        'receiverId': participantId,
        'offer': <String, dynamic>{
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'status': 'offered',
        'createdAt':
            FieldValue.serverTimestamp(),
      },
    );

    _log(
      'GROUP OFFER WRITTEN | '
      'participant=$participantId',
    );
  } catch (error, stackTrace) {
    _logError(
      'GROUP OFFER CREATION FAILED',
      error,
      stackTrace,
    );

    rethrow;
  }
}

  /// ==========================================================================
  /// SEND GROUP ICE CANDIDATE
  /// ==========================================================================

  Future<void> _sendGroupIceCandidate(
    String participantId,
    RTCIceCandidate candidate,
  ) async {
    final callId = _groupCallId;
    final user = _auth.currentUser;

    if (callId == null ||
        callId.isEmpty ||
        user == null) {
      return;
    }

    final value = candidate.candidate;

    if (value == null ||
        value.isEmpty) {
      return;
    }

    try {
      final peerRef = _firestore
          .collection('calls')
          .doc(callId)
          .collection('peers')
          .doc(participantId);

      await peerRef
          .collection('callerCandidates')
          .add(
        <String, dynamic>{
          'candidate': value,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex':
              candidate.sdpMLineIndex,
          'senderId': user.uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      _log(
        'GROUP ICE UPLOADED | '
        'participant=$participantId',
      );
    } catch (error, stackTrace) {
      _logError(
        'GROUP ICE UPLOAD FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// ICE SERVERS
  /// ==========================================================================

  List<Map<String, dynamic>>
      _buildIceServers() {
    final servers =
        <Map<String, dynamic>>[
      <String, dynamic>{
        'urls': <String>[
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ];

    final turn =
        turnConfig;

    if (turn != null &&
        turn.urls.isNotEmpty &&
        turn.username.isNotEmpty &&
        turn.credential.isNotEmpty) {
      servers.add(
        turn.toIceServer(),
      );

      _log(
        'TURN CONFIGURED | '
        '${turn.urls}',
      );
    } else {
      _log(
        '⚠️ NO TURN SERVER CONFIGURED',
      );
    }

    return servers;
  }

  /// ==========================================================================
  /// CONFIGURE TURN
  /// ==========================================================================

  void configureTurn({
    required String username,
    required String credential,
    required List<String> urls,
  }) {
    final cleanUrls =
        urls
            .map(
              (String value) =>
                  value.trim(),
            )
            .where(
              (String value) =>
                  value.isNotEmpty,
            )
            .toList();

    if (username.trim().isEmpty ||
        credential.trim().isEmpty ||
        cleanUrls.isEmpty) {
      throw ArgumentError(
        'Valid TURN username, credential and URL are required.',
      );
    }

    turnConfig =
        ChattaxTurnConfig(
      username:
          username.trim(),
      credential:
          credential.trim(),
      urls:
          cleanUrls,
    );

    _log(
      'TURN CONFIGURATION UPDATED',
    );
  }

  /// ==========================================================================
  /// LOCAL MEDIA
  /// ==========================================================================

  Future<void> _createLocalStream(
    ChattaxCallType type,
  ) async {
    final constraints =
        <String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'channelCount': 1,
      },
      'video':
          type == ChattaxCallType.video
              ? <String, dynamic>{
                  'facingMode': 'user',
                  'width': <String, dynamic>{
                    'ideal': 1280,
                  },
                  'height': <String, dynamic>{
                    'ideal': 720,
                  },
                  'frameRate': <String, dynamic>{
                    'ideal': 30,
                  },
                }
              : false,
    };

    _log(
      'MEDIA: requesting getUserMedia',
    );

    final stream =
        await navigator.mediaDevices
            .getUserMedia(
      constraints,
    );

    _localStream =
        stream;

    final audioTracks =
        stream.getAudioTracks();

    final videoTracks =
        stream.getVideoTracks();

    _log(
      'MEDIA CREATED | '
      'audio=${audioTracks.length} '
      'video=${videoTracks.length}',
    );

    if (audioTracks.isEmpty) {
      throw Exception(
        'Microphone track was not created.',
      );
    }

    for (final track
        in stream.getTracks()) {
      track.enabled =
          true;

      final pc =
          _peerConnection;

      if (pc == null) {
        throw Exception(
          'PeerConnection unavailable.',
        );
      }

      await pc.addTrack(
        track,
        stream,
      );
    }

    _microphoneMuted =
        false;

    _cameraEnabled =
        type == ChattaxCallType.video;

    if (!_localStreamController.isClosed &&
        !_isDisposed) {
      _localStreamController.add(
        stream,
      );
    }

    /// Speaker ON by default for voice calls.
    await setSpeaker(
      true,
    );
  }

  /// ==========================================================================
  /// REMOTE STREAM
  /// ==========================================================================

  void _setRemoteStream(
    MediaStream stream,
  ) {
    if (_isDisposed) {
      return;
    }

    _remoteStream =
        stream;

    _log(
      'REMOTE STREAM SET | '
      'audio=${stream.getAudioTracks().length} '
      'video=${stream.getVideoTracks().length}',
    );

    if (!_remoteStreamController.isClosed) {
      _remoteStreamController.add(
        stream,
      );
    }
  }

  /// ==========================================================================
  /// LOCAL ICE
  /// ==========================================================================

  Future<void> _handleLocalIceCandidate(
    RTCIceCandidate candidate,
  ) async {
    final value =
        candidate.candidate;

    if (value == null ||
        value.isEmpty) {
      return;
    }

    final key =
        '$value|'
        '${candidate.sdpMid}|'
        '${candidate.sdpMLineIndex}';

    if (_sentLocalCandidateKeys
        .contains(key)) {
      return;
    }

    _sentLocalCandidateKeys.add(
      key,
    );

    if (!_signalingReady) {
      _pendingLocalCandidates.add(
        candidate,
      );

      _log(
        'LOCAL ICE QUEUED | signaling not ready',
      );

      return;
    }

    await _sendIceCandidate(
      candidate,
    );
  }

  Future<void> _sendIceCandidate(
    RTCIceCandidate candidate,
  ) async {
    final callId =
        _activeCallId;

    if (callId == null) {
      return;
    }

    final collection =
        _isCaller
            ? 'callerCandidates'
            : 'receiverCandidates';

    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection(collection)
          .add(
        <String, dynamic>{
          'candidate':
              candidate.candidate,
          'sdpMid':
              candidate.sdpMid,
          'sdpMLineIndex':
              candidate.sdpMLineIndex,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      _log(
        'ICE UPLOADED | $collection',
      );
    } catch (error, stackTrace) {
      _logError(
        'ICE UPLOAD FAILED',
        error,
        stackTrace,
      );
    }
  }

  Future<void>
      _flushPendingLocalCandidates() async {
    if (!_signalingReady) {
      return;
    }

    final candidates =
        List<RTCIceCandidate>.from(
      _pendingLocalCandidates,
    );

    _pendingLocalCandidates.clear();

    for (final candidate
        in candidates) {
      await _sendIceCandidate(
        candidate,
      );
    }
  }

  /// ==========================================================================
  /// CALLER ICE
  /// ==========================================================================

  void _listenForCallerCandidates(
    String callId,
  ) {
    unawaited(
      _callerCandidatesSubscription?.cancel(),
    );

    _receivedRemoteCandidateIds.clear();

    _callerCandidatesSubscription =
        _firestore
            .collection('calls')
            .doc(callId)
            .collection('callerCandidates')
            .snapshots()
            .listen(
      (snapshot) {
        for (final doc
            in snapshot.docs) {
          if (_receivedRemoteCandidateIds
              .contains(doc.id)) {
            continue;
          }

          _receivedRemoteCandidateIds.add(
            doc.id,
          );

          unawaited(
            _handleRemoteIceCandidate(
              doc.data(),
            ),
          );
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'CALLER ICE LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );
  }

  /// ==========================================================================
  /// RECEIVER ICE
  /// ==========================================================================

  void _listenForReceiverCandidates(
    String callId,
  ) {
    unawaited(
      _receiverCandidatesSubscription?.cancel(),
    );

    _receivedRemoteCandidateIds.clear();

    _receiverCandidatesSubscription =
        _firestore
            .collection('calls')
            .doc(callId)
            .collection('receiverCandidates')
            .snapshots()
            .listen(
      (snapshot) {
        for (final doc
            in snapshot.docs) {
          if (_receivedRemoteCandidateIds
              .contains(doc.id)) {
            continue;
          }

          _receivedRemoteCandidateIds.add(
            doc.id,
          );

          unawaited(
            _handleRemoteIceCandidate(
              doc.data(),
            ),
          );
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'RECEIVER ICE LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );
  }

  /// ==========================================================================
  /// REMOTE ICE
  /// ==========================================================================

  Future<void> _handleRemoteIceCandidate(
    Map<String, dynamic> data,
  ) async {
    final candidateString =
        data['candidate']?.toString();

    if (candidateString == null ||
        candidateString.isEmpty) {
      return;
    }

    int? sdpMLineIndex;

    final rawIndex =
        data['sdpMLineIndex'];

    if (rawIndex is int) {
      sdpMLineIndex =
          rawIndex;
    } else {
      sdpMLineIndex =
          int.tryParse(
        rawIndex?.toString() ?? '',
      );
    }

    final candidate =
        RTCIceCandidate(
      candidateString,
      data['sdpMid']?.toString(),
      sdpMLineIndex,
    );

    final pc =
        _peerConnection;

    if (pc == null ||
        !_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(
        candidate,
      );

      _log(
        'REMOTE ICE QUEUED',
      );

      return;
    }

    try {
      await pc.addCandidate(
        candidate,
      );

      _log(
        'REMOTE ICE ADDED',
      );
    } catch (error, stackTrace) {
      _logError(
        'REMOTE ICE ADD FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// FLUSH REMOTE ICE
  /// ==========================================================================

  Future<void>
      _flushPendingRemoteCandidates() async {
    if (!_remoteDescriptionSet) {
      return;
    }

    final pc =
        _peerConnection;

    if (pc == null) {
      return;
    }

    final candidates =
        List<RTCIceCandidate>.from(
      _pendingRemoteCandidates,
    );

    _pendingRemoteCandidates.clear();

    for (final candidate
        in candidates) {
      try {
        await pc.addCandidate(
          candidate,
        );

        _log(
          'QUEUED REMOTE ICE ADDED',
        );
      } catch (error, stackTrace) {
        _logError(
          'QUEUED REMOTE ICE ADD FAILED',
          error,
          stackTrace,
        );
      }
    }
  }

  /// ==========================================================================
  /// CALL DOCUMENT LISTENER
  /// ==========================================================================

  void _listenToCallDocument(
    String callId,
  ) {
    unawaited(
      _callSubscription?.cancel(),
    );

    _callSubscription =
        _firestore
            .collection('calls')
            .doc(callId)
            .snapshots()
            .listen(
      (snapshot) {
        if (!snapshot.exists) {
          return;
        }

        final data =
            snapshot.data();

        if (data == null) {
          return;
        }

        final status =
            (data['status'] ?? '')
                .toString()
                .toLowerCase();

        _log(
          'CALL DOCUMENT STATUS = $status',
        );

        switch (status) {
          case 'calling':
            _emitStatus(
              ChattaxCallStatus.calling,
              callId: callId,
            );

            return;

          case 'ringing':
            _emitStatus(
              ChattaxCallStatus.ringing,
              callId: callId,
            );

            return;

          case 'connecting':
            _emitStatus(
              ChattaxCallStatus.connecting,
              callId: callId,
            );

            break;

          case 'connected':
            unawaited(
              _markConnected(),
            );

            return;

          case 'rejected':
            _cancelOutgoingCallTimer();
            _cancelConnectionTimer();

            _emitStatus(
              ChattaxCallStatus.rejected,
              callId: callId,
            );

            unawaited(
              _cleanupCall(),
            );

            return;

          case 'ended':
            _cancelOutgoingCallTimer();
            _cancelConnectionTimer();

            _emitStatus(
              ChattaxCallStatus.ended,
              callId: callId,
            );

            unawaited(
              _cleanupCall(),
            );

            return;

          case 'failed':
            _cancelOutgoingCallTimer();
            _cancelConnectionTimer();

            _emitStatus(
              ChattaxCallStatus.failed,
              callId: callId,
            );

            unawaited(
              _cleanupCall(),
            );

            return;
        }

        /// Only caller processes answer.
        if (!_isCaller) {
          return;
        }

        final answer =
            data['answer'];

        if (answer is! Map) {
          return;
        }

        if (_answerApplied ||
            _answerApplying) {
          return;
        }

        final pc =
            _peerConnection;

        if (pc == null) {
          return;
        }

        final answerSdp =
            answer['sdp']?.toString();

        if (answerSdp == null ||
            answerSdp.isEmpty) {
          return;
        }

        final remoteAnswer =
            RTCSessionDescription(
          answerSdp,
          answer['type']?.toString() ??
              'answer',
        );

        unawaited(
          _applyRemoteAnswer(
            pc,
            remoteAnswer,
          ),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'CALL DOCUMENT LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );
  }

  /// ==========================================================================
  /// APPLY REMOTE OFFER
  /// ==========================================================================

  Future<void> _applyRemoteOffer(
    Map<String, dynamic> data,
  ) async {
    final pc =
        _peerConnection;

    if (pc == null) {
      throw Exception(
        'PeerConnection unavailable.',
      );
    }

    final offer =
        data['offer'];

    if (offer is! Map) {
      throw Exception(
        'Caller offer missing.',
      );
    }

    final sdp =
        offer['sdp']?.toString();

    if (sdp == null ||
        sdp.isEmpty) {
      throw Exception(
        'Caller offer SDP missing.',
      );
    }

    final description =
        RTCSessionDescription(
      sdp,
      offer['type']?.toString() ??
          'offer',
    );

    _log(
      'RECEIVER: applying remote offer',
    );

    await pc.setRemoteDescription(
      description,
    );

    _remoteDescriptionSet =
        true;

    _log(
      'RECEIVER: remote offer applied',
    );

    await _flushPendingRemoteCandidates();
  }

  /// ==========================================================================
  /// APPLY REMOTE ANSWER
  /// ==========================================================================

  Future<void> _applyRemoteAnswer(
    RTCPeerConnection pc,
    RTCSessionDescription answer,
  ) async {
    if (_answerApplied ||
        _answerApplying) {
      return;
    }

    _answerApplying =
        true;

    try {
      final current =
          await pc.getRemoteDescription();

      if (current != null) {
        _answerApplied =
            true;

        _remoteDescriptionSet =
            true;

        await _flushPendingRemoteCandidates();

        return;
      }

      _log(
        'CALLER: applying remote answer',
      );

      await pc.setRemoteDescription(
        answer,
      );

      _answerApplied =
          true;

      _remoteDescriptionSet =
          true;

      _log(
        'CALLER: remote answer applied',
      );

      await _flushPendingRemoteCandidates();
    } catch (error, stackTrace) {
      _logError(
        'APPLY REMOTE ANSWER FAILED',
        error,
        stackTrace,
      );

      unawaited(
        _handleConnectionFailure(),
      );
    } finally {
      _answerApplying =
          false;
    }
  }

  /// ==========================================================================
  /// CONNECTED
  /// ==========================================================================

  Future<void> _markConnected() async {
    final callId =
        _activeCallId;

    if (callId == null ||
        _connectedReported ||
        _endingCall) {
      return;
    }

    _connectedReported =
        true;

    _cancelOutgoingCallTimer();

    _cancelConnectionTimer();

    _cancelDisconnectTimer();

    _log(
      '==================================================',
    );

    _log(
      '🎉 CHATTªX WEBRTC CONNECTED',
    );

    _log(
      'callId=$callId',
    );

    _log(
      'role=${_isCaller ? 'CALLER' : 'RECEIVER'}',
    );

    _log(
      '==================================================',
    );

    /// Ensure speaker is enabled after connection.
    try {
      await Helper.setSpeakerphoneOn(
        _speakerEnabled,
      );
    } catch (_) {}

    _emitStatus(
      ChattaxCallStatus.connected,
      callId: callId,
    );

    try {
      final callRef =
          _firestore
              .collection('calls')
              .doc(callId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            callRef,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final status =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (status == 'ended' ||
              status == 'rejected' ||
              status == 'failed') {
            return;
          }

          transaction.update(
            callRef,
            <String, dynamic>{
              'status': 'connected',
              'connectedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'CONNECTED STATUS WRITE FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// CONNECTION FAILURE
  /// ==========================================================================

  Future<void> _handleConnectionFailure() async {
    if (_failureHandling ||
        _connectedReported) {
      return;
    }

    _failureHandling =
        true;

    try {
      final callId =
          _activeCallId;

      if (callId == null) {
        return;
      }

      _log(
        '❌ WEBRTC CONNECTION FAILED | $callId',
      );

      _cancelOutgoingCallTimer();

      _cancelConnectionTimer();

      _cancelDisconnectTimer();

      _emitStatus(
        ChattaxCallStatus.failed,
        callId: callId,
      );

      await _safeMarkCallFailed(
  callId,
);

try {
  await _updateCallHistoryMessage(
    callId: callId,
    callStatus: 'unanswered',
  );
} catch (e) {
  debugPrint(
    'CHATTªX call history failure update failed: $e',
  );
}

await _cleanupCall();
    } finally {
      _failureHandling =
          false;
    }
  }

  /// ==========================================================================
  /// CONNECTION TIMEOUT
  /// ==========================================================================

  void _startConnectionTimeout(
    String callId,
  ) {
    _cancelConnectionTimer();

    _connectionTimerStarted =
        true;

    _connectionTimer =
        Timer(
      connectionTimeout,
      () {
        if (_activeCallId != callId) {
          return;
        }

        if (_connectedReported) {
          return;
        }

        _log(
          '❌ WEBRTC CONNECTION TIMEOUT | $callId',
        );

        unawaited(
          _handleConnectionFailure(),
        );
      },
    );
  }

  void _cancelConnectionTimer() {
    _connectionTimer?.cancel();

    _connectionTimer =
        null;

    _connectionTimerStarted =
        false;
  }

  /// ==========================================================================
  /// DISCONNECT GRACE
  /// ==========================================================================

  void _startDisconnectGracePeriod() {
    if (_activeCallId == null ||
        _connectedReported == false) {
      return;
    }

    _cancelDisconnectTimer();

    _disconnectTimer =
        Timer(
      disconnectGracePeriod,
      () {
        if (_activeCallId == null) {
          return;
        }

        if (!_connectedReported) {
          return;
        }

        unawaited(
          _handleConnectionFailure(),
        );
      },
    );
  }

  void _cancelDisconnectTimer() {
    _disconnectTimer?.cancel();

    _disconnectTimer =
        null;
  }

  /// ==========================================================================
  /// OUTGOING CALL TIMEOUT
  /// ==========================================================================

  void _startOutgoingCallTimeout(
    String callId,
  ) {
    _cancelOutgoingCallTimer();

    _outgoingCallTimer =
        Timer(
      outgoingCallTimeout,
      () async {
        if (_activeCallId != callId) {
          return;
        }

        if (!_isCaller) {
          return;
        }

        if (_connectedReported) {
          return;
        }

        _log(
          'OUTGOING CALL TIMEOUT',
        );

        await _safeMarkCallEnded(
  callId,
);

try {
  await _updateCallHistoryMessage(
    callId: callId,
    callStatus: 'unanswered',
  );
} catch (e) {
  debugPrint(
    'CHATTªX unanswered call history update failed: $e',
  );
}

_emitStatus(
  ChattaxCallStatus.ended,
  callId: callId,
);

        await _cleanupCall();
      },
    );
  }

  void _cancelOutgoingCallTimer() {
    _outgoingCallTimer?.cancel();

    _outgoingCallTimer =
        null;
  }

  /// ==========================================================================
  /// MICROPHONE
  /// ==========================================================================

  Future<bool> toggleMicrophone() async {
    final muted =
        !_microphoneMuted;

    await setMicrophoneMuted(
      muted,
    );

    return !_microphoneMuted;
  }

  Future<void> setMicrophoneMuted(
    bool muted,
  ) async {
    final stream =
        _localStream;

    if (stream == null) {
      _microphoneMuted =
          muted;

      return;
    }

    for (final track
        in stream.getAudioTracks()) {
      track.enabled =
          !muted;
    }

    _microphoneMuted =
        muted;

    _log(
      'MICROPHONE '
      '${muted ? 'MUTED' : 'UNMUTED'}',
    );
  }

  /// ==========================================================================
  /// CAMERA
  /// ==========================================================================

  Future<bool> toggleCamera() async {
    final enabled =
        !_cameraEnabled;

    await setCameraEnabled(
      enabled,
    );

    return _cameraEnabled;
  }

  Future<void> setCameraEnabled(
    bool enabled,
  ) async {
    final stream =
        _localStream;

    if (stream == null) {
      _cameraEnabled =
          enabled;

      return;
    }

    for (final track
        in stream.getVideoTracks()) {
      track.enabled =
          enabled;
    }

    _cameraEnabled =
        enabled;
  }

  /// ==========================================================================
  /// SWITCH CAMERA
  /// ==========================================================================

  Future<void> switchCamera() async {
    final stream =
        _localStream;

    if (stream == null) {
      return;
    }

    final tracks =
        stream.getVideoTracks();

    if (tracks.isEmpty) {
      return;
    }

    try {
      await Helper.switchCamera(
        tracks.first,
      );

      _log(
        'CAMERA SWITCHED',
      );
    } catch (error, stackTrace) {
      _logError(
        'SWITCH CAMERA FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// SPEAKER
  /// ==========================================================================

  Future<void> setSpeaker(
    bool enabled,
  ) async {
    try {
      await Helper.setSpeakerphoneOn(
        enabled,
      );

      _speakerEnabled =
          enabled;

      _log(
        'SPEAKERPHONE '
        '${enabled ? 'ON' : 'OFF'}',
      );
    } catch (error, stackTrace) {
      _logError(
        'SPEAKER ROUTING FAILED',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> toggleSpeaker() async {
    final enabled =
        !_speakerEnabled;

    await setSpeaker(
      enabled,
    );

    return _speakerEnabled;
  }

  /// ==========================================================================
  /// PERMISSIONS
  /// ==========================================================================

  Future<void> _requestPermissions(
    ChattaxCallType type,
  ) async {
    final microphone =
        await Permission.microphone.request();

    if (!microphone.isGranted) {
      throw Exception(
        'Microphone permission is required for calls.',
      );
    }

    if (type ==
        ChattaxCallType.video) {
      final camera =
          await Permission.camera.request();

      if (!camera.isGranted) {
        throw Exception(
          'Camera permission is required for video calls.',
        );
      }
    }
  }

  /// ==========================================================================
  /// GET CALL
  /// ==========================================================================

  Future<ChattaxCall?> getCall(
    String callId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('calls')
              .doc(callId)
              .get();

      if (!snapshot.exists) {
        return null;
      }

      final data =
          snapshot.data();

      if (data == null) {
        return null;
      }

      return ChattaxCall.fromFirestore(
        snapshot.id,
        data,
      );
    } catch (error, stackTrace) {
      _logError(
        'GET CALL FAILED',
        error,
        stackTrace,
      );

      return null;
    }
  }

  /// ==========================================================================
  /// CHECK CALL
  /// ==========================================================================

  Future<bool> isCallStillActive(
    String callId,
  ) async {
    try {
      final call =
          await getCall(
        callId,
      );

      if (call == null) {
        return false;
      }

      return call.status ==
              ChattaxCallStatus.calling ||
          call.status ==
              ChattaxCallStatus.ringing ||
          call.status ==
              ChattaxCallStatus.connecting ||
          call.status ==
              ChattaxCallStatus.connected;
    } catch (_) {
      return false;
    }
  }

  /// ==========================================================================
  /// REJECT CALL
  /// ==========================================================================

  Future<void> rejectCall(
    String callId,
  ) async {
    final cleanCallId =
        callId.trim();

    if (cleanCallId.isEmpty) {
      return;
    }

    try {
      final callRef =
          _firestore
              .collection('calls')
              .doc(cleanCallId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            callRef,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final receiverId =
              (data['receiverId'] ?? '')
                  .toString();

          final currentUser =
              _auth.currentUser;

          if (currentUser == null ||
              receiverId !=
                  currentUser.uid) {
            return;
          }

          final status =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (status != 'ringing') {
            return;
          }

          transaction.update(
            callRef,
            <String, dynamic>{
              'status': 'rejected',
              'endedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _announcedIncomingCalls.remove(
        cleanCallId,
      );

      _emitStatus(
        ChattaxCallStatus.rejected,
        callId: cleanCallId,
      );

      if (_activeCallId ==
          cleanCallId) {
        await _cleanupCall();
      }
    } catch (error, stackTrace) {
      _logError(
        'REJECT CALL FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// END CALL
  /// ==========================================================================

  Future<void> endCall() async {
    await _finishCall(
      ChattaxCallStatus.ended,
    );
  }

  /// ==========================================================================
  /// CANCEL CALL
  /// ==========================================================================

  Future<void> cancelCall() async {
    await _finishCall(
      ChattaxCallStatus.ended,
    );
  }

  /// ==========================================================================
  /// CANCEL OUTGOING CALL
  /// ==========================================================================

  Future<void> cancelOutgoingCall() async {
    await cancelCall();
  }

  /// ==========================================================================
/// FINISH CALL
/// ==========================================================================

Future<void> _finishCall(
  ChattaxCallStatus finalStatus,
) async {
  if (_endingCall) {
    return;
  }

  _endingCall =
      true;

  try {
    final callId =
        _activeCallId;

    if (callId == null) {
      return;
    }

    _cancelOutgoingCallTimer();

    _cancelConnectionTimer();

    _cancelDisconnectTimer();

    // Remember whether the call actually connected
    // BEFORE cleanup clears the active call state.
    final bool wasConnected =
        _connectedReported;

    int callDuration = 0;

    if (wasConnected) {
      callDuration =
          await _getCallDuration(
        callId,
      );
    }

    // If the call connected, it is a real ended call.
    // If it never connected, it is an unanswered call.
    final String historyStatus =
        wasConnected
            ? 'ended'
            : 'unanswered';

    await _safeFinishCallDocument(
      callId,
      _statusToString(
        finalStatus,
      ),
    );

    try {
      await _updateCallHistoryMessage(
        callId: callId,
        callStatus: historyStatus,
        callDuration: callDuration,
      );
    } catch (e) {
      debugPrint(
        'CHATTªX call history finish update failed: $e',
      );
    }

    _emitStatus(
      finalStatus,
      callId: callId,
    );

    await _cleanupCall();
  } finally {
    _endingCall =
        false;
  }
}

  /// ==========================================================================
  /// SET CALL STATUS
  /// ==========================================================================

  Future<void> setCallStatus(
    ChattaxCallStatus status,
  ) async {
    final callId =
        _activeCallId;

    if (callId == null) {
      return;
    }

    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update(
        <String, dynamic>{
          'status':
              _statusToString(
            status,
          ),
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'SET CALL STATUS FAILED',
        error,
        stackTrace,
      );
    }

    _emitStatus(
      status,
      callId: callId,
    );
  }

  /// ==========================================================================
/// CLOSE CALL
/// ==========================================================================

Future<void> closeCall(
  String callId,
) async {
  final cleanCallId =
      callId.trim();

  if (cleanCallId.isEmpty) {
    return;
  }

  await _safeMarkCallEnded(
    cleanCallId,
  );

  await _cleanupCall();
}

  /// ==========================================================================
  /// STATUS STRING
  /// ==========================================================================

  String _statusToString(
    ChattaxCallStatus status,
  ) {
    switch (status) {
      case ChattaxCallStatus.calling:
        return 'calling';

      case ChattaxCallStatus.ringing:
        return 'ringing';

      case ChattaxCallStatus.connecting:
        return 'connecting';

      case ChattaxCallStatus.connected:
        return 'connected';

      case ChattaxCallStatus.rejected:
        return 'rejected';

      case ChattaxCallStatus.ended:
        return 'ended';

      case ChattaxCallStatus.failed:
        return 'failed';
    }
  }

  /// ==========================================================================
  /// STATUS EMITTER
  /// ==========================================================================

  void _emitStatus(
    ChattaxCallStatus status, {
    String? callId,
  }) {
    if (_isDisposed) {
      return;
    }

    final effectiveCallId =
        callId ?? _activeCallId;

    _log(
      'UI STATUS = $status'
      '${effectiveCallId == null ? '' : ' | $effectiveCallId'}',
    );

    if (!_callStatusController.isClosed) {
      _callStatusController.add(
        status,
      );
    }

    if (effectiveCallId != null &&
        !_callStatusEventController.isClosed) {
      _callStatusEventController.add(
        ChattaxCallStatusEvent(
          callId:
              effectiveCallId,
          status:
              status,
        ),
      );
    }
  }

  /// ==========================================================================
  /// SAFE FINISH CALL DOCUMENT
  /// ==========================================================================

  Future<void> _safeFinishCallDocument(
    String callId,
    String status,
  ) async {
    try {
      final ref =
          _firestore
              .collection('calls')
              .doc(callId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            ref,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final currentStatus =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (currentStatus ==
                  'ended' ||
              currentStatus ==
                  'rejected' ||
              currentStatus ==
                  'failed') {
            return;
          }

          transaction.update(
            ref,
            <String, dynamic>{
              'status': status,
              'endedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'FINISH CALL DOCUMENT FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// SAFE MARK ENDED
  /// ==========================================================================

  Future<void> _safeMarkCallEnded(
    String callId,
  ) async {
    try {
      final ref =
          _firestore
              .collection('calls')
              .doc(callId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            ref,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final status =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (status ==
                  'ended' ||
              status ==
                  'rejected' ||
              status ==
                  'failed') {
            return;
          }

          transaction.update(
            ref,
            <String, dynamic>{
              'status': 'ended',
              'endedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'MARK CALL ENDED FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// SAFE MARK FAILED
  /// ==========================================================================

  Future<void> _safeMarkCallFailed(
    String callId,
  ) async {
    try {
      final ref =
          _firestore
              .collection('calls')
              .doc(callId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            ref,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final status =
              (data['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (status ==
                  'ended' ||
              status ==
                  'rejected' ||
              status ==
                  'failed') {
            return;
          }

          transaction.update(
            ref,
            <String, dynamic>{
              'status': 'failed',
              'endedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'MARK CALL FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ==========================================================================
  /// PREPARE NEW CALL
  /// ==========================================================================

  Future<void> _prepareForNewCall() async {
    if (_activeCallId != null ||
        _peerConnection != null ||
        _localStream != null) {
      await _cleanupCall();
    }

    _resetCallState();
  }

  /// ==========================================================================
  /// RESET STATE
  /// ==========================================================================

  void _resetCallState() {
    _microphoneMuted =
        false;

    _cameraEnabled =
        true;

    _speakerEnabled =
        true;

    _remoteDescriptionSet =
        false;

    _answerApplied =
        false;

    _connectedReported =
        false;

    _signalingReady =
        false;

    _endingCall =
        false;

    _failureHandling =
        false;

    _answerApplying =
        false;

    _acceptInProgress =
        false;

    _connectionTimerStarted =
        false;

    _pendingLocalCandidates.clear();

    _pendingRemoteCandidates.clear();

    _receivedRemoteCandidateIds.clear();

    _sentLocalCandidateKeys.clear();
  }

  String _callHistoryChatId(String callerId, String receiverId) {
  final ids = [callerId, receiverId]..sort();
  return ids.join('_');
}

DocumentReference<Map<String, dynamic>> _callHistoryMessageRef({
  required String callId,
  required String callerId,
  required String receiverId,
}) {
  final chatId = _callHistoryChatId(callerId, receiverId);

  return _firestore
      .collection('chat_rooms')
      .doc(chatId)
      .collection('messages')
      .doc('call_$callId');
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

Future<void> _createCallHistoryMessage({
  required String callId,
  required String callerId,
  required String receiverId,
  required ChattaxCallType type,
}) async {
  final bool isVideo = type == ChattaxCallType.video;

  final ref = _callHistoryMessageRef(
    callId: callId,
    callerId: callerId,
    receiverId: receiverId,
  );

  await ref.set(
    {
      'senderId': callerId,
      'receiverId': receiverId,
      'message': isVideo ? '📹 Video call' : '📞 Voice call',
      'type': isVideo ? 'video_call' : 'voice_call',
      'callId': callId,
      'callStatus': 'outgoing',
      'callDuration': 0,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'delivered': true,
      'isFrozen': false,
      'isMelted': false,
      'reactions': {},
    },
    SetOptions(merge: true),
  );
}

Future<void> _updateCallHistoryMessage({
  required String callId,
  required String callStatus,
  int callDuration = 0,
}) async {
  final callSnap =
      await _firestore.collection('calls').doc(callId).get();

  if (!callSnap.exists) {
    return;
  }

  final data = callSnap.data();

  if (data == null) {
    return;
  }

  final callerId = (data['callerId'] ?? '').toString();
  final receiverId = (data['receiverId'] ?? '').toString();

  if (callerId.isEmpty || receiverId.isEmpty) {
    return;
  }

  final typeValue =
      (data['type'] ?? 'audio').toString();

  final bool isVideo = typeValue == 'video';

  final ref = _callHistoryMessageRef(
    callId: callId,
    callerId: callerId,
    receiverId: receiverId,
  );

  await ref.set(
    {
      'senderId': callerId,
      'receiverId': receiverId,
      'message': isVideo ? '📹 Video call' : '📞 Voice call',
      'type': isVideo ? 'video_call' : 'voice_call',
      'callId': callId,
      'callStatus': callStatus,
      'callDuration': callDuration < 0 ? 0 : callDuration,
      'delivered': true,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

Future<int> _getCallDuration(String callId) async {
  final snap =
      await _firestore.collection('calls').doc(callId).get();

  final data = snap.data();

  if (data == null) {
    return 0;
  }

  final connectedAt =
      _timestampToDate(data['connectedAt']);

  if (connectedAt == null) {
    return 0;
  }

  final seconds =
      DateTime.now().difference(connectedAt).inSeconds;

  return seconds < 0 ? 0 : seconds;
}

  /// ==========================================================================
  /// CLEANUP
  /// ==========================================================================

  Future<void> _cleanupCall() async {
    if (_cleanupInProgress) {
      return;
    }

    _cleanupInProgress =
        true;

    try {
      _cancelOutgoingCallTimer();

      _cancelConnectionTimer();

      _cancelDisconnectTimer();

      /// ----------------------------------------------------------------------
      /// FIRESTORE LISTENERS
      /// ----------------------------------------------------------------------

      await _callSubscription?.cancel();

      _callSubscription =
          null;

      await _callerCandidatesSubscription?.cancel();

      _callerCandidatesSubscription =
          null;

      await _receiverCandidatesSubscription?.cancel();

      _receiverCandidatesSubscription =
          null;

      /// ----------------------------------------------------------------------
      /// PEER CONNECTION
      /// ----------------------------------------------------------------------

      final pc =
          _peerConnection;

      _peerConnection =
          null;

      if (pc != null) {
        try {
          pc.onTrack =
              null;

          pc.onAddStream =
              null;

          pc.onIceCandidate =
              null;

          pc.onIceConnectionState =
              null;

          pc.onConnectionState =
              null;

          pc.onSignalingState =
              null;

          pc.onIceGatheringState =
              null;

          await pc.close();
        } catch (error) {
          _log(
            'PEER CLOSE ERROR | $error',
          );
        }
      }

      /// ----------------------------------------------------------------------
      /// LOCAL STREAM
      /// ----------------------------------------------------------------------

      final local =
          _localStream;

      _localStream =
          null;

      if (local != null) {
        for (final track
            in local.getTracks()) {
          try {
            await track.stop();
          } catch (_) {}
        }

        try {
          await local.dispose();
        } catch (_) {}
      }

      /// ----------------------------------------------------------------------
      /// REMOTE STREAM
      ///
      /// Do not stop remote tracks here if the plugin owns the remote
      /// receiver lifecycle. Clearing the reference is sufficient.
      /// ----------------------------------------------------------------------

      _remoteStream =
          null;

      /// ----------------------------------------------------------------------
      /// RESET
      /// ----------------------------------------------------------------------

      _pendingLocalCandidates.clear();

      _pendingRemoteCandidates.clear();

      _receivedRemoteCandidateIds.clear();

      _sentLocalCandidateKeys.clear();

      _remoteDescriptionSet =
          false;

      _answerApplied =
          false;

      _connectedReported =
          false;

      _signalingReady =
          false;

      _activeCallId =
          null;

      _activeCallType =
          null;

      _isCaller =
          false;

      _microphoneMuted =
          false;

      _cameraEnabled =
          true;

      _speakerEnabled =
          true;

      _connectionTimerStarted =
          false;

      /// ----------------------------------------------------------------------
      /// AUDIO ROUTING
      /// ----------------------------------------------------------------------

      try {
        await Helper.setSpeakerphoneOn(
          false,
        );
      } catch (_) {}

      /// ----------------------------------------------------------------------
      /// UI STREAM RESET
      /// ----------------------------------------------------------------------

      if (!_isDisposed) {
        if (!_localStreamController.isClosed) {
          _localStreamController.add(
            null,
          );
        }

        if (!_remoteStreamController.isClosed) {
          _remoteStreamController.add(
            null,
          );
        }
      }

      _log(
        'CALL CLEANUP COMPLETE',
      );
    } finally {
      _cleanupInProgress =
          false;
    }
  }

  /// ==========================================================================
  /// CALL CREATED TIME
  /// ==========================================================================

  DateTime? _getCallCreatedTime(
    Map<String, dynamic> data,
  ) {
    final created =
        data['createdAt'];

    if (created is Timestamp) {
      return created.toDate();
    }

    final clientCreated =
        data['clientCreatedAt'];

    if (clientCreated is Timestamp) {
      return clientCreated.toDate();
    }

    return null;
  }

  /// ==========================================================================
  /// DISPOSE
  /// ==========================================================================

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _log(
      'DISPOSING CHATTªX CALL SERVICE',
    );

    await _authSubscription?.cancel();

    _authSubscription =
        null;

    await _stopIncomingListener();

    await _cleanupCall();

    _isDisposed =
        true;

    await _incomingCallController.close();

    await _callStatusController.close();

    await _callStatusEventController.close();

    await _remoteStreamController.close();

    await _localStreamController.close();

    _announcedIncomingCalls.clear();

    _log(
      'CHATTªX CALL SERVICE DISPOSED',
    );
  }

  /// ==========================================================================
  /// LOGGING
  /// ==========================================================================

  void _log(
    String message,
  ) {
    debugPrint(
      '📞 [ChattªX CALL] $message',
    );
  }

  void _logError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '❌ [ChattªX CALL] $message',
    );

    debugPrint(
      '❌ ERROR: $error',
    );

    debugPrint(
      '❌ STACK TRACE:\n$stackTrace',
    );
  }

  String _candidateSummary(
    RTCIceCandidate candidate,
  ) {
    final value =
        candidate.candidate ?? '';

    if (value.length <= 120) {
      return value;
    }

    return value.substring(
      0,
      120,
    );
  }

  /// ==========================================================================
  /// SAFETY
  /// ==========================================================================

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'ChattªX Call Service has already been disposed.',
      );
    }
  }
}