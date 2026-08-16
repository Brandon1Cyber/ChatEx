import 'package:hive_flutter/hive_flutter.dart';

class ChatMessageCacheService {
  static const String _boxName = "chat_message_cache";

  Box get _box => Hive.box(_boxName);

  String _messagesKey(String chatId) {
    return "messages_$chatId";
  }

  String _syncKey(String chatId) {
    return "sync_$chatId";
  }

  // ============================================================
  // SAVE MESSAGES
  // ============================================================

  Future<void> saveMessages(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    final cleanMessages = messages
        .map(
          (message) => Map<String, dynamic>.from(message),
        )
        .toList();

    await _box.put(
      _messagesKey(chatId),
      cleanMessages,
    );
  }

  // ============================================================
  // GET CACHED MESSAGES
  // ============================================================

  List<Map<String, dynamic>> getMessages(
    String chatId,
  ) {
    final data = _box.get(
      _messagesKey(chatId),
    );

    if (data == null || data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // SAVE LAST SYNC TIMESTAMP
  // ============================================================

  Future<void> saveLastSync(
    String chatId,
    DateTime timestamp,
  ) async {
    await _box.put(
      _syncKey(chatId),
      timestamp.millisecondsSinceEpoch,
    );
  }

  // ============================================================
  // GET LAST SYNC TIMESTAMP
  // ============================================================

  DateTime? getLastSync(
    String chatId,
  ) {
    final value = _box.get(
      _syncKey(chatId),
    );

    if (value is! int) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      value,
    );
  }

  // ============================================================
  // HAS CACHE
  // ============================================================

  bool hasMessages(
    String chatId,
  ) {
    final messages = getMessages(chatId);

    return messages.isNotEmpty;
  }

  // ============================================================
  // CLEAR CHAT
  // ============================================================

  Future<void> clearMessages(
    String chatId,
  ) async {
    await _box.delete(
      _messagesKey(chatId),
    );

    await _box.delete(
      _syncKey(chatId),
    );
  }

  // ============================================================
  // CLEAR EVERYTHING
  // ============================================================

  Future<void> clearAllMessages() async {
    await _box.clear();
  }
}