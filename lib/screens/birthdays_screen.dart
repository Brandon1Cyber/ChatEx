import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ============================================================================
/// CHATTªX — COMPACT FUTURISTIC BIRTHDAYS SCREEN
/// ============================================================================
///
/// REAL DATA
/// ---------
/// users/{uid}
///
/// Birthday:
///   birthday
///
/// Supported names:
///   name
///   displayName
///
/// Supported photos:
///   photoUrl
///   profilePhoto
///   photo
///
/// Users without birthdays are not displayed.
///
/// The Wish button is only active on the user's birthday.
/// ============================================================================

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================================
  // CHATTªX COLOR SYSTEM
  // ==========================================================================

  static const Color background = Color(0xFF050816);
  static const Color backgroundDeep = Color(0xFF030309);

  static const Color surface = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF0D1324);
  static const Color surfaceRaised = Color(0xFF10182A);

  static const Color border = Color(0xFF18243A);

  static const Color purple = Color(0xFF8B2CF8);
  static const Color brightPurple = Color(0xFFD946EF);

  static const Color deepPurple = Color(0xFF4018D8);
  static const Color deepPurple3 = Color(0xFF250C70);

  static const Color neonPurple = Color(0xFFB026FF);
  static const Color cyan = Color(0xFF00D9FF);

  static const Color primaryText = Color(0xFFF5F7FF);

  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================

  final TextEditingController _searchController =
      TextEditingController();

  late final AnimationController _animationController;

  String _search = '';

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundDeep,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  DateTime? _birthdayFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }

      final parts = value.split(RegExp(r'[-/]'));

      if (parts.length == 3) {
        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        final third = int.tryParse(parts[2]);

        if (first != null &&
            second != null &&
            third != null) {
          if (first > 31) {
            return DateTime(first, second, third);
          }

          if (third > 31) {
            return DateTime(third, second, first);
          }
        }
      }
    }

    return null;
  }

  bool _isToday(DateTime? birthday) {
    if (birthday == null) {
      return false;
    }

    final now = DateTime.now();

    return birthday.month == now.month &&
        birthday.day == now.day;
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();

    int age = now.year - birthday.year;

    if (now.month < birthday.month ||
        (now.month == birthday.month &&
            now.day < birthday.day)) {
      age--;
    }

    return age < 0 ? 0 : age;
  }

  DateTime _nextBirthday(DateTime birthday) {
    final now = DateTime.now();

    DateTime next = DateTime(
      now.year,
      birthday.month,
      birthday.day,
    );

    if (DateUtils.dateOnly(next).isBefore(
      DateUtils.dateOnly(now),
    )) {
      next = DateTime(
        now.year + 1,
        birthday.month,
        birthday.day,
      );
    }

    return next;
  }

  int _daysUntilBirthday(DateTime birthday) {
    final today = DateUtils.dateOnly(
      DateTime.now(),
    );

    final next = DateUtils.dateOnly(
      _nextBirthday(birthday),
    );

    return next.difference(today).inDays;
  }

  String _birthdayDateText(DateTime birthday) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[birthday.month - 1]} ${birthday.day}';
  }

  // ==========================================================================
  // WISH
  // ==========================================================================

  void _sendWish({
    required String userId,
    required String name,
    required bool isToday,
  }) {
    if (!isToday) {
      _showMessage(
        'You can wish $name on their birthday.',
        Icons.lock_outline_rounded,
      );

      return;
    }

    _showMessage(
      'Birthday wish ready for $name 🎉',
      Icons.cake_rounded,
    );
  }

  void _showMessage(
    String message,
    IconData icon,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            16,
          ),
          backgroundColor: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: BorderSide(
              color: purple.withValues(alpha: 0.40),
            ),
          ),
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      cyan,
                      purple,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: purple.withValues(alpha: 0.25),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundDeep,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundDeep,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // =================================================================
            // BACKGROUND
            // =================================================================

            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      background,
                      backgroundDeep,
                    ],
                  ),
                ),
              ),
            ),

            // =================================================================
            // PURPLE GLOW
            // =================================================================

            Positioned(
              top: -170,
              right: -130,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      deepPurple.withValues(alpha: 0.20),
                      deepPurple3.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // =================================================================
            // CYAN GLOW
            // =================================================================

            Positioned(
              top: 200,
              left: -220,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cyan.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // =================================================================
            // HUD RING
            // =================================================================

            Positioned(
              top: -120,
              right: -95,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle:
                        _animationController.value *
                        math.pi *
                        2,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 290,
                  height: 290,
                  child: CustomPaint(
                    painter: _HudRingPainter(
                      purple: neonPurple,
                      cyan: cyan,
                    ),
                  ),
                ),
              ),
            ),

            // =================================================================
            // EDGE-TO-EDGE CONTENT
            // =================================================================

            Column(
              children: [
                _buildHeader(),
                _buildSearch(),
                Expanded(
                  child: _buildBirthdayStream(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    final topPadding =
        MediaQuery.of(context).viewPadding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        topPadding + 7,
        0,
        6,
      ),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              Navigator.of(context).maybePop();
            },
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
  'Birthdays',
  style: TextStyle(
    color: Colors.white,
    fontSize: 25,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.9,
  ),
),
                const SizedBox(height: 1),
                Text(
                  'Celebrate your ChattªX people',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.40,
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface,
              border: Border.all(
                color: neonPurple.withValues(
                  alpha: 0.38,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: neonPurple.withValues(
                    alpha: 0.14,
                  ),
                  blurRadius: 22,
                ),
              ],
            ),
            child: const Icon(
  Icons.cake_rounded,
  color: Colors.white,
  size: 21,
),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        3,
        0,
        9,
      ),
      child: Container(
        height: 49,
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.22,
              ),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _search = value.trim().toLowerCase();
            });
          },
          style: const TextStyle(
            color: primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: cyan,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Search birthdays...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
  Icons.search_rounded,
  color: Colors.white,
  size: 20,
),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 19,
                    ),
                  ),
            contentPadding:
                const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 4,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FIRESTORE
  // ==========================================================================

  Widget _buildBirthdayStream() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState();
        }

        final documents =
            snapshot.data?.docs ?? [];

        final users = documents.where((doc) {
          final data = doc.data();

          final birthday = _birthdayFromValue(
            data['birthday'],
          );

          if (birthday == null) {
            return false;
          }

          final name = (
            data['name'] ??
            data['displayName'] ??
            ''
          )
              .toString()
              .trim()
              .toLowerCase();

          if (_search.isNotEmpty &&
              !name.contains(_search)) {
            return false;
          }

          return true;
        }).toList();

        users.sort((a, b) {
          final aBirthday = _birthdayFromValue(
            a.data()['birthday'],
          );

          final bBirthday = _birthdayFromValue(
            b.data()['birthday'],
          );

          if (aBirthday == null ||
              bBirthday == null) {
            return 0;
          }

          return _daysUntilBirthday(aBirthday)
              .compareTo(
            _daysUntilBirthday(bBirthday),
          );
        });

        if (users.isEmpty) {
          return _buildEmptyState();
        }

        final todayUsers = users.where((doc) {
          final birthday = _birthdayFromValue(
            doc.data()['birthday'],
          );

          return _isToday(birthday);
        }).toList();

        final upcomingUsers = users.where((doc) {
          final birthday = _birthdayFromValue(
            doc.data()['birthday'],
          );

          return !_isToday(birthday);
        }).toList();

        return RefreshIndicator(
          color: cyan,
          backgroundColor: surface,
          onRefresh: () async {
            await FirebaseFirestore.instance
                .collection('users')
                .get();
          },
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent:
                  AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              0,
              0,
              0,
              35,
            ),
            children: [
              if (todayUsers.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Happening today',
                  subtitle:
                      'Make someone feel special',
                  icon:
                      Icons.auto_awesome_rounded,
                  accent: cyan,
                ),
                const SizedBox(height: 6),
                ...todayUsers.map(
                  _buildBirthdayCard,
                ),
                if (upcomingUsers.isNotEmpty)
                  const SizedBox(height: 0),
              ],

              if (upcomingUsers.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Coming up',
                  subtitle:
                      'Never miss a birthday',
                  icon:
                      Icons.calendar_month_rounded,
                  accent: neonPurple,
                ),
                const SizedBox(height: 2),
                ...upcomingUsers.map(
                  _buildBirthdayCard,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // SECTION HEADER
  // ==========================================================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        2,
        0,
        2,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(11),
              color: accent.withValues(
                alpha: 0.07,
              ),
              border: Border.all(
                color: accent.withValues(
                  alpha: 0.20,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 17,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.34,
                    ),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                    alpha: 0.45,
                  ),
                  blurRadius: 9,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMPACT BIRTHDAY CARD
  // ==========================================================================

  Widget _buildBirthdayCard(
    QueryDocumentSnapshot<Map<String, dynamic>>
        user,
  ) {
    final data = user.data();

    final String userId = user.id;

    final String name = (
      data['name'] ??
      data['displayName'] ??
      'ChattªX User'
    )
        .toString()
        .trim();

    final String photoUrl = (
      data['photoUrl'] ??
      data['profilePhoto'] ??
      data['photo'] ??
      ''
    )
        .toString()
        .trim();

    final DateTime? birthday =
        _birthdayFromValue(
      data['birthday'],
    );

    if (birthday == null) {
      return const SizedBox.shrink();
    }

    final bool isToday =
        _isToday(birthday);

    final int age =
        _calculateAge(birthday);

    final int daysLeft =
        _daysUntilBirthday(birthday);

    final String dateText =
        _birthdayDateText(birthday);

    final Color accent =
        isToday ? cyan : neonPurple;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(19),
        color: surface,
        border: Border.all(
          color: isToday
              ? cyan.withValues(alpha: 0.34)
              : border,
          width: isToday ? 1.1 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? cyan.withValues(alpha: 0.06)
                : Colors.black.withValues(
                    alpha: 0.20,
                  ),
            blurRadius: isToday ? 22 : 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(19),
        child: Stack(
          children: [
            // ================================================================
            // CARD GLOW
            // ================================================================

            Positioned(
              top: -75,
              right: -70,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(
                        alpha: isToday
                            ? 0.08
                            : 0.045,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ================================================================
            // TOP ACCENT LINE
            // ================================================================

            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accent.withValues(
                        alpha: 0.45,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                11,
                11,
                11,
                10,
              ),
              child: Column(
                children: [
                  // ==========================================================
                  // TOP USER ROW
                  // ==========================================================

                  Row(
                    children: [
                      _buildAvatar(
                        photoUrl: photoUrl,
                        name: name,
                        isToday: isToday,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name.isEmpty
                                        ? 'ChattªX User'
                                        : name,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      color: primaryText,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  const Text(
                                    '🎉',
                                    style:
                                        TextStyle(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 3),

                            Text(
                              isToday
                                  ? 'Birthday today'
                                  : 'Birthday • $dateText',
                              style: TextStyle(
                                color: isToday
                                    ? cyan
                                    : Colors.white
                                        .withValues(
                                        alpha: 0.46,
                                      ),
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 7),

                      _buildCountdown(
                        isToday: isToday,
                        daysLeft: daysLeft,
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  // ==========================================================
                  // COMPACT INFORMATION STRIP
                  // ==========================================================

                  Container(
                    height: 48,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceDark.withValues(
                        alpha: 0.88,
                      ),
                      borderRadius:
                          BorderRadius.circular(13),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: Row(
                      children: [
                        _infoItem(
                          icon:
                              Icons.cake_outlined,
                          label: isToday
                              ? 'Today'
                              : 'Next',
                          value: isToday
                              ? '🎂'
                              : '$daysLeft d',
                        ),

                        _verticalDivider(),

                        _infoItem(
                          icon: Icons
                              .person_outline_rounded,
                          label: 'Turning',
                          value: '$age',
                        ),

                        _verticalDivider(),

                        _infoItem(
                          icon: Icons
                              .calendar_today_outlined,
                          label: 'Date',
                          value: dateText,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==========================================================
                  // WISH BUTTON
                  // ==========================================================

                  _buildWishButton(
                    userId: userId,
                    name: name,
                    isToday: isToday,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // COMPACT AVATAR
  // ==========================================================================

  Widget _buildAvatar({
    required String photoUrl,
    required String name,
    required bool isToday,
  }) {
    final Color accent =
        isToday ? cyan : neonPurple;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isToday
                  ? const [
                      cyan,
                      purple,
                    ]
                  : const [
                      purple,
                      brightPurple,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                  alpha: 0.18,
                ),
                blurRadius: 15,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundDeep,
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stack) {
                        return _avatarFallback(
                          name,
                        );
                      },
                    )
                  : _avatarFallback(name),
            ),
          ),
        ),

        if (isToday)
          Positioned(
            right: -4,
            bottom: -3,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: purple,
                shape: BoxShape.circle,
                border: Border.all(
                  color: backgroundDeep,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(
                      alpha: 0.32,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🎂',
                  style: TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    String letter = '?';

    if (name.trim().isNotEmpty) {
      letter =
          name.trim()[0].toUpperCase();
    }

    return Container(
      color: surfaceRaised,
      alignment: Alignment.center,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [
              cyan,
              purple,
            ],
          ).createShader(bounds);
        },
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // COMPACT COUNTDOWN
  // ==========================================================================

  Widget _buildCountdown({
    required bool isToday,
    required int daysLeft,
  }) {
    if (isToday) {
      return Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: cyan.withValues(alpha: 0.07),
          borderRadius:
              BorderRadius.circular(9),
          border: Border.all(
            color: cyan.withValues(alpha: 0.20),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: cyan,
              size: 11,
            ),
            SizedBox(width: 3),
            Text(
              'TODAY',
              style: TextStyle(
                color: cyan,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: 0.07),
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color: purple.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        '$daysLeft ${daysLeft == 1 ? 'DAY' : 'DAYS'}',
        style: const TextStyle(
          color: cyan,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ==========================================================================
  // COMPACT INFO ITEM
  // ==========================================================================

  Widget _infoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 13,
            color: cyan.withValues(
              alpha: 0.80,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.30,
              ),
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: primaryText,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 26,
      color: border,
    );
  }

  // ==========================================================================
  // COMPACT WISH BUTTON
  // ==========================================================================

  Widget _buildWishButton({
    required String userId,
    required String name,
    required bool isToday,
  }) {
    if (!isToday) {
      return Container(
        width: double.infinity,
        height: 38,
        decoration: BoxDecoration(
          color: surfaceRaised,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: border,
          ),
        ),
        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.white38,
              size: 14,
            ),
            SizedBox(width: 6),
            Text(
              'Wish locked until their birthday',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          _sendWish(
            userId: userId,
            name: name,
            isToday: isToday,
          );
        },
        child: Ink(
          width: double.infinity,
          height: 38,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            gradient:
                const LinearGradient(
              colors: [
                deepPurple,
                purple,
                brightPurple,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(
                  alpha: 0.18,
                ),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cake_rounded,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'Wish them a Happy Birthday',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '🎉',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ICON BUTTON
  // ==========================================================================

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: border,
            ),
          ),
          child: Icon(
            icon,
            color: primaryText,
            size: 17,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // LOADING
  // ==========================================================================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color: cyan,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading birthdays...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // EMPTY
  // ==========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    deepPurple3,
                    surfaceRaised,
                  ],
                ),
                border: Border.all(
                  color: neonPurple.withValues(
                    alpha: 0.28,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        neonPurple.withValues(
                      alpha: 0.13,
                    ),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: const Icon(
                Icons.cake_outlined,
                color: cyan,
                size: 32,
              ),
            ),

            const SizedBox(height: 19),

            const Text(
              'No birthdays found',
              style: TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              _search.isNotEmpty
                  ? 'Try searching for another person.'
                  : 'Birthdays will appear here when ChattªX users add their birthday.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.40,
                ),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surface,
                border: Border.all(
                  color: border,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white38,
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Birthdays unavailable',
              style: TextStyle(
                color: primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'We could not load the birthday list right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.40,
                ),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FUTURISTIC HUD RING
// ============================================================================

class _HudRingPainter extends CustomPainter {
  final Color purple;
  final Color cyan;

  _HudRingPainter({
    required this.purple,
    required this.cyan,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        size.width / 2 - 8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    paint.color =
        purple.withValues(alpha: 0.11);

    canvas.drawCircle(
      center,
      radius,
      paint,
    );

    paint.color =
        cyan.withValues(alpha: 0.08);

    canvas.drawCircle(
      center,
      radius - 14,
      paint,
    );

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    paint.color =
        purple.withValues(alpha: 0.18);

    canvas.drawArc(
      rect,
      -0.7,
      1.1,
      false,
      paint,
    );

    paint.color =
        cyan.withValues(alpha: 0.15);

    canvas.drawArc(
      rect,
      2.0,
      0.75,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _HudRingPainter oldDelegate,
  ) {
    return false;
  }
}