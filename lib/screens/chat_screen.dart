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
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  // FIREBASE / SERVICES
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ChatService _chatService = ChatService();
  final ChatMessageCacheService _messageCache =
      ChatMessageCacheService();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  // ============================================================
  // SUBSCRIPTIONS
  // ============================================================

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _receiverStatusSubscription;
  StreamSubscription? _currentVerificationSubscription;
  StreamSubscription? _receiverVerificationSubscription;
  StreamSubscription? _liveLocationSubscription;

  Timer? _typingTimer;

  // ============================================================
  // MESSAGE STATE
  // ============================================================

  List<Map<String, dynamic>> _messages = [];

  bool _firestoreLoaded = false;
bool _loadingInitialMessages = false;

  // ============================================================
  // UI STATE
  // ============================================================

  bool typing = false;
  bool recording = false;
  bool showQuickActions = true;
  bool _sendingMessage = false;
  bool _sendingVoice = false;

  String receiverStatus = "Offline";

final ValueNotifier<String> _currentDateLabel =
    ValueNotifier<String>("");

bool _dateUpdateScheduled = false;

  // ============================================================
// SELECTION
// ============================================================

String? _selectedMessageId;

/// Keeps the floating reaction/menu overlay attached to the
/// selected message without changing the message-list layout.
///
/// IMPORTANT:
/// We deliberately do NOT use a GlobalKey or measure the
/// RenderBox. The overlay follows the selected message through
/// Flutter's composited transform system.
final LayerLink _selectionLayerLink = LayerLink();

bool get hasSelectedMessage =>
    _selectedMessageId != null &&
    _selectedMessageId!.isNotEmpty;

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
  // REACTION
  // ============================================================

  bool _processingReaction = false;

  // ============================================================
  // GETTERS
  // ============================================================

  String get currentUser =>
      _auth.currentUser?.uid ?? "";

  String get chatId {
    final ids = <String>[
      currentUser,
      widget.receiverId,
    ];

    ids.sort();

    return ids.join("_");
  }

// ============================================================
// INIT
// ============================================================

@override
void initState() {
  super.initState();

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  _liveLocationController =
      ChattaXLiveLocationController();

  // ============================================================
  // SCROLL
  // ============================================================

  _scrollController.addListener(
    _onScroll,
  );

  // ============================================================
  // LOAD CACHE IMMEDIATELY
  // ============================================================
  //
  // Hive reads synchronously because the box was already opened
  // in main.dart.
  //
  // This puts the previous conversation into _messages before
  // the first useful frame whenever cached messages exist.
  //

  _loadCachedMessages();

  // ============================================================
  // START MESSAGE STREAM IMMEDIATELY
  // ============================================================
  //
  // IMPORTANT:
  // Do NOT put this inside addPostFrameCallback.
  //
  // Firestore's local/offline cache can deliver data without
  // waiting for the network. Starting the listener immediately
  // allows the conversation to appear as soon as Flutter can
  // build it.
  //

  _listenToMessages();

  // ============================================================
  // ONLINE STATUS
  // ============================================================

  _chatService.setOnline();

  // ============================================================
  // RESET UNREAD
  // ============================================================

  _resetUnreadCount();

  // ============================================================
  // TYPING
  // ============================================================

  _listenToTyping();

  // ============================================================
  // RECEIVER STATUS
  // ============================================================

  _listenToReceiverStatus();

  // ============================================================
  // VERIFICATION
  // ============================================================

  _listenToVerificationStatus();

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  _loadExistingLiveLocationSession();

  // ============================================================
  // AFTER FIRST FRAME
  // ============================================================
  //
  // These operations depend on the widgets having been laid out,
  // so they can safely remain after the first frame.
  //

  WidgetsBinding.instance.addPostFrameCallback(
    (_) {
      if (!mounted) return;

      // ----------------------------------------------------------
      // MARK MESSAGES SEEN
      // ----------------------------------------------------------

      _markMessagesAsSeen();

      // ----------------------------------------------------------
      // UPDATE DATE LABEL
      // ----------------------------------------------------------

      _scheduleDateUpdate();
    },
  );
}


  // ============================================================
  // CACHE
  // ============================================================

