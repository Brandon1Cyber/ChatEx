import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

/// ============================================================================
/// CHATTªX CALL SERVICE
/// ============================================================================
///
/// FIRESTORE
///
/// calls/{callId}
///   callerId
///   receiverId
///   type
///   status
///   createdAt
///   clientCreatedAt
///   answeredAt
///   connectedAt
///   endedAt
///   offer
///   answer
///
/// calls/{callId}/callerCandidates/{candidateId}
/// calls/{callId}/receiverCandidates/{candidateId}
///
/// IMPORTANT:
///
/// The service automatically watches FirebaseAuth.authStateChanges().
/// Once a user is authenticated, the incoming-call Firestore listener starts.
///
/// CALLER:
///   startCall()
///      ↓
///   create PeerConnection
///      ↓
///   create local media
///      ↓
///   create OFFER
///      ↓
///   setLocalDescription
///      ↓
///   create Firestore call
///      ↓
///   status = ringing
///      ↓
///   receiver detects call
///
/// RECEIVER:
///   incoming listener
///      ↓
///   IncomingVoiceCallScreen
///      ↓
///   acceptCall()
///      ↓
///   status = connecting
///      ↓
///   create PeerConnection
///      ↓
///   get local media
///      ↓
///   apply OFFER
///      ↓
///   create ANSWER
///      ↓
///   write ANSWER
///
/// CALLER:
///   receives ANSWER
///      ↓
///   setRemoteDescription
///      ↓
///   ICE connection
///      ↓
///   connected
///
/// Navigation is intentionally NOT performed inside this service.
/// The IncomingVoiceCallScreen must navigate to VoiceCallScreen after
/// acceptCall(callId) completes successfully.
///
/// ============================================================================

