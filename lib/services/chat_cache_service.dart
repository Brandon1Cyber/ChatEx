import 'package:hive_flutter/hive_flutter.dart';

class ChatCacheService {
  static const String _boxName = "chat_cache";
  static const String _key = "chat_list";

  Box get _box => Hive.box(_boxName);

  Future<void> saveChats(
    List<Map<String, dynamic>> chats,
  ) async {
    try {
      final safeChats = chats.map((chat) {
        return _makeHiveSafe(chat);
      }).toList();

      await _box.put(
        _key,
        safeChats,
      );
    } catch (_) {
      // Never let caching stop ChattªX from working.
    }
  }

  List<Map<String, dynamic>> getChats() {
    try {
      final data = _box.get(_key);

      if (data == null) {
        return [];
      }

      if (data is! List) {
        return [];
      }

      return data.map<Map<String, dynamic>>((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearChats() async {
    try {
      await _box.delete(_key);
    } catch (_) {
      // Ignore cache errors.
    }
  }

  Map<String, dynamic> _makeHiveSafe(
    Map<String, dynamic> data,
  ) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      if (value == null ||
          value is String ||
          value is num ||
          value is bool) {
        result[key] = value;
      } else if (value is DateTime) {
        result[key] = value.millisecondsSinceEpoch;
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item == null ||
              item is String ||
              item is num ||
              item is bool) {
            return item;
          }

          return item.toString();
        }).toList();
      } else {
        // Handles Firestore Timestamp and other
        // unsupported Firestore values.
        try {
          result[key] =
              value.toDate().millisecondsSinceEpoch;
        } catch (_) {
          result[key] = value.toString();
        }
      }
    });

    return result;
  }
}