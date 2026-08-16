import 'package:flutter/material.dart';

import 'location_message_data.dart';

class ChattaXLiveLocationDurationSheet {
  static Future<ChattaXLiveLocationDuration?> show(
    BuildContext context,
  ) async {
    return showModalBottomSheet<ChattaXLiveLocationDuration>(
      context: context,
      backgroundColor: const Color(0xff080D18),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // =====================================================
                // HANDLE
                // =====================================================

                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                // =====================================================
                // ICON
                // =====================================================

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffff3158)
                        .withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xffff3158)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xffff3158),
                    size: 30,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Share live location",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Choose how long you want ChattªX to share your live location.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 22),

                // =====================================================
                // 15 MINUTES
                // =====================================================

                _durationOption(
                  context: context,
                  icon: Icons.timer_outlined,
                  title: "15 minutes",
                  subtitle: "Short trip or quick meetup",
                  duration:
                      ChattaXLiveLocationDuration.fifteenMinutes,
                ),

                const SizedBox(height: 10),

                // =====================================================
                // 1 HOUR
                // =====================================================

                _durationOption(
                  context: context,
                  icon: Icons.schedule_rounded,
                  title: "1 hour",
                  subtitle: "Keep sharing for an hour",
                  duration:
                      ChattaXLiveLocationDuration.oneHour,
                ),

                const SizedBox(height: 10),

                // =====================================================
                // 8 HOURS
                // =====================================================

                _durationOption(
                  context: context,
                  icon: Icons.access_time_filled_rounded,
                  title: "8 hours",
                  subtitle: "For longer trips and activities",
                  duration:
                      ChattaXLiveLocationDuration.eightHours,
                ),

                const SizedBox(height: 10),

                // =====================================================
                // 30 DAYS
                // =====================================================

                _durationOption(
                  context: context,
                  icon: Icons.calendar_month_rounded,
                  title: "30 days",
                  subtitle: "Long-term live location sharing",
                  duration:
                      ChattaXLiveLocationDuration.thirtyDays,
                ),

                const SizedBox(height: 10),

                // =====================================================
                // CANCEL
                // =====================================================

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _durationOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ChattaXLiveLocationDuration duration,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(
            context,
            duration,
          );
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xff111827),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xffff3158)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xffff3158),
                  size: 23,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}