import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/friend_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState
    extends State<FriendRequestsScreen> {
  final FriendService _friendService = FriendService();

  final String currentUserId =
      FirebaseAuth.instance.currentUser!.uid;

  static const Color background = Color(0xFF050816);
  static const Color card = Color(0xFF0D1528);
  static const Color cyan = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          "Friend Requests",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('receiverId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Something went wrong",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No Friend Requests",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              final senderId = request['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final user =
                      userSnapshot.data!.data()
                          as Map<String, dynamic>?;

                  final name =
                      user?['displayName'] ?? "Unknown User";

                  final username =
                      user?['username'] ?? "";

                  final photo =
                      user?['photoUrl'] ?? "";

                  final verified =
                      user?['verified'] ?? false;

                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: 14),

                    decoration: BoxDecoration(
                      color: card,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),

                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.all(12),

                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          if (verified)
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            ),
                        ],
                      ),

                      subtitle: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Accept",
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await _friendService
                                  .acceptFriendRequest(
                                request.id,
                                senderId,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Friend request accepted",
                                    ),
                                  ),
                                );
                              }
                            },
                          ),

                          IconButton(
                            tooltip: "Decline",
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await _friendService
                                  .declineFriendRequest(
                                request.id,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Friend request declined",
                                    ),
                                  ),
                                );
                              }
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
        },
      ),
    );
  }
}