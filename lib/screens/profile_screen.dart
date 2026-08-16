import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/verified_name.dart';
import 'privacy_settings_screen.dart';

/// ============================================================================
/// CHATTªX — MY IDENTITY / PROFILE
/// ============================================================================
///
/// • Futuristic ChattªX profile
/// • True edge-to-edge width
/// • Uses the full available screen height
/// • Bottom controls reach the bottom of the screen
/// • Professional Dashboard stretches
/// • Privacy Shield stretches
/// • Save button stretches
/// • Firebase profile information
/// • Real profile editing
/// • Real bio editing
/// • Real @username editing
/// • Real phone editing
/// • Firebase verification / blue tick
/// • Uses VerifiedName
/// • Privacy Shield
/// • Professional Dashboard
/// • Responsive
/// • No withOpacity()
/// • No studio_rounded
/// • No singleLine
///
/// ============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  static const Color background = Color(0xFF03050D);
  static const Color surface = Color(0xFF080C19);
  static const Color surfaceTwo = Color(0xFF0D1221);

  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFF8A2EFF);
  static const Color deepPurple = Color(0xFF5D18D9);

  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isVerified = false;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  String _savedName = '';
  String _savedUsername = '';
  String _savedBio = '';
  String _savedPhone = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();

    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // LOAD PROFILE
  // ==========================================================================

  Future<void> _loadProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await user.reload();

      final User? refreshedUser =
          FirebaseAuth.instance.currentUser;

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data = snapshot.data();

      final String name =
          refreshedUser?.displayName?.trim().isNotEmpty == true
              ? refreshedUser!.displayName!.trim()
              : ((data?['name'] ??
                          data?['displayName'] ??
                          'ChattªX User')
                      .toString()
                      .trim());

      final String username =
          ((data?['username'] ??
                      data?['userName'] ??
                      '')
                  .toString()
                  .trim()
                  .replaceFirst('@', ''));

      final String bio =
          (data?['bio'] ?? '').toString().trim();

      final String phone =
          ((data?['phoneNumber'] ??
                      data?['phone'] ??
                      refreshedUser?.phoneNumber ??
                      '')
                  .toString()
                  .trim());

      _savedName =
          name.isNotEmpty ? name : 'ChattªX User';

      _savedUsername =
          username.isNotEmpty
              ? username
              : _emailUsername(refreshedUser);

      _savedBio = bio;
      _savedPhone = phone;

      _isVerified = _readVerificationState(data);

      _nameController.text = _savedName;
      _usernameController.text = _savedUsername;
      _bioController.text = _savedBio;
      _phoneController.text = _savedPhone;

      _hasChanges = false;

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      _savedName =
          currentUser?.displayName?.trim().isNotEmpty == true
              ? currentUser!.displayName!.trim()
              : 'ChattªX User';

      _savedUsername =
          _emailUsername(currentUser);

      _savedBio = '';
      _savedPhone =
          currentUser?.phoneNumber ?? '';

      _isVerified = false;

      _nameController.text = _savedName;
      _usernameController.text = _savedUsername;
      _bioController.text = _savedBio;
      _phoneController.text = _savedPhone;

      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _readVerificationState(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return false;
    }

    return data['verified'] == true ||
        data['isVerified'] == true ||
        data['verificationStatus'] == 'verified';
  }

  String _emailUsername(User? user) {
    final String? email =
        user?.email?.trim();

    if (email != null && email.isNotEmpty) {
      final String value =
          email.split('@').first.trim();

      if (value.isNotEmpty) {
        return value.replaceAll(' ', '_');
      }
    }

    return 'chattax_user';
  }

  // ==========================================================================
  // SAVE PROFILE
  // ==========================================================================

  Future<void> _saveProfile() async {
    if (!_hasChanges || _isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'You are not signed in.',
      );
      return;
    }

    final String name =
        _nameController.text.trim();

    final String username =
        _cleanUsername(
      _usernameController.text,
    );

    final String bio =
        _bioController.text.trim();

    final String phone =
        _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Please enter your name.',
      );
      return;
    }

    if (username.isEmpty) {
      _showMessage(
        'Please enter a username.',
      );
      return;
    }

    if (!_validUsername(username)) {
      _showMessage(
        'Username can only contain letters, numbers and underscores.',
      );
      return;
    }

    if (username.length < 3) {
      _showMessage(
        'Username must be at least 3 characters.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (user.displayName != name) {
        await user.updateDisplayName(name);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'username': username,
          'bio': bio,
          'phoneNumber': phone,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.reload();

      _savedName = name;
      _savedUsername = username;
      _savedBio = bio;
      _savedPhone = phone;

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
      }

      _showMessage(
        'Profile saved successfully.',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }

      _showMessage(
        'Could not save your profile. Please try again.',
      );
    }
  }

  String _cleanUsername(String value) {
    return value
        .trim()
        .replaceFirst('@', '')
        .toLowerCase();
  }

  bool _validUsername(String username) {
    return RegExp(
      r'^[a-zA-Z0-9_]+$',
    ).hasMatch(username);
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            // ================================================================
            // IMPORTANT:
            // Use the COMPLETE available height.
            //
            // Previously the screen was forced to 760px which could create
            // empty space underneath the Save button.
            // ================================================================

            final double availableHeight =
                constraints.maxHeight;

            return SizedBox(
              width: constraints.maxWidth,
              height: availableHeight,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  6,
                  4,
                  6,
                  0,
                ),
                child: Column(
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 7),

                    Expanded(
                      child:
                          _buildMainContent(user),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN CONTENT
  // ==========================================================================

  Widget _buildMainContent(User? user) {
    return Column(
      children: [
        // ====================================================================
        // PROFILE HERO
        // ====================================================================

        Expanded(
          flex: 24,
          child:
              _buildIdentityHero(user),
        ),

        const SizedBox(height: 7),

        // ====================================================================
        // PROFILE INFORMATION
        // ====================================================================

        Expanded(
          flex: 14,
          child:
              _buildProfileInformation(user),
        ),

        const SizedBox(height: 7),

        // ====================================================================
        // MOMENTS
        // ====================================================================

        Expanded(
          flex: 15,
          child:
              _buildMoments(),
        ),

        const SizedBox(height: 7),

        // ====================================================================
        // ACTION BUTTONS
        // ====================================================================

        Expanded(
          flex: 13,
          child:
              _buildActionButtons(),
        ),

        const SizedBox(height: 7),

        // ====================================================================
        // BOTTOM CONTROL AREA
        //
        // This entire section is anchored to the bottom.
        //
        // Professional Dashboard
        // Privacy Shield
        // Save
        //
        // The final Save card has NO widget underneath it, so it reaches the
        // exact bottom edge of the available screen.
        // ====================================================================

        Expanded(
          flex: 34,
          child: _buildBottomControlArea(),
        ),
      ],
    );
  }

  // ==========================================================================
  // BOTTOM CONTROL AREA
  // ==========================================================================

  Widget _buildBottomControlArea() {
    return Column(
      children: [
        // ====================================================================
        // PROFESSIONAL DASHBOARD
        // ====================================================================

        Expanded(
          child:
              _buildProfessionalDashboard(),
        ),

        const SizedBox(height: 4),

        // ====================================================================
        // PRIVACY SHIELD
        // ====================================================================

        Expanded(
          child:
              _buildIdentityControls(),
        ),

        const SizedBox(height: 4),

        // ====================================================================
        // SAVE
        //
        // Nothing comes after this.
        // It therefore reaches the exact bottom of the screen.
        // ====================================================================

        Expanded(
          child:
              _buildSaveCard(),
        ),
      ],
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'My Identity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(width: 3),
                    ShaderMask(
                      shaderCallback:
                          (bounds) {
                        return const LinearGradient(
                          colors: [
                            cyan,
                            purple,
                          ],
                        ).createShader(
                          bounds,
                        );
                      },
                      child: const Text(
                        'X',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight:
                              FontWeight.w900,
                          fontStyle:
                              FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Your ChattªX universe',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          _headerButton(
            icon:
                Icons.qr_code_2_rounded,
            iconColor: purple,
            onTap: () {
              _showMessage(
                'ChattªX QR Identity',
              );
            },
          ),

          const SizedBox(width: 6),

          _headerButton(
            icon: Icons.menu_rounded,
            iconColor: Colors.white70,
            onTap: _showMenu,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: surfaceTwo,
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.08,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 25,
        ),
      ),
    );
  }

  // ==========================================================================
  // IDENTITY HERO
  // ==========================================================================

  Widget _buildIdentityHero(User? user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF130A2B),
            Color(0xFF07162B),
            Color(0xFF070A15),
          ],
        ),
        border: Border.all(
          color: purple.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -22,
            child: _backgroundX(
              size: 95,
              opacity: 0.05,
            ),
          ),

          Positioned(
            right: 45,
            bottom: 5,
            child: _backgroundX(
              size: 40,
              opacity: 0.03,
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            child: Row(
              children: [
                _buildAnimatedAvatar(user),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: VerifiedName(
                          name:
                              _displayName(user),
                          verified:
                              _isVerified,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w800,
                          textColor:
                              Colors.white,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '@${_username(user)}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 7),

                      _eliteBadge(),

                      const SizedBox(height: 9),

                      Container(
                        height: 1,
                        color: Colors.white
                            .withValues(
                          alpha: 0.07,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          _heroStat(
                            '469',
                            'Followers',
                          ),
                          _heroDivider(),
                          _heroStat(
                            '192',
                            'Following',
                          ),
                          _heroDivider(),
                          _heroStat(
                            '98%',
                            'Trust',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AVATAR
  // ==========================================================================

  Widget _buildAnimatedAvatar(User? user) {
    return AnimatedBuilder(
      animation:
          _animationController,
      builder: (
        context,
        child,
      ) {
        final double angle =
            _animationController.value *
                6.283185307;

        return Transform.rotate(
          angle: angle,
          child: Container(
            padding:
                const EdgeInsets.all(3.5),
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  SweepGradient(
                colors: [
                  cyan,
                  purple,
                  deepPurple,
                  cyan,
                ],
              ),
            ),
            child: Transform.rotate(
              angle: -angle,
              child: Container(
                padding:
                    const EdgeInsets.all(3.5),
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  color: background,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: CircleAvatar(
        radius: 48,
        backgroundColor:
            const Color(0xFF10182B),
        backgroundImage:
            _hasPhoto(user)
                ? NetworkImage(
                    user!.photoURL!,
                  )
                : null,
        child: !_hasPhoto(user)
            ? const Icon(
                Icons.person_rounded,
                color: Colors.white54,
                size: 48,
              )
            : null,
      ),
    );
  }

  // ==========================================================================
  // ELITE BADGE
  // ==========================================================================

  Widget _eliteBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: purple.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: purple.withValues(
            alpha: 0.8,
          ),
        ),
      ),
      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: purple,
            size: 14,
          ),
          SizedBox(width: 4),
          Text(
            'ELITE',
            style: TextStyle(
              color: purple,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HERO STAT
  // ==========================================================================

  Widget _heroStat(
    String value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 25,
      color: Colors.white.withValues(
        alpha: 0.09,
      ),
    );
  }

  // ==========================================================================
  // PROFILE INFORMATION
  // ==========================================================================

  Widget _buildProfileInformation(
    User? user,
  ) {
    final String bio =
        _savedBio.trim().isEmpty
            ? 'No bio added yet.'
            : _savedBio.trim();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _compactInfo(
                  Icons.grid_view_rounded,
                  'Artist  🎹',
                ),
                _compactInfo(
                  Icons.sports_tennis_rounded,
                  'Padel Addict  🎾 📍',
                ),
                _compactInfo(
                  Icons.phone_outlined,
                  user?.phoneNumber
                              ?.isNotEmpty ==
                          true
                      ? user!.phoneNumber!
                      : (_savedPhone
                              .isNotEmpty
                          ? _savedPhone
                          : 'Add phone number'),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 1,
            height: 58,
            color: Colors.white.withValues(
              alpha: 0.08,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: GestureDetector(
              onTap: _openRealEditor,
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .format_quote_rounded,
                        color: cyan,
                        size: 17,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      const Text(
                        'Bio',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              cyan.withValues(
                            alpha: 0.06,
                          ),
                          border:
                              Border.all(
                            color:
                                cyan.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .edit_outlined,
                          color: cyan,
                          size: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Text(
                    bio,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          _savedBio.isEmpty
                              ? Colors.white38
                              : Colors.white70,
                      fontSize: 10,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfo(
    IconData icon,
    String text,
  ) {
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Icon(
              icon,
              color: cyan,
              size: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MOMENTS
  // ==========================================================================

  Widget _buildMoments() {
    return Column(
      children: [
        SizedBox(
          height: 22,
          child: Row(
            children: [
              ShaderMask(
                shaderCallback:
                    (bounds) {
                  return const LinearGradient(
                    colors: [
                      purple,
                      cyan,
                    ],
                  ).createShader(
                    bounds,
                  );
                },
                child: const Text(
                  'X',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                    fontStyle:
                        FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              const Text(
                'Moments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const Spacer(),

              GestureDetector(
                onTap: () {
                  _showMessage(
                    'All Moments',
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style:
                          TextStyle(
                        color: purple,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons
                          .chevron_right_rounded,
                      color: purple,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: Row(
            children: [
              _moment(
                'New',
                Icons.add_rounded,
                true,
              ),
              _moment(
                'Qhaghazela 🇿🇦',
                Icons.music_note_rounded,
                false,
              ),
              _moment(
                'Izono',
                Icons.auto_awesome_rounded,
                false,
              ),
              _moment(
                'WhistleEffects',
                Icons.graphic_eq_rounded,
                false,
              ),
              _moment(
                'Studio Life',
                Icons.music_video_rounded,
                false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moment(
    String label,
    IconData icon,
    bool isNew,
  ) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              padding:
                  const EdgeInsets.all(2.5),
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    SweepGradient(
                  colors: [
                    purple,
                    cyan,
                    deepPurple,
                    purple,
                  ],
                ),
              ),
              child: Container(
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface,
                  border: Border.all(
                    color: background,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isNew
                      ? Colors.white
                      : cyan,
                  size:
                      isNew ? 27 : 22,
                ),
              ),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: Colors.white70,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACTION BUTTONS
  // ==========================================================================

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            Icons.edit_outlined,
            'Edit Profile',
            _openRealEditor,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _actionButton(
            Icons.ios_share_rounded,
            'Share Profile',
            () {
              _showMessage(
                'Profile sharing',
              );
            },
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _actionButton(
            Icons.send_rounded,
            'Contact',
            () {
              _showMessage(
                'Contact',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(0xFF160D2B),
              Color(0xFF0D1221),
            ],
          ),
          borderRadius:
              BorderRadius.circular(17),
          border: Border.all(
            color: purple.withValues(
              alpha: 0.34,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: cyan,
              size: 21,
            ),

            const SizedBox(height: 2),

            Text(
              title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 1),

            const Text(
              'Open',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // PROFESSIONAL DASHBOARD
  // ==========================================================================

  Widget _buildProfessionalDashboard() {
    return _sameSizeCard(
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(12),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF091A35),
                  Color(0xFF11102A),
                ],
              ),
              border: Border.all(
                color: cyan.withValues(
                  alpha: 0.32,
                ),
              ),
            ),
            child: const Icon(
              Icons
                  .workspace_premium_rounded,
              color: cyan,
              size: 23,
            ),
          ),

          const SizedBox(width: 9),

          const Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Professional Dashboard',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your growth and unlock exclusive tools.',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          _smallOpenButton(
            onTap: () {
              _showMessage(
                'Professional Dashboard',
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PRIVACY SHIELD
  // ==========================================================================

  Widget _buildIdentityControls() {
    return _sameSizeCard(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const PrivacySettingsScreen(),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(12),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF081B35),
                    Color(0xFF10152B),
                  ],
                ),
                border: Border.all(
                  color: cyan.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: cyan,
                size: 22,
              ),
            ),

            const SizedBox(width: 9),

            const Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy Shield',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Control your privacy and visibility',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SAVE CARD
  // ==========================================================================

  Widget _buildSaveCard() {
    return GestureDetector(
      onTap:
          _hasChanges && !_isSaving
              ? _saveProfile
              : null,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(17),
          gradient: _hasChanges
              ? const LinearGradient(
                  begin:
                      Alignment.centerLeft,
                  end:
                      Alignment.centerRight,
                  colors: [
                    purple,
                    cyan,
                  ],
                )
              : const LinearGradient(
                  begin:
                      Alignment.centerLeft,
                  end:
                      Alignment.centerRight,
                  colors: [
                    Color(0xFF151927),
                    Color(0xFF10131E),
                  ],
                ),
          border: Border.all(
            color: _hasChanges
                ? cyan.withValues(
                    alpha: 0.65,
                  )
                : Colors.white.withValues(
                    alpha: 0.08,
                  ),
          ),
          boxShadow: _hasChanges
              ? [
                  BoxShadow(
                    color:
                        purple.withValues(
                      alpha: 0.22,
                    ),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.save_rounded,
                      color: _hasChanges
                          ? Colors.white
                          : Colors.white30,
                      size: 20,
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    Text(
                      _hasChanges
                          ? 'Save Changes'
                          : 'No Changes to Save',
                      style: TextStyle(
                        color: _hasChanges
                            ? Colors.white
                            : Colors.white30,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SAME SIZE CARD
  // ==========================================================================

  Widget _sameSizeCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090D1B),
            Color(0xFF110C27),
          ],
        ),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: purple.withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: child,
      ),
    );
  }

  // ==========================================================================
  // OPEN BUTTON
  // ==========================================================================

  Widget _smallOpenButton({
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: purple,
          ),
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              'Open',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            SizedBox(width: 2),
            Icon(
              Icons
                  .chevron_right_rounded,
              color: purple,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MENU
  // ==========================================================================

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            25,
          ),
          decoration:
              const BoxDecoration(
            color: Color(0xFF080C19),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(25),
            ),
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
                    10,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _menuItem(
                Icons.edit_outlined,
                'Edit Profile',
                () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openRealEditor();
                },
              ),

              _menuItem(
                Icons.shield_outlined,
                'Privacy Shield',
                () {
                  Navigator.pop(
                    sheetContext,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PrivacySettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 8,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          color: surfaceTwo,
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white
                .withValues(
              alpha: 0.07,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: cyan,
              size: 23,
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // REAL PROFILE EDITOR
  // ==========================================================================

  Future<void> _openRealEditor() async {
    final bool? changed =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _RealProfileEditor(
          initialName: _savedName,
          initialUsername:
              _savedUsername,
          initialBio: _savedBio,
          initialPhone: _savedPhone,
        ),
      ),
    );

    if (changed == true) {
      await _loadProfile();
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool _hasPhoto(User? user) {
    return user != null &&
        user.photoURL != null &&
        user.photoURL!.trim().isNotEmpty;
  }

  String _displayName(User? user) {
    final String? name =
        user?.displayName?.trim();

    if (name != null &&
        name.isNotEmpty) {
      return name;
    }

    if (_savedName.isNotEmpty) {
      return _savedName;
    }

    return 'ChattªX User';
  }

  String _username(User? user) {
    if (_savedUsername.isNotEmpty) {
      return _savedUsername;
    }

    return _emailUsername(user);
  }

  Widget _backgroundX({
    required double size,
    required double opacity,
  }) {
    return Opacity(
      opacity: opacity,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [
              purple,
              cyan,
            ],
          ).createShader(
            bounds,
          );
        },
        child: Text(
          'X',
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight:
                FontWeight.w900,
            fontStyle:
                FontStyle.italic,
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              surfaceTwo,
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(
            seconds: 2,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }
}

// ============================================================================
// REAL PROFILE EDITOR
// ============================================================================

class _RealProfileEditor
    extends StatefulWidget {
  final String initialName;
  final String initialUsername;
  final String initialBio;
  final String initialPhone;

  const _RealProfileEditor({
    required this.initialName,
    required this.initialUsername,
    required this.initialBio,
    required this.initialPhone,
  });

  @override
  State<_RealProfileEditor> createState() =>
      _RealProfileEditorState();
}

class _RealProfileEditorState
    extends State<_RealProfileEditor> {
  static const Color background =
      Color(0xFF03050D);

  static const Color surface =
      Color(0xFF080C19);

  static const Color surfaceTwo =
      Color(0xFF0D1221);

  static const Color cyan =
      Color(0xFF00D9FF);

  static const Color purple =
      Color(0xFF8A2EFF);

  late TextEditingController
      _nameController;

  late TextEditingController
      _usernameController;

  late TextEditingController
      _bioController;

  late TextEditingController
      _phoneController;

  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text: widget.initialName,
    );

    _usernameController =
        TextEditingController(
      text: widget.initialUsername,
    );

    _bioController =
        TextEditingController(
      text: widget.initialBio,
    );

    _phoneController =
        TextEditingController(
      text: widget.initialPhone,
    );

    _nameController.addListener(
      _checkChanges,
    );

    _usernameController.addListener(
      _checkChanges,
    );

    _bioController.addListener(
      _checkChanges,
    );

    _phoneController.addListener(
      _checkChanges,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  void _checkChanges() {
    final bool changed =
        _nameController.text.trim() !=
                widget.initialName.trim() ||
            _cleanUsername(
                  _usernameController.text,
                ) !=
                _cleanUsername(
                  widget.initialUsername,
                ) ||
            _bioController.text.trim() !=
                widget.initialBio.trim() ||
            _phoneController.text.trim() !=
                widget.initialPhone.trim();

    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  String _cleanUsername(
    String value,
  ) {
    return value
        .trim()
        .replaceFirst('@', '')
        .toLowerCase();
  }

  bool _validUsername(
    String value,
  ) {
    return RegExp(
      r'^[a-zA-Z0-9_]+$',
    ).hasMatch(value);
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message(
        'You are not signed in.',
      );
      return;
    }

    final String name =
        _nameController.text.trim();

    final String username =
        _cleanUsername(
      _usernameController.text,
    );

    final String bio =
        _bioController.text.trim();

    final String phone =
        _phoneController.text.trim();

    if (name.isEmpty) {
      _message(
        'Enter your name.',
      );
      return;
    }

    if (username.isEmpty) {
      _message(
        'Enter a username.',
      );
      return;
    }

    if (!_validUsername(username)) {
      _message(
        'Username can only use letters, numbers and underscores.',
      );
      return;
    }

    if (username.length < 3) {
      _message(
        'Username must be at least 3 characters.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (user.displayName != name) {
        await user.updateDisplayName(name);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': name,
          'displayName': name,
          'username': username,
          'bio': bio,
          'phoneNumber': phone,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.reload();

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }

      _message(
        'Could not save your profile.',
      );
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor:
              surfaceTwo,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ================================================================
            // EDITOR HEADER
            // ================================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                7,
                8,
                10,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _saving
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                            );
                          },
                    child: Container(
                      width: 47,
                      height: 47,
                      decoration:
                          BoxDecoration(
                        color: surfaceTwo,
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                        border:
                            Border.all(
                          color: Colors
                              .white
                              .withValues(
                            alpha: 0.08,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .arrow_back_rounded,
                        color:
                            Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Edit Profile',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customize your ChattªX identity',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap:
                        _hasChanges &&
                                !_saving
                            ? _save
                            : null,
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 200,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          17,
                        ),
                        gradient:
                            _hasChanges
                                ? const LinearGradient(
                                    colors: [
                                      purple,
                                      cyan,
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(
                                        0xFF151927,
                                      ),
                                      Color(
                                        0xFF10131E,
                                      ),
                                    ],
                                  ),
                        border:
                            Border.all(
                          color: _hasChanges
                              ? cyan
                              : Colors.white
                                  .withValues(
                                  alpha:
                                      0.08,
                                ),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : Text(
                              'SAVE',
                              style:
                                  TextStyle(
                                color:
                                    _hasChanges
                                        ? Colors
                                            .white
                                        : Colors
                                            .white30,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                letterSpacing:
                                    0.7,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // EDITOR BODY
            // ================================================================

            Expanded(
              child:
                  SingleChildScrollView(
                physics:
                    const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  8,
                  0,
                  8,
                  25,
                ),
                child: Column(
                  children: [
                    _editorCard(
                      title:
                          'Display Name',
                      icon: Icons
                          .person_outline_rounded,
                      child: TextField(
                        controller:
                            _nameController,
                        maxLines: 1,
                        textInputAction:
                            TextInputAction
                                .next,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                        ),
                        decoration:
                            _inputDecoration(
                          'Your name',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _editorCard(
                      title:
                          '@Username',
                      icon: Icons
                          .alternate_email_rounded,
                      child: TextField(
                        controller:
                            _usernameController,
                        maxLines: 1,
                        textInputAction:
                            TextInputAction
                                .next,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                        ),
                        decoration:
                            _inputDecoration(
                          'username',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _editorCard(
                      title: 'Bio',
                      icon: Icons
                          .format_quote_rounded,
                      child: TextField(
                        controller:
                            _bioController,
                        minLines: 2,
                        maxLines: 4,
                        keyboardType:
                            TextInputType
                                .multiline,
                        textInputAction:
                            TextInputAction
                                .newline,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                        decoration:
                            _inputDecoration(
                          'Tell people about yourself...',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _editorCard(
                      title:
                          'Phone Number',
                      icon: Icons
                          .phone_outlined,
                      child: TextField(
                        controller:
                            _phoneController,
                        maxLines: 1,
                        keyboardType:
                            TextInputType
                                .phone,
                        textInputAction:
                            TextInputAction
                                .done,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                        ),
                        decoration:
                            _inputDecoration(
                          '+27...',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    GestureDetector(
                      onTap:
                          _hasChanges &&
                                  !_saving
                              ? _save
                              : null,
                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds:
                              200,
                        ),
                        height: 62,
                        width:
                            double.infinity,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                          gradient:
                              _hasChanges
                                  ? const LinearGradient(
                                      colors: [
                                        purple,
                                        cyan,
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(
                                          0xFF151927,
                                        ),
                                        Color(
                                          0xFF10131E,
                                        ),
                                      ],
                                    ),
                          border:
                              Border.all(
                            color: _hasChanges
                                ? cyan
                                : Colors.white
                                    .withValues(
                                    alpha:
                                        0.08,
                                  ),
                          ),
                        ),
                        child: Center(
                          child: _saving
                              ? const CircularProgressIndicator(
                                  strokeWidth:
                                      2.4,
                                  color:
                                      Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(
                                      Icons
                                          .save_rounded,
                                      color: _hasChanges
                                          ? Colors
                                              .white
                                          : Colors
                                              .white30,
                                      size: 21,
                                    ),
                                    const SizedBox(
                                      width: 7,
                                    ),
                                    Text(
                                      _hasChanges
                                          ? 'Save Changes'
                                          : 'No Changes to Save',
                                      style:
                                          TextStyle(
                                        color: _hasChanges
                                            ? Colors
                                                .white
                                            : Colors
                                                .white30,
                                        fontSize:
                                            13,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // EDITOR CARD
  // ==========================================================================

  Widget _editorCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        14,
      ),
      decoration:
          BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: Colors.white
              .withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: cyan,
                size: 19,
              ),

              const SizedBox(width: 8),

              Text(
                title,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          child,
        ],
      ),
    );
  }

  // ==========================================================================
  // INPUT DECORATION
  // ==========================================================================

  InputDecoration _inputDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(
        color: Colors.white30,
        fontSize: 14,
      ),
      filled: true,
      fillColor: surfaceTwo,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            BorderSide(
          color: Colors.white
              .withValues(
            alpha: 0.06,
          ),
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            BorderSide(
          color: Colors.white
              .withValues(
            alpha: 0.06,
          ),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: cyan,
          width: 1.2,
        ),
      ),
    );
  }
}