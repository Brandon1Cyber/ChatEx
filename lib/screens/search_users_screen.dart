import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import 'public_profile_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final FriendService _friendService = FriendService();

  final String currentUserId =
      FirebaseAuth.instance.currentUser!.uid;

  String search = "";

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
          "Search Users",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  search = value.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by name or username...",
                hintStyle: const TextStyle(
                  color: Colors.white54,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: cyan,
                ),
                filled: true,
                fillColor: card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;

                  final name = (data['displayName'] ?? "")
                      .toString()
                      .toLowerCase();

                  final username =
                      (data['username'] ?? "")
                          .toString()
                          .toLowerCase();

                  return name.contains(search) ||
                      username.contains(search);
                }).toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data =
                        users[index].data()
                            as Map<String, dynamic>;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (data["photoUrl"] ?? "")
                                    .toString()
                                    .isNotEmpty
                                ? NetworkImage(
                                    data["photoUrl"],
                                  )
                                : null,
                        child:
                            (data["photoUrl"] ?? "")
                                    .toString()
                                    .isEmpty
                                ? const Icon(Icons.person)
                                : null,
                      ),

                      title: Text(
                        data["displayName"] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      subtitle: Text(
                        data["username"] ?? "",
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),

                       trailing: FutureBuilder<String>(
  future: _friendService.getFriendStatus(users[index].id),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final status = snapshot.data!;

    if (status == "you") {
      return const Chip(
        label: Text("You"),
      );
    }

    if (status == "friends") {
      return const Chip(
        label: Text("Friends"),
      );
    }

    if (status == "pending") {
      return const Chip(
        label: Text("Sent"),
      );
    }

    return IconButton(
      icon: const Icon(
        Icons.person_add,
        color: cyan,
      ),
      onPressed: () async {
        try {
          await _friendService.sendFriendRequest(users[index].id);

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
    );
  },
),

                      onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PublicProfileScreen(
        userId: users[index].id,
      ),
    ),
  );
},
                    );
                  },
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}