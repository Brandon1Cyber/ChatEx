import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/friend_service.dart';
import 'chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final FriendService _friendService = FriendService();

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
          "Public Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .get(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const Center(
        child: Text(
          "User not found",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final user =
        snapshot.data!.data() as Map<String, dynamic>;

    final name = user["displayName"] ?? "Unknown User";
    final username = user["username"] ?? "";
    final bio = user["bio"] ?? "";
    final photo = user["photoUrl"] ?? "";
    final verified = user["verified"] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [

          CircleAvatar(
            radius: 55,
            backgroundImage:
                photo.toString().isNotEmpty
                    ? NetworkImage(photo)
                    : null,
            child: photo.toString().isEmpty
                ? const Icon(
                    Icons.person,
                    size: 55,
                  )
                : null,
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (verified)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.verified,
                    color: Colors.blue,
                  ),
                ),

            ],
          ),

          const SizedBox(height: 8),

          Text(
            username,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bio.isEmpty ? "No bio yet." : bio,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 25),

        FutureBuilder<String>(
  future: _friendService.getFriendStatus(widget.userId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final status = snapshot.data!;

    if (status == "you") {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: Text("This is you"),
        ),
      );
    }

    if (status == "friends") {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        receiverId: widget.userId,
        receiverName: name,
      ),
    ),
  );
},
          icon: const Icon(Icons.chat),
          label: const Text("Message"),
        ),
      );
    }

    if (status == "pending") {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: Text("Request Sent"),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            await _friendService.sendFriendRequest(widget.userId);

            if (!mounted) return;

            setState(() {});

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Friend request sent!"),
              ),
            );
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
              ),
            );
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text("Add Friend"),
      ),
    );
  },
),

        ],
      ),
    );
  },
),
    );
  }
}