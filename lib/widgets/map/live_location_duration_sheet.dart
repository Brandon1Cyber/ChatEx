import 'package:flutter/material.dart';

import 'package:chatex/location/location_message_data.dart';

class LiveLocationDurationSheet extends StatelessWidget {
  const LiveLocationDurationSheet({
    super.key,
  });

  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonBlue = Color(0xFF38BDF8);
  static const Color background = Color(0xFF0B0713);
  static const Color cardBackground = Color(0xFF151021);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.20,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          neonPurple,
                          neonBlue,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: neonPurple.withValues(
                            alpha: 0.30,
                          ),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share live location',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose how long your location stays live',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 15 minutes
              _DurationOption(
                icon: Icons.timer_outlined,
                title: '15 minutes',
                subtitle:
                    'Short-term location sharing',
                onTap: () {
                  Navigator.pop(
                    context,
                    ChattaXLiveLocationDuration
                        .fifteenMinutes,
                  );
                },
              ),

              const SizedBox(height: 10),

              // 1 hour
              _DurationOption(
                icon: Icons.schedule_rounded,
                title: '1 hour',
                subtitle:
                    'Good for meeting someone',
                onTap: () {
                  Navigator.pop(
                    context,
                    ChattaXLiveLocationDuration
                        .oneHour,
                  );
                },
              ),

              const SizedBox(height: 10),

              // 8 hours
              _DurationOption(
                icon: Icons.access_time_rounded,
                title: '8 hours',
                subtitle:
                    'Keep your location live for the day',
                onTap: () {
                  Navigator.pop(
                    context,
                    ChattaXLiveLocationDuration
                        .eightHours,
                  );
                },
              ),

              const SizedBox(height: 10),

              // 30 days
              _DurationOption(
                icon: Icons.calendar_month_rounded,
                title: '30 days',
                subtitle:
                    'Long-term live location sharing',
                onTap: () {
                  Navigator.pop(
                    context,
                    ChattaXLiveLocationDuration
                        .thirtyDays,
                  );
                },
              ),

              const SizedBox(height: 18),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor:
                        Colors.white.withValues(
                      alpha: 0.05,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DurationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color neonPurple =
      Color(0xFF8B5CF6);

  static const Color neonBlue =
      Color(0xFF38BDF8);

  static const Color cardBackground =
      Color(0xFF151021);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: neonPurple.withValues(
          alpha: 0.12,
        ),
        highlightColor: neonPurple.withValues(
          alpha: 0.06,
        ),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      neonPurple,
                      neonBlue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
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
                        fontSize: 12,
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

/// Opens the ChattªX live-location duration selector.
///
/// Returns the selected duration.
/// Returns null if the user cancels.
Future<ChattaXLiveLocationDuration?>
    showLiveLocationDurationSheet(
  BuildContext context,
) {
  return showModalBottomSheet<
      ChattaXLiveLocationDuration>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return const LiveLocationDurationSheet();
    },
  );
}