import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;
final NotificationService _notificationService =
    NotificationService();

  /// Send a friend request
  Future<void> sendFriendRequest(String receiverId) async {
    final String senderId = _auth.currentUser!.uid;

    // Prevent sending a request to yourself
    if (senderId == receiverId) {
      throw Exception("You cannot send a friend request to yourself.");
    }

    // Check if a request already exists
    final existing = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception("Friend request already sent.");
    }

    // Create the friend request
    await _firestore.collection('friend_requests').add({
  'senderId': senderId,
  'receiverId': receiverId,
  'status': 'pending',
  'timestamp': FieldValue.serverTimestamp(),
});

await _notificationService.sendNotification(
  receiverId: receiverId,
  title: "New Friend Request",
  body: "You have received a new friend request.",
  type: "friend_request",
);
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(
    String requestId,
    String senderId,
  ) async {
    final String currentUserId = _auth.currentUser!.uid;

    final WriteBatch batch = _firestore.batch();

    // Update request status
    final requestRef =
        _firestore.collection('friend_requests').doc(requestId);

    batch.update(requestRef, {
      'status': 'accepted',
    });

    // Add sender to current user's friends
    final currentUserFriendRef = _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('contacts')
        .doc(senderId);

    batch.set(currentUserFriendRef, {
      'since': FieldValue.serverTimestamp(),
      'favorite': false,
      'nickname': '',
    });

    // Add current user to sender's friends
    final senderFriendRef = _firestore
        .collection('friends')
        .doc(senderId)
        .collection('contacts')
        .doc(currentUserId);

    batch.set(senderFriendRef, {
      'since': FieldValue.serverTimestamp(),
      'favorite': false,
      'nickname': '',
    });

    await batch.commit();
  }

  /// Decline a friend request
  Future<void> declineFriendRequest(String requestId) async {
    await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .update({
      'status': 'declined',
    });
  }

  /// Cancel a sent friend request
  Future<void> cancelFriendRequest(String requestId) async {
    await _firestore
        .collection('friend_requests')
        .doc(requestId)
        .delete();
  }

  /// Remove a friend
  Future<void> removeFriend(String friendId) async {
    final String currentUserId = _auth.currentUser!.uid;

    final WriteBatch batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection('friends')
          .doc(currentUserId)
          .collection('contacts')
          .doc(friendId),
    );

    batch.delete(
      _firestore
          .collection('friends')
          .doc(friendId)
          .collection('contacts')
          .doc(currentUserId),
    );

    await batch.commit();
  }

  /// Check if two users are already friends
  Future<bool> areFriends(String otherUserId) async {
    final String currentUserId = _auth.currentUser!.uid;

    final doc = await _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('contacts')
        .doc(otherUserId)
        .get();

    return doc.exists;
  }

  /// Check if a friend request is pending
 Future<bool> hasPendingRequest(String receiverId) async {
    final String senderId = _auth.currentUser!.uid;

    final result = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    return result.docs.isNotEmpty;
  }

  Future<String> getFriendStatus(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;

    if (currentUserId == otherUserId) {
      return "you";
    }

    final friendDoc = await _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('contacts')
        .doc(otherUserId)
        .get();

    if (friendDoc.exists) {
      return "friends";
    }

    final sentRequest = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('receiverId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (sentRequest.docs.isNotEmpty) {
      return "pending";
    }

    return "none";
  }
}