enum ChattaxCallType {
  audio,
  video,
}

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
/// CALL MODEL
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
    final typeValue =
        (data['type'] ?? 'audio').toString().toLowerCase();

    final statusValue =
        (data['status'] ?? 'calling').toString().toLowerCase();

    DateTime? createdAt;

    final timestamp = data['createdAt'];

    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    } else {
      final clientTimestamp = data['clientCreatedAt'];

      if (clientTimestamp is Timestamp) {
        createdAt = clientTimestamp.toDate();
      }
    }

    return ChattaxCall(
      callId: callId,
      callerId: (data['callerId'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      type: typeValue == 'video'
          ? ChattaxCallType.video
          : ChattaxCallType.audio,
      status: _statusFromString(statusValue),
      createdAt: createdAt,
    );
  }

  static ChattaxCallStatus _statusFromString(String value) {
    switch (value) {
      case 'calling':
        return ChattaxCallStatus.calling;

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
/// CALL SERVICE
/// ============================================================================

class ChattaxCallService {
  ChattaxCallService._() {
    _startAuthListener();
  }

  static final ChattaxCallService instance =
      ChattaxCallService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final Uuid _uuid =
      const Uuid();

  /// Optional TURN configuration.
  ChattaxTurnConfig? turnConfig;

  /// Outgoing call timeout.
  static const Duration outgoingCallTimeout =
      Duration(seconds: 45);

  /// Incoming calls older than this are automatically expired.
  static const Duration incomingCallMaxAge =
      Duration(seconds: 60);

  /// Temporary WebRTC disconnect tolerance.
  static const Duration disconnectGracePeriod =
      Duration(seconds: 12);

  /// ========================================================================
  /// WEBRTC STATE
  /// ========================================================================

  RTCPeerConnection? _peerConnection;

  MediaStream? _localStream;

  MediaStream? _remoteStream;

  /// ========================================================================
  /// ACTIVE CALL
  /// ========================================================================

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

  /// ========================================================================
  /// TIMERS
  /// ========================================================================

  Timer? _outgoingCallTimer;

  Timer? _disconnectTimer;

  /// ========================================================================
  /// AUTH LISTENER
  /// ========================================================================

  StreamSubscription<User?>? _authSubscription;

  /// ========================================================================
  /// INCOMING CALL STATE
  /// ========================================================================

  final Set<String> _announcedIncomingCalls =
      <String>{};

  bool _incomingListenerStarted = false;

  String? _incomingListenerUid;

  /// ========================================================================
  /// ICE STATE
  /// ========================================================================

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

  /// ========================================================================
  /// FIRESTORE LISTENERS
  /// ========================================================================

  StreamSubscription<
          DocumentSnapshot<Map<String, dynamic>>>?
      _callSubscription;

  StreamSubscription<
          QuerySnapshot<Map<String, dynamic>>>?
      _callerCandidatesSubscription;

  StreamSubscription<
          QuerySnapshot<Map<String, dynamic>>>?
      _receiverCandidatesSubscription;

  StreamSubscription<
          QuerySnapshot<Map<String, dynamic>>>?
      _incomingCallsSubscription;

  /// ========================================================================
  /// STREAM CONTROLLERS
  /// ========================================================================

  final StreamController<ChattaxCall>
      _incomingCallController =
      StreamController<ChattaxCall>.broadcast();

  final StreamController<ChattaxCallStatus>
      _callStatusController =
      StreamController<ChattaxCallStatus>.broadcast();

  final StreamController<MediaStream?>
      _remoteStreamController =
      StreamController<MediaStream?>.broadcast();

  final StreamController<MediaStream?>
      _localStreamController =
      StreamController<MediaStream?>.broadcast();

  /// ========================================================================
  /// PUBLIC STREAMS
  /// ========================================================================

  Stream<ChattaxCall> get incomingCalls {
    _ensureIncomingListener();

    return _incomingCallController.stream;
  }

  Stream<ChattaxCallStatus> get callStatusStream =>
      _callStatusController.stream;

  Stream<ChattaxCallStatus> get callStatus =>
      _callStatusController.stream;

  Stream<MediaStream?> get remoteStream =>
      _remoteStreamController.stream;

  Stream<MediaStream?> get localStream =>
      _localStreamController.stream;

  /// ========================================================================
  /// PUBLIC STATE
  /// ========================================================================

  String? get callId =>
      _activeCallId;

  String? get activeCallId =>
      _activeCallId;

  ChattaxCallType? get activeCallType =>
      _activeCallType;

  MediaStream? get currentLocalStream =>
      _localStream;

  MediaStream? get currentRemoteStream =>
      _remoteStream;

  bool get isMicrophoneMuted =>
      _microphoneMuted;

  bool get isCameraEnabled =>
      _cameraEnabled;

  bool get isSpeakerEnabled =>
      _speakerEnabled;

  bool get isCaller =>
      _isCaller;

  bool get hasActiveCall =>
      _activeCallId != null;

  String? get currentUserId =>
      _auth.currentUser?.uid;

  /// ========================================================================
  /// AUTHENTICATION LISTENER
  /// ========================================================================

  void _startAuthListener() {
    _authSubscription =
        _auth.authStateChanges().listen(
      (User? user) {
        if (_isDisposed) {
          return;
        }

        if (user == null) {
          _log(
            'AUTH: user signed out',
          );

          unawaited(
            _stopIncomingListener(),
          );

          return;
        }

        _log(
          'AUTH: user authenticated UID=${user.uid}',
        );

        unawaited(
          initializeIncomingCallListener(),
        );
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'AUTH STATE LISTENER ERROR',
          error,
          stackTrace,
        );
      },
    );

    final existingUser =
        _auth.currentUser;

    if (existingUser != null) {
      unawaited(
        initializeIncomingCallListener(),
      );
    }
  }

  /// ========================================================================
  /// PUBLIC INITIALIZATION
  /// ========================================================================

  Future<void>
      initializeIncomingCallListener() async {
    _ensureNotDisposed();

    final uid =
        currentUserId;

    if (uid == null) {
      _log(
        'INCOMING INIT: no authenticated user.',
      );

      return;
    }

    _log(
      'INCOMING INIT: UID=$uid',
    );

    await _startIncomingListener(
      uid,
    );
  }

  /// ========================================================================
  /// START AUDIO CALL
  /// ========================================================================

  Future<ChattaxCall?> startAudioCall(
    String receiverId,
  ) {
    return startCall(
      receiverId: receiverId,
      type: ChattaxCallType.audio,
    );
  }

  /// ========================================================================
  /// START VIDEO CALL
  /// ========================================================================

  Future<ChattaxCall?> startVideoCall(
    String receiverId,
  ) {
    return startCall(
      receiverId: receiverId,
      type: ChattaxCallType.video,
    );
  }

  /// ========================================================================
  /// START CALL
  /// ========================================================================

  Future<ChattaxCall?> startCall({
    required String receiverId,
    required ChattaxCallType type,
  }) async {
    _ensureNotDisposed();

    final callerId =
        currentUserId;

    _log(
      '==================================================',
    );

    _log(
      'START CALL',
    );

    _log(
      'caller=$callerId',
    );

    _log(
      'receiver=$receiverId',
    );

    _log(
      'type=$type',
    );

    _log(
      '==================================================',
    );

    if (callerId == null) {
      throw Exception(
        'You must be signed in to make a call.',
      );
    }

    final cleanedReceiverId =
        receiverId.trim();

    if (cleanedReceiverId.isEmpty) {
      throw Exception(
        'Receiver ID cannot be empty.',
      );
    }

    if (callerId == cleanedReceiverId) {
      throw Exception(
        'You cannot call yourself.',
      );
    }

    if (hasActiveCall) {
      throw Exception(
        'You are already in a call.',
      );
    }

    await _requestPermissions(
      type,
    );

    await _prepareForNewCall();

    final newCallId =
        _uuid.v4();

    _activeCallId =
        newCallId;

    _activeCallType =
        type;

    _isCaller =
        true;

    final callRef =
        _firestore
            .collection('calls')
            .doc(newCallId);

    try {
      /// --------------------------------------------------------------------
      /// PEER CONNECTION
      /// --------------------------------------------------------------------

      _log(
        'CALLER: creating PeerConnection...',
      );

      await _createPeerConnection();

      /// --------------------------------------------------------------------
      /// LOCAL MEDIA
      /// --------------------------------------------------------------------

      _log(
        'CALLER: creating local media...',
      );

      await _createLocalStream(
        type,
      );

      final peerConnection =
          _peerConnection;

      if (peerConnection == null) {
        throw Exception(
          'Unable to create peer connection.',
        );
      }

      /// --------------------------------------------------------------------
      /// OFFER
      /// --------------------------------------------------------------------

      _log(
        'CALLER: creating OFFER...',
      );

      final offer =
          await peerConnection.createOffer(
        <String, dynamic>{
          'offerToReceiveAudio': true,
          'offerToReceiveVideo':
              type == ChattaxCallType.video,
        },
      );

      _log(
        'CALLER: OFFER CREATED '
        'type=${offer.type} '
        'sdpLength=${offer.sdp?.length ?? 0}',
      );

      await peerConnection.setLocalDescription(
        offer,
      );

      _log(
        'CALLER: LOCAL OFFER SET',
      );

      /// --------------------------------------------------------------------
      /// FIRESTORE CALL
      /// --------------------------------------------------------------------

      final now =
          Timestamp.now();

      await callRef.set(
        <String, dynamic>{
          'callerId':
              callerId,
          'receiverId':
              cleanedReceiverId,
          'type':
              type == ChattaxCallType.video
                  ? 'video'
                  : 'audio',
          'status':
              'ringing',
          'createdAt':
              FieldValue.serverTimestamp(),
          'clientCreatedAt':
              now,
          'offer':
              <String, dynamic>{
            'type':
                offer.type,
            'sdp':
                offer.sdp,
          },
        },
      );

      _log(
        'CALLER: FIRESTORE CALL CREATED',
      );

      _log(
        'CALLER: callId=$newCallId',
      );

      /// Signaling is now ready because the call document exists.
      _signalingReady =
          true;

      await _flushPendingLocalCandidates();

      /// --------------------------------------------------------------------
      /// LISTEN FOR CALL DOCUMENT
      /// --------------------------------------------------------------------

      _listenToCallDocument(
        newCallId,
      );

      /// --------------------------------------------------------------------
      /// LISTEN FOR RECEIVER ICE
      /// --------------------------------------------------------------------

      _listenForReceiverCandidates(
        newCallId,
      );

      /// --------------------------------------------------------------------
      /// TIMEOUT
      /// --------------------------------------------------------------------

      _startOutgoingCallTimeout(
        newCallId,
      );

      _emitStatus(
        ChattaxCallStatus.ringing,
      );

      _log(
        '==================================================',
      );

      _log(
        '📞 CALL IS NOW RINGING',
      );

      _log(
        'callId=$newCallId',
      );

      _log(
        'receiver=$cleanedReceiverId',
      );

      _log(
        '==================================================',
      );

      return ChattaxCall(
        callId:
            newCallId,
        callerId:
            callerId,
        receiverId:
            cleanedReceiverId,
        type:
            type,
        status:
            ChattaxCallStatus.ringing,
        createdAt:
            now.toDate(),
      );
    } catch (error, stackTrace) {
      _logError(
        'START CALL FAILED',
        error,
        stackTrace,
      );

      await _safeMarkCallFailed(
        newCallId,
      );

      await _cleanupCall();

      rethrow;
    }
  }

  /// ========================================================================
  /// PREPARE NEW CALL
  /// ========================================================================

  Future<void> _prepareForNewCall() async {
    if (_activeCallId != null ||
        _peerConnection != null ||
        _localStream != null) {
      _log(
        'Preparing for new call: cleaning old state.',
      );

      await _cleanupCall();
    }

    _resetCallState();
  }

  /// ========================================================================
  /// INCOMING CALL LISTENER
  /// ========================================================================

  void _ensureIncomingListener() {
    if (_isDisposed) {
      return;
    }

    final uid =
        currentUserId;

    if (uid == null) {
      _log(
        'INCOMING: waiting for authentication.',
      );

      return;
    }

    if (_incomingListenerStarted &&
        _incomingListenerUid == uid &&
        _incomingCallsSubscription != null) {
      return;
    }

    unawaited(
      _startIncomingListener(
        uid,
      ),
    );
  }

  Future<void> _startIncomingListener(
    String uid,
  ) async {
    if (_isDisposed) {
      return;
    }

    if (_incomingListenerStarted &&
        _incomingListenerUid == uid &&
        _incomingCallsSubscription != null) {
      _log(
        'INCOMING: listener already active.',
      );

      return;
    }

    await _incomingCallsSubscription?.cancel();

    _incomingCallsSubscription =
        null;

    _incomingListenerStarted =
        true;

    _incomingListenerUid =
        uid;

    _log(
      '==================================================',
    );

    _log(
      '📲 INCOMING CALL LISTENER ACTIVE',
    );

    _log(
      'UID=$uid',
    );

    _log(
      '==================================================',
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
              isEqualTo: 'ringing',
            )
            .snapshots()
            .listen(
      (snapshot) {
        _log(
          'INCOMING: Firestore snapshot '
          '${snapshot.docs.length} ringing call(s)',
        );

        for (final doc in snapshot.docs) {
          unawaited(
            _processIncomingCallDocument(
              doc,
              uid,
            ),
          );
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        _logError(
          'INCOMING LISTENER ERROR',
          error,
          stackTrace,
        );

        _incomingListenerStarted =
            false;

        _incomingListenerUid =
            null;

        _incomingCallsSubscription =
            null;
      },
    );
  }

  Future<void> _stopIncomingListener() async {
    await _incomingCallsSubscription?.cancel();

    _incomingCallsSubscription =
        null;

    _incomingListenerStarted =
        false;

    _incomingListenerUid =
        null;

    _announcedIncomingCalls.clear();

    _log(
      'INCOMING: listener stopped.',
    );
  }

  /// ========================================================================
  /// PROCESS INCOMING CALL
  /// ========================================================================

  Future<void> _processIncomingCallDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) async {
    try {
      final data =
          doc.data();

      final callerId =
          (data['callerId'] ?? '').toString();

      final receiverId =
          (data['receiverId'] ?? '').toString();

      final status =
          (data['status'] ?? '')
              .toString()
              .toLowerCase();

      _log(
        'INCOMING CHECK | '
        'id=${doc.id} '
        'caller=$callerId '
        'receiver=$receiverId '
        'status=$status',
      );

      if (receiverId != uid) {
        return;
      }

      if (callerId.isEmpty) {
        _log(
          'INCOMING IGNORE: empty caller ID',
        );

        return;
      }

      if (callerId == uid) {
        _log(
          'INCOMING IGNORE: caller is current user',
        );

        return;
      }

      if (status != 'ringing') {
        return;
      }

      /// --------------------------------------------------------------------
      /// VALIDATE OFFER
      /// --------------------------------------------------------------------

      final offer =
          data['offer'];

      if (offer is! Map) {
        _log(
          'INCOMING IGNORE: no WebRTC offer.',
        );

        return;
      }

      final offerSdp =
          offer['sdp']?.toString();

      if (offerSdp == null ||
          offerSdp.isEmpty) {
        _log(
          'INCOMING IGNORE: offer SDP empty.',
        );

        return;
      }

      /// --------------------------------------------------------------------
      /// STALE CALL
      /// --------------------------------------------------------------------

      final createdTime =
          _getCallCreatedTime(
        data,
      );

      if (createdTime == null) {
        _log(
          'INCOMING IGNORE: no creation timestamp.',
        );

        return;
      }

      final age =
          DateTime.now().difference(
        createdTime,
      );

      if (age.isNegative &&
          age.abs() >
              const Duration(seconds: 10)) {
        _log(
          'INCOMING IGNORE: future timestamp.',
        );

        return;
      }

      if (age >
          incomingCallMaxAge) {
        _log(
          'INCOMING: stale call ${doc.id}',
        );

        await _safeUpdateCallStatus(
          doc.reference,
          'ended',
          includeEndedAt: true,
        );

        _announcedIncomingCalls.remove(
          doc.id,
        );

        return;
      }

      /// --------------------------------------------------------------------
      /// ACTIVE CALL
      /// --------------------------------------------------------------------

      if (hasActiveCall) {
        _log(
          'INCOMING IGNORE: already active '
          'call=$_activeCallId',
        );

        return;
      }

      /// --------------------------------------------------------------------
      /// DUPLICATE PROTECTION
      /// --------------------------------------------------------------------

      if (_announcedIncomingCalls.contains(
        doc.id,
      )) {
        return;
      }

      _announcedIncomingCalls.add(
        doc.id,
      );

      final call =
          ChattaxCall.fromFirestore(
        doc.id,
        data,
      );

      _log(
        '==================================================',
      );

      _log(
        '📲 REAL INCOMING CALL',
      );

      _log(
        'callId=${call.callId}',
      );

      _log(
        'caller=${call.callerId}',
      );

      _log(
        'receiver=${call.receiverId}',
      );

      _log(
        'type=${call.type}',
      );

      _log(
        '==================================================',
      );

      if (!_incomingCallController.isClosed) {
        _incomingCallController.add(
          call,
        );
      }
    } catch (error, stackTrace) {
      _logError(
        'PROCESS INCOMING CALL FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ========================================================================
  /// CALL CREATION TIME
  /// ========================================================================

  DateTime? _getCallCreatedTime(
    Map<String, dynamic> data,
  ) {
    final clientCreatedAt =
        data['clientCreatedAt'];

    if (clientCreatedAt is Timestamp) {
      return clientCreatedAt.toDate();
    }

    final serverCreatedAt =
        data['createdAt'];

    if (serverCreatedAt is Timestamp) {
      return serverCreatedAt.toDate();
    }

    return null;
  }

  /// ========================================================================
  /// PUBLIC INCOMING LISTENER
  /// ========================================================================

  StreamSubscription<
          QuerySnapshot<Map<String, dynamic>>>
      listenForIncomingCalls() {
    _ensureNotDisposed();

    _ensureIncomingListener();

    final subscription =
        _incomingCallsSubscription;

    if (subscription == null) {
      throw Exception(
        'Incoming call listener is not ready yet.',
      );
    }

    return subscription;
  }

  /// ========================================================================
  /// ACCEPT CALL
  /// ========================================================================

  Future<void> acceptCall(
    String callId,
  ) async {
    _ensureNotDisposed();

    if (_acceptInProgress) {
      _log(
        'ACCEPT: already processing.',
      );

      return;
    }

    _acceptInProgress =
        true;

    try {
      final uid =
          currentUserId;

      if (uid == null) {
        throw Exception(
          'You must be signed in.',
        );
      }

      _log(
        '==================================================',
      );

      _log(
        '📞 ACCEPT CALL',
      );

      _log(
        'callId=$callId',
      );

      _log(
        'receiver=$uid',
      );

      _log(
        '==================================================',
      );

      if (hasActiveCall) {
        throw Exception(
          'You are already in a call.',
        );
      }

      final callRef =
          _firestore
              .collection('calls')
              .doc(callId);

      /// --------------------------------------------------------------------
      /// GET CALL
      /// --------------------------------------------------------------------

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
          'Invalid call data.',
        );
      }

      final callerId =
          (data['callerId'] ?? '').toString();

      final receiverId =
          (data['receiverId'] ?? '').toString();

      final status =
          (data['status'] ?? '')
              .toString()
              .toLowerCase();

      if (receiverId != uid) {
        throw Exception(
          'You are not the receiver of this call.',
        );
      }

      if (callerId.isEmpty) {
        throw Exception(
          'Invalid caller.',
        );
      }

      if (status != 'ringing') {
        throw Exception(
          'This call is no longer available.',
        );
      }

      /// --------------------------------------------------------------------
      /// OFFER VALIDATION
      /// --------------------------------------------------------------------

      final offer =
          data['offer'];

      if (offer is! Map) {
        throw Exception(
          'WebRTC offer is missing.',
        );
      }

      final offerSdp =
          offer['sdp']?.toString();

      if (offerSdp == null ||
          offerSdp.isEmpty) {
        throw Exception(
          'WebRTC offer SDP is missing.',
        );
      }

      /// --------------------------------------------------------------------
      /// STALE CHECK
      /// --------------------------------------------------------------------

      final createdTime =
          _getCallCreatedTime(
        data,
      );

      if (createdTime != null) {
        final age =
            DateTime.now().difference(
          createdTime,
        );

        if (age >
            incomingCallMaxAge) {
          await _safeUpdateCallStatus(
            callRef,
            'ended',
            includeEndedAt: true,
          );

          throw Exception(
            'This call has expired.',
          );
        }
      }

      /// --------------------------------------------------------------------
      /// CLAIM CALL
      /// --------------------------------------------------------------------

      await _firestore.runTransaction(
        (transaction) async {
          final fresh =
              await transaction.get(
            callRef,
          );

          if (!fresh.exists) {
            throw Exception(
              'Call no longer exists.',
            );
          }

          final freshData =
              fresh.data();

          if (freshData == null) {
            throw Exception(
              'Invalid call data.',
            );
          }

          final freshReceiver =
              (freshData['receiverId'] ?? '')
                  .toString();

          final freshStatus =
              (freshData['status'] ?? '')
                  .toString()
                  .toLowerCase();

          if (freshReceiver != uid) {
            throw Exception(
              'You are not the receiver.',
            );
          }

          if (freshStatus != 'ringing') {
            throw Exception(
              'This call was already answered or ended.',
            );
          }

          transaction.update(
            callRef,
            <String, dynamic>{
              'status':
                  'connecting',
              'answeredAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _log(
        'ACCEPT: call successfully claimed.',
      );

      _announcedIncomingCalls.remove(
        callId,
      );

      /// --------------------------------------------------------------------
      /// CALL TYPE
      /// --------------------------------------------------------------------

      final typeString =
          (data['type'] ?? 'audio')
              .toString()
              .toLowerCase();

      final type =
          typeString == 'video'
              ? ChattaxCallType.video
              : ChattaxCallType.audio;

      await _requestPermissions(
        type,
      );

      await _prepareForNewCall();

      _activeCallId =
          callId;

      _activeCallType =
          type;

      _isCaller =
          false;

      try {
        /// ------------------------------------------------------------------
        /// PEER CONNECTION
        /// ------------------------------------------------------------------

        _log(
          'RECEIVER: creating PeerConnection...',
        );

        await _createPeerConnection();

        /// ------------------------------------------------------------------
        /// LOCAL MEDIA
        /// ------------------------------------------------------------------

        _log(
          'RECEIVER: creating local media...',
        );

        await _createLocalStream(
          type,
        );

        /// ------------------------------------------------------------------
        /// LISTEN FOR CALLER ICE
        /// ------------------------------------------------------------------

        _listenForCallerCandidates(
          callId,
        );

        /// ------------------------------------------------------------------
        /// APPLY OFFER
        /// ------------------------------------------------------------------

        _log(
          'RECEIVER: applying OFFER...',
        );

        await _applyRemoteOffer(
          data,
        );

        _remoteDescriptionSet =
            true;

        _log(
          'RECEIVER: OFFER APPLIED',
        );

        await _flushPendingRemoteCandidates();

        final peerConnection =
            _peerConnection;

        if (peerConnection == null) {
          throw Exception(
            'Peer connection unavailable.',
          );
        }

        _emitStatus(
          ChattaxCallStatus.connecting,
        );

        /// ------------------------------------------------------------------
        /// CREATE ANSWER
        /// ------------------------------------------------------------------

        _log(
          'RECEIVER: creating ANSWER...',
        );

        final answer =
            await peerConnection.createAnswer(
          <String, dynamic>{
            'offerToReceiveAudio':
                true,
            'offerToReceiveVideo':
                type ==
                    ChattaxCallType.video,
          },
        );

        _log(
          'RECEIVER: ANSWER CREATED '
          'type=${answer.type} '
          'sdpLength=${answer.sdp?.length ?? 0}',
        );

        /// ------------------------------------------------------------------
        /// LOCAL ANSWER
        /// ------------------------------------------------------------------

        await peerConnection.setLocalDescription(
          answer,
        );

        _log(
          'RECEIVER: LOCAL ANSWER SET',
        );

        /// ------------------------------------------------------------------
        /// WRITE ANSWER
        /// ------------------------------------------------------------------

        await callRef.update(
          <String, dynamic>{
            'status':
                'connecting',
            'answer':
                <String, dynamic>{
              'type':
                  answer.type,
              'sdp':
                  answer.sdp,
            },
          },
        );

        _log(
          '==================================================',
        );

        _log(
          '✅ ACCEPT COMPLETE',
        );

        _log(
          'callId=$callId',
        );

        _log(
          'status=connecting',
        );

        _log(
          'ANSWER WRITTEN',
        );

        _log(
          '==================================================',
        );

        /// ------------------------------------------------------------------
        /// SIGNALING READY
        /// ------------------------------------------------------------------

        _signalingReady =
            true;

        await _flushPendingLocalCandidates();

        _listenToCallDocument(
          callId,
        );

        _emitStatus(
          ChattaxCallStatus.connecting,
        );

        _log(
          'RECEIVER: waiting for WebRTC connection.',
        );
      } catch (error, stackTrace) {
        _logError(
          'ACCEPT CALL FAILED',
          error,
          stackTrace,
        );

        await _safeMarkCallFailed(
          callId,
        );

        await _cleanupCall();

        rethrow;
      }
    } finally {
      _acceptInProgress =
          false;
    }
  }

  /// ========================================================================
  /// APPLY OFFER
  /// ========================================================================

  Future<void> _applyRemoteOffer(
    Map<String, dynamic> data,
  ) async {
    final offerData =
        data['offer'];

    if (offerData is! Map) {
      throw Exception(
        'No WebRTC offer found.',
      );
    }

    final sdp =
        offerData['sdp']?.toString();

    if (sdp == null ||
        sdp.isEmpty) {
      throw Exception(
        'WebRTC offer SDP is empty.',
      );
    }

    final offer =
        RTCSessionDescription(
      sdp,
      offerData['type']?.toString() ??
          'offer',
    );

    final peerConnection =
        _peerConnection;

    if (peerConnection == null) {
      throw Exception(
        'Peer connection unavailable.',
      );
    }

    await peerConnection.setRemoteDescription(
      offer,
    );

    _log(
      'RECEIVER: remote OFFER successfully applied.',
    );
  }

  /// ========================================================================
  /// REJECT CALL
  /// ========================================================================

  Future<void> rejectCall(
    String callId,
  ) async {
    _ensureNotDisposed();

    final uid =
        currentUserId;

    if (uid == null) {
      return;
    }

    final callRef =
        _firestore
            .collection('calls')
            .doc(callId);

    try {
      final snapshot =
          await callRef.get();

      if (!snapshot.exists) {
        return;
      }

      final data =
          snapshot.data();

      if (data == null) {
        return;
      }

      if (data['receiverId'] != uid) {
        return;
      }

      final status =
          (data['status'] ?? '')
              .toString()
              .toLowerCase();

      if (status != 'ringing') {
        return;
      }

      await callRef.update(
        <String, dynamic>{
          'status':
              'rejected',
          'endedAt':
              FieldValue.serverTimestamp(),
        },
      );

      _log(
        'CALL REJECTED | $callId',
      );
    } catch (error, stackTrace) {
      _logError(
        'REJECT CALL FAILED',
        error,
        stackTrace,
      );
    }

    _announcedIncomingCalls.remove(
      callId,
    );

    if (_activeCallId == callId) {
      _emitStatus(
        ChattaxCallStatus.rejected,
      );

      await _cleanupCall();
    } else {
      _emitStatus(
        ChattaxCallStatus.rejected,
      );
    }
  }

  /// ========================================================================
  /// END CALL
  /// ========================================================================

  Future<void> endCall() async {
    _ensureNotDisposed();

    await _finishCall(
      uiStatus:
          ChattaxCallStatus.ended,
      firestoreStatus:
          'ended',
    );
  }

  /// ========================================================================
  /// CANCEL OUTGOING CALL
  /// ========================================================================

  Future<void> cancelCall() async {
    _ensureNotDisposed();

    if (!_isCaller) {
      return;
    }

    await _finishCall(
      uiStatus:
          ChattaxCallStatus.ended,
      firestoreStatus:
          'ended',
    );
  }

  Future<void> cancelOutgoingCall() async {
    await cancelCall();
  }

  /// ========================================================================
  /// FINISH CALL
  /// ========================================================================

  Future<void> _finishCall({
    required ChattaxCallStatus uiStatus,
    required String firestoreStatus,
  }) async {
    final currentCallId =
        _activeCallId;

    if (currentCallId == null) {
      return;
    }

    if (_endingCall) {
      return;
    }

    _endingCall =
        true;

    try {
      _cancelOutgoingCallTimer();

      _cancelDisconnectTimer();

      try {
        await _firestore
            .collection('calls')
            .doc(currentCallId)
            .update(
          <String, dynamic>{
            'status':
                firestoreStatus,
            'endedAt':
                FieldValue.serverTimestamp(),
          },
        );
      } catch (error, stackTrace) {
        _logError(
          'FINISH CALL FIRESTORE UPDATE FAILED',
          error,
          stackTrace,
        );
      }

      _emitStatus(
        uiStatus,
      );

      await _cleanupCall();
    } finally {
      _endingCall =
          false;
    }
  }

  /// ========================================================================
  /// MICROPHONE
  /// ========================================================================

  Future<void> toggleMicrophone() async {
    await setMicrophoneMuted(
      !_microphoneMuted,
    );
  }

  Future<void> setMicrophoneMuted(
    bool muted,
  ) async {
    _microphoneMuted =
        muted;

    final stream =
        _localStream;

    if (stream == null) {
      return;
    }

    for (final track
        in stream.getAudioTracks()) {
      track.enabled =
          !muted;
    }

    _log(
      'MICROPHONE '
      '${muted ? 'MUTED' : 'UNMUTED'}',
    );
  }

  /// ========================================================================
  /// CAMERA
  /// ========================================================================

  Future<void> toggleCamera() async {
    await setCameraEnabled(
      !_cameraEnabled,
    );
  }

  Future<void> setCameraEnabled(
    bool enabled,
  ) async {
    _cameraEnabled =
        enabled;

    final stream =
        _localStream;

    if (stream == null) {
      return;
    }

    for (final track
        in stream.getVideoTracks()) {
      track.enabled =
          enabled;
    }

    _log(
      'CAMERA '
      '${enabled ? 'ENABLED' : 'DISABLED'}',
    );
  }

  /// ========================================================================
  /// SWITCH CAMERA
  /// ========================================================================

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
        'CAMERA SWITCH FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ========================================================================
  /// SPEAKER
  /// ========================================================================

  Future<void> setSpeaker(
    bool enabled,
  ) async {
    _speakerEnabled =
        enabled;

    try {
      await Helper.setSpeakerphoneOn(
        enabled,
      );

      _log(
        'SPEAKERPHONE '
        '${enabled ? 'ON' : 'OFF'}',
      );
    } catch (error, stackTrace) {
      _logError(
        'SPEAKERPHONE ERROR',
        error,
        stackTrace,
      );
    }
  }

  Future<void> toggleSpeaker() async {
    await setSpeaker(
      !_speakerEnabled,
    );
  }

  /// ========================================================================
  /// CREATE PEER CONNECTION
  /// ========================================================================

  Future<void> _createPeerConnection() async {
    final configuration =
        <String, dynamic>{
      'iceServers':
          _buildIceServers(),
      'sdpSemantics':
          'unified-plan',
      'bundlePolicy':
          'max-bundle',
      'rtcpMuxPolicy':
          'require',
      'iceTransportPolicy':
          'all',
    };

    _log(
      'WEBRTC: creating PeerConnection',
    );

    try {
      _peerConnection =
          await createPeerConnection(
        configuration,
      );
    } catch (error, stackTrace) {
      _logError(
        'CREATE PEER CONNECTION FAILED',
        error,
        stackTrace,
      );

      rethrow;
    }

    final peerConnection =
        _peerConnection;

    if (peerConnection == null) {
      throw Exception(
        'createPeerConnection returned null.',
      );
    }

    _log(
      'WEBRTC: PeerConnection CREATED',
    );

    /// ----------------------------------------------------------------------
    /// LOCAL ICE
    /// ----------------------------------------------------------------------

    peerConnection.onIceCandidate =
        (RTCIceCandidate candidate) {
      final value =
          candidate.candidate;

      if (value == null ||
          value.isEmpty) {
        return;
      }

      _log(
        'LOCAL ICE GENERATED | '
        '${_candidateSummary(candidate)}',
      );

      unawaited(
        _handleLocalIceCandidate(
          candidate,
        ),
      );
    };

    /// ----------------------------------------------------------------------
    /// ICE GATHERING
    /// ----------------------------------------------------------------------

    peerConnection.onIceGatheringState =
        (RTCIceGatheringState state) {
      _log(
        'ICE GATHERING STATE = $state',
      );
    };

    /// ----------------------------------------------------------------------
    /// REMOTE TRACK
    /// ----------------------------------------------------------------------

    peerConnection.onTrack =
        (RTCTrackEvent event) {
      _log(
        'REMOTE TRACK | '
        'kind=${event.track.kind} '
        'streams=${event.streams.length}',
      );

      if (event.streams.isEmpty) {
        return;
      }

      _remoteStream =
          event.streams.first;

      if (!_isDisposed &&
          !_remoteStreamController.isClosed) {
        _remoteStreamController.add(
          _remoteStream,
        );
      }
    };

    /// ----------------------------------------------------------------------
    /// REMOTE STREAM
    /// ----------------------------------------------------------------------

    peerConnection.onAddStream =
        (MediaStream stream) {
      _log(
        'REMOTE STREAM RECEIVED',
      );

      _remoteStream =
          stream;

      if (!_isDisposed &&
          !_remoteStreamController.isClosed) {
        _remoteStreamController.add(
          stream,
        );
      }
    };

    /// ----------------------------------------------------------------------
    /// ICE CONNECTION
    /// ----------------------------------------------------------------------

    peerConnection.onIceConnectionState =
        (RTCIceConnectionState state) {
      _log(
        'ICE CONNECTION STATE = $state',
      );

      final value =
          state.toString().toLowerCase();

      if (value.contains('checking')) {
        _cancelDisconnectTimer();

        _emitStatus(
          ChattaxCallStatus.connecting,
        );

        return;
      }

      if (value.contains('connected') ||
          value.contains('completed')) {
        _cancelDisconnectTimer();

        unawaited(
          _markConnected(),
        );

        return;
      }

      if (value.contains('disconnected')) {
        _startDisconnectGracePeriod();

        return;
      }

      if (value.contains('failed')) {
        _cancelDisconnectTimer();

        unawaited(
          _handleConnectionFailure(),
        );

        return;
      }

      if (value.contains('closed')) {
        _log(
          'ICE CLOSED',
        );
      }
    };

    /// ----------------------------------------------------------------------
    /// PEER CONNECTION STATE
    /// ----------------------------------------------------------------------

    peerConnection.onConnectionState =
        (RTCPeerConnectionState state) {
      _log(
        'PEER CONNECTION STATE = $state',
      );

      final value =
          state.toString().toLowerCase();

      if (value.contains('connecting')) {
        _cancelDisconnectTimer();

        _emitStatus(
          ChattaxCallStatus.connecting,
        );

        return;
      }

      if (value.contains('connected')) {
        _cancelDisconnectTimer();

        unawaited(
          _markConnected(),
        );

        return;
      }

      if (value.contains('disconnected')) {
        _startDisconnectGracePeriod();

        return;
      }

      if (value.contains('failed')) {
        _cancelDisconnectTimer();

        unawaited(
          _handleConnectionFailure(),
        );

        return;
      }

      if (value.contains('closed')) {
        _log(
          'PEER CONNECTION CLOSED',
        );
      }
    };

    /// ----------------------------------------------------------------------
    /// SIGNALING STATE
    /// ----------------------------------------------------------------------

    peerConnection.onSignalingState =
        (RTCSignalingState state) {
      _log(
        'SIGNALING STATE = $state',
      );
    };
  }

  /// ========================================================================
  /// ICE SERVERS
  /// ========================================================================

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
        'urls=${turn.urls}',
      );
    } else {
      _log(
        'WARNING: NO TURN SERVER CONFIGURED',
      );
    }

    return servers;
  }

  /// ========================================================================
  /// CONFIGURE TURN
  /// ========================================================================

  void configureTurn({
    required String username,
    required String credential,
    required List<String> urls,
  }) {
    turnConfig =
        ChattaxTurnConfig(
      username:
          username,
      credential:
          credential,
      urls:
          urls,
    );

    _log(
      'TURN CONFIGURATION UPDATED',
    );
  }

  /// ========================================================================
  /// LOCAL MEDIA
  /// ========================================================================

  Future<void> _createLocalStream(
    ChattaxCallType type,
  ) async {
    final constraints =
        <String, dynamic>{
      'audio':
          <String, dynamic>{
        'echoCancellation':
            true,
        'noiseSuppression':
            true,
        'autoGainControl':
            true,
        'channelCount':
            1,
      },
      'video':
          type ==
                  ChattaxCallType.video
              ? <String, dynamic>{
                  'facingMode':
                      'user',
                  'width':
                      <String, dynamic>{
                    'ideal':
                        1280,
                  },
                  'height':
                      <String, dynamic>{
                    'ideal':
                        720,
                  },
                  'frameRate':
                      <String, dynamic>{
                    'ideal':
                        30,
                  },
                }
              : false,
    };

    _log(
      'MEDIA: requesting getUserMedia type=$type',
    );

    try {
      _localStream =
          await navigator
              .mediaDevices
              .getUserMedia(
        constraints,
      );
    } catch (error, stackTrace) {
      _logError(
        'GET USER MEDIA FAILED',
        error,
        stackTrace,
      );

      rethrow;
    }

    final stream =
        _localStream;

    if (stream == null) {
      throw Exception(
        'Unable to create local media stream.',
      );
    }

    _log(
      'MEDIA CREATED | '
      'audio=${stream.getAudioTracks().length} '
      'video=${stream.getVideoTracks().length}',
    );

    if (!_isDisposed &&
        !_localStreamController.isClosed) {
      _localStreamController.add(
        stream,
      );
    }

    final peerConnection =
        _peerConnection;

    if (peerConnection == null) {
      throw Exception(
        'PeerConnection unavailable.',
      );
    }

    for (final track
        in stream.getTracks()) {
      await peerConnection.addTrack(
        track,
        stream,
      );
    }

    _microphoneMuted =
        false;

    _cameraEnabled =
        type ==
            ChattaxCallType.video;

    await setSpeaker(
      true,
    );
  }

  /// ========================================================================
  /// LOCAL ICE
  /// ========================================================================

  Future<void> _handleLocalIceCandidate(
    RTCIceCandidate candidate,
  ) async {
    final candidateValue =
        candidate.candidate;

    if (candidateValue == null ||
        candidateValue.isEmpty) {
      return;
    }

    final key =
        '$candidateValue|'
        '${candidate.sdpMid}|'
        '${candidate.sdpMLineIndex}';

    if (_sentLocalCandidateKeys.contains(
      key,
    )) {
      return;
    }

    _sentLocalCandidateKeys.add(
      key,
    );

    if (!_signalingReady) {
      _log(
        'LOCAL ICE QUEUED: signaling not ready',
      );

      _pendingLocalCandidates.add(
        candidate,
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
    final currentCallId =
        _activeCallId;

    if (currentCallId == null) {
      return;
    }

    final collectionName =
        _isCaller
            ? 'callerCandidates'
            : 'receiverCandidates';

    try {
      await _firestore
          .collection('calls')
          .doc(currentCallId)
          .collection(collectionName)
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
        'ICE UPLOADED | $collectionName',
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

  /// ========================================================================
  /// CALLER ICE
  /// ========================================================================

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

  /// ========================================================================
  /// RECEIVER ICE
  /// ========================================================================

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

  /// ========================================================================
  /// REMOTE ICE
  /// ========================================================================

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

    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(
        candidate,
      );

      return;
    }

    final peerConnection =
        _peerConnection;

    if (peerConnection == null) {
      return;
    }

    try {
      await peerConnection.addCandidate(
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

  /// ========================================================================
  /// FLUSH REMOTE ICE
  /// ========================================================================

  Future<void>
      _flushPendingRemoteCandidates() async {
    if (!_remoteDescriptionSet) {
      return;
    }

    final peerConnection =
        _peerConnection;

    if (peerConnection == null) {
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
        await peerConnection.addCandidate(
          candidate,
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

  /// ========================================================================
  /// CALL DOCUMENT LISTENER
  /// ========================================================================

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
        if (_activeCallId != callId) {
          return;
        }

        if (!snapshot.exists) {
          unawaited(
            _cleanupCall(),
          );

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
          'CALL STATUS = $status',
        );

        switch (status) {
          case 'calling':
            _emitStatus(
              ChattaxCallStatus.calling,
            );
            break;

          case 'ringing':
            _emitStatus(
              ChattaxCallStatus.ringing,
            );
            break;

          case 'connecting':
            _emitStatus(
              ChattaxCallStatus.connecting,
            );
            break;

          case 'connected':
            _cancelOutgoingCallTimer();

            _emitStatus(
              ChattaxCallStatus.connected,
            );
            break;

          case 'rejected':
            _cancelOutgoingCallTimer();

            _emitStatus(
              ChattaxCallStatus.rejected,
            );

            unawaited(
              _cleanupCall(),
            );

            return;

          case 'ended':
            _cancelOutgoingCallTimer();

            _emitStatus(
              ChattaxCallStatus.ended,
            );

            unawaited(
              _cleanupCall(),
            );

            return;

          case 'failed':
            _cancelOutgoingCallTimer();

            _emitStatus(
              ChattaxCallStatus.failed,
            );

            unawaited(
              _cleanupCall(),
            );

            return;
        }

        /// Only the caller processes the answer.
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

        final peerConnection =
            _peerConnection;

        if (peerConnection == null) {
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

        _log(
          'CALLER: ANSWER RECEIVED',
        );

        unawaited(
          _applyRemoteAnswer(
            peerConnection,
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

  /// ========================================================================
  /// APPLY REMOTE ANSWER
  /// ========================================================================

  Future<void> _applyRemoteAnswer(
    RTCPeerConnection peerConnection,
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
          await peerConnection
              .getRemoteDescription();

      if (current != null) {
        _answerApplied =
            true;

        _remoteDescriptionSet =
            true;

        await _flushPendingRemoteCandidates();

        return;
      }

      await peerConnection.setRemoteDescription(
        answer,
      );

      _answerApplied =
          true;

      _remoteDescriptionSet =
          true;

      _log(
        'CALLER: REMOTE ANSWER APPLIED',
      );

      await _flushPendingRemoteCandidates();
    } catch (error, stackTrace) {
      _logError(
        'APPLY REMOTE ANSWER FAILED',
        error,
        stackTrace,
      );

      await _handleConnectionFailure();
    } finally {
      _answerApplying =
          false;
    }
  }

  /// ========================================================================
  /// CONNECTED
  /// ========================================================================

  Future<void> _markConnected() async {
    final currentCallId =
        _activeCallId;

    if (currentCallId == null) {
      return;
    }

    if (_connectedReported) {
      return;
    }

    _connectedReported =
        true;

    _cancelOutgoingCallTimer();

    _cancelDisconnectTimer();

    _log(
      '==================================================',
    );

    _log(
      '🎉 CHATTªX WEBRTC CONNECTED',
    );

    _log(
      'callId=$currentCallId',
    );

    _log(
      'role=${_isCaller ? 'CALLER' : 'RECEIVER'}',
    );

    _log(
      '==================================================',
    );

    _emitStatus(
      ChattaxCallStatus.connected,
    );

    try {
      await _firestore
          .collection('calls')
          .doc(currentCallId)
          .update(
        <String, dynamic>{
          'status':
              'connected',
          'connectedAt':
              FieldValue.serverTimestamp(),
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

  /// ========================================================================
  /// CONNECTION FAILURE
  /// ========================================================================

  Future<void> _handleConnectionFailure() async {
    if (_failureHandling) {
      return;
    }

    _failureHandling =
        true;

    try {
      final currentCallId =
          _activeCallId;

      if (currentCallId == null) {
        return;
      }

      _log(
        '❌ WEBRTC CONNECTION FAILED '
        'callId=$currentCallId',
      );

      _cancelOutgoingCallTimer();

      _cancelDisconnectTimer();

      _emitStatus(
        ChattaxCallStatus.failed,
      );

      try {
        await _firestore
            .collection('calls')
            .doc(currentCallId)
            .update(
          <String, dynamic>{
            'status':
                'failed',
            'endedAt':
                FieldValue.serverTimestamp(),
          },
        );
      } catch (error, stackTrace) {
        _logError(
          'FAILURE STATUS WRITE FAILED',
          error,
          stackTrace,
        );
      }

      await _cleanupCall();
    } finally {
      _failureHandling =
          false;
    }
  }

  /// ========================================================================
  /// DISCONNECT GRACE
  /// ========================================================================

  void _startDisconnectGracePeriod() {
    _cancelDisconnectTimer();

    _log(
      'Starting disconnect grace period '
      '${disconnectGracePeriod.inSeconds}s',
    );

    _disconnectTimer =
        Timer(
      disconnectGracePeriod,
      () {
        if (_activeCallId == null) {
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

  /// ========================================================================
  /// OUTGOING TIMEOUT
  /// ========================================================================

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

        try {
          await _firestore
              .collection('calls')
              .doc(callId)
              .update(
            <String, dynamic>{
              'status':
                  'ended',
              'endedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        } catch (error, stackTrace) {
          _logError(
            'OUTGOING TIMEOUT FIRESTORE FAILED',
            error,
            stackTrace,
          );
        }

        _emitStatus(
          ChattaxCallStatus.ended,
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

  /// ========================================================================
  /// SET CALL STATUS
  /// ========================================================================

  Future<void> setCallStatus(
    ChattaxCallStatus status,
  ) async {
    final currentCallId =
        _activeCallId;

    if (currentCallId == null) {
      return;
    }

    try {
      await _firestore
          .collection('calls')
          .doc(currentCallId)
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
    );
  }

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

  /// ========================================================================
  /// STATUS EMITTER
  /// ========================================================================

  void _emitStatus(
    ChattaxCallStatus status,
  ) {
    _log(
      'UI CALL STATUS -> $status',
    );

    if (_isDisposed) {
      return;
    }

    if (_callStatusController.isClosed) {
      return;
    }

    _callStatusController.add(
      status,
    );
  }

  /// ========================================================================
  /// PERMISSIONS
  /// ========================================================================

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

    _log(
      'CALL PERMISSIONS GRANTED',
    );
  }

  /// ========================================================================
  /// CHECK CALL
  /// ========================================================================

  Future<bool> isCallStillActive(
    String callId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('calls')
              .doc(callId)
              .get();

      if (!snapshot.exists) {
        return false;
      }

      final data =
          snapshot.data();

      if (data == null) {
        return false;
      }

      final status =
          (data['status'] ?? '')
              .toString()
              .toLowerCase();

      return status == 'calling' ||
          status == 'ringing' ||
          status == 'connecting' ||
          status == 'connected';
    } catch (error, stackTrace) {
      _logError(
        'CHECK CALL FAILED',
        error,
        stackTrace,
      );

      return false;
    }
  }

  /// ========================================================================
  /// GET CALL
  /// ========================================================================

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

  /// ========================================================================
  /// CLOSE CALL
  /// ========================================================================

  Future<void> closeCall(
    String callId,
  ) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update(
        <String, dynamic>{
          'status':
              'ended',
          'endedAt':
              FieldValue.serverTimestamp(),
        },
      );
    } catch (error, stackTrace) {
      _logError(
        'CLOSE CALL FIRESTORE FAILED',
        error,
        stackTrace,
      );
    }

    _announcedIncomingCalls.remove(
      callId,
    );

    if (_activeCallId == callId) {
      _emitStatus(
        ChattaxCallStatus.ended,
      );

      await _cleanupCall();
    }
  }

  /// ========================================================================
  /// SAFE STATUS UPDATE
  /// ========================================================================

  Future<void> _safeUpdateCallStatus(
    DocumentReference<Map<String, dynamic>> callRef,
    String status, {
    bool includeEndedAt = false,
  }) async {
    final update =
        <String, dynamic>{
      'status':
          status,
    };

    if (includeEndedAt) {
      update['endedAt'] =
          FieldValue.serverTimestamp();
    }

    try {
      await callRef.update(
        update,
      );
    } catch (error, stackTrace) {
      _logError(
        'SAFE CALL STATUS UPDATE FAILED',
        error,
        stackTrace,
      );
    }
  }

  /// ========================================================================
  /// MARK FAILED
  /// ========================================================================

  Future<void> _safeMarkCallFailed(
    String callId,
  ) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update(
        <String, dynamic>{
          'status':
              'failed',
          'endedAt':
              FieldValue.serverTimestamp(),
        },
      );

      _log(
        'CALL MARKED FAILED | $callId',
      );
    } catch (error, stackTrace) {
      _logError(
        'MARK CALL FAILED FIRESTORE ERROR',
        error,
        stackTrace,
      );
    }
  }

  /// ========================================================================
  /// RESET CALL STATE
  /// ========================================================================

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

    _pendingLocalCandidates.clear();

    _pendingRemoteCandidates.clear();

    _receivedRemoteCandidateIds.clear();

    _sentLocalCandidateKeys.clear();
  }

  /// ========================================================================
  /// CLEANUP ACTIVE CALL
  /// ========================================================================

  Future<void> _cleanupCall() async {
    if (_cleanupInProgress) {
      return;
    }

    _cleanupInProgress =
        true;

    try {
      _log(
        'CLEANUP: starting',
      );

      _cancelOutgoingCallTimer();

      _cancelDisconnectTimer();

      /// --------------------------------------------------------------------
      /// CALL LISTENER
      /// --------------------------------------------------------------------

      await _callSubscription?.cancel();

      _callSubscription =
          null;

      /// --------------------------------------------------------------------
      /// CALLER ICE
      /// --------------------------------------------------------------------

      await _callerCandidatesSubscription?.cancel();

      _callerCandidatesSubscription =
          null;

      /// --------------------------------------------------------------------
      /// RECEIVER ICE
      /// --------------------------------------------------------------------

      await _receiverCandidatesSubscription?.cancel();

      _receiverCandidatesSubscription =
          null;

      /// --------------------------------------------------------------------
      /// PEER CONNECTION
      /// --------------------------------------------------------------------

      final peerConnection =
          _peerConnection;

      _peerConnection =
          null;

      if (peerConnection != null) {
        try {
          await peerConnection.close();
        } catch (error, stackTrace) {
          _logError(
            'PEER CONNECTION CLOSE FAILED',
            error,
            stackTrace,
          );
        }
      }

      /// --------------------------------------------------------------------
      /// LOCAL STREAM
      /// --------------------------------------------------------------------

      final localStream =
          _localStream;

      _localStream =
          null;

      if (localStream != null) {
        for (final track
            in localStream.getTracks()) {
          try {
            await track.stop();
          } catch (_) {}
        }

        try {
          await localStream.dispose();
        } catch (_) {}
      }

      /// --------------------------------------------------------------------
      /// REMOTE STREAM
      /// --------------------------------------------------------------------

      final remoteStream =
          _remoteStream;

      _remoteStream =
          null;

      if (remoteStream != null) {
        try {
          for (final track
              in remoteStream.getTracks()) {
            try {
              await track.stop();
            } catch (_) {}
          }
        } catch (_) {}
      }

      /// --------------------------------------------------------------------
      /// RESET SIGNALING
      /// --------------------------------------------------------------------

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

      _answerApplying =
          false;

      /// --------------------------------------------------------------------
      /// RESET ACTIVE CALL
      /// --------------------------------------------------------------------

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

      _endingCall =
          false;

      _failureHandling =
          false;

      /// --------------------------------------------------------------------
      /// AUDIO ROUTING
      /// --------------------------------------------------------------------

      try {
        await Helper.setSpeakerphoneOn(
          false,
        );
      } catch (_) {}

      /// --------------------------------------------------------------------
      /// UI STREAMS
      /// --------------------------------------------------------------------

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
        'CLEANUP: complete',
      );
    } finally {
      _cleanupInProgress =
          false;
    }
  }

  /// ========================================================================
  /// DISPOSE
  /// ========================================================================

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

    await _remoteStreamController.close();

    await _localStreamController.close();

    _announcedIncomingCalls.clear();

    _log(
      'CHATTªX CALL SERVICE DISPOSED',
    );
  }

  /// ========================================================================
  /// LOGGING
  /// ========================================================================

  void _log(
    String message,
  ) {
    // ignore: avoid_print
    print(
      '📞 [ChattªX CALL] $message',
    );
  }

  void _logError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    // ignore: avoid_print
    print(
      '❌ [ChattªX CALL] $message',
    );

    // ignore: avoid_print
    print(
      '❌ ERROR: $error',
    );

    // ignore: avoid_print
    print(
      '❌ STACK TRACE:\n$stackTrace',
    );
  }

  String _candidateSummary(
    RTCIceCandidate candidate,
  ) {
    final value =
        candidate.candidate ?? '';

    if (value.length <= 100) {
      return value;
    }

    return value.substring(
      0,
      100,
    );
  }

  /// ========================================================================
  /// SAFETY
  /// ========================================================================

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'ChattªX Call Service has already been disposed.',
      );
    }
  }
}