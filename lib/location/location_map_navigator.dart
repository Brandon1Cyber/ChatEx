import 'package:flutter/material.dart';

import '../screens/maps/chatex_map_screen.dart';
import 'live_location_session.dart';

class ChattaXLocationMapNavigator {
  ChattaXLocationMapNavigator._();

  static Future<void> openLiveLocation({
    required BuildContext context,
    required ChattaXLiveLocationSession session,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatexMapScreen(
            latitude: session.latitude,
            longitude: session.longitude,
            title: 'Live location',
            mode: 'live',
          );
        },
      ),
    );
  }

  static Future<void> openLocation({
    required BuildContext context,
    required double latitude,
    required double longitude,
    String? title,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatexMapScreen(
            latitude: latitude,
            longitude: longitude,
            title: title ?? 'Shared location',
            mode: 'location',
          );
        },
      ),
    );
  }
}