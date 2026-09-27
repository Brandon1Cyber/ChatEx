import 'package:hive_flutter/hive_flutter.dart';

/// ============================================================================
/// CHATTªX — CHAT MESSAGE CACHE SERVICE
/// ============================================================================
///
/// Purpose:
/// - Keep chat messages locally in Hive.
/// - Read cached messages synchronously.
/// - Save Firestore messages in the background.
/// - Prevent ChatScreen from opening completely blank when cached messages
///   are already available.
///
/// IMPORTANT:
/// Hive must be initialized and the box opened BEFORE runApp().
/// ============================================================================

class ChatMessageCacheService {
  static const String _boxName = "chat_message_cache";

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  // ==========================================================================
  // BOX
  // ==========================================================================

  Box get _box => Hive.box(_boxName);

  // ==========================================================================
  // KEYS
  // ==========================================================================

  String _messagesKey(String chatId) {
    return "messages_$chatId";
  }

  String _syncKey(String chatId) {
    return "sync_$chatId";
  }

  // ==========================================================================
  // SAVE MESSAGES
  // ==========================================================================

  Future<void> saveMessages(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await initialize();
    }

    final cleanMessages = messages
        .map<Map<String, dynamic>>(
          (message) => Map<String, dynamic>.from(message),
        )
        .toList();

    try {
      await _box.put(
        _messagesKey(chatId),
        cleanMessages,
      );
    } catch (e) {
      // Never allow cache failure to affect the chat screen.
      print(
        "ChattªX CACHE SAVE ERROR: $e",
      );
    }
  }

  // ==========================================================================
  // GET CACHED MESSAGES
  // ==========================================================================
  //
  // This method is intentionally synchronous.
  //
  // ChatScreen can call it immediately and put the messages into memory
  // without waiting for another Future.
  //

  List<Map<String, dynamic>> getMessages(
    String chatId,
  ) {
    if (!Hive.isBoxOpen(_boxName)) {
      return <Map<String, dynamic>>[];
    }

    try {
      final data = _box.get(
        _messagesKey(chatId),
      );

      if (data == null || data is! List) {
        return <Map<String, dynamic>>[];
      }

      return data
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      print(
        "ChattªX CACHE READ ERROR: $e",
      );

      return <Map<String, dynamic>>[];
    }
  }

  // ==========================================================================
  // SAVE LAST SYNC
  // ==========================================================================

  Future<void> saveLastSync(
    String chatId,
    DateTime timestamp,
  ) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await initialize();
    }

    try {
      await _box.put(
        _syncKey(chatId),
        timestamp.millisecondsSinceEpoch,
      );
    } catch (e) {
      print(
        "ChattªX CACHE SYNC SAVE ERROR: $e",
      );
    }
  }

  // ==========================================================================
  // GET LAST SYNC
  // ==========================================================================

  DateTime? getLastSync(
    String chatId,
  ) {
    if (!Hive.isBoxOpen(_boxName)) {
      return null;
    }

    try {
      final value = _box.get(
        _syncKey(chatId),
      );

      if (value is! int) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    } catch (e) {
      print(
        "ChattªX CACHE SYNC READ ERROR: $e",
      );

      return null;
    }
  }

  // ==========================================================================
  // HAS MESSAGES
  // ==========================================================================

  bool hasMessages(
    String chatId,
  ) {
    return getMessages(chatId).isNotEmpty;
  }

  // ==========================================================================
  // CLEAR CHAT
  // ==========================================================================

  Future<void> clearMessages(
    String chatId,
  ) async {
    if (!Hive.isBoxOpen(_boxName)) {
      return;
    }

    try {
      await _box.delete(
        _messagesKey(chatId),
      );

      await _box.delete(
        _syncKey(chatId),
      );
    } catch (e) {
      print(
        "ChattªX CACHE CLEAR ERROR: $e",
      );
    }
  }

  // ==========================================================================
  // CLEAR EVERYTHING
  // ==========================================================================

  Future<void> clearAllMessages() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return;
    }

    try {
      await _box.clear();
    } catch (e) {
      print(
        "ChattªX CACHE CLEAR ALL ERROR: $e",
      );
    }
  }
}
