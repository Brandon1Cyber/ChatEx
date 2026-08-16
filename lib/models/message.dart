class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;

  final bool isMe;
  final bool isSeen;
  final bool isDelivered;

  final String? imageUrl;
  final String? voiceUrl;
  final String? videoUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSeen = false,
    this.isDelivered = false,
    this.imageUrl,
    this.voiceUrl,
    this.videoUrl,
  });
}