void _loadCachedMessages() {
  if (currentUser.isEmpty) {
    return;
  }

  try {
    // ============================================================
    // READ HIVE CACHE
    // ============================================================

    final cached = _messageCache.getMessages(
      chatId,
    );

    // ============================================================
    // NOTHING CACHED
    // ============================================================

    if (cached.isEmpty) {
      _messages = <Map<String, dynamic>>[];

      _firestoreLoaded = false;
      _loadingInitialMessages = false;

      return;
    }

    // ============================================================
    // CREATE SAFE COPY
    // ============================================================

    final safeCopy = cached
        .map<Map<String, dynamic>>(
          (message) => Map<String, dynamic>.from(
            message,
          ),
        )
        .toList();

    // ============================================================
    // PUT CACHE INTO MEMORY IMMEDIATELY
    // ============================================================
    //
    // This is the important part.
    //
    // The ListView should be able to use these messages during the
    // very first build instead of waiting for Firestore.
    //

    _messages = safeCopy;

    _firestoreLoaded = false;
    _loadingInitialMessages = false;

    // ============================================================
    // PRE-CACHE IMAGES
    // ============================================================
    //
    // Image downloading MUST NOT block the messages from appearing.
    //

    for (final message in safeCopy) {
      final imageUrl =
          message["imageUrl"]
                  ?.toString()
                  .trim() ??
              "";

      if (imageUrl.isNotEmpty &&
          imageUrl.startsWith("http")) {
        precacheImage(
          NetworkImage(imageUrl),
          context,
        );
      }
    }

    // ============================================================
    // AFTER FIRST FRAME
    // ============================================================

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        _scheduleDateUpdate();

        // ========================================================
        // OPEN AT NEWEST MESSAGE
        // ========================================================

        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.minScrollExtent,
          );
        }
      },
    );
  } catch (e) {
    debugPrint(
      "ChattªX CACHE LOAD ERROR: $e",
    );
  }
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
      if (!mounted) return;

      final nextMessages =
          snapshot.docs.map<Map<String, dynamic>>(
        (doc) {
          final data =
              Map<String, dynamic>.from(
            doc.data(),
          );

          data["_id"] = doc.id;

          return data;
        },
      ).toList();

      _firestoreLoaded = true;

      // ==========================================================
      // EMPTY FIRESTORE CHAT
      // ==========================================================

      if (nextMessages.isEmpty) {
        if (_messages.isEmpty) {
          setState(() {
            _messages = <Map<String, dynamic>>[];
            _loadingInitialMessages = false;
          });

          _currentDateLabel.value = "";
        }

        return;
      }

      // ==========================================================
      // SAVE FIRESTORE DATA TO HIVE
      // ==========================================================
      //
      // This runs independently and does not block the UI.
      //

      _messageCache.saveMessages(
        chatId,
        nextMessages,
      );

      // ==========================================================
      // CHECK WHETHER CACHE IS ALREADY CURRENT
      // ==========================================================

      if (_messagesEqual(
        _messages,
        nextMessages,
      )) {
        _loadingInitialMessages = false;
        return;
      }

      // ==========================================================
      // UPDATE IMMEDIATELY
      // ==========================================================
      //
      // IMPORTANT:
      // There is NO addPostFrameCallback here.
      //
      // As soon as Firestore provides the messages, they are
      // placed into memory and Flutter rebuilds the message list.
      //

      setState(() {
        _messages = nextMessages
            .map<Map<String, dynamic>>(
              (message) =>
                  Map<String, dynamic>.from(message),
            )
            .toList();

        _loadingInitialMessages = false;
      });

      // ==========================================================
      // UPDATE DATE LABEL
      // ==========================================================

      _scheduleDateUpdate();
    },
    onError: (error) {
      debugPrint(
        "ChattªX MESSAGE STREAM ERROR: $error",
      );
    },
  );
}


  // ============================================================
  // MESSAGE COMPARISON
  // ============================================================

  bool _messagesEqual(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (!_mapEqual(
        a[i],
        b[i],
      )) {
        return false;
      }
    }

    return true;
  }

  bool _mapEqual(
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

      if (!_valueEqual(
        a[key],
        b[key],
      )) {
        return false;
      }
    }

    return true;
  }

  bool _valueEqual(
    dynamic a,
    dynamic b,
  ) {
    if (identical(a, b)) {
      return true;
    }

    if (a is Timestamp && b is Timestamp) {
      return a.seconds == b.seconds &&
          a.nanoseconds == b.nanoseconds;
    }

    if (a is DateTime && b is DateTime) {
      return a.isAtSameMomentAs(b);
    }

    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }

      for (final key in a.keys) {
        if (!b.containsKey(key)) {
          return false;
        }

        if (!_valueEqual(
          a[key],
          b[key],
        )) {
          return false;
        }
      }

      return true;
    }

    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }

      for (int i = 0; i < a.length; i++) {
        if (!_valueEqual(
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
  // SCROLL / DATE
  // ============================================================

  void _onScroll() {
    _scheduleDateUpdate();
  }

  void _scheduleDateUpdate() {
    if (!mounted ||
        _dateUpdateScheduled) {
      return;
    }

    _dateUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateUpdateScheduled = false;

      if (!mounted) return;

      _updateCurrentDateLabel();
    });
  }

  void _updateCurrentDateLabel() {
  if (!mounted ||
      !_scrollController.hasClients ||
      _messages.isEmpty) {
    return;
  }

  const double estimatedHeight = 76.0;

  final offset = _scrollController.offset;

  int displayedIndex =
      (offset / estimatedHeight).floor();

  if (displayedIndex < 0) {
    displayedIndex = 0;
  }

  if (displayedIndex >= _messages.length) {
    displayedIndex = _messages.length - 1;
  }

  final actualIndex =
      _messages.length - 1 - displayedIndex;

  if (actualIndex < 0 ||
      actualIndex >= _messages.length) {
    return;
  }

  final date = _messageDate(
    _messages[actualIndex]["timestamp"],
  );

  if (date == null) {
    return;
  }

  final label = getDateLabel(date);

  if (label == _currentDateLabel.value) {
    return;
  }

  // IMPORTANT:
  // Do NOT call setState() while the user is scrolling.
  //
  // Only the small floating date widget listens to this value.
  _currentDateLabel.value = label;
}


  String getDateLabel(DateTime date) {
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
        today.difference(messageDay).inDays;

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

  DateTime? _messageDate(dynamic timestamp) {
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
    if (currentUser.isEmpty) return;

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .set(
        {
          "unread_$currentUser": 0,
        },
        SetOptions(merge: true),
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
    if (currentUser.isEmpty) return;

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

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();

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

      final roomRef = _firestore
          .collection("chat_rooms")
          .doc(chatId);

      batch.set(
        roomRef,
        {
          "unread_$currentUser": 0,
          "lastMessageStatus": "seen",
          "lastInfinity": "seen",
        },
        SetOptions(merge: true),
      );

      await batch.commit();
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
    final id = _chatService.getChatId(
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
        if (!mounted) return;

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

        if (value == typing) return;

        setState(() {
          typing = value;
        });
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
                "Last seen ${TimeOfDay.fromDateTime(
              lastSeen.toDate(),
            ).format(context)}";
          } else {
            status = "Offline";
          }
        }

        if (status == receiverStatus) {
          return;
        }

        setState(() {
          receiverStatus = status;
        });
      },
      onError: (error) {
        debugPrint(
          "ChattªX STATUS ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // VERIFICATION
  // ============================================================

  void _listenToVerificationStatus() {
    _currentVerificationSubscription?.cancel();
    _receiverVerificationSubscription?.cancel();

    _currentVerificationSubscription =
        _firestore
            .collection("users")
            .doc(currentUser)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted) return;

        final verified =
            snapshot.data()?["verified"] == true;

        if (verified ==
            currentUserIsVerified) {
          return;
        }

        setState(() {
          currentUserIsVerified =
              verified;
        });
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
        if (!mounted) return;

        final verified =
            snapshot.data()?["verified"] == true;

        if (verified ==
            receiverIsVerified) {
          return;
        }

        setState(() {
          receiverIsVerified =
              verified;
        });
      },
      onError: (error) {
        debugPrint(
          "ChattªX RECEIVER VERIFICATION ERROR: $error",
        );
      },
    );
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  Future<void> _addReaction(
    String messageId,
    String emoji,
  ) async {
    final cleanEmoji = emoji.trim();

    if (messageId.isEmpty ||
        cleanEmoji.isEmpty ||
        currentUser.isEmpty ||
        _processingReaction) {
      return;
    }

    _processingReaction = true;

    try {
      final ref = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc(messageId);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(ref);

          if (!snapshot.exists) {
            throw Exception(
              "Message no longer exists.",
            );
          }

          final data =
              snapshot.data() ?? {};

          final reactions =
              <String, List<String>>{};

          final raw =
              data["reactions"];

          if (raw is Map) {
            raw.forEach(
              (key, value) {
                final reaction =
                    key.toString();

                if (value is List) {
                  reactions[reaction] =
                      value
                          .map(
                            (item) =>
                                item.toString(),
                          )
                          .toList();
                } else if (value is String) {
                  reactions[reaction] = [
                    value,
                  ];
                }
              },
            );
          }

          final emptyKeys =
              <String>[];

          reactions.forEach(
            (reaction, users) {
              users.removeWhere(
                (id) =>
                    id == currentUser,
              );

              if (users.isEmpty) {
                emptyKeys.add(reaction);
              }
            },
          );

          for (final key in emptyKeys) {
            reactions.remove(key);
          }

          final users =
              reactions.putIfAbsent(
            cleanEmoji,
            () => <String>[],
          );

          if (!users.contains(currentUser)) {
            users.add(currentUser);
          }

          transaction.update(
            ref,
            {
              "reactions": reactions,
            },
          );
        },
      );

      if (!mounted) return;

      _closeSelection();
    } catch (e) {
      debugPrint(
        "ChattªX REACTION ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't add reaction",
          ),
        ),
      );
    } finally {
      _processingReaction = false;
    }
  }

  Future<void> _showCustomReactionDialog(
    String messageId,
  ) async {
    if (messageId.isEmpty ||
        !mounted) {
      return;
    }

    /*
     * IMPORTANT:
     *
     * We now use a normal dialog instead of placing
     * a hidden TextField over the Scaffold.
     *
     * This avoids the keyboard/focus/reparenting
     * combination that was causing the framework
     * assertions.
     */

    final controller =
        TextEditingController();

    final emoji = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xff111827),
          title: const Text(
            "Add reaction",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                TextInputType.text,
            textInputAction:
                TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
            ),
            decoration:
                const InputDecoration(
              hintText: "😀",
              hintStyle: TextStyle(
                color: Colors.white30,
              ),
              enabledBorder:
                  UnderlineInputBorder(
                borderSide:
                    BorderSide(
                  color: Colors.white24,
                ),
              ),
              focusedBorder:
                  UnderlineInputBorder(
                borderSide:
                    BorderSide(
                  color:
                      Color(0xff00E5FF),
                ),
              ),
            ),
            onSubmitted: (value) {
              final clean =
                  value.trim();

              if (clean.isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  clean,
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            TextButton(
              onPressed: () {
                final clean =
                    controller.text.trim();

                if (clean.isNotEmpty) {
                  Navigator.pop(
                    dialogContext,
                    clean,
                  );
                }
              },
              child: const Text(
                "Add",
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

    controller.dispose();

    if (!mounted ||
        emoji == null ||
        emoji.trim().isEmpty) {
      return;
    }

    await _addReaction(
      messageId,
      emoji,
    );
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void _selectMessage(
    String messageId,
  ) {
    if (messageId.isEmpty ||
        !mounted) {
      return;
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    if (_selectedMessageId ==
        messageId) {
      return;
    }

    setState(() {
      _selectedMessageId =
          messageId;
    });
  }

  void _closeSelection() {
    if (!mounted ||
        _selectedMessageId == null) {
      return;
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    setState(() {
      _selectedMessageId = null;
    });
  }

  // ============================================================
// REPLY
// ============================================================

void _startReply(
  Map<String, dynamic> message,
  String type,
) {
  if (!mounted) return;

  final String text;

  if (type == "voice_call") {
    text = "📞 Voice call";
  } else if (type == "voice") {
    text = "🎤 Voice message";
  } else {
    text =
        (message["message"] ?? "")
            .toString();
  }

  setState(() {
    replyingMessage = text;
    _selectedMessageId = null;
  });

  WidgetsBinding.instance
      .addPostFrameCallback((_) {
    if (!mounted) return;

    FocusManager.instance.primaryFocus
        ?.unfocus();
  });
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
    if (messageId.isEmpty ||
        currentUser.isEmpty) {
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
  // SEND TEXT
  // ============================================================

  Future<void> sendMessage({
    bool frozen = false,
  }) async {
    final text =
        _controller.text.trim();

    if (text.isEmpty ||
        currentUser.isEmpty ||
        _sendingMessage) {
      return;
    }

    final reply = replyingMessage;

    _controller.clear();

    if (mounted) {
      setState(() {
        replyingMessage = null;
        _selectedMessageId = null;
        _sendingMessage = true;
      });
    }

    FocusManager.instance.primaryFocus
        ?.unfocus();

    try {
      await _chatService.sendMessage(
        widget.receiverId,
        widget.receiverName,
        text,
        isFrozen: frozen,
        replyTo: reply,
      );

      if (!mounted) return;

      setState(() {
        _sendingMessage = false;
      });

      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint(
        "ChattªX SEND MESSAGE ERROR: $e",
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _sendingMessage = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't send message. Please try again.",
          ),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted ||
            !_scrollController.hasClients) {
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
  // SEND VOICE NOTE (with real waveform)
  // ============================================================
  //
  // VoiceRecorder hands us the actual recorded file path, the real
  // duration, and a waveform compressed from the real microphone
  // amplitude samples. We upload the audio then write the message
  // directly to Firestore (same direct-write pattern already used
  // for location / live-location messages) so we can persist the
  // waveform alongside voiceUrl/voiceDuration. MessageBubble reads
  // "voiceWaveform" straight off the message map and renders the
  // real bars instead of a flat line.
  // ============================================================

  Future<void> _sendVoiceRecording(
    String path,
    int duration,
    List<double> waveform,
  ) async {
    if (currentUser.isEmpty || _sendingVoice) {
      return;
    }

    if (mounted) {
      setState(() {
        _sendingVoice = true;
      });
    }

    final reply = replyingMessage;

    try {
      final url = await CloudinaryService.uploadVoice(
        File(path),
      );

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Couldn't upload voice message.",
              ),
            ),
          );
        }

        return;
      }

      final ref = _firestore
          .collection("chat_rooms")
          .doc(chatId)
          .collection("messages")
          .doc();

      await ref.set({
        "senderId": currentUser,
        "receiverId": widget.receiverId,
        "message": "🎤 Voice message",
        "type": "voice",
        "voiceUrl": url,
        "voiceDuration": duration,

        // Real waveform derived from the actual recording —
        // never random/decorative data.
        "voiceWaveform": waveform,

        "timestamp": FieldValue.serverTimestamp(),
        "seen": false,
        "delivered": false,
        "isFrozen": false,
        "isMelted": false,
        "reactions": {},
        "replyTo": reply,
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
          "lastMessage": "🎤 Voice message",
          "lastMessageTime": FieldValue.serverTimestamp(),
          "lastSenderId": currentUser,
          "lastInfinity": "sent",
          "unread_${widget.receiverId}": FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        replyingMessage = null;
        _selectedMessageId = null;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint(
        "ChattªX VOICE SEND ERROR: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't send voice message. Please try again.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingVoice = false;
        });
      }
    }
  }

  // ============================================================
// SEND IMAGE
// ============================================================

Future<void> _sendImageMessage(XFile file) async {
  if (currentUser.isEmpty) return;

  try {
    final imageFile = File(file.path);

    // ------------------------------------------------------------
    // 1. Validate file
    // ------------------------------------------------------------
    if (!await imageFile.exists()) {
      throw Exception("Image file does not exist.");
    }

    final fileSize = await imageFile.length();

    if (fileSize == 0) {
      throw Exception("Image file is empty.");
    }

    // ------------------------------------------------------------
    // 2. Show uploading state
    // ------------------------------------------------------------
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text("Uploading photo..."),
            ],
          ),
          duration: Duration(minutes: 1),
        ),
      );
    }

    // ------------------------------------------------------------
    // 3. Upload to Cloudinary
    // ------------------------------------------------------------
    final imageUrl = await CloudinaryService.uploadImage(
      imageFile,
    );

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception("Image upload failed.");
    }

    // ------------------------------------------------------------
    // 4. Create message reference
    // ------------------------------------------------------------
    final messageRef = _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .collection("messages")
        .doc();

    final reply = replyingMessage;

    // ------------------------------------------------------------
    // 5. Save image message
    // ------------------------------------------------------------
    await messageRef.set({
      "senderId": currentUser,
      "receiverId": widget.receiverId,

      "message": "📷 Photo",
      "type": "image",

      "imageUrl": imageUrl,

      "timestamp": FieldValue.serverTimestamp(),

      "seen": false,
      "delivered": false,

      "isFrozen": false,
      "isMelted": false,

      "reactions": {},

      "replyTo": reply,

      // Useful for identifying the message instantly.
      "messageId": messageRef.id,
    });

    // ------------------------------------------------------------
    // 6. Update chat room preview
    // ------------------------------------------------------------
    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "participants": [
          currentUser,
          widget.receiverId,
        ],

        "lastMessage": "📷 Photo",
        "lastMessageType": "image",
        "lastMessageTime": FieldValue.serverTimestamp(),
        "lastSenderId": currentUser,

        "lastInfinity": "sent",

        "unread_${widget.receiverId}":
            FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    // ------------------------------------------------------------
    // 7. Clear reply / selection
    // ------------------------------------------------------------
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      replyingMessage = null;
      _selectedMessageId = null;
    });

    // ------------------------------------------------------------
    // 8. Scroll to newest message
    // ------------------------------------------------------------
    _scrollToBottom();

    // ------------------------------------------------------------
    // 9. Success
    // ------------------------------------------------------------
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📷 Photo sent"),
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint("ChattªX IMAGE SEND ERROR: $e");
    debugPrintStack(stackTrace: stackTrace);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't send photo. Please try again.",
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ============================================================
// SEND VIDEO TO CLOUDINARY
// ============================================================

