import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get currentUserId {
    return _auth.currentUser?.uid ?? "";
  }

  // ============================================================
  // CHAT ID
  // ============================================================

  String getChatId(String otherUserId) {
    final users = [
      currentUserId,
      otherUserId,
    ];

    users.sort();

    return users.join("_");
  }

  // ============================================================
  // GET USER DATA
  // ============================================================

  Future<Map<String, dynamic>> getUserData(
    String uid,
  ) async {
    if (uid.isEmpty) {
      return {};
    }

    try {
      final doc = await _firestore
          .collection("users")
          .doc(uid)
          .get(
            const GetOptions(
              source: Source.server,
            ),
          );

      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      debugPrint(
        "ChattªX getUserData server error: $e",
      );

      try {
        final cachedDoc = await _firestore
            .collection("users")
            .doc(uid)
            .get(
              const GetOptions(
                source: Source.cache,
              ),
            );

        if (cachedDoc.exists) {
          return cachedDoc.data() ?? {};
        }
      } catch (cacheError) {
        debugPrint(
          "ChattªX getUserData cache error: $cacheError",
        );
      }
    }

    return {};
  }

  // ============================================================
  // SYNC PROFILE CHANGES
  // ============================================================

  Future<void> syncProfileChanges({
    required String name,
    required String photoUrl,
  }) async {
    if (currentUserId.isEmpty) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection("chat_rooms")
          .where(
            "participants",
            arrayContains: currentUserId,
          )
          .get(
            const GetOptions(
              source: Source.server,
            ),
          );

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final lastSenderId =
            data["lastSenderId"];

        if (lastSenderId == currentUserId) {
          batch.set(
            doc.reference,
            {
              "senderName": name,
              "senderPhoto": photoUrl,
            },
            SetOptions(
              merge: true,
            ),
          );
        } else {
          batch.set(
            doc.reference,
            {
              "receiverName": name,
              "receiverPhoto": photoUrl,
            },
            SetOptions(
              merge: true,
            ),
          );
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint(
        "ChattªX profile sync error: $e",
      );
    }
  }

  // ============================================================
  // SEND TEXT MESSAGE
  // ============================================================

  Future<void> sendMessage(
    String receiverId,
    String receiverName,
    String message, {
    bool isFrozen = false,
    String? replyTo,
  }) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (receiverId.isEmpty) {
      return;
    }

    if (message.trim().isEmpty) {
      return;
    }

    final chatId =
        getChatId(receiverId);

    final me =
        await getUserData(currentUserId);

    final receiver =
        await getUserData(receiverId);

    final messageRef = _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .collection("messages")
        .doc();

    await messageRef.set({
      "senderId": currentUserId,
      "receiverId": receiverId,
      "message": message,
      "type": "text",
      "timestamp":
          FieldValue.serverTimestamp(),

      "delivered": false,
      "seen": false,
      "status": "sent",

      "isFrozen": isFrozen,
      "isMelted": false,
      "meltedAt": null,

      "replyTo": replyTo,

      // ========================================================
      // REACTIONS
      // ========================================================

      "reactions": {},

      // Stores the actual users who reacted.
      //
      // {
      //   "❤️": {
      //      "USER_ID": true
      //   }
      // }
      //
      "reactionUsers": {},
    });

    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "participants": [
          currentUserId,
          receiverId,
        ],

        "lastMessage": message,

        "lastMessageTime":
            FieldValue.serverTimestamp(),

        "lastSenderId":
            currentUserId,

        "lastInfinity": "sent",

        "lastMessageStatus": "sent",

        "lastMessageId":
            messageRef.id,

        "receiverName":
            receiver["name"] ?? receiverName,

        "receiverPhoto":
            receiver["photoUrl"] ?? "",

        "receiverVerified":
            receiver["verified"] ?? false,

        "receiverOnline":
            receiver["isOnline"] ?? false,

        "senderName":
            me["name"] ?? "",

        "senderPhoto":
            me["photoUrl"] ?? "",

        "unread_$receiverId":
            FieldValue.increment(1),

        "unread_$currentUserId":
            0,
      },
      SetOptions(
        merge: true,
      ),
    );

    debugPrint(
      "ChattªX MESSAGE SENT: ${messageRef.id}",
    );
  }

  // ============================================================
  // SEND VOICE MESSAGE
  // ============================================================

  Future<void> sendVoiceMessage(
    String receiverId,
    String receiverName,
    String voiceUrl,
    int duration,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (receiverId.isEmpty) {
      return;
    }

    if (voiceUrl.trim().isEmpty) {
      return;
    }

    final chatId =
        getChatId(receiverId);

    final me =
        await getUserData(currentUserId);

    final receiver =
        await getUserData(receiverId);

    final messageRef = _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .collection("messages")
        .doc();

    await messageRef.set({
      "senderId": currentUserId,
      "receiverId": receiverId,
      "message": "",
      "voiceUrl": voiceUrl,
      "voiceDuration": duration,
      "type": "voice",
      "timestamp":
          FieldValue.serverTimestamp(),

      "delivered": false,
      "seen": false,
      "status": "sent",

      "isFrozen": false,
      "isMelted": false,
      "meltedAt": null,

      "replyTo": null,

      "reactions": {},
      "reactionUsers": {},
    });

    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "participants": [
          currentUserId,
          receiverId,
        ],

        "lastMessage":
            "🎤 Voice message",

        "lastMessageTime":
            FieldValue.serverTimestamp(),

        "lastSenderId":
            currentUserId,

        "lastInfinity": "sent",

        "lastMessageStatus": "sent",

        "lastMessageId":
            messageRef.id,

        "receiverName":
            receiver["name"] ?? receiverName,

        "receiverPhoto":
            receiver["photoUrl"] ?? "",

        "receiverVerified":
            receiver["verified"] ?? false,

        "receiverOnline":
            receiver["isOnline"] ?? false,

        "senderName":
            me["name"] ?? "",

        "senderPhoto":
            me["photoUrl"] ?? "",

        "unread_$receiverId":
            FieldValue.increment(1),

        "unread_$currentUserId":
            0,
      },
      SetOptions(
        merge: true,
      ),
    );

    debugPrint(
      "ChattªX VOICE MESSAGE SENT: ${messageRef.id}",
    );
  }

  // ============================================================
  // SEND LOCATION MESSAGE
  // ============================================================

  Future<void> sendLocationMessage(
    String receiverId,
    String receiverName,
    double latitude,
    double longitude,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (receiverId.isEmpty) {
      return;
    }

    final chatId =
        getChatId(receiverId);

    final me =
        await getUserData(currentUserId);

    final receiver =
        await getUserData(receiverId);

    final messageRef = _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .collection("messages")
        .doc();

    await messageRef.set({
      "senderId": currentUserId,
      "receiverId": receiverId,
      "message":
          "📍 Shared location",
      "type": "location",

      "latitude": latitude,
      "longitude": longitude,

      "timestamp":
          FieldValue.serverTimestamp(),

      "delivered": false,
      "seen": false,
      "status": "sent",

      "isFrozen": false,
      "isMelted": false,
      "meltedAt": null,

      "replyTo": null,

      "reactions": {},
      "reactionUsers": {},
    });

    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "participants": [
          currentUserId,
          receiverId,
        ],

        "lastMessage":
            "📍 Shared location",

        "lastMessageTime":
            FieldValue.serverTimestamp(),

        "lastSenderId":
            currentUserId,

        "lastInfinity": "sent",

        "lastMessageStatus": "sent",

        "lastMessageId":
            messageRef.id,

        "receiverName":
            receiver["name"] ?? receiverName,

        "receiverPhoto":
            receiver["photoUrl"] ?? "",

        "receiverVerified":
            receiver["verified"] ?? false,

        "receiverOnline":
            receiver["isOnline"] ?? false,

        "senderName":
            me["name"] ?? "",

        "senderPhoto":
            me["photoUrl"] ?? "",

        "unread_$receiverId":
            FieldValue.increment(1),

        "unread_$currentUserId":
            0,
      },
      SetOptions(
        merge: true,
      ),
    );

    debugPrint(
      "ChattªX LOCATION MESSAGE SENT: ${messageRef.id}",
    );
  }

  // ============================================================
  // MARK MESSAGE DELIVERED
  // ============================================================

  Future<void> markMessageDelivered(
    String chatId,
    String messageId,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty ||
        messageId.isEmpty) {
      return;
    }

    try {
      final messageRef = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);

      final message =
          await messageRef.get();

      if (!message.exists) {
        return;
      }

      final data =
          message.data();

      if (data == null) {
        return;
      }

      if (data["receiverId"] !=
          currentUserId) {
        debugPrint(
          "ChattªX: blocked invalid delivered update.",
        );

        return;
      }

      await messageRef.update({
        "delivered": true,
        "status": "delivered",
        "deliveredAt":
            FieldValue.serverTimestamp(),
      });

      final roomRef = _firestore
          .collection("chat_rooms")
          .doc(chatId);

      final room =
          await roomRef.get();

      if (!room.exists) {
        return;
      }

      final roomData =
          room.data();

      if (roomData == null) {
        return;
      }

      if (roomData["lastMessageId"] ==
          messageId) {
        await roomRef.set(
          {
            "lastInfinity":
                "delivered",
            "lastMessageStatus":
                "delivered",
          },
          SetOptions(
            merge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX mark delivered error: $e",
      );
    }
  }

  // ============================================================
  // MARK MESSAGE SEEN
  // ============================================================

  Future<void> markMessageSeen(
    String chatId,
    String messageId,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty ||
        messageId.isEmpty) {
      return;
    }

    try {
      final messageRef = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);

      final message =
          await messageRef.get();

      if (!message.exists) {
        return;
      }

      final data =
          message.data();

      if (data == null) {
        return;
      }

      if (data["receiverId"] !=
          currentUserId) {
        debugPrint(
          "ChattªX: blocked invalid seen update.",
        );

        return;
      }

      await messageRef.update({
        "seen": true,
        "delivered": true,
        "status": "seen",
        "seenAt":
            FieldValue.serverTimestamp(),
      });

      final roomRef = _firestore
          .collection("chat_rooms")
          .doc(chatId);

      final room =
          await roomRef.get();

      if (!room.exists) {
        return;
      }

      final roomData =
          room.data();

      if (roomData == null) {
        return;
      }

      if (roomData["lastMessageId"] ==
          messageId) {
        await roomRef.set(
          {
            "lastInfinity": "seen",
            "lastMessageStatus":
                "seen",
            "unread_$currentUserId":
                0,
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      debugPrint(
        "ChattªX MESSAGE SEEN: $messageId",
      );
    } catch (e) {
      debugPrint(
        "ChattªX mark seen error: $e",
      );
    }
  }

  // ============================================================
  // MARK ALL RECEIVED MESSAGES AS SEEN
  // ============================================================

  Future<void> markChatMessagesAsSeen(
    String chatId,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty) {
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .where(
                "receiverId",
                isEqualTo: currentUserId,
              )
              .where(
                "seen",
                isEqualTo: false,
              )
              .get();

      if (snapshot.docs.isEmpty) {
        await _firestore
            .collection("chat_rooms")
            .doc(chatId)
            .set(
          {
            "unread_$currentUserId":
                0,
          },
          SetOptions(
            merge: true,
          ),
        );

        return;
      }

      final batch =
          _firestore.batch();

      String? latestMessageId;
      Timestamp? latestTimestamp;

      for (final doc
          in snapshot.docs) {
        final data =
            doc.data();

        final timestamp =
            data["timestamp"];

        if (timestamp is Timestamp) {
          if (latestTimestamp == null ||
              timestamp.compareTo(
                    latestTimestamp,
                  ) >
                  0) {
            latestTimestamp =
                timestamp;

            latestMessageId =
                doc.id;
          }
        }

        if (data["receiverId"] !=
            currentUserId) {
          continue;
        }

        batch.update(
          doc.reference,
          {
            "seen": true,
            "delivered": true,
            "status": "seen",
            "seenAt":
                FieldValue.serverTimestamp(),
          },
        );
      }

      final roomRef = _firestore
          .collection("chat_rooms")
          .doc(chatId);

      final roomSnapshot =
          await roomRef.get();

      final roomData =
          roomSnapshot.data();

      final roomLastMessageId =
          roomData?["lastMessageId"];

      if (latestMessageId != null &&
          roomLastMessageId ==
              latestMessageId) {
        batch.set(
          roomRef,
          {
            "lastInfinity": "seen",
            "lastMessageStatus":
                "seen",
            "unread_$currentUserId":
                0,
          },
          SetOptions(
            merge: true,
          ),
        );
      } else {
        batch.set(
          roomRef,
          {
            "unread_$currentUserId":
                0,
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      debugPrint(
        "ChattªX: received messages marked seen.",
      );
    } catch (e) {
      debugPrint(
        "ChattªX mark chat messages seen error: $e",
      );
    }
  }

  // ============================================================
  // REACTIONS
  // ============================================================
  //
  // ChattªX reaction structure:
  //
  // reactions:
  // {
  //   "❤️": 2,
  //   "😂": 1,
  //   "🔥": 4
  // }
  //
  // reactionUsers:
  // {
  //   "❤️": {
  //     "USER_A": true,
  //     "USER_B": true
  //   },
  //
  //   "😂": {
  //     "USER_A": true
  //   }
  // }
  //
  // This lets us know:
  //
  // 1. How many reactions exist.
  // 2. Which users reacted.
  // 3. Whether the current user already reacted.
  // 4. Whether to add or remove the reaction.
  //
  // ============================================================

  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty ||
        messageId.isEmpty) {
      return;
    }

    final cleanEmoji =
        emoji.trim();

    if (cleanEmoji.isEmpty) {
      return;
    }

    try {
      final messageRef = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            messageRef,
          );

          if (!snapshot.exists) {
            throw Exception(
              "Message does not exist.",
            );
          }

          final data =
              snapshot.data();

          if (data == null) {
            throw Exception(
              "Message data is empty.",
            );
          }

          // ======================================================
          // READ REACTION COUNTS
          // ======================================================

          final rawReactions =
              data["reactions"];

          final Map<String, dynamic>
              reactions =
              rawReactions is Map
                  ? Map<String, dynamic>.from(
                      rawReactions,
                    )
                  : {};

          // ======================================================
          // READ REACTION USERS
          // ======================================================

          final rawReactionUsers =
              data["reactionUsers"];

          final Map<String, dynamic>
              reactionUsers =
              rawReactionUsers is Map
                  ? Map<String, dynamic>.from(
                      rawReactionUsers,
                    )
                  : {};

          // ======================================================
          // GET USERS FOR THIS EMOJI
          // ======================================================

          final rawUsers =
              reactionUsers[cleanEmoji];

          final Map<String, dynamic>
              usersForEmoji =
              rawUsers is Map
                  ? Map<String, dynamic>.from(
                      rawUsers,
                    )
                  : {};

          final bool alreadyReacted =
              usersForEmoji.containsKey(
            currentUserId,
          );

          // ======================================================
          // REMOVE REACTION
          // ======================================================

          if (alreadyReacted) {
            usersForEmoji.remove(
              currentUserId,
            );

            int currentCount = 0;

            final existingCount =
                reactions[cleanEmoji];

            if (existingCount is int) {
              currentCount =
                  existingCount;
            } else if (existingCount
                is num) {
              currentCount =
                  existingCount.toInt();
            }

            final newCount =
                currentCount > 0
                    ? currentCount - 1
                    : 0;

            if (newCount <= 0) {
              reactions.remove(
                cleanEmoji,
              );

              reactionUsers.remove(
                cleanEmoji,
              );
            } else {
              reactions[cleanEmoji] =
                  newCount;

              reactionUsers[cleanEmoji] =
                  usersForEmoji;
            }
          }

          // ======================================================
          // ADD REACTION
          // ======================================================

          else {
            usersForEmoji[
                    currentUserId] =
                true;

            int currentCount = 0;

            final existingCount =
                reactions[cleanEmoji];

            if (existingCount is int) {
              currentCount =
                  existingCount;
            } else if (existingCount
                is num) {
              currentCount =
                  existingCount.toInt();
            }

            reactions[cleanEmoji] =
                currentCount + 1;

            reactionUsers[cleanEmoji] =
                usersForEmoji;
          }

          // ======================================================
          // SAVE EVERYTHING AT ONCE
          // ======================================================

          transaction.update(
            messageRef,
            {
              "reactions": reactions,
              "reactionUsers":
                  reactionUsers,
            },
          );
        },
      );

      debugPrint(
        "ChattªX reaction toggled: "
        "$cleanEmoji "
        "on $messageId",
      );
    } catch (e) {
      debugPrint(
        "ChattªX toggle reaction error: $e",
      );
    }
  }

  // ============================================================
  // ADD REACTION
  // ============================================================
  //
  // Kept for compatibility with your existing UI.
  //
  // If your current MessageBubble calls:
  //
  // chatService.addReaction(...)
  //
  // it will still work.
  //
  // It now uses the proper toggle system.
  //
  // ============================================================

  Future<void> addReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    await toggleReaction(
      chatId,
      messageId,
      emoji,
    );
  }

  // ============================================================
  // REMOVE REACTION
  // ============================================================

  Future<void> removeReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty ||
        messageId.isEmpty) {
      return;
    }

    final cleanEmoji =
        emoji.trim();

    if (cleanEmoji.isEmpty) {
      return;
    }

    try {
      final messageRef = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            messageRef,
          );

          if (!snapshot.exists) {
            return;
          }

          final data =
              snapshot.data();

          if (data == null) {
            return;
          }

          final rawReactions =
              data["reactions"];

          final rawReactionUsers =
              data["reactionUsers"];

          final Map<String, dynamic>
              reactions =
              rawReactions is Map
                  ? Map<String, dynamic>.from(
                      rawReactions,
                    )
                  : {};

          final Map<String, dynamic>
              reactionUsers =
              rawReactionUsers is Map
                  ? Map<String, dynamic>.from(
                      rawReactionUsers,
                    )
                  : {};

          final rawUsers =
              reactionUsers[cleanEmoji];

          final Map<String, dynamic>
              usersForEmoji =
              rawUsers is Map
                  ? Map<String, dynamic>.from(
                      rawUsers,
                    )
                  : {};

          if (!usersForEmoji
              .containsKey(
            currentUserId,
          )) {
            return;
          }

          usersForEmoji.remove(
            currentUserId,
          );

          int currentCount = 0;

          final existingCount =
              reactions[cleanEmoji];

          if (existingCount is int) {
            currentCount =
                existingCount;
          } else if (existingCount
              is num) {
            currentCount =
                existingCount.toInt();
          }

          final newCount =
              currentCount > 0
                  ? currentCount - 1
                  : 0;

          if (newCount <= 0) {
            reactions.remove(
              cleanEmoji,
            );

            reactionUsers.remove(
              cleanEmoji,
            );
          } else {
            reactions[cleanEmoji] =
                newCount;

            reactionUsers[cleanEmoji] =
                usersForEmoji;
          }

          transaction.update(
            messageRef,
            {
              "reactions": reactions,
              "reactionUsers":
                  reactionUsers,
            },
          );
        },
      );

      debugPrint(
        "ChattªX reaction removed: "
        "$cleanEmoji",
      );
    } catch (e) {
      debugPrint(
        "ChattªX remove reaction error: $e",
      );
    }
  }

  // ============================================================
  // CHECK IF CURRENT USER REACTED
  // ============================================================

  bool hasUserReacted(
    Map<String, dynamic>? messageData,
    String emoji,
  ) {
    if (currentUserId.isEmpty) {
      return false;
    }

    if (messageData == null) {
      return false;
    }

    final rawReactionUsers =
        messageData["reactionUsers"];

    if (rawReactionUsers is! Map) {
      return false;
    }

    final rawUsers =
        rawReactionUsers[emoji];

    if (rawUsers is! Map) {
      return false;
    }

    return rawUsers.containsKey(
      currentUserId,
    );
  }

  // ============================================================
  // GET REACTION COUNT
  // ============================================================

  int getReactionCount(
    Map<String, dynamic>? messageData,
    String emoji,
  ) {
    if (messageData == null) {
      return 0;
    }

    final rawReactions =
        messageData["reactions"];

    if (rawReactions is! Map) {
      return 0;
    }

    final value =
        rawReactions[emoji];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  // ============================================================
  // ONLINE STATUS
  // ============================================================

  Future<void> setOnline() async {
    if (currentUserId.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("users")
          .doc(currentUserId)
          .set(
        {
          "isOnline": true,
          "lastSeen":
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      debugPrint(
        "ChattªX set online error: $e",
      );
    }
  }

  // ============================================================
  // OFFLINE STATUS
  // ============================================================

  Future<void> setOffline() async {
    if (currentUserId.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("users")
          .doc(currentUserId)
          .set(
        {
          "isOnline": false,
          "lastSeen":
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      debugPrint(
        "ChattªX set offline error: $e",
      );
    }
  }

  // ============================================================
  // TYPING STATUS
  // ============================================================

  Future<void> setTyping(
    String chatId,
    bool typing,
  ) async {
    if (currentUserId.isEmpty) {
      return;
    }

    if (chatId.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .set(
        {
          "typing_$currentUserId":
              typing,
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      debugPrint(
        "ChattªX typing error: $e",
      );
    }
  }

  // ============================================================
  // SEARCH MESSAGES
  // ============================================================

  Future<List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>> searchMessages(
    String query,
  ) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final result =
          await _firestore
              .collectionGroup(
                "messages",
              )
              .where(
                "message",
                isGreaterThanOrEqualTo:
                    query,
              )
              .where(
                "message",
                isLessThan:
                    "${query}z",
              )
              .limit(20)
              .get();

      return result.docs;
    } catch (e) {
      debugPrint(
        "ChattªX search messages error: $e",
      );

      return [];
    }
  }

  // ============================================================
  // CHATTªX MESSAGE STATUS
  // ============================================================

  String getMessageStatus({
    required String status,
  }) {
    switch (status.toLowerCase()) {
      case "seen":
        return "seen";

      case "delivered":
        return "delivered";

      case "sent":
      default:
        return "sent";
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  int getMessageStatusColor({
    required String status,
  }) {
    switch (status.toLowerCase()) {
      case "seen":
        return 0xff9C27FF;

      case "delivered":
        return 0xff00E5FF;

      case "sent":
      default:
        return 0xff7A7A7A;
    }
  }

  // ============================================================
  // STATUS SYMBOL
  // ============================================================

  String getMessageStatusSymbol({
    required String status,
  }) {
    switch (status.toLowerCase()) {
      case "seen":
        return "∞";

      case "delivered":
        return "∞";

      case "sent":
      default:
        return "∞";
    }
  }
}