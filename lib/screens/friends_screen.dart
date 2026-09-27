import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/call_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  static const Color background = Color(0xFF050816);
  static const Color card = Color(0xFF0D1528);
  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFFB026FF);
  static const Color border = Color(0xFF18243A);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            'Please log in to view your friends.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Friends',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUser.uid)
            .collection('contacts')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: cyan,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load friends.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No Friends Yet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          }

          final friends = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 20,
            ),
            itemCount: friends.length,

            itemBuilder: (context, index) {
              final friendId = friends[index].id;

              return FutureBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(friendId)
                    .get(),

                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(
                      height: 84,
                    );
                  }

                  if (!userSnapshot.hasData ||
                      !userSnapshot.data!.exists) {
                    return const SizedBox();
                  }

                  final user = userSnapshot.data!.data();

                  if (user == null) {
                    return const SizedBox();
                  }

                  final String name =
                      (user['displayName'] ?? 'Unknown')
                          .toString();

                  final String username =
                      (user['username'] ?? '').toString();

                  final String photo =
                      (user['photoUrl'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: card,
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: border,
                        width: 1,
                      ),
                    ),

                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),

                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            const Color(0xFF111827),
                        backgroundImage:
                            photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                        child: photo.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Colors.white70,
                              )
                            : null,
                      ),

                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      subtitle: username.isNotEmpty
                          ? Text(
                              username,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            )
                          : null,

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// AUDIO CALL
                          IconButton(
                            tooltip: 'Audio call',
                            onPressed: () async {
                              try {
                                await ChattaxCallService
                                    .instance
                                    .startAudioCall(
                                  friendId,
                                );
                              } catch (e) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not start audio call: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.call_outlined,
                              color: cyan,
                              size: 23,
                            ),
                          ),

                          /// VIDEO CALL
                          IconButton(
                            tooltip: 'Video call',
                            onPressed: () async {
                              try {
                                await ChattaxCallService
                                    .instance
                                    .startVideoCall(
                                  friendId,
                                );
                              } catch (e) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not start video call: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.videocam_outlined,
                              color: purple,
                              size: 23,
                            ),
                          ),

                          /// CHAT
                          IconButton(
                            tooltip: 'Message',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChatScreen(
                                    receiverId:
                                        friendId,
                                    receiverName:
                                        name,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons
                                  .chat_bubble_outline,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                        ],
                      ),

                      /// TAPPING THE FRIEND STILL OPENS CHAT
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: friendId,
                              receiverName: name,
                            ),
                          ),
                        );
                      },
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