Future<void> _sendVideoMessage(
  XFile file,
) async {
  if (currentUser.isEmpty) {
    return;
  }

  try {
    final videoFile = File(file.path);

    if (!await videoFile.exists()) {
      throw Exception(
        'Video file does not exist.',
      );
    }

    final fileSize =
        await videoFile.length();

    if (fileSize <= 0) {
      throw Exception(
        'Video file is empty.',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Uploading video...',
              ),
            ],
          ),
          duration: Duration(minutes: 1),
        ),
      );
    }

    // ==========================================================
    // UPLOAD TO CLOUDINARY
    // ==========================================================

    final videoUrl =
        await CloudinaryService.uploadVideo(
      videoFile,
      folder: 'chat_videos',
    );

    if (videoUrl == null ||
        videoUrl.trim().isEmpty) {
      throw Exception(
        'Cloudinary video upload failed.',
      );
    }

    // ==========================================================
    // CREATE FIRESTORE MESSAGE
    // ==========================================================

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatId)
        .collection('messages')
        .doc();

    final reply = replyingMessage;

    final fileName =
        file.name.trim().isNotEmpty
            ? file.name.trim()
            : 'Video';

    await messageRef.set({
      'senderId': currentUser,
      'receiverId': widget.receiverId,

      'message': '🎥 Video',
      'type': 'video',

      // CLOUDINARY URL
      'videoUrl': videoUrl,

      'fileName': fileName,
      'mimeType': 'video/mp4',
      'fileSize': fileSize,

      'timestamp':
          FieldValue.serverTimestamp(),

      'seen': false,
      'delivered': false,

      'isFrozen': false,
      'isMelted': false,

      'reactions': {},

      'replyTo': reply,

      'messageId': messageRef.id,
    });

    // ==========================================================
    // UPDATE CHAT PREVIEW
    // ==========================================================

    await _firestore
        .collection('chat_rooms')
        .doc(chatId)
        .set(
      {
        'participants': [
          currentUser,
          widget.receiverId,
        ],

        'lastMessage': '🎥 Video',
        'lastMessageType': 'video',
        'lastMessageTime':
            FieldValue.serverTimestamp(),
        'lastSenderId': currentUser,

        'unread_${widget.receiverId}':
            FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    setState(() {
      replyingMessage = null;
      _selectedMessageId = null;
    });

    _scrollToBottom();
  } catch (e, stackTrace) {
    debugPrint(
      'ChattªX VIDEO SEND ERROR: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Couldn\'t send video. Please try again.',
        ),
      ),
    );
  }
}

// ============================================================
// PICK DOCUMENT
// ============================================================

