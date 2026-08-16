import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserCacheService {
  static const String _cacheKey = "chatex_user_cache";

  Map<String, Map<String, dynamic>> _users = {};

  bool _loaded = false;

  // Prevent multiple save operations from fighting each other.
  Future<void>? _saveOperation;

  // ============================================================
  // LOAD CACHE
  // ============================================================

  Future<void> load() async {
    // Already loaded.
    if (_loaded) return;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final raw =
          prefs.getString(_cacheKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded =
            jsonDecode(raw);

        if (decoded is Map) {
          final Map<String, Map<String, dynamic>>
              loadedUsers = {};

          decoded.forEach((key, value) {
            if (value is Map) {
              loadedUsers[key.toString()] =
                  Map<String, dynamic>.from(value);
            }
          });

          _users = loadedUsers;
        }
      }
    } catch (e) {
      // If the cache is corrupted,
      // don't crash ChattªX.
      _users = {};
    }

    _loaded = true;
  }

  // ============================================================
  // MAKE SURE CACHE IS READY
  // ============================================================

  Future<void> ensureLoaded() async {
    if (!_loaded) {
      await load();
    }
  }

  // ============================================================
  // GET USER
  // ============================================================

  Map<String, dynamic>? getUser(
    String uid,
  ) {
    if (uid.isEmpty) return null;

    return _users[uid];
  }

  // ============================================================
  // CHECK IF USER EXISTS IN CACHE
  // ============================================================

  bool hasUser(
    String uid,
  ) {
    if (uid.isEmpty) return false;

    return _users.containsKey(uid);
  }

  // ============================================================
  // SAVE USER
  // ============================================================

  Future<void> saveUser(
    String uid,
    Map<String, dynamic> user,
  ) async {
    if (uid.isEmpty) return;

    _users[uid] = {
      ...?_users[uid],
      ...user,
    };

    await _saveCache();
  }

  // ============================================================
  // SAVE USER WITHOUT BLOCKING THE UI
  // ============================================================

  void saveUserFast(
    String uid,
    Map<String, dynamic> user,
  ) {
    if (uid.isEmpty) return;

    _users[uid] = {
      ...?_users[uid],
      ...user,
    };

    // Save locally without making the UI wait.
    _saveInBackground();
  }

  // ============================================================
  // SAVE CACHE
  // ============================================================

  Future<void> _saveCache() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        _cacheKey,
        jsonEncode(_users),
      );
    } catch (_) {}
  }

  // ============================================================
  // SAVE CACHE IN BACKGROUND
  // ============================================================

  void _saveInBackground() {
    // If a save is already happening, don't start
    // unnecessary simultaneous SharedPreferences writes.
    if (_saveOperation != null) {
      return;
    }

    _saveOperation = _saveCache();

    _saveOperation!.whenComplete(() {
      _saveOperation = null;
    });
  }

  // ============================================================
  // REMOVE USER
  // ============================================================

  Future<void> removeUser(
    String uid,
  ) async {
    if (uid.isEmpty) return;

    _users.remove(uid);

    await _saveCache();
  }

  // ============================================================
  // CLEAR ALL CACHE
  // ============================================================

  Future<void> clear() async {
    _users.clear();

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  // ============================================================
  // GET ALL CACHED USERS
  // ============================================================

  Map<String, Map<String, dynamic>>
      getAllUsers() {
    return Map<String, Map<String, dynamic>>.from(
      _users,
    );
  }
}