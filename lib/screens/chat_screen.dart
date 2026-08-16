import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../screens/calls/outgoing_voice_call_screen.dart';
import '../location/live_location_controller.dart';
import '../location/live_location_duration_sheet.dart';
import '../location/live_location_session.dart';
import '../screens/maps/chatex_map_screen.dart';
import '../screens/user_profile_view_screen.dart';
import '../services/call_service.dart';
import '../services/chat_message_cache_service.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/message_menu.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_recorder.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverImage;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final ChatService _chatService = ChatService();

  final ChatMessageCacheService _messageCache =
      ChatMessageCacheService();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _controller =
      TextEditingController();

  final TextEditingController _reactionEmojiController =
      TextEditingController();

  final FocusNode _reactionEmojiFocusNode =
      FocusNode();

  final ScrollController _scrollController =
      ScrollController();

  final GlobalKey _messageListKey =
      GlobalKey();

  // ============================================================
  // MESSAGE KEYS
  // ============================================================

  final Map<String, GlobalKey> _messageKeys = {};

  // ============================================================
  // SUBSCRIPTIONS / TIMERS
  // ============================================================

  Timer? _typingTimer;

  StreamSubscription? _typingSubscription;
  StreamSubscription? _receiverStatusSubscription;
  StreamSubscription? _messagesSubscription;

  StreamSubscription?
      _currentUserVerificationSubscription;

  StreamSubscription?
      _receiverVerificationSubscription;

  StreamSubscription? _liveLocationSubscription;

  // ============================================================
  // MESSAGE STATE
  // ============================================================

  List<Map<String, dynamic>> _currentMessages = [];

  List<Map<String, dynamic>> cachedMessages = [];

  bool _firestoreHasLoadedMessages = false;

  bool _isInitialMessageLoad = true;

  // ============================================================
  // UI STATE
  // ============================================================

  bool typing = false;

  bool recording = false;

  bool showQuickActions = true;

  String receiverStatus = "Offline";

  String currentDateLabel = "";

  // ============================================================
  // SELECTION / REACTIONS
  // ============================================================

  String? _selectedMessageId;

  String? _reactionMessageId;

  bool _processingReactionEmoji = false;

  // ============================================================
  // REPLY
  // ============================================================

  String? replyingMessage;

  // ============================================================
  // VERIFICATION
  // ============================================================

  bool receiverIsVerified = false;

  bool currentUserIsVerified = false;

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  late final ChattaXLiveLocationController
      _liveLocationController;

  bool _startingLiveLocation = false;

  bool _liveLocationMessageSent = false;

  String? _liveLocationMessageId;

  // ============================================================
  // GETTERS
  // ============================================================

  String get currentUser =>
      _auth.currentUser?.uid ?? "";

  bool get hasSelectedMessage =>
      _selectedMessageId != null;

  String get chatId {
    final users = <String>[
      currentUser,
      widget.receiverId,
    ];

    users.sort();

    return users.join("_");
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _liveLocationController =
        ChattaXLiveLocationController();

    _loadCachedMessages();

    _chatService.setOnline();

    _resetUnreadCount();

    _listenToMessages();

    _listenToTyping();

    _listenToReceiverStatus();

    _listenToVerificationStatus();

    _loadExistingLiveLocationSession();

    Future.microtask(
      _markMessagesAsSeen,
    );

    _scrollController.addListener(
      _onScroll,
    );
  }

  // ============================================================
  // CACHE
  // ============================================================

  void _loadCachedMessages() {
    final cached =
        _messageCache.getMessages(chatId);

    if (cached.isEmpty) {
      debugPrint(
        "ChattªX CACHE: No cached messages for $chatId.",
      );
      return;
    }

    cachedMessages =
        List<Map<String, dynamic>>.from(
      cached,
    );

    _currentMessages =
        List<Map<String, dynamic>>.from(
      cached,
    );

    _isInitialMessageLoad = false;

    debugPrint(
      "ChattªX CACHE: "
      "${cached.length} messages loaded immediately.",
    );
  }

  // ============================================================
  // FIRESTORE MESSAGE LISTENER
  // ============================================================

  void _listenToMessages() {
    _messagesSubscription?.cancel();

    _messagesSubscription = _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .collection("messages")
        .orderBy(
          "timestamp",
          descending: false,
        )
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) {
          return;
        }

        final firestoreMessages =
            snapshot.docs
                .map<Map<String, dynamic>>(
          (doc) {
            return {
              ...doc.data(),
              "_id": doc.id,
            };
          },
        ).toList();

        _firestoreHasLoadedMessages = true;

        if (firestoreMessages.isEmpty) {
          debugPrint(
            "ChattªX FIRESTORE: No messages returned.",
          );

          if (_currentMessages.isEmpty &&
              _isInitialMessageLoad) {
            setState(() {
              _isInitialMessageLoad = false;
            });
          }

          return;
        }

        _messageCache.saveMessages(
          chatId,
          firestoreMessages,
        );

        final changed = !_listsAreEqual(
          _currentMessages,
          firestoreMessages,
        );

        if (!changed &&
            !_isInitialMessageLoad) {
          return;
        }

        setState(() {
          _currentMessages =
              List<Map<String, dynamic>>.from(
            firestoreMessages,
          );

          cachedMessages =
              List<Map<String, dynamic>>.from(
            firestoreMessages,
          );

          _isInitialMessageLoad = false;
        });

        debugPrint(
          "ChattªX FIRESTORE: "
          "${firestoreMessages.length} messages received.",
        );
      },
      onError: (error) {
        debugPrint(
          "ChattªX MESSAGE LISTENER ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // COMPLETE MESSAGE COMPARISON
  // ============================================================

  bool _listsAreEqual(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (!_mapsAreEqual(
        a[i],
        b[i],
      )) {
        return false;
      }
    }

    return true;
  }

  bool _mapsAreEqual(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (final key in a.keys) {
      if (!b.containsKey(key)) {
        return false;
      }

      if (!_valuesAreEqual(
        a[key],
        b[key],
      )) {
        return false;
      }
    }

    return true;
  }

  bool _valuesAreEqual(
    dynamic a,
    dynamic b,
  ) {
    if (identical(a, b)) {
      return true;
    }

    if (a is Timestamp &&
        b is Timestamp) {
      return a.seconds == b.seconds &&
          a.nanoseconds == b.nanoseconds;
    }

    if (a is DateTime &&
        b is DateTime) {
      return a.isAtSameMomentAs(b);
    }

    if (a is Map &&
        b is Map) {
      if (a.length != b.length) {
        return false;
      }

      for (final key in a.keys) {
        if (!b.containsKey(key)) {
          return false;
        }

        if (!_valuesAreEqual(
          a[key],
          b[key],
        )) {
          return false;
        }
      }

      return true;
    }

    if (a is List &&
        b is List) {
      if (a.length != b.length) {
        return false;
      }

      for (int i = 0; i < a.length; i++) {
        if (!_valuesAreEqual(
          a[i],
          b[i],
        )) {
          return false;
        }
      }

      return true;
    }

    return a == b;
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _onScroll() {
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _updateCurrentDateLabel();
      },
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  String getDateLabel(
    DateTime date,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final messageDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference =
        today
            .difference(messageDay)
            .inDays;

    if (difference == 0) {
      return "Today";
    }

    if (difference == 1) {
      return "Yesterday";
    }

    if (difference > 1 &&
        difference < 7) {
      return DateFormat(
        "EEEE",
      ).format(date);
    }

    return DateFormat(
      "dd MMMM yyyy",
    ).format(date);
  }

  // ============================================================
  // DATE SCROLL LABEL
  // ============================================================

  void _updateCurrentDateLabel() {
    if (!mounted ||
        !_scrollController.hasClients ||
        _currentMessages.isEmpty) {
      return;
    }

    final listContext =
        _messageListKey.currentContext;

    if (listContext == null) {
      return;
    }

    final renderObject =
        listContext.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final listTop =
        renderObject
            .localToGlobal(
              Offset.zero,
            )
            .dy;

    if (_scrollController.offset <= 20) {
      final newest =
          _currentMessages.last;

      final date =
          _messageDate(
        newest["timestamp"],
      );

      if (date == null) {
        return;
      }

      final label =
          getDateLabel(date);

      if (label != currentDateLabel) {
        setState(() {
          currentDateLabel = label;
        });
      }

      return;
    }

    Map<String, dynamic>? visibleMessage;

    double closestTop =
        double.infinity;

    for (final message
        in _currentMessages) {
      final id =
          message["_id"]?.toString() ?? "";

      if (id.isEmpty) {
        continue;
      }

      final key = _messageKeys[id];

      if (key == null) {
        continue;
      }

      final context =
          key.currentContext;

      if (context == null) {
        continue;
      }

      final object =
          context.findRenderObject();

      if (object is! RenderBox) {
        continue;
      }

      final position =
          object.localToGlobal(
        Offset.zero,
      );

      final top = position.dy;

      final bottom =
          top + object.size.height;

      if (bottom <= listTop) {
        continue;
      }

      if (top <= listTop &&
          bottom > listTop) {
        visibleMessage = message;
        break;
      }

      if (top >= listTop &&
          top < closestTop) {
        closestTop = top;
        visibleMessage = message;
      }
    }

    if (visibleMessage == null) {
      return;
    }

    final date =
        _messageDate(
      visibleMessage["timestamp"],
    );

    if (date == null) {
      return;
    }

    final label =
        getDateLabel(date);

    if (label != currentDateLabel) {
      setState(() {
        currentDateLabel = label;
      });
    }
  }

  DateTime? _messageDate(
    dynamic timestamp,
  ) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    return null;
  }

  // ============================================================
  // UNREAD
  // ============================================================

  Future<void> _resetUnreadCount() async {
    if (currentUser.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .set(
        {
          "unread_$currentUser": 0,
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      debugPrint(
        "ChattªX RESET UNREAD ERROR: $e",
      );
    }
  }

  // ============================================================
  // SEEN
  // ============================================================

  Future<void> _markMessagesAsSeen() async {
    if (currentUser.isEmpty) {
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
                isEqualTo: currentUser,
              )
              .where(
                "seen",
                isEqualTo: false,
              )
              .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch =
          _firestore.batch();

      for (final doc in snapshot.docs) {
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

      final chatRoomRef =
          _firestore
              .collection("chat_rooms")
              .doc(chatId);

      final chatRoom =
          await chatRoomRef.get();

      final data =
          chatRoom.data() ?? {};

      final lastSender =
          data["lastSenderId"];

      if (lastSender != currentUser) {
        batch.set(
          chatRoomRef,
          {
            "lastMessageStatus": "seen",
            "lastInfinity": "seen",
            "unread_$currentUser": 0,
          },
          SetOptions(
            merge: true,
          ),
        );
      } else {
        batch.set(
          chatRoomRef,
          {
            "unread_$currentUser": 0,
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      debugPrint(
        "ChattªX: "
        "${snapshot.docs.length} messages marked as seen.",
      );
    } catch (e) {
      debugPrint(
        "ChattªX MARK SEEN ERROR: $e",
      );
    }
  }

  // ============================================================
  // TYPING
  // ============================================================

  void handleTyping(String value) {
    final id =
        _chatService.getChatId(
      widget.receiverId,
    );

    _chatService.setTyping(
      id,
      true,
    );

    _typingTimer?.cancel();

    _typingTimer = Timer(
      const Duration(seconds: 2),
      () {
        _chatService.setTyping(
          id,
          false,
        );
      },
    );
  }

  void _listenToTyping() {
    _typingSubscription?.cancel();

    final key =
        "typing_${widget.receiverId}";

    _typingSubscription =
        _firestore
            .collection("chat_rooms")
            .doc(chatId)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted ||
            !snapshot.exists) {
          return;
        }

        final data =
            snapshot.data() ?? {};

        final value =
            data[key] == true;

        if (value != typing) {
          setState(() {
            typing = value;
          });
        }
      },
      onError: (error) {
        debugPrint(
          "ChattªX TYPING ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // RECEIVER STATUS
  // ============================================================

  void _listenToReceiverStatus() {
    _receiverStatusSubscription?.cancel();

    _receiverStatusSubscription =
        _firestore
            .collection("users")
            .doc(widget.receiverId)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted ||
            !snapshot.exists) {
          return;
        }

        final data =
            snapshot.data() ?? {};

        final online =
            data["isOnline"] == true;

        String status;

        if (online) {
          status = "Online";
        } else {
          final lastSeen =
              data["lastSeen"];

          if (lastSeen is Timestamp) {
            status =
                "Last seen "
                "${TimeOfDay.fromDateTime(
                  lastSeen.toDate(),
                ).format(context)}";
          } else {
            status = "Offline";
          }
        }

        if (status != receiverStatus) {
          setState(() {
            receiverStatus = status;
          });
        }
      },
      onError: (error) {
        debugPrint(
          "ChattªX RECEIVER STATUS ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // VERIFICATION
  // ============================================================
  //
  // NOTE: Firestore stores this field as "verified" (same field
  // used by home_screen.dart). This must stay in sync with that
  // field name or the tick will silently stop working again.
  // ============================================================

  void _listenToVerificationStatus() {
    _currentUserVerificationSubscription?.cancel();

    _receiverVerificationSubscription?.cancel();

    _currentUserVerificationSubscription =
        _firestore
            .collection("users")
            .doc(currentUser)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted) {
          return;
        }

        final data =
            snapshot.data();

        final verified =
            data?["verified"] == true;

        if (verified !=
            currentUserIsVerified) {
          setState(() {
            currentUserIsVerified =
                verified;
          });
        }
      },
      onError: (error) {
        debugPrint(
          "ChattªX CURRENT VERIFICATION ERROR: $error",
        );
      },
    );

    _receiverVerificationSubscription =
        _firestore
            .collection("users")
            .doc(widget.receiverId)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted) {
          return;
        }

        final data =
            snapshot.data();

        final verified =
            data?["verified"] == true;

        if (verified !=
            receiverIsVerified) {
          setState(() {
            receiverIsVerified =
                verified;
          });
        }
      },
      onError: (error) {
        debugPrint(
          "ChattªX RECEIVER VERIFICATION ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // ============================================================
  // REACTIONS — FIXED
  // ============================================================
  //
  // Reactions are stored as:
  //
  // "reactions": {
  //   "❤️": ["userA", "userB"],
  //   "😂": ["userC"]
  // }
  //
  // Each user can have one instance of an emoji.
  //
  // A Firestore transaction is used so reactions cannot
  // accidentally overwrite one another.
  // ============================================================

  Future<void> _addReaction(
    String messageId,
    String emoji,
  ) async {
    final cleanEmoji = emoji.trim();

    if (messageId.isEmpty ||
        cleanEmoji.isEmpty ||
        currentUser.isEmpty) {
      return;
    }

    try {
      final messageRef =
          _firestore
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
              "Message no longer exists.",
            );
          }

          final data =
              snapshot.data() ??
                  <String, dynamic>{};

          final rawReactions =
              data["reactions"];

          final Map<String, List<String>>
              reactions = {};

          if (rawReactions is Map) {
            rawReactions.forEach(
              (key, value) {
                final reactionEmoji =
                    key.toString();

                if (value is List) {
                  reactions[reactionEmoji] =
                      value
                          .map(
                            (user) =>
                                user.toString(),
                          )
                          .toList();
                } else if (value is String) {
                  reactions[reactionEmoji] = [
                    value,
                  ];
                }
              },
            );
          }

          // ------------------------------------------------------
          // Remove this user from every existing reaction.
          //
          // This guarantees that one user does not accidentally
          // end up reacting multiple times to the same message.
          // ------------------------------------------------------

          final emptyReactionKeys =
              <String>[];

          reactions.forEach(
            (reactionEmoji, users) {
              users.removeWhere(
                (userId) =>
                    userId == currentUser,
              );

              if (users.isEmpty) {
                emptyReactionKeys.add(
                  reactionEmoji,
                );
              }
            },
          );

          for (final key
              in emptyReactionKeys) {
            reactions.remove(key);
          }

          // ------------------------------------------------------
          // Add the new reaction.
          // ------------------------------------------------------

          final users =
              reactions.putIfAbsent(
            cleanEmoji,
            () => <String>[],
          );

          if (!users.contains(currentUser)) {
            users.add(currentUser);
          }

          // ------------------------------------------------------
          // Convert to Firestore-safe data.
          // ------------------------------------------------------

          final Map<String, dynamic>
              firestoreReactions = {};

          reactions.forEach(
            (reactionEmoji, userIds) {
              firestoreReactions[
                  reactionEmoji] =
                  List<String>.from(
                userIds,
              );
            },
          );

          transaction.update(
            messageRef,
            {
              "reactions":
                  firestoreReactions,
            },
          );
        },
      );

      debugPrint(
        "ChattªX REACTION ADDED: "
        "$cleanEmoji -> $messageId",
      );

      if (!mounted) {
        return;
      }

      _reactionEmojiController.clear();

      FocusManager.instance.primaryFocus
          ?.unfocus();

      _closeSelection();
    } catch (e) {
      debugPrint(
        "ChattªX REACTION ERROR: $e",
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't add reaction",
          ),
        ),
      );
    }
  }

  // ============================================================
  // CUSTOM EMOJI INPUT
  // ============================================================

  Future<void> _handleReactionEmojiInput(
    String value,
  ) async {
    if (_processingReactionEmoji) {
      return;
    }

    final emoji = value.trim();

    if (emoji.isEmpty) {
      return;
    }

    final messageId =
        _reactionMessageId;

    if (messageId == null ||
        messageId.isEmpty) {
      _reactionEmojiController.clear();
      return;
    }

    _processingReactionEmoji = true;

    try {
      await _addReaction(
        messageId,
        emoji,
      );
    } finally {
      _processingReactionEmoji = false;
    }
  }

  void _openReactionEmojiKeyboard(
    String messageId,
  ) {
    if (messageId.isEmpty) {
      return;
    }

    setState(() {
      _reactionMessageId = messageId;
    });

    _reactionEmojiController.clear();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _reactionEmojiFocusNode.requestFocus();

        SystemChannels.textInput.invokeMethod(
          "TextInput.show",
        );
      },
    );
  }

  // ============================================================
  // MESSAGE SELECTION
  // ============================================================

  void _selectMessage(
    String messageId,
  ) {
    if (messageId.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedMessageId = messageId;
      _reactionMessageId = messageId;
    });
  }

  void _closeSelection() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMessageId = null;
      _reactionMessageId = null;
    });
  }

  // ============================================================
  // REPLY
  // ============================================================

  void _startReply(
    Map<String, dynamic> message,
    String type,
  ) {
    setState(() {
      replyingMessage =
          type == "voice"
              ? "🎤 Voice message"
              : (message["message"] ?? "")
                  .toString();

      _selectedMessageId = null;
      _reactionMessageId = null;
    });

    FocusScope.of(context).unfocus();
  }

  // ============================================================
  // STAR
  // ============================================================

  bool _isMessageStarred(
    Map<String, dynamic> message,
  ) {
    final starredBy =
        message["starredBy"];

    if (starredBy is! List) {
      return false;
    }

    return starredBy.contains(
      currentUser,
    );
  }

  Future<void> _toggleStar(
    String messageId,
    Map<String, dynamic> message,
  ) async {
    if (messageId.isEmpty) {
      return;
    }

    try {
      final starred =
          _isMessageStarred(message);

      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "starredBy": starred
            ? FieldValue.arrayRemove([
                currentUser,
              ])
            : FieldValue.arrayUnion([
                currentUser,
              ]),
      });

      _closeSelection();
    } catch (e) {
      debugPrint(
        "ChattªX STAR ERROR: $e",
      );
    }
  }

  // ============================================================
  // SEND TEXT MESSAGE
  // ============================================================

  Future<void> sendMessage({
    bool frozen = false,
  }) async {
    final text =
        _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    final reply =
        replyingMessage;

    _controller.clear();

    setState(() {
      replyingMessage = null;
      _selectedMessageId = null;
      _reactionMessageId = null;
    });

    FocusScope.of(context).unfocus();

    try {
      await _chatService.sendMessage(
        widget.receiverId,
        widget.receiverName,
        text,
        isFrozen: frozen,
        replyTo: reply,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint(
        "ChattªX SEND MESSAGE ERROR: $e",
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          0,
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // LOCATION OPTIONS
  // ============================================================

  Future<void> _showLocationOptions() async {
    if (!mounted) {
      return;
    }

    final choice =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor:
          const Color(0xff080D18),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const Text(
                  "Share location",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Choose how you want to share your location.",
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(0xff00B85A),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    "Current location",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    "Send your location once",
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      "current",
                    );
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(0xffFF3158),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: const Text(
                    "Live location",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    "Share your movement in real time",
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      "live",
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (choice == "current") {
      await _sendLocation();
    } else if (choice == "live") {
      await _startLiveLocationFromChat();
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _sendLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        final open =
            await showDialog<bool>(
          context: context,
          builder: (_) {
            return AlertDialog(
              backgroundColor:
                  const Color(0xff111827),
              title: const Text(
                "Location is turned off",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              content: const Text(
                "Turn on your phone's location services so ChattªX can find your current location.",
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      false,
                    );
                  },
                  child: const Text(
                    "Cancel",
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      true,
                    );
                  },
                  child: const Text(
                    "Turn On",
                    style: TextStyle(
                      color:
                          Color(0xff00E5FF),
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (open == true) {
          await Geolocator
              .openLocationSettings();
        }

        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Location permission was denied.",
              ),
            ),
          );
        }

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          final open =
              await showDialog<bool>(
            context: context,
            builder: (_) {
              return AlertDialog(
                backgroundColor:
                    const Color(0xff111827),
                title: const Text(
                  "Location permission required",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                content: const Text(
                  "Location permission has been permanently denied. Open ChattªX settings and allow location access.",
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        false,
                      );
                    },
                    child:
                        const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        true,
                      );
                    },
                    child: const Text(
                      "Open Settings",
                    ),
                  ),
                ],
              );
            },
          );

          if (open == true) {
            await Geolocator
                .openAppSettings();
          }
        }

        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "Getting your location...",
                ),
              ],
            ),
            duration:
                Duration(seconds: 3),
          ),
        );
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          timeLimit:
              Duration(seconds: 15),
        ),
      );

      final messageRef =
          _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .doc();

      await messageRef.set({
        "senderId": currentUser,
        "receiverId": widget.receiverId,
        "message": "📍 Current location",
        "type": "location",
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp":
            FieldValue.serverTimestamp(),
        "seen": false,
        "delivered": false,
        "isFrozen": false,
        "isMelted": false,
        "reactions": {},
        "replyTo": null,
      });

      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .set(
        {
          "participants": [
            currentUser,
            widget.receiverId,
          ],
          "lastMessage": "📍 Location",
          "lastMessageTime":
              FieldValue.serverTimestamp(),
          "lastSenderId": currentUser,
          "lastInfinity": "sent",
          "unread_${widget.receiverId}":
              FieldValue.increment(1),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "📍 Location sent",
            ),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't get your location. Please try again.",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX SEND LOCATION ERROR: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't send location: $e",
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // OPEN LOCATION
  // ============================================================

  void _openLocationMessage(
    Map<String, dynamic> message,
  ) {
    final latitude =
        _toDouble(message["latitude"]);

    final longitude =
        _toDouble(message["longitude"]);

    if (latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Location information is unavailable.",
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatexMapScreen(
          latitude: latitude,
          longitude: longitude,
          title:
              message["message"]
                      ?.toString() ??
                  "Shared location",
          mode:
              message["type"] ==
                      "live_location"
                  ? "live_location"
                  : "location",
        ),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? "",
    );
  }

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  Future<void>
      _loadExistingLiveLocationSession() async {
    try {
      final session =
          await _liveLocationController
              .loadExistingSession();

      if (session == null ||
          !mounted) {
        return;
      }

      final messages =
          await _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .where(
                "sessionId",
                isEqualTo:
                    session.sessionId,
              )
              .limit(1)
              .get();

      if (messages.docs.isEmpty) {
        return;
      }

      _liveLocationMessageId =
          messages.docs.first.id;

      _liveLocationMessageSent = true;

      _startLiveLocationTracking();
    } catch (e) {
      debugPrint(
        "ChattªX LOAD LIVE LOCATION ERROR: $e",
      );
    }
  }

  void _startLiveLocationTracking() {
    _liveLocationSubscription?.cancel();

    _liveLocationSubscription =
        _liveLocationController.positionStream
            .listen(
      (position) async {
        try {
          if (!_liveLocationController
              .hasActiveSession) {
            await _liveLocationSubscription
                ?.cancel();

            _liveLocationSubscription = null;

            return;
          }

          final updated =
              await _liveLocationController
                  .updateLiveLocation(
            position,
          );

          if (!updated) {
            return;
          }

          final messageId =
              _liveLocationMessageId;

          if (messageId == null ||
              messageId.isEmpty) {
            return;
          }

          await _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .doc(messageId)
              .update({
            "latitude":
                position.latitude,
            "longitude":
                position.longitude,
            "isLive": true,
            "isActive": true,
            "lastUpdatedAt":
                FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint(
            "ChattªX LIVE LOCATION UPDATE ERROR: $e",
          );
        }
      },
    );
  }

  Future<void>
      _startLiveLocationFromChat() async {
    if (_startingLiveLocation) {
      return;
    }

    if (_liveLocationController
        .hasActiveSession) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Live location is already active.",
            ),
          ),
        );
      }

      return;
    }

    _startingLiveLocation = true;

    try {
      final duration =
          await ChattaXLiveLocationDurationSheet
              .show(context);

      if (duration == null ||
          !mounted) {
        return;
      }

      _liveLocationMessageSent = false;
      _liveLocationMessageId = null;

      final session =
          await _liveLocationController
              .startLiveLocation(
        duration: duration,
      );

      if (session == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Unable to start live location.",
            ),
          ),
        );

        return;
      }

      await _sendLiveLocationMessage(
        session,
      );

      if (!_liveLocationMessageSent) {
        return;
      }

      _startLiveLocationTracking();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "🔴 Live location started.",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX START LIVE LOCATION ERROR: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              "Unable to start live location: $e",
            ),
          ),
        );
      }
    } finally {
      _startingLiveLocation = false;
    }
  }

  Future<void> _sendLiveLocationMessage(
    ChattaXLiveLocationSession session,
  ) async {
    if (_liveLocationMessageSent ||
        currentUser.isEmpty) {
      return;
    }

    final messageRef =
        _firestore
            .collection("chat_rooms")
            .doc(chatId)
            .collection("messages")
            .doc();

    _liveLocationMessageId =
        messageRef.id;

    await messageRef.set({
      "senderId": currentUser,
      "receiverId": widget.receiverId,
      "message": "🔴 Live location",
      "type": "live_location",
      "latitude": session.latitude,
      "longitude": session.longitude,
      "sessionId": session.sessionId,
      "duration": session.duration.name,
      "startedAt":
          Timestamp.fromDate(
        session.startedAt,
      ),
      "expiresAt":
          Timestamp.fromDate(
        session.expiresAt,
      ),
      "isLive": true,
      "isActive": true,
      "lastUpdatedAt":
          FieldValue.serverTimestamp(),
      "timestamp":
          FieldValue.serverTimestamp(),
      "seen": false,
      "delivered": false,
      "isFrozen": false,
      "isMelted": false,
      "reactions": {},
      "replyTo": null,
    });

    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "participants": [
          currentUser,
          widget.receiverId,
        ],
        "lastMessage":
            "🔴 Live location",
        "lastMessageTime":
            FieldValue.serverTimestamp(),
        "lastSenderId": currentUser,
        "lastInfinity": "sent",
        "unread_${widget.receiverId}":
            FieldValue.increment(1),
      },
      SetOptions(
        merge: true,
      ),
    );

    _liveLocationMessageSent = true;
  }

  // ============================================================
  // STOP LIVE LOCATION
  // ============================================================

  Future<void> _stopLiveLocationMessage() async {
    final messageId =
        _liveLocationMessageId;

    if (messageId == null ||
        messageId.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "isLive": false,
        "isActive": false,
        "endedAt":
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint(
        "ChattªX STOP LIVE LOCATION ERROR: $e",
      );
    }
  }

  // ============================================================
  // VOICE CALL
  // ============================================================

  Future<void> _startOutgoingVoiceCall() async {
    if (currentUser.isEmpty) {
      return;
    }

    try {
      final ChattaxCall? call =
          await ChattaxCallService
              .instance
              .startAudioCall(
        widget.receiverId,
      );

      if (call == null) {
        throw Exception(
          "Unable to start the call.",
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OutgoingVoiceCallScreen(
            callerName:
                widget.receiverName,
            profileImageUrl:
                widget.receiverImage,
            callId: call.callId,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        "ChattªX OUTGOING CALL ERROR: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              "Unable to start the call: $e",
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (currentUser.isEmpty) {
      return const Scaffold(
        backgroundColor:
            Color(0xff090E18),
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xff090E18),
      body: GestureDetector(
        behavior:
            HitTestBehavior.translucent,
        onTap: () {
          if (hasSelectedMessage) {
            _closeSelection();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                "assets/chat_background.png",
                fit: BoxFit.cover,
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  ChatHeader(
  name: widget.receiverName,
  status: receiverStatus,
  image: widget.receiverImage ?? "",
  userId: widget.receiverId,
  isVerified: receiverIsVerified,
  isOnline: receiverStatus == "Online",
  isTyping: typing,
  showQuickActions: showQuickActions,

  onBack: () {
    Navigator.pop(context);
  },

  onNameTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileViewScreen(
          userId: widget.receiverId,
          userName: widget.receiverName,
          userImage: widget.receiverImage,
        ),
      ),
    );
  },

  onVoiceCall: _startOutgoingVoiceCall,

  onVideoCall: () {},

  onMenu: () {},
),
              

                  Expanded(
                    child:
                        _buildMessageArea(),
                  ),

                  _buildComposer(),
                ],
              ),
            ),

            // ==================================================
            // HIDDEN EMOJI INPUT
            // ==================================================

            Positioned(
              left: 0,
              bottom: 0,
              child: SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    controller:
                        _reactionEmojiController,
                    focusNode:
                        _reactionEmojiFocusNode,
                    keyboardType:
                        TextInputType.text,
                    textInputAction:
                        TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions:
                        false,
                    onChanged:
                        _handleReactionEmojiInput,
                    decoration:
                        const InputDecoration(
                      border:
                          InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE AREA
  // ============================================================

  Widget _buildMessageArea() {
    if (_currentMessages.isNotEmpty) {
      return _buildMessageList(
        _currentMessages,
      );
    }

    if (_firestoreHasLoadedMessages) {
      return const Center(
        child: Text(
          "No messages yet",
          style: TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    return const SizedBox.expand();
  }

  // ============================================================
  // MESSAGE LIST
  // ============================================================

  Widget _buildMessageList(
    List<Map<String, dynamic>> messages,
  ) {
    _prepareMessageKeys(messages);

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _updateCurrentDateLabel();
        }
      },
    );

    return Stack(
      children: [
        ListView.builder(
          key: _messageListKey,
          controller:
              _scrollController,
          reverse: true,
          padding:
              const EdgeInsets.only(
            top: 8,
            bottom: 10,
          ),
          itemCount: messages.length,
          itemBuilder:
              (context, index) {
            final actualIndex =
                messages.length -
                    1 -
                    index;

            final message =
                messages[actualIndex];

            return _buildMessageItem(
              messages: messages,
              message: message,
              actualIndex:
                  actualIndex,
            );
          },
        ),

        if (currentDateLabel.isNotEmpty)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xff151515),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Text(
                    currentDateLabel,
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // MESSAGE KEYS
  // ============================================================

  void _prepareMessageKeys(
    List<Map<String, dynamic>> messages,
  ) {
    final existingIds = <String>{};

    for (final message in messages) {
      final id =
          message["_id"]?.toString() ?? "";

      if (id.isEmpty) {
        continue;
      }

      existingIds.add(id);

      _messageKeys.putIfAbsent(
        id,
        GlobalKey.new,
      );
    }

    _messageKeys.removeWhere(
      (id, key) =>
          !existingIds.contains(id),
    );
  }

  // ============================================================
  // MESSAGE ITEM
  // ============================================================

  Widget _buildMessageItem({
    required List<Map<String, dynamic>>
        messages,
    required Map<String, dynamic>
        message,
    required int actualIndex,
  }) {
    final messageId =
        message["_id"]?.toString() ?? "";

    final isMe =
        message["senderId"] ==
            currentUser;

    final type =
        message["type"]?.toString() ??
            "text";

    final messageDate =
        _messageDate(
      message["timestamp"],
    );

    final showDateSeparator =
        _shouldShowDateSeparator(
      messages,
      actualIndex,
    );

    final isSelected =
        _selectedMessageId ==
            messageId;

    final anotherSelected =
        hasSelectedMessage &&
            !isSelected;

    return Column(
      key: _messageKeys[messageId],
      children: [
        if (showDateSeparator &&
            messageDate != null)
          _buildDateSeparator(
            messageDate,
          ),

        GestureDetector(
          behavior:
              HitTestBehavior.opaque,
          onLongPress: () {
            _selectMessage(
              messageId,
            );
          },
          child: AnimatedOpacity(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            opacity:
                anotherSelected
                    ? 0.35
                    : 1,
            child: ImageFiltered(
              imageFilter:
                  anotherSelected
                      ? ui.ImageFilter.blur(
                          sigmaX: 5.5,
                          sigmaY: 5.5,
                        )
                      : ui.ImageFilter.blur(
                          sigmaX: 0,
                          sigmaY: 0,
                        ),
              child: GestureDetector(
                behavior:
                    HitTestBehavior.opaque,
                onTap:
                    type == "location" ||
                            type ==
                                "live_location"
                        ? () {
                            _openLocationMessage(
                              message,
                            );
                          }
                        : null,
                child:
                    _buildMessageBubble(
                  message:
                      message,
                  messageId:
                      messageId,
                  isMe: isMe,
                  type: type,
                  messageDate:
                      messageDate,
                ),
              ),
            ),
          ),
        ),

        if (isSelected)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 4,
              bottom: 4,
            ),
            child:
                _buildSelectedControls(
              map: message,
              messageId: messageId,
              isMe: isMe,
              type: type,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // DATE SEPARATOR
  // ============================================================

  bool _shouldShowDateSeparator(
    List<Map<String, dynamic>> messages,
    int index,
  ) {
    if (index <= 0) {
      return false;
    }

    final currentDate =
        _messageDate(
      messages[index]["timestamp"],
    );

    final previousDate =
        _messageDate(
      messages[index - 1]["timestamp"],
    );

    if (currentDate == null ||
        previousDate == null) {
      return false;
    }

    return currentDate.year !=
            previousDate.year ||
        currentDate.month !=
            previousDate.month ||
        currentDate.day !=
            previousDate.day;
  }

  Widget _buildDateSeparator(
    DateTime date,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(0xff151515),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Text(
            getDateLabel(date),
            style:
                const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble({
    required Map<String, dynamic>
        message,
    required String messageId,
    required bool isMe,
    required String type,
    required DateTime? messageDate,
  }) {
    final voiceUrl =
        message["voiceUrl"]
                ?.toString() ??
            "";

    final voiceDuration =
        _toInt(
      message["voiceDuration"],
    );

    // ==========================================================
    // IMPORTANT:
    // Always provide MessageBubble with a proper Map<String,dynamic>
    // for reactions.
    // ==========================================================

    final Map<String, dynamic>
        reactions =
        _normaliseReactions(
      message["reactions"],
    );

    return MessageBubble(
      type: type,
      message:
          message["message"] ?? "",
      latitude:
          _toDouble(
        message["latitude"],
      ),
      longitude:
          _toDouble(
        message["longitude"],
      ),
      voiceUrl: voiceUrl,
      voiceDuration:
          voiceDuration,
      time: messageDate != null
          ? TimeOfDay.fromDateTime(
              messageDate,
            ).format(context)
          : "",
      isMe: isMe,
      isSeen:
          message["seen"] == true,
      isDelivered:
          message["delivered"] == true,
      isReply:
          message["replyTo"] != null,
      replyTo:
          message["replyTo"],
      isFrozen:
          message["isFrozen"] == true,
      isMelted:
          message["isMelted"] == true,

      // ========================================================
      // FIXED REACTIONS
      // ========================================================

      reactions: reactions,

      onMelt: () async {
        if (messageId.isEmpty) {
          return;
        }

        try {
          await _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .doc(messageId)
              .update({
            "isMelted": true,
            "meltedAt":
                FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint(
            "ChattªX MELT ERROR: $e",
          );
        }
      },
    );
  }

  // ============================================================
  // NORMALISE REACTIONS
  // ============================================================

  Map<String, dynamic> _normaliseReactions(
    dynamic raw,
  ) {
    final Map<String, dynamic>
        result = {};

    if (raw is! Map) {
      return result;
    }

    raw.forEach(
      (key, value) {
        final emoji =
            key.toString();

        if (value is List) {
          result[emoji] =
              value
                  .map(
                    (user) =>
                        user.toString(),
                  )
                  .toList();
        } else if (value is String) {
          result[emoji] = [
            value,
          ];
        }
      },
    );

    return result;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }

  // ============================================================
  // SELECTED CONTROLS
  // ============================================================

  Widget _buildSelectedControls({
    required Map<String, dynamic>
        map,
    required String messageId,
    required bool isMe,
    required String type,
  }) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        ReactionBar(
          onReactionSelected:
              (emoji) async {
            final cleanEmoji =
                emoji.trim();

            if (messageId.isEmpty ||
                cleanEmoji.isEmpty ||
                _processingReactionEmoji) {
              return;
            }

            _processingReactionEmoji =
                true;

            try {
              await _addReaction(
                messageId,
                cleanEmoji,
              );
            } finally {
              _processingReactionEmoji =
                  false;
            }
          },
          onAddEmoji: () {
            _openReactionEmojiKeyboard(
              messageId,
            );
          },
        ),

        const SizedBox(height: 5),

        _buildMessageMenu(
          map: map,
          messageId: messageId,
          isMe: isMe,
          type: type,
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGE MENU
  // ============================================================

  Widget _buildMessageMenu({
    required Map<String, dynamic>
        map,
    required String messageId,
    required bool isMe,
    required String type,
  }) {
    return MessageMenu(
      canDeleteForEveryone: isMe,

      onReply: () {
        _startReply(
          map,
          type,
        );
      },

      onCopy: () async {
        if (type == "text") {
          await Clipboard.setData(
            ClipboardData(
              text:
                  map["message"]
                      ?.toString() ??
                      "",
            ),
          );

          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Message copied",
                ),
              ),
            );
          }
        }

        _closeSelection();
      },

      onPin: () async {
        if (messageId.isEmpty) {
          return;
        }

        try {
          await _firestore
              .collection("chat_rooms")
              .doc(chatId)
              .collection("messages")
              .doc(messageId)
              .update({
            "isPinned": true,
            "pinnedBy": currentUser,
            "pinnedAt":
                FieldValue.serverTimestamp(),
          });

          _closeSelection();

          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Message pinned",
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint(
            "ChattªX PIN ERROR: $e",
          );
        }
      },

      onReport: () async {
        await _reportMessage(
          map,
          messageId,
        );
      },

      onDeleteForMe: () async {
        await _deleteForMe(
          messageId,
        );
      },

      onDeleteForEveryone: () async {
        await _deleteForEveryone(
          messageId,
          isMe,
        );
      },

      isStarred:
          _isMessageStarred(map),

      onStar: () async {
        await _toggleStar(
          messageId,
          map,
        );
      },
    );
  }

  // ============================================================
  // REPORT
  // ============================================================

  Future<void> _reportMessage(
    Map<String, dynamic> map,
    String messageId,
  ) async {
    if (messageId.isEmpty) {
      return;
    }

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              const Color(0xff111827),
          title: const Text(
            "Report message?",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            "Are you sure you want to report this message?",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                "Report",
                style: TextStyle(
                  color:
                      Colors.orangeAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _firestore
          .collection("reports")
          .add({
        "messageId": messageId,
        "chatId": chatId,
        "reportedBy": currentUser,
        "message":
            map["message"] ?? "",
        "senderId":
            map["senderId"] ?? "",
        "timestamp":
            FieldValue.serverTimestamp(),
      });

      _closeSelection();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text("Message reported"),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX REPORT ERROR: $e",
      );
    }
  }

  // ============================================================
  // DELETE FOR ME
  // ============================================================

  Future<void> _deleteForMe(
    String messageId,
  ) async {
    if (messageId.isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "deletedFor":
            FieldValue.arrayUnion([
          currentUser,
        ]),
      });

      _closeSelection();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Message deleted for you",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX DELETE FOR ME ERROR: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't delete message",
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // DELETE FOR EVERYONE
  // ============================================================

  Future<void> _deleteForEveryone(
    String messageId,
    bool isMe,
  ) async {
    if (messageId.isEmpty) {
      return;
    }

    if (!isMe) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Only the sender can delete this message for everyone.",
            ),
          ),
        );
      }

      return;
    }

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor:
              const Color(0xff111827),
          title: const Text(
            "Delete for everyone?",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            "This message will be removed for everyone in the chat.",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .delete();

      _closeSelection();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Message deleted for everyone",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "ChattªX DELETE EVERYONE ERROR: $e",
      );
    }
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  Widget _buildComposer() {
    if (recording) {
      return VoiceRecorder(
        onCancel: () {
          setState(() {
            recording = false;
          });
        },
        onSend:
            (path, duration, waveform) async {
          setState(() {
            recording = false;
          });

          try {
            final url =
                await CloudinaryService
                    .uploadVoice(
              File(path),
            );

            if (url == null) {
              return;
            }

            await _chatService
                .sendVoiceMessage(
              widget.receiverId,
              widget.receiverName,
              url,
              duration,
            );

            await _firestore
                .collection("chat_rooms")
                .doc(chatId)
                .set(
              {
                "participants": [
                  currentUser,
                  widget.receiverId,
                ],
                "lastMessage":
                    "🎤 Voice message",
                "lastMessageTime":
                    FieldValue
                        .serverTimestamp(),
                "lastSenderId":
                    currentUser,
                "lastInfinity":
                    "sent",
              },
              SetOptions(
                merge: true,
              ),
            );
          } catch (e) {
            debugPrint(
              "ChattªX VOICE SEND ERROR: $e",
            );
          }
        },
      );
    }

    return Column(
      children: [
        if (typing)
          const Padding(
            padding:
                EdgeInsets.only(
              left: 16,
              bottom: 4,
            ),
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  TypingIndicator(),
            ),
          ),

        if (replyingMessage != null &&
            replyingMessage!.isNotEmpty)
          _buildReplyPreview(),

        MessageInput(
          controller: _controller,
          onChanged: handleTyping,
          onSend: () {
            sendMessage();
          },
          onFrozenSend: () {
            sendMessage(
              frozen: true,
            );
          },
          onAttachment:
              openAttachments,
          onEmoji: () {},
          onVoiceStart: () {
            setState(() {
              recording = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      padding:
          const EdgeInsets.all(10),
      decoration:
          BoxDecoration(
        color:
            const Color(0xff131C30),
        borderRadius:
            BorderRadius.circular(12),
        border:
            const Border(
          left: BorderSide(
            color: Color(0xff00E5FF),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.reply_rounded,
            color:
                Color(0xff00E5FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              replyingMessage!,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                replyingMessage = null;
              });
            },
            icon: const Icon(
              Icons.close,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  void openAttachments() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return AttachmentSheet(
          onCamera: () {
            debugPrint(
              "ChattªX CAMERA TAPPED",
            );
          },
          onGallery: () {
            debugPrint(
              "ChattªX GALLERY TAPPED",
            );
          },
          onVideo: () {
            debugPrint(
              "ChattªX VIDEO TAPPED",
            );
          },
          onAudio: () {
            debugPrint(
              "ChattªX AUDIO TAPPED",
            );
          },
          onDocument: () {
            debugPrint(
              "ChattªX DOCUMENT TAPPED",
            );
          },
          onLocation: () {
            Navigator.pop(context);
            _showLocationOptions();
          },
          onContact: () {
            debugPrint(
              "ChattªX CONTACT TAPPED",
            );
          },
          onPoll: () {
            debugPrint(
              "ChattªX POLL TAPPED",
            );
          },
          onPay: () {
            debugPrint(
              "ChattªX PAY TAPPED",
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _chatService.setOffline();

    _messagesSubscription?.cancel();

    _typingSubscription?.cancel();

    _receiverStatusSubscription?.cancel();

    _currentUserVerificationSubscription
        ?.cancel();

    _receiverVerificationSubscription
        ?.cancel();

    _liveLocationSubscription?.cancel();

    _typingTimer?.cancel();

    _liveLocationController.dispose();

    _controller.dispose();

    _reactionEmojiController.dispose();

    _reactionEmojiFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }
}