Future<void> _pickAndSendDocument() async {
  if (currentUser.isEmpty) {
    return;
  }

  try {
    final result =
        await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );

    if (result == null ||
        result.files.isEmpty ||
        !mounted) {
      return;
    }

    final picked =
        result.files.single;

    final path = picked.path;

    if (path == null ||
        path.trim().isEmpty) {
      throw Exception(
        'Document path unavailable.',
      );
    }

    final extension =
        picked.extension ?? '';

    await _sendDocumentMessage(
      File(path),
      fileName: picked.name,
      mimeType:
          _documentMimeFromExtension(
        extension,
      ),
      fileSize: picked.size,
    );
  } catch (e, stackTrace) {
    debugPrint(
      'ChattªX DOCUMENT PICK ERROR: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Couldn\'t select document.',
        ),
      ),
    );
  }
}

// ============================================================
// SEND DOCUMENT TO CLOUDINARY
// ============================================================

Future<void> _sendDocumentMessage(
  File file, {
  required String fileName,
  required String mimeType,
  required int fileSize,
}) async {
  if (currentUser.isEmpty) {
    return;
  }

  try {
    if (!await file.exists()) {
      throw Exception(
        'Document does not exist.',
      );
    }

    final actualSize =
        await file.length();

    if (actualSize <= 0) {
      throw Exception(
        'Document is empty.',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Uploading document...',
              ),
            ],
          ),
          duration: Duration(minutes: 1),
        ),
      );
    }

    // ==========================================================
    // UPLOAD TO CLOUDINARY AS RAW
    // ==========================================================

    final documentUrl =
        await CloudinaryService.uploadDocument(
      file,
    );

    if (documentUrl == null ||
        documentUrl.trim().isEmpty) {
      throw Exception(
        'Cloudinary document upload failed.',
      );
    }

    // ==========================================================
    // CREATE FIRESTORE MESSAGE
    // ==========================================================

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatId)
        .collection('messages')
        .doc();

    final reply = replyingMessage;

    await messageRef.set({
      'senderId': currentUser,
      'receiverId': widget.receiverId,

      'message': '📄 $fileName',
      'type': 'document',

      // CLOUDINARY URL
      'documentUrl': documentUrl,

      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': actualSize,

      'timestamp':
          FieldValue.serverTimestamp(),

      'seen': false,
      'delivered': false,

      'isFrozen': false,
      'isMelted': false,

      'reactions': {},

      'replyTo': reply,

      'messageId': messageRef.id,
    });

    // ==========================================================
    // UPDATE CHAT PREVIEW
    // ==========================================================

    await _firestore
        .collection('chat_rooms')
        .doc(chatId)
        .set(
      {
        'participants': [
          currentUser,
          widget.receiverId,
        ],

        'lastMessage':
            '📄 $fileName',

        'lastMessageType':
            'document',

        'lastMessageTime':
            FieldValue.serverTimestamp(),

        'lastSenderId':
            currentUser,

        'unread_${widget.receiverId}':
            FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    setState(() {
      replyingMessage = null;
      _selectedMessageId = null;
    });

    _scrollToBottom();
  } catch (e, stackTrace) {
    debugPrint(
      'ChattªX DOCUMENT SEND ERROR: $e',
    );

    debugPrintStack(
      stackTrace: stackTrace,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Couldn\'t send document. Please try again.',
        ),
      ),
    );
  }
}

// ============================================================
// DOCUMENT MIME TYPE
// ============================================================

String _documentMimeFromExtension(
  String extension,
) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';

    case 'doc':
      return 'application/msword';

    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    case 'xls':
      return 'application/vnd.ms-excel';

    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    case 'ppt':
      return 'application/vnd.ms-powerpoint';

    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

    case 'txt':
      return 'text/plain';

    case 'csv':
      return 'text/csv';

    case 'json':
      return 'application/json';

    case 'zip':
      return 'application/zip';

    case 'rar':
      return 'application/vnd.rar';

    default:
      return 'application/octet-stream';
  }
}

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _showLocationOptions() async {
    if (!mounted) return;

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
      builder: (sheetContext) {
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
                      sheetContext,
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
                      sheetContext,
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

    if (!mounted) return;

    if (choice == "current") {
      await _sendLocation();
    } else if (choice == "live") {
      await _startLiveLocationFromChat();
    }
  }

  Future<void> _sendLocation() async {
    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        final open =
            await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
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
                      dialogContext,
                      false,
                    );
                  },
                  child:
                      const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
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
            builder: (dialogContext) {
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
                        dialogContext,
                        false,
                      );
                    },
                    child:
                        const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    },
                    child:
                        const Text(
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
          await Geolocator
              .getCurrentPosition(
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
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text("📍 Location sent"),
          ),
        );

        _scrollToBottom();
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
      if (!mounted) return;

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

      final result =
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

      if (result.docs.isEmpty) {
        return;
      }

      _liveLocationMessageId =
          result.docs.first.id;

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

            _liveLocationSubscription =
                null;

            return;
          }

          final updated =
              await _liveLocationController
                  .updateLiveLocation(
            position,
          );

          if (!updated) return;

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
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Unable to start live location.",
              ),
            ),
          );
        }

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

    final ref =
        _firestore
            .collection("chat_rooms")
            .doc(chatId)
            .collection("messages")
            .doc();

    _liveLocationMessageId = ref.id;

    await ref.set({
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
      SetOptions(merge: true),
    );

    _liveLocationMessageSent = true;

    _scrollToBottom();
  }

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

      if (!mounted) return;

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
// CHATTªX — CHAT OPTIONS 
// ============================================================ 
// 
// Opens the useful chat controls directly over the current 
// conversation. This does NOT navigate away from ChatScreen. 
// 
// ============================================================ 
 
