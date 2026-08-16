import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String callId;
  final String callerId;
  final String receiverId;
  final String chatId;
  final String callerName;
  final String callerPhoto;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int duration;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.chatId,
    required this.callerName,
    required this.callerPhoto,
    required this.type,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.duration = 0,
  });

  factory CallModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return CallModel(
      callId: snapshot.id,
      callerId: data['callerId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      chatId: data['chatId'] ?? '',
      callerName: data['callerName'] ?? 'ChattªX User',
      callerPhoto: data['callerPhoto'] ?? '',
      type: data['type'] ?? 'voice',
      status: data['status'] ?? 'ringing',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answeredAt: (data['answeredAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      duration: data['duration'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'receiverId': receiverId,
      'chatId': chatId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt':
          answeredAt == null ? null : Timestamp.fromDate(answeredAt!),
      'endedAt':
          endedAt == null ? null : Timestamp.fromDate(endedAt!),
      'duration': duration,
    };
  }

  CallModel copyWith({
    String? status,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? duration,
  }) {
    return CallModel(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      chatId: chatId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
    );
  }
}