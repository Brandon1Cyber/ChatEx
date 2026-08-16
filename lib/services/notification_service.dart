import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendNotification({
    required String receiverId,
    required String title,
    required String body,
    required String type,
  }) async {
    final senderId = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .add({
      'senderId': senderId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}