void _showChatOptions() { 
  showModalBottomSheet( 
    context: context, 
    backgroundColor: Colors.transparent, 
    isScrollControlled: true, 
    useSafeArea: true, 
    builder: (sheetContext) { 
      return Container( 
        constraints: BoxConstraints( 
          maxHeight: MediaQuery.of(context).size.height * 0.82, 
        ), 
        decoration: const BoxDecoration( 
          color: Color(0xFF080D18), 
          borderRadius: BorderRadius.vertical( 
            top: Radius.circular(26), 
          ), 
        ), 
        child: Column( 
          mainAxisSize: MainAxisSize.min, 
          children: [ 
            // ====================================================== 
            // HANDLE 
            // ====================================================== 
 
            const SizedBox(height: 10), 
 
            Container( 
              width: 42, 
              height: 4, 
              decoration: BoxDecoration( 
                color: Colors.white24, 
                borderRadius: BorderRadius.circular(20), 
              ), 
            ), 
 
            const SizedBox(height: 14), 
 
            // ====================================================== 
            // CONTACT HEADER 
            // ====================================================== 
 
            Padding( 
              padding: const EdgeInsets.symmetric( 
                horizontal: 18, 
              ), 
              child: Row( 
                children: [ 
                  Container( 
                    width: 52, 
                    height: 52, 
                    padding: const EdgeInsets.all(2), 
                    decoration: const BoxDecoration( 
                      shape: BoxShape.circle, 
                      gradient: LinearGradient( 
                        colors: [ 
                          Color(0xFF00D9FF), 
                          Color(0xFF7B2FF7), 
                        ], 
                      ), 
                    ), 
                    child: CircleAvatar( 
                      backgroundColor: 
                          const Color(0xFF111827), 
                      backgroundImage: 
                          _chatOptionsImageProvider(), 
                      child: 
                          _chatOptionsImageProvider() == null 
                              ? const Icon( 
                                  Icons.person_rounded, 
                                  color: Colors.white54, 
                                  size: 27, 
                                ) 
                              : null, 
                    ), 
                  ), 
 
                  const SizedBox(width: 12), 
 
                  Expanded( 
                    child: Column( 
                      crossAxisAlignment: 
                          CrossAxisAlignment.start, 
                      children: [ 
                        Row( 
                          children: [ 
                            Flexible( 
                              child: Text( 
                                widget.receiverName, 
                                maxLines: 1, 
                                overflow: 
                                    TextOverflow.ellipsis, 
                                style: const TextStyle( 
                                  color: Colors.white, 
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w800, 
                                ), 
                              ), 
                            ), 
 
                            if (receiverIsVerified) ...[ 
                              const SizedBox(width: 6), 
                              Container( 
                                width: 17, 
                                height: 17, 
                                decoration: 
                                    const BoxDecoration( 
                                  color: Color(0xFF2196F3), 
                                  shape: BoxShape.circle, 
                                ), 
                                child: const Icon( 
                                  Icons.check_rounded, 
                                  color: Colors.white, 
                                  size: 11, 
                                ), 
                              ), 
                            ], 
                          ], 
                        ), 
 
                        const SizedBox(height: 3), 
 
                        Text( 
                          receiverStatus, 
                          style: TextStyle( 
                            color: 
                                receiverStatus == "Online" 
                                    ? const Color(0xFF39FF88) 
                                    : Colors.white54, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w600, 
                          ), 
                        ), 
                      ], 
                    ), 
                  ), 
                ], 
              ), 
            ), 
 
            const SizedBox(height: 15), 
 
            const Divider( 
              color: Colors.white10, 
              height: 1, 
            ), 
 
            // ====================================================== 
            // OPTIONS 
            // ====================================================== 
 
            Flexible( 
              child: ListView( 
                shrinkWrap: true, 
                padding: const EdgeInsets.symmetric( 
                  vertical: 6, 
                ), 
                children: [ 
                  _chatOption( 
                    icon: Icons.person_rounded, 
                    title: "View contact", 
                    subtitle: "Open this person's profile", 
                    color: const Color(0xFF00D9FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      Navigator.push( 
                        context, 
                        MaterialPageRoute( 
                          builder: (_) => 
                              UserProfileViewScreen( 
                            userId: widget.receiverId, 
                            userName: widget.receiverName, 
                            userImage: widget.receiverImage, 
                          ), 
                        ), 
                      ); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.search_rounded, 
                    title: "Search", 
                    subtitle: "Search messages in this chat", 
                    color: const Color(0xFF7B2FF7), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      // Connect your chat search here. 
                      _openChatSearch(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.photo_library_rounded, 
                    title: "Media", 
                    subtitle: "Photos and videos shared here", 
                    color: const Color(0xFFB026FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openChatMedia(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.insert_drive_file_rounded, 
                    title: "Files", 
                    subtitle: "Documents and files shared here", 
                    color: const Color(0xFF00D9FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openChatFiles(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.link_rounded, 
                    title: "Links", 
                    subtitle: "Links shared in this chat", 
                    color: const Color(0xFF7B2FF7), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openChatLinks(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.star_rounded, 
                    title: "Starred messages", 
                    subtitle: "Messages you've saved", 
                    color: const Color(0xFFFFC857), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openStarredMessages(); 
                    }, 
                  ), 
 
                  const Padding( 
                    padding: EdgeInsets.symmetric( 
                      horizontal: 18, 
                    ), 
                    child: Divider( 
                      color: Colors.white10, 
                      height: 12, 
                    ), 
                  ), 
 
                  _chatOption( 
                    icon: 
                        Icons.notifications_off_rounded, 
                    title: "Mute notifications", 
                    subtitle: 
                        "Stop notifications from this chat", 
                    color: const Color(0xFF00D9FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _toggleChatMute(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.auto_delete_rounded, 
                    title: "Disappearing messages", 
                    subtitle: 
                        "Choose when messages disappear", 
                    color: const Color(0xFFB026FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openDisappearingMessages(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.push_pin_rounded, 
                    title: "Pin chat", 
                    subtitle: 
                        "Keep this conversation at the top", 
                    color: const Color(0xFF00D9FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _toggleChatPin(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.palette_rounded, 
                    title: "Chat appearance", 
                    subtitle: 
                        "Wallpaper and chat appearance", 
                    color: const Color(0xFF7B2FF7), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _openChatAppearance(); 
                    }, 
                  ), 
 
                  const Padding( 
                    padding: EdgeInsets.symmetric( 
                      horizontal: 18, 
                    ), 
                    child: Divider( 
                      color: Colors.white10, 
                      height: 12, 
                    ), 
                  ), 
 
                  _chatOption( 
                    icon: Icons.lock_outline_rounded, 
                    title: "Encryption", 
                    subtitle: 
                        "Learn how this conversation is protected", 
                    color: const Color(0xFF00D9FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _showChatEncryption(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.verified_user_rounded, 
                    title: "Security verification", 
                    subtitle: 
                        "Verify this contact", 
                    color: const Color(0xFFB026FF), 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _showChatSecurityVerification(); 
                    }, 
                  ), 
 
                  const Padding( 
                    padding: EdgeInsets.symmetric( 
                      horizontal: 18, 
                    ), 
                    child: Divider( 
                      color: Colors.white10, 
                      height: 12, 
                    ), 
                  ), 
 
                  _chatOption( 
                    icon: Icons.block_rounded, 
                    title: 
                        "Block ${widget.receiverName}", 
                    subtitle: 
                        "Stop messages and calls", 
                    color: Colors.redAccent, 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _blockChatUser(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.flag_rounded, 
                    title: "Report", 
                    subtitle: 
                        "Report this account", 
                    color: Colors.redAccent, 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _reportChatUser(); 
                    }, 
                  ), 
 
                  _chatOption( 
                    icon: Icons.delete_sweep_rounded, 
                    title: "Clear chat", 
                    subtitle: 
                        "Remove messages from this device", 
                    color: Colors.redAccent, 
                    onTap: () { 
                      Navigator.pop(sheetContext); 
 
                      _clearCurrentChat(); 
                    }, 
                  ), 
 
                  const SizedBox(height: 12), 
                ], 
              ), 
            ), 
          ], 
        ), 
      ); 
    }, 
  ); 
} 
 
Widget _chatOption({ 
  required IconData icon, 
  required String title, 
  required String subtitle, 
  required Color color, 
  required VoidCallback onTap, 
}) { 
  return Material( 
    color: Colors.transparent, 
    child: InkWell( 
      onTap: onTap, 
      child: Padding( 
        padding: const EdgeInsets.symmetric( 
          horizontal: 18, 
          vertical: 7, 
        ), 
        child: Row( 
          children: [ 
            Container( 
              width: 43, 
              height: 43, 
              decoration: BoxDecoration( 
                color: color.withValues(alpha: .10), 
                borderRadius: BorderRadius.circular(13), 
              ), 
              child: Icon( 
                icon, 
                color: color, 
                size: 20, 
              ), 
            ), 
 
            const SizedBox(width: 13), 
 
            Expanded( 
              child: Column( 
                crossAxisAlignment: 
                    CrossAxisAlignment.start, 
                children: [ 
                  Text( 
                    title, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle( 
                      color: Colors.white, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w700, 
                    ), 
                  ), 
 
                  const SizedBox(height: 2), 
 
                  Text( 
                    subtitle, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle( 
                      color: Colors.white54, 
                      fontSize: 10, 
                    ), 
                  ), 
                ], 
              ), 
            ), 
 
            const Icon( 
              Icons.chevron_right_rounded, 
              color: Colors.white24, 
              size: 19, 
            ), 
          ], 
        ), 
      ), 
    ), 
  ); 
}

ImageProvider? _chatOptionsImageProvider() {
  final image = widget.receiverImage?.trim() ?? "";

  if (image.isEmpty) {
    return null;
  }

  if (image.startsWith("http://") ||
      image.startsWith("https://")) {
    return NetworkImage(image);
  }

  return AssetImage(image);
}

// ============================================================
// CHATTªX — CHAT OPTIONS FUNCTIONALITY
// ============================================================

// ============================================================
// SEARCH
// ============================================================

void _openChatSearch() {
  if (!mounted) return;

  final controller = TextEditingController();
  String query = "";

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF080D18),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final results = query.trim().isEmpty
              ? <Map<String, dynamic>>[]
              : _messages.where((message) {
                  final text =
                      message["message"]?.toString() ?? "";

                  return text
                      .toLowerCase()
                      .contains(query.toLowerCase());
                }).toList();

          return SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height * 0.78,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF7B2FF7),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            onChanged: (value) {
                              setSheetState(() {
                                query = value;
                              });
                            },
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration:
                                InputDecoration(
                              hintText:
                                  "Search messages...",
                              hintStyle:
                                  const TextStyle(
                                color: Colors.white38,
                              ),
                              filled: true,
                              fillColor:
                                  const Color(0xFF111827),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide:
                                    BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color:
                                    Color(0xFF7B2FF7),
                              ),
                              suffixIcon:
                                  controller.text
                                          .isNotEmpty
                                      ? IconButton(
                                          icon:
                                              const Icon(
                                            Icons.clear,
                                            color:
                                                Colors.white54,
                                          ),
                                          onPressed: () {
                                            controller.clear();

                                            setSheetState(() {
                                              query = "";
                                            });
                                          },
                                        )
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: query.trim().isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: Colors.white24,
                                  size: 46,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Search this conversation",
                                  style: TextStyle(
                                    color:
                                        Colors.white70,
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "Find messages by typing a word or phrase.",
                                  style: TextStyle(
                                    color:
                                        Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : results.isEmpty
                            ? const Center(
                                child: Text(
                                  "No messages found",
                                  style: TextStyle(
                                    color:
                                        Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 14,
                                ),
                                itemCount:
                                    results.length,
                                itemBuilder:
                                    (context, index) {
                                  final message =
                                      results[index];

                                  final text =
                                      message["message"]
                                              ?.toString() ??
                                          "";

                                  final senderId =
                                      message["senderId"]
                                              ?.toString() ??
                                          "";

                                  final date =
                                      _messageDate(
                                    message["timestamp"],
                                  );

                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                    ),
                                    leading:
                                        Container(
                                      width: 42,
                                      height: 42,
                                      decoration:
                                          BoxDecoration(
                                        color: const Color(
                                          0xFF7B2FF7,
                                        ).withValues(
                                          alpha: .10,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child: Icon(
                                        senderId ==
                                                currentUser
                                            ? Icons
                                                .north_east_rounded
                                            : Icons
                                                .south_west_rounded,
                                        color:
                                            const Color(
                                          0xFF7B2FF7,
                                        ),
                                        size: 19,
                                      ),
                                    ),
                                    title: Text(
                                      text,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: date == null
                                        ? null
                                        : Text(
                                            DateFormat(
                                              "dd MMM yyyy • HH:mm",
                                            ).format(date),
                                            style:
                                                const TextStyle(
                                              color: Colors
                                                  .white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                    onTap: () {
                                      Navigator.pop(
                                        sheetContext,
                                      );

                                      _closeSelection();

                                      ScaffoldMessenger
                                              .of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Found: $text",
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ============================================================
// MEDIA
// ============================================================

void _openChatMedia() {
  final media = _messages.where((message) {
    final type =
        message["type"]?.toString().toLowerCase() ?? "";

    return type == "image" || type == "video";
  }).toList();

  _openChatMediaViewer(
    title: "Media",
    messages: media,
    emptyIcon: Icons.photo_library_rounded,
    emptyText: "No media shared yet",
  );
}

// ============================================================
// FILES
// ============================================================

void _openChatFiles() {
  final files = _messages.where((message) {
    final type =
        message["type"]?.toString().toLowerCase() ?? "";

    return type == "document";
  }).toList();

  _openChatMediaViewer(
    title: "Files",
    messages: files,
    emptyIcon: Icons.insert_drive_file_rounded,
    emptyText: "No files shared yet",
  );
}

// ============================================================
// LINKS
// ============================================================

void _openChatLinks() {
  final links = _messages.where((message) {
    final text =
        message["message"]?.toString() ?? "";

    final url =
        RegExp(
          r'https?:\/\/[^\s]+',
          caseSensitive: false,
        );

    return url.hasMatch(text);
  }).toList();

  _openChatMediaViewer(
    title: "Links",
    messages: links,
    emptyIcon: Icons.link_rounded,
    emptyText: "No links shared yet",
  );
}

// ============================================================
// SHARED MEDIA / FILE / LINK VIEW
// ============================================================

void _openChatMediaViewer({
  required String title,
  required List<Map<String, dynamic>> messages,
  required IconData emptyIcon,
  required String emptyText,
}) {
  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF080D18),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${messages.length}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              emptyIcon,
                              color: Colors.white24,
                              size: 48,
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              emptyText,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                        ),
                        itemCount:
                            messages.length,
                        itemBuilder:
                            (context, index) {
                          final message =
                              messages[index];

                          final type =
                              message["type"]
                                      ?.toString() ??
                                  "";

                          final text =
                              message["message"]
                                      ?.toString() ??
                                  "";

                          final fileName =
                              message["fileName"]
                                      ?.toString() ??
                                  "";

                          String displayText =
                              text;

                          if (type ==
                                  "document" &&
                              fileName.isNotEmpty) {
                            displayText =
                                fileName;
                          }

                          return Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF111827,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child: ListTile(
                              leading:
                                  Container(
                                width: 44,
                                height: 44,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFF00D9FF,
                                  ).withValues(
                                    alpha: .10,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                                child: Icon(
                                  type == "image"
                                      ? Icons
                                          .image_rounded
                                      : type ==
                                              "video"
                                          ? Icons
                                              .play_circle_fill_rounded
                                          : type ==
                                                  "document"
                                              ? Icons
                                                  .description_rounded
                                              : Icons
                                                  .link_rounded,
                                  color:
                                      const Color(
                                    0xFF00D9FF,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayText,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              subtitle:
                                  Text(
                                message["senderId"]
                                            ?.toString() ==
                                        currentUser
                                    ? "You"
                                    : widget
                                        .receiverName,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// STARRED MESSAGES
// ============================================================

void _openStarredMessages() {
  final starred =
      _messages.where(_isMessageStarred).toList();

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF080D18),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Starred messages",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: starred.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.white24,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              "No starred messages",
                              style: TextStyle(
                                color:
                                    Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Star important messages to find them here.",
                              style: TextStyle(
                                color:
                                    Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 14,
                        ),
                        itemCount: starred.length,
                        itemBuilder:
                            (context, index) {
                          final message =
                              starred[index];

                          final text =
                              message["message"]
                                      ?.toString() ??
                                  "";

                          return Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF111827,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child: ListTile(
                              leading:
                                  const Icon(
                                Icons.star_rounded,
                                color:
                                    Color(
                                  0xFFFFC857,
                                ),
                              ),
                              title: Text(
                                text,
                                maxLines: 3,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle:
                                  const Text(
                                "Starred by you",
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// MUTE NOTIFICATIONS
// ============================================================

Future<void> _toggleChatMute() async {
  if (currentUser.isEmpty) return;

  final roomRef = _firestore
      .collection("chat_rooms")
      .doc(chatId);

  try {
    final snapshot = await roomRef.get();

    final data = snapshot.data() ?? {};

    final key = "muted_$currentUser";

    final currentlyMuted =
        data[key] == true;

    await roomRef.set(
      {
        key: !currentlyMuted,
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          !currentlyMuted
              ? "Notifications muted"
              : "Notifications unmuted",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX MUTE ERROR: $e",
    );
  }
}

// ============================================================
// DISAPPEARING MESSAGES
// ============================================================

Future<void> _openDisappearingMessages() async {
  if (!mounted) return;

  final selected =
      await showModalBottomSheet<String>(
    context: context,
    backgroundColor:
        const Color(0xFF080D18),
    shape:
        const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      final options = <Map<String, String>>[
        {
          "value": "off",
          "title": "Off",
          "subtitle":
              "Messages stay in the chat",
        },
        {
          "value": "24h",
          "title": "24 hours",
          "subtitle":
              "Messages disappear after 24 hours",
        },
        {
          "value": "7d",
          "title": "7 days",
          "subtitle":
              "Messages disappear after 7 days",
        },
        {
          "value": "90d",
          "title": "90 days",
          "subtitle":
              "Messages disappear after 90 days",
        },
      ];

      return SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            20,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Disappearing messages",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Choose how long new messages remain.",
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              ...options.map(
                (option) {
                  return ListTile(
                    leading: const Icon(
                      Icons
                          .auto_delete_rounded,
                      color:
                          Color(0xFFB026FF),
                    ),
                    title: Text(
                      option["title"]!,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      option["subtitle"]!,
                      style:
                          const TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        option["value"],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected == null ||
      currentUser.isEmpty ||
      !mounted) {
    return;
  }

  try {
    await _firestore
        .collection("chat_rooms")
        .doc(chatId)
        .set(
      {
        "disappearingMessages":
            selected,
        "disappearingUpdatedBy":
            currentUser,
        "disappearingUpdatedAt":
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          selected == "off"
              ? "Disappearing messages turned off"
              : "Disappearing messages: $selected",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX DISAPPEARING ERROR: $e",
    );
  }
}

// ============================================================
// PIN CHAT
// ============================================================

Future<void> _toggleChatPin() async {
  if (currentUser.isEmpty) return;

  final roomRef = _firestore
      .collection("chat_rooms")
      .doc(chatId);

  try {
    final snapshot = await roomRef.get();

    final data = snapshot.data() ?? {};

    final key = "pinned_$currentUser";

    final currentlyPinned =
        data[key] == true;

    await roomRef.set(
      {
        key: !currentlyPinned,
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          !currentlyPinned
              ? "Chat pinned"
              : "Chat unpinned",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX PIN ERROR: $e",
    );
  }
}

// ============================================================
// CHAT APPEARANCE
// ============================================================

void _openChatAppearance() {
  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF080D18),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Chat appearance",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "ChattªX chat appearance controls",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 18),

              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF7B2FF7)
                            .withValues(
                      alpha: .10,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wallpaper_rounded,
                    color:
                        Color(0xFF7B2FF7),
                  ),
                ),
                title: const Text(
                  "Wallpaper",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  "Current ChattªX wallpaper is active",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Wallpaper customization is coming next.",
                      ),
                    ),
                  );
                },
              ),

              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF00D9FF)
                            .withValues(
                      alpha: .10,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.text_fields_rounded,
                    color:
                        Color(0xFF00D9FF),
                  ),
                ),
                title: const Text(
                  "Chat text",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  "Message size and display",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "ChattªX message styling is already optimized.",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// ENCRYPTION INFORMATION
// ============================================================

void _showChatEncryption() {
  if (!mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color:
                  Color(0xFF00D9FF),
            ),
            SizedBox(width: 10),
            Text(
              "Encryption",
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          "Your ChattªX messages are protected while being transferred between the app and Firebase services. This screen does not claim end-to-end encryption unless ChattªX's messaging system has been configured for true end-to-end encryption.",
          style: TextStyle(
            color: Colors.white70,
            height: 1.45,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
              );
            },
            child: const Text(
              "Done",
              style: TextStyle(
                color:
                    Color(0xFF00D9FF),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ============================================================
// SECURITY VERIFICATION
// ============================================================

void _showChatSecurityVerification() {
  if (!mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.verified_user_rounded,
              color:
                  Color(0xFFB026FF),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Security verification",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "You're chatting with ${widget.receiverName}. A future ChattªX security-verification system can compare a security code between both devices.",
          style: const TextStyle(
            color: Colors.white70,
            height: 1.45,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
              );
            },
            child: const Text(
              "Close",
              style: TextStyle(
                color:
                    Color(0xFFB026FF),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ============================================================
// BLOCK USER
// ============================================================

Future<void> _blockChatUser() async {
  if (currentUser.isEmpty ||
      !mounted) {
    return;
  }

  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            const Color(0xFF111827),
        title: Text(
          "Block ${widget.receiverName}?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          "They will no longer be able to contact you through ChattªX.",
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                false,
              );
            },
            child:
                const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                true,
              );
            },
            child: const Text(
              "Block",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  try {
    await _firestore
        .collection("users")
        .doc(currentUser)
        .collection("blocked_users")
        .doc(widget.receiverId)
        .set({
      "userId": widget.receiverId,
      "blockedAt":
          FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          "${widget.receiverName} blocked",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX BLOCK ERROR: $e",
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't block this user.",
        ),
      ),
    );
  }
}

// ============================================================
// REPORT USER
// ============================================================

Future<void> _reportChatUser() async {
  if (currentUser.isEmpty ||
      !mounted) {
    return;
  }

  final reason =
      await showModalBottomSheet<String>(
    context: context,
    backgroundColor:
        const Color(0xFF080D18),
    shape:
        const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      final reasons = [
        "Spam",
        "Harassment",
        "Scam or fraud",
        "Inappropriate content",
        "Other",
      ];

      return SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration:
                    BoxDecoration(
                  color: Colors.white24,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Report account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Why are you reporting this account?",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 12),

              ...reasons.map(
                (reason) {
                  return ListTile(
                    leading: const Icon(
                      Icons.flag_rounded,
                      color:
                          Colors.redAccent,
                    ),
                    title: Text(
                      reason,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        reason,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  if (reason == null ||
      reason.isEmpty) {
    return;
  }

  try {
    await _firestore
        .collection("reports")
        .add({
      "reporterId": currentUser,
      "reportedUserId":
          widget.receiverId,
      "reason": reason,
      "chatId": chatId,
      "createdAt":
          FieldValue.serverTimestamp(),
      "status": "pending",
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Report submitted. Thank you.",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX REPORT ERROR: $e",
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't submit report.",
        ),
      ),
    );
  }
}

// ============================================================
// CLEAR CHAT
// ============================================================

Future<void> _clearCurrentChat() async {
  if (currentUser.isEmpty ||
      !mounted) {
    return;
  }

  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor:
            const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          "Clear chat?",
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        content: const Text(
          "This removes the conversation from this device's ChattªX cache. It does not delete the other person's copy.",
          style: TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                false,
              );
            },
            child:
                const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                true,
              );
            },
            child: const Text(
              "Clear",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  try {
    // ==========================================================
    // REMOVE LOCAL CACHE
    // ==========================================================

    await _messageCache.saveMessages(
      chatId,
      <Map<String, dynamic>>[],
    );

    if (!mounted) return;

    setState(() {
      _messages =
          <Map<String, dynamic>>[];
    });

    _currentDateLabel.value = "";

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Chat cleared from this device.",
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX CLEAR CHAT ERROR: $e",
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't clear the chat.",
        ),
      ),
    );
  }
}

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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

            Column(
  children: [
    // ============================================================
    // CHAT HEADER — ABSOLUTE TOP
    // ============================================================

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

      onMenu: _showChatOptions,
    ),

    // ============================================================
    // MESSAGES
    // ============================================================

    Expanded(
      child: _buildMessageArea(),
    ),

    // ============================================================
    // MESSAGE COMPOSER
    // ============================================================

    _buildComposer(),
  ],
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
    if (_messages.isNotEmpty) {
      return _buildMessageList();
    }

    if (_firestoreLoaded) {
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

Widget _buildMessageList() {
  final selectedId = _selectedMessageId;

  Map<String, dynamic>? selectedMessage;

  if (selectedId != null && selectedId.isNotEmpty) {
    for (final message in _messages) {
      final id = message["_id"]?.toString() ?? "";

      if (id == selectedId) {
        selectedMessage = message;
        break;
      }
    }
  }

  return Stack(
    clipBehavior: Clip.none,
    children: [
      // ==========================================================
      // REAL MESSAGE LIST
      //
      // NOTHING is added to the selected message's height.
      // Therefore long-pressing NEVER creates extra space.
      // ==========================================================

      ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 10,
        ),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final actualIndex =
              _messages.length -
                  1 -
                  index;

          final message =
              _messages[actualIndex];

          final id =
              message["_id"]
                      ?.toString() ??
                  "";

          return KeyedSubtree(
            key: ValueKey<String>(
              id.isNotEmpty
                  ? id
                  : "message_$actualIndex",
            ),
            child: _buildMessageItem(
              message: message,
              actualIndex: actualIndex,
            ),
          );
        },
      ),

      // ==========================================================
// FLOATING DATE LABEL
// ==========================================================
//
// IMPORTANT:
// This is isolated from the ChatScreen's setState().
// Scrolling therefore does NOT rebuild the entire chat.
//
ValueListenableBuilder<String>(
  valueListenable: _currentDateLabel,
  builder: (
    context,
    dateLabel,
    child,
  ) {
    if (dateLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xff151515),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              dateLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  },
),

      // ==========================================================
      // FLOATING SELECTION CONTROLS
      //
      // These are NOT inside the ListView.
      //
      // Therefore they DO NOT consume space.
      // ==========================================================

      if (selectedMessage != null)
        CompositedTransformFollower(
          link: _selectionLayerLink,

          // Attach the overlay to the bottom-center of the
          // selected message.
          targetAnchor:
              Alignment.bottomCenter,

          // Put the top-center of the reaction/menu stack
          // at that point.
          followerAnchor:
              Alignment.topCenter,

          offset: const Offset(
            0,
            8,
          ),

          showWhenUnlinked: false,

          child: Material(
            color: Colors.transparent,
            child: _buildFloatingSelectedControls(
              map: selectedMessage,
              messageId: selectedId!,
              isMe:
                  selectedMessage["senderId"] ==
                      currentUser,
              type:
                  selectedMessage["type"]
                          ?.toString() ??
                      "text",
            ),
          ),
        ),
    ],
  );
}

  // ============================================================
// MESSAGE ITEM
// ============================================================

Widget _buildMessageItem({
  required Map<String, dynamic> message,
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

  final selected =
      _selectedMessageId ==
          messageId;

  final showDate =
      _shouldShowDateSeparator(
    actualIndex,
  );

  // ==========================================================
  // ORIGINAL MESSAGE CONTENT
  // ==========================================================

  Widget messageContent = Column(
    mainAxisSize:
        MainAxisSize.min,
    children: [
      if (showDate &&
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

        onTap: () {
          if (hasSelectedMessage) {
            if (selected) {
              return;
            }

            _closeSelection();
            return;
          }

          if (type == "location" ||
              type == "live_location") {
            _openLocationMessage(
              message,
            );
          }
        },

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 120,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 1,
          ),

          child: selected
              ? CompositedTransformTarget(
                  link:
                      _selectionLayerLink,
                  child:
                      _buildMessageBubble(
                    message: message,
                    messageId:
                        messageId,
                    isMe: isMe,
                    type: type,
                    messageDate:
                        messageDate,
                  ),
                )
              : _buildMessageBubble(
                  message: message,
                  messageId:
                      messageId,
                  isMe: isMe,
                  type: type,
                  messageDate:
                      messageDate,
                ),
        ),
      ),
    ],
  );

  // ==========================================================
  // BLUR EVERYTHING EXCEPT THE SELECTED MESSAGE
  // ==========================================================

  if (hasSelectedMessage &&
      !selected) {
    messageContent = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: 3.8,
        sigmaY: 3.8,
      ),
      child: messageContent,
    );
  }

  return messageContent;
}

  // ============================================================
  // DATE SEPARATOR
  // ============================================================

  bool _shouldShowDateSeparator(
    int index,
  ) {
    if (index <= 0 ||
        index >= _messages.length) {
      return false;
    }

    final current =
        _messageDate(
      _messages[index]["timestamp"],
    );

    final previous =
        _messageDate(
      _messages[index - 1]["timestamp"],
    );

    if (current == null ||
        previous == null) {
      return false;
    }

    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
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

    // Real waveform saved when the voice note was sent
    // (falls back to an empty list, which MessageBubble
    // treats as "no data" and draws a flat line for).
    final voiceWaveform =
        _toDoubleList(
      message["voiceWaveform"],
    );

    final reactions =
        _normaliseReactions(
      message["reactions"],
    );

    return MessageBubble(
      type: type,
      message:
          message["message"] ?? "",
          imageUrl:
    message["imageUrl"]
            ?.toString() ??
        "",

videoUrl:
    message["videoUrl"]
            ?.toString() ??
        "",

documentUrl:
    message["documentUrl"]
            ?.toString() ??
        "",

fileName:
    message["fileName"]
            ?.toString() ??
        "",

mimeType:
    message["mimeType"]
            ?.toString() ??
        "",

fileSize:
    _toInt(
  message["fileSize"],
),
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
      voiceWaveform: voiceWaveform,
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
          // ============================================================
      // VOICE CALL HISTORY
      // ============================================================

      callStatus:
          message["callStatus"]?.toString() ?? "",
      callDuration:
          _toInt(message["callDuration"]),
      isReply:
          message["replyTo"] != null,
      replyTo:
          message["replyTo"],
      isFrozen:
          message["isFrozen"] == true,
      isMelted:
          message["isMelted"] == true,
      reactions: reactions,
      onReaction: (emoji) async {
        await _addReaction(
          messageId,
          emoji,
        );
      },
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
  // REACTION NORMALISATION
  // ============================================================

  Map<String, dynamic>
      _normaliseReactions(
    dynamic raw,
  ) {
    final result =
        <String, dynamic>{};

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
                    (item) =>
                        item.toString(),
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
  if (value == null) {
    return 0;
  }

  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(
        value.toString(),
      ) ??
      0;
}

  // ============================================================
  // WAVEFORM FIELD PARSING
  // ============================================================
  //
  // Firestore returns the stored "voiceWaveform" array as
  // List<dynamic> (num values). This converts it safely into
  // List<double> for MessageBubble, tolerating legacy messages
  // that don't have the field at all.
  // ============================================================

  List<double> _toDoubleList(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    final result = <double>[];

    for (final value in raw) {
      double? parsed;

      if (value is num) {
        parsed = value.toDouble();
      } else if (value is String) {
        parsed = double.tryParse(value);
      }

      if (parsed == null ||
          parsed.isNaN ||
          parsed.isInfinite) {
        continue;
      }

      result.add(parsed.clamp(0.0, 1.0));
    }

    return result;
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
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 4,
        bottom: 4,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          ReactionBar(
            onReactionSelected:
                (emoji) async {
              await _addReaction(
                messageId,
                emoji,
              );
            },
            onAddEmoji: () {
              _showCustomReactionDialog(
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
      ),
    );
  }

  // ============================================================
// FLOATING SELECTED CONTROLS
// ============================================================

Widget _buildFloatingSelectedControls({
  required Map<String, dynamic> map,
  required String messageId,
  required bool isMe,
  required String type,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ======================================================
        // REACTION BAR
        // ======================================================

        ReactionBar(
          onReactionSelected:
              (emoji) async {
            await _addReaction(
              messageId,
              emoji,
            );
          },
          onAddEmoji: () {
            _showCustomReactionDialog(
              messageId,
            );
          },
        ),

        const SizedBox(height: 5),

        // ======================================================
        // MESSAGE MENU
        // ======================================================

        _buildMessageMenu(
          map: map,
          messageId: messageId,
          isMe: isMe,
          type: type,
        ),
      ],
    ),
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
  final String text =
      map["message"]
              ?.toString()
              .trim() ??
          "";

  if (text.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Nothing to copy",
          ),
        ),
      );
    }

    _closeSelection();
    return;
  }

  try {
    await Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );

    if (!mounted) return;

    _closeSelection();

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Message copied",
        ),
        duration:
            Duration(seconds: 1),
      ),
    );
  } catch (e) {
    debugPrint(
      "ChattªX COPY ERROR: $e",
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't copy message",
        ),
      ),
    );
  }
},

      onPin: () async {
        if (messageId.isEmpty) return;

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
                content:
                    Text("Message pinned"),
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
    if (messageId.isEmpty) return;

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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

    if (confirm != true) return;

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
    if (messageId.isEmpty) return;

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
    if (messageId.isEmpty) return;

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
      builder: (dialogContext) {
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
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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

    if (confirm != true) return;

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
          if (!mounted) return;

          setState(() {
            recording = false;
          });
        },
        onSend:
            (path, duration, waveform) async {
          if (!mounted) return;

          setState(() {
            recording = false;
          });

          await _sendVoiceRecording(
            path,
            duration,
            waveform,
          );
        },
      );
    }

    return Column(
      mainAxisSize:
          MainAxisSize.min,
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
          controller:
              _controller,
          onChanged:
              handleTyping,
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
            if (!mounted ||
                _sendingMessage ||
                _sendingVoice) {
              return;
            }

            setState(() {
              recording = true;
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // REPLY PREVIEW
  // ============================================================

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
              if (!mounted) return;

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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return AttachmentSheet(
        // ========================================================
        // CAMERA
        // ========================================================

        onCamera: (XFile file) async {
          Navigator.pop(sheetContext);

          await _sendImageMessage(file);
        },

        // ========================================================
        // GALLERY
        // ========================================================

        onGallery: () async {
          Navigator.pop(sheetContext);

          final picker = ImagePicker();

          final XFile? file =
              await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 92,
          );

          if (file == null || !mounted) {
            return;
          }

          await _sendImageMessage(file);
        },

        // ========================================================
        // VIDEO
        // ========================================================

        onVideo: () async {
          Navigator.pop(sheetContext);

          final picker = ImagePicker();

          final XFile? file =
              await picker.pickVideo(
            source: ImageSource.gallery,
          );

          if (file == null || !mounted) {
            return;
          }

          await _sendVideoMessage(file);
        },

        // ========================================================
        // AUDIO
        // ========================================================

        onAudio: () {
          debugPrint(
            "ChattªX AUDIO TAPPED",
          );
        },

        // ========================================================
        // DOCUMENT
        // ========================================================

        onDocument: () async {
          Navigator.pop(sheetContext);

          await _pickAndSendDocument();
        },

        // ========================================================
        // LOCATION
        // ========================================================

        onLocation: () {
          Navigator.pop(sheetContext);

          WidgetsBinding.instance
              .addPostFrameCallback(
            (_) {
              if (!mounted) return;

              _showLocationOptions();
            },
          );
        },

        // ========================================================
        // CONTACT
        // ========================================================

        onContact: () {
          debugPrint(
            "ChattªX CONTACT TAPPED",
          );
        },

        // ========================================================
        // POLL
        // ========================================================

        onPoll: () {
          debugPrint(
            "ChattªX POLL TAPPED",
          );
        },

        // ========================================================
        // PAY
        // ========================================================

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
    _typingTimer?.cancel();

    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _receiverStatusSubscription?.cancel();
    _currentVerificationSubscription?.cancel();
    _receiverVerificationSubscription?.cancel();
    _liveLocationSubscription?.cancel();

    _scrollController.removeListener(
      _onScroll,
    );

    _controller.dispose();
_scrollController.dispose();
_currentDateLabel.dispose();

    /*
     * Stop local services before destroying
     * the controller tree.
     */
    try {
      _chatService.setOffline();
    } catch (_) {}

    try {
      _liveLocationController.dispose();
    } catch (_) {}

    super.dispose();
  }
}