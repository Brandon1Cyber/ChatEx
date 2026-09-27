import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../services/cloudinary_service.dart';
import '../widgets/verified_name.dart';

/// ============================================================================
/// ChattªX — CREATE POST
/// ============================================================================
///
/// Features:
/// • Real user profile picture
/// • Real user name
/// • Real verified blue tick
/// • Photo
/// • Video
/// • Camera
/// • Voice Note
/// • Add more media
/// • Music
/// • Feeling
/// • Tag people
/// • Schedule
/// • Poll
/// • Location
/// • Event
/// • GIF
/// • Save Draft
/// • Post Preview
/// • Cloudinary media uploads
/// • Firestore post creation
///
/// Layout:
/// • Almost edge-to-edge
/// • Compact spacing
/// • No AI controls
/// • No oversized decorative elements
/// • No unnecessary animations
/// ============================================================================

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // ==========================================================================
  // COLORS
  // ==========================================================================

  static const Color kBg = Color(0xFF050816);
  static const Color kCard = Color(0xFF0B0A14);
  static const Color kBorder = Color(0xFF262238);

  static const Color kPurple = Color(0xFFB026FF);
  static const Color kPurpleDeep = Color(0xFF7B2FF7);

  static const Color kTextDim = Color(0xFF9B98A8);

  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================

  final TextEditingController _postController =
      TextEditingController();

  final TextEditingController _tagController =
      TextEditingController();

  final TextEditingController _locationController =
      TextEditingController();

  final TextEditingController _eventTitleController =
      TextEditingController();

  final TextEditingController _eventDescriptionController =
      TextEditingController();

  final TextEditingController _gifController =
      TextEditingController();

  final TextEditingController _pollQuestionController =
      TextEditingController();

  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final ImagePicker _picker = ImagePicker();

  final AudioRecorder _audioRecorder = AudioRecorder();

  VideoPlayerController? _videoController;

  // ==========================================================================
  // STATE
  // ==========================================================================

  bool _publishingPost = false;
  bool _savingDraft = false;
  bool _loadingProfile = true;

  int _charCount = 0;

  // ==========================================================================
  // MEDIA STATE
  // ==========================================================================

  final List<XFile> _selectedMedia = <XFile>[];

  String? _voiceNotePath;

  bool _isRecordingVoice = false;

  // ==========================================================================
  // USER PROFILE
  // ==========================================================================

  Map<String, dynamic>? _currentUserData;

  // ==========================================================================
  // ENHANCEMENT STATE
  // ==========================================================================

  String? _selectedFeeling;

  String? _selectedMusicPath;

  String? _selectedMusicName;

  final List<String> _taggedPeople = <String>[];

  DateTime? _scheduledDateTime;

  String? _selectedLocation;

  String? _gifUrl;

  String? _eventTitle;

  String? _eventDescription;

  String? _pollQuestion;

  List<String> _pollOptions = <String>[];

  // ==========================================================================
  // FEELINGS
  // ==========================================================================

  final List<Map<String, String>> _feelings = [
    {'emoji': '😀', 'name': 'Happy'},
    {'emoji': '😍', 'name': 'Loved'},
    {'emoji': '🥳', 'name': 'Celebrating'},
    {'emoji': '😎', 'name': 'Cool'},
    {'emoji': '😢', 'name': 'Sad'},
    {'emoji': '😡', 'name': 'Angry'},
    {'emoji': '😴', 'name': 'Tired'},
    {'emoji': '🤔', 'name': 'Thinking'},
    {'emoji': '🙏', 'name': 'Grateful'},
    {'emoji': '🔥', 'name': 'Excited'},
    {'emoji': '💪', 'name': 'Motivated'},
    {'emoji': '🥰', 'name': 'Blessed'},
  ];

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  @override
  void dispose() {
    _postController.dispose();
    _tagController.dispose();
    _locationController.dispose();
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    _gifController.dispose();
    _pollQuestionController.dispose();

    for (final controller in _pollOptionControllers) {
      controller.dispose();
    }

    _audioRecorder.dispose();
    _videoController?.dispose();

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 2,
        ),
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: 4),

            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LOAD CURRENT USER
  // ==========================================================================

  Future<void> _loadCurrentUserProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProfile = false;
      });

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserData =
            doc.data() ?? <String, dynamic>{};
        _loadingProfile = false;
      });
    } catch (e) {
      debugPrint(
        'ChattªX profile loading error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserData = <String, dynamic>{};
        _loadingProfile = false;
      });
    }
  }

  // ==========================================================================
  // CURRENT USER NAME
  // ==========================================================================

  String get _currentUserName {
    final User? user =
        FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> data =
        _currentUserData ?? <String, dynamic>{};

    final String displayName =
        (data['displayName'] ?? '').toString().trim();

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final String name =
        (data['name'] ?? '').toString().trim();

    if (name.isNotEmpty) {
      return name;
    }

    final String fullName =
        (data['fullName'] ?? '').toString().trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final String authDisplayName =
        user?.displayName?.trim() ?? '';

    if (authDisplayName.isNotEmpty) {
      return authDisplayName;
    }

    return 'ChattªX User';
  }

  // ==========================================================================
  // CURRENT USER PHOTO
  // ==========================================================================

  String? get _currentUserPhotoUrl {
    final User? user =
        FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> data =
        _currentUserData ?? <String, dynamic>{};

    const List<String> photoFields = [
      'photoUrl',
      'profilePhoto',
      'profileImage',
      'profileImageUrl',
      'photoURL',
      'avatarUrl',
      'avatar',
    ];

    for (final String field in photoFields) {
      final String? value =
          data[field]?.toString().trim();

      if (value != null &&
          value.isNotEmpty &&
          value != 'null') {
        return value;
      }
    }

    final String? authPhoto =
        user?.photoURL?.trim();

    if (authPhoto != null &&
        authPhoto.isNotEmpty) {
      return authPhoto;
    }

    return null;
  }

  // ==========================================================================
  // CURRENT USER VERIFIED
  // ==========================================================================

  bool get _currentUserIsVerified {
    final Map<String, dynamic> data =
        _currentUserData ?? <String, dynamic>{};

    final dynamic value =
        data['verified'] ??
        data['isVerified'] ??
        data['verification'] ??
        data['verifiedUser'];

    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }

  // ==========================================================================
  // MAIN CONTENT
  // ==========================================================================

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        return Column(
          children: [
            _buildUserRow(),

            const SizedBox(height: 5),

            Expanded(
              child: _buildScrollableContent(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 108,
            child: _buildPostInput(),
          ),

          const SizedBox(height: 5),

          if (_hasSelectedMedia) ...[
            SizedBox(
              height: 145,
              child: _buildMediaRow(),
            ),
            const SizedBox(height: 5),
          ],

          _buildActionIconsRow(),

          const SizedBox(height: 5),

          _buildEnhanceSection(),

          if (_hasAnyEnhancement) ...[
            const SizedBox(height: 5),
            _buildSelectedEnhancements(),
          ],

          const SizedBox(height: 5),

          _buildSaveDraftButton(),

          const SizedBox(height: 4),

          _buildFooterNote(),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              icon: const Icon(
                Icons.close,
                color: kPurple,
                size: 24,
              ),
            ),
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: const [
                Text(
                  'Create Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ChattªX',
                  style: TextStyle(
                    color: kPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 36,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  kPurpleDeep,
                  kPurple,
                ],
              ),
            ),
            child: TextButton(
              onPressed: _nextPost,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                ),
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NEXT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 1),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // USER ROW
  // ==========================================================================

  Widget _buildUserRow() {
    return SizedBox(
      height: 47,
      child: Row(
        children: [
          _buildRealProfilePicture(),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                _loadingProfile
                    ? Container(
                        width: 110,
                        height: 15,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1A1726),
                          borderRadius:
                              BorderRadius.circular(5),
                        ),
                      )
                    : VerifiedName(
                        name: _currentUserName,
                        verified:
                            _currentUserIsVerified,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                        textColor: Colors.white,
                      ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    _buildPill(
                      icon: Icons.public,
                      label: 'Public',
                    ),

                    const SizedBox(width: 5),

                    // AI ASSIST REMOVED.
                    // Replaced with a useful preview action.
                    GestureDetector(
                      onTap: _nextPost,
                      child: _buildPill(
                        icon: Icons.visibility_outlined,
                        label: 'Preview',
                        borderColor: kPurple,
                        labelColor: kPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 5),

          _buildAudienceButton(),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROFILE PICTURE
  // ==========================================================================

  Widget _buildRealProfilePicture() {
    final String? photoUrl =
        _currentUserPhotoUrl;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kPurple,
          width: 1.6,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return _defaultProfileAvatar();
                },
              )
            : _defaultProfileAvatar(),
      ),
    );
  }

  Widget _defaultProfileAvatar() {
    return Container(
      width: 40,
      height: 40,
      color: const Color(0xFF1A1726),
      child: const Icon(
        Icons.person,
        color: Colors.white54,
        size: 21,
      ),
    );
  }

  // ==========================================================================
  // PILL
  // ==========================================================================

  Widget _buildPill({
    IconData? icon,
    required String label,
    Color? borderColor,
    Color? labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? kBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: labelColor ??
                  Colors.white70,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color:
                  labelColor ?? Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AUDIENCE
  // ==========================================================================

  Widget _buildAudienceButton() {
    return Container(
      height: 34,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 14,
            color: kPurple,
          ),
          SizedBox(width: 3),
          Text(
            'Audience',
            style: TextStyle(
              color: kPurple,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // POST INPUT
  // ==========================================================================

  Widget _buildPostInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        9,
        8,
        9,
        5,
      ),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _postController,
              maxLength: 500,
              maxLines: null,
              expands: true,
              textAlignVertical:
                  TextAlignVertical.top,
              onChanged: (String value) {
                setState(() {
                  _charCount = value.length;
                });
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
              ),
              decoration:
                  const InputDecoration(
                hintText:
                    "What's on your mind?",
                hintStyle: TextStyle(
                  color: kTextDim,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                counterText: '',
                isCollapsed: true,
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '$_charCount/500',
              style: const TextStyle(
                color: kTextDim,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MEDIA
  // ==========================================================================

  bool get _hasSelectedMedia =>
      _selectedMedia.isNotEmpty ||
      _voiceNotePath != null ||
      _isRecordingVoice;

  Widget _buildMediaRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: _buildMainMediaPreview(),
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _addMoreMedia,
            child: DottedBorderBox(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration:
                        const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          LinearGradient(
                        colors: [
                          kPurpleDeep,
                          kPurple,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Add more',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const Text(
                    'Photos / Videos',
                    style: TextStyle(
                      color: kPurple,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MAIN MEDIA PREVIEW
  // ==========================================================================

  Widget _buildMainMediaPreview() {
    if (_isRecordingVoice) {
      return Container(
        color: kCard,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    LinearGradient(
                  colors: [
                    kPurpleDeep,
                    kPurple,
                  ],
                ),
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 25,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Recording Voice Note...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            const Text(
              'Tap Voice Note to stop',
              style: TextStyle(
                color: kTextDim,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_voiceNotePath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: kCard,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        LinearGradient(
                      colors: [
                        kPurpleDeep,
                        kPurple,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 25,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Voice Note Ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: _removeVoiceNote,
              child: _closeButton(),
            ),
          ),
        ],
      );
    }

    if (_selectedMedia.isEmpty) {
      return Container(
        color: kCard,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: kTextDim,
            size: 34,
          ),
        ),
      );
    }

    final XFile media =
        _selectedMedia.last;

    if (_isVideo(media.path)) {
      if (_videoController != null &&
          _videoController!
              .value
              .isInitialized) {
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    _videoController!
                        .value
                        .size
                        .width,
                height:
                    _videoController!
                        .value
                        .size
                        .height,
                child: VideoPlayer(
                  _videoController!,
                ),
              ),
            ),

            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleVideo,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration:
                        const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _videoController!
                              .value
                              .isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 6,
              left: 6,
              child: _mediaCounter(),
            ),

            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () {
                  _removeMedia(
                    _selectedMedia.length - 1,
                  );
                },
                child: _closeButton(),
              ),
            ),
          ],
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(media.path),
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return Container(
              color: kCard,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: kTextDim,
                size: 34,
              ),
            );
          },
        ),

        Positioned(
          top: 6,
          left: 6,
          child: _mediaCounter(),
        ),

        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () {
              _removeMedia(
                _selectedMedia.length - 1,
              );
            },
            child: _closeButton(),
          ),
        ),
      ],
    );
  }

  Widget _mediaCounter() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        '${_selectedMedia.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _closeButton() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.close,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  // ==========================================================================
  // MEDIA ACTIONS
  // ==========================================================================

  Widget _buildActionIconsRow() {
    return Container(
      width: double.infinity,
      height: 57,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: _actionIcon(
                Icons.photo_library,
                kPurple,
                'Photo',
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: _pickVideo,
              child: _actionIcon(
                Icons.play_circle_fill,
                kPurple,
                'Video',
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: _takePhoto,
              child: _actionIcon(
                Icons.camera_alt,
                kPurple,
                'Camera',
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: _toggleVoiceNote,
              child: _actionIcon(
                _isRecordingVoice
                    ? Icons.stop_circle
                    : Icons.mic,
                _isRecordingVoice
                    ? Colors.redAccent
                    : kPurple,
                _isRecordingVoice
                    ? 'Stop'
                    : 'Voice Note',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    Color color,
    String label,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),

          const SizedBox(height: 2),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ENHANCE SECTION
  // ==========================================================================

  Widget _buildEnhanceSection() {
    final List<_EnhanceItem> items = [
      _EnhanceItem(
        Icons.music_note,
        kPurple,
        'Music',
        _showMusicPicker,
      ),
      _EnhanceItem(
        Icons.person_add_alt_1,
        kPurple,
        'Tag people',
        _showTagPeopleDialog,
      ),
      _EnhanceItem(
        Icons.location_on,
        kPurple,
        'Location',
        _showLocationDialog,
      ),
      _EnhanceItem(
        Icons.emoji_emotions,
        kPurple,
        'Feeling',
        _showFeelingPicker,
      ),
      _EnhanceItem(
        Icons.bar_chart,
        kPurple,
        'Poll',
        _showPollDialog,
      ),
      _EnhanceItem(
        Icons.schedule,
        kPurple,
        'Schedule',
        _showSchedulePicker,
      ),
      _EnhanceItem(
        Icons.event,
        kPurple,
        'Event',
        _showEventDialog,
      ),
      _EnhanceItem(
        Icons.gif_box,
        kPurple,
        'GIF',
        _showGifDialog,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enhance your post',
            style: TextStyle(
              color: kPurple,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.38,
            ),
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final _EnhanceItem item =
                  items[index];

              return GestureDetector(
                onTap: item.onTap,
                child: _buildEnhanceTile(item),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhanceTile(
    _EnhanceItem item,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: item.color,
            size: 17,
          ),

          const SizedBox(height: 2),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SELECTED ENHANCEMENTS
  // ==========================================================================

  bool get _hasAnyEnhancement {
    return _selectedFeeling != null ||
        _selectedMusicName != null ||
        _taggedPeople.isNotEmpty ||
        _scheduledDateTime != null ||
        _selectedLocation != null ||
        _gifUrl != null ||
        _eventTitle != null ||
        _pollQuestion != null;
  }

  Widget _buildSelectedEnhancements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Added to your post',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (_selectedFeeling != null)
                _selectedChip(
                  Icons.emoji_emotions,
                  _selectedFeeling!,
                ),

              if (_selectedMusicName != null)
                _selectedChip(
                  Icons.music_note,
                  _selectedMusicName!,
                ),

              if (_taggedPeople.isNotEmpty)
                _selectedChip(
                  Icons.person,
                  'Tagged: ${_taggedPeople.join(', ')}',
                ),

              if (_scheduledDateTime != null)
                _selectedChip(
                  Icons.schedule,
                  _formatDateTime(
                    _scheduledDateTime!,
                  ),
                ),

              if (_selectedLocation != null)
                _selectedChip(
                  Icons.location_on,
                  _selectedLocation!,
                ),

              if (_pollQuestion != null)
                _selectedChip(
                  Icons.bar_chart,
                  'Poll',
                ),

              if (_eventTitle != null)
                _selectedChip(
                  Icons.event,
                  _eventTitle!,
                ),

              if (_gifUrl != null)
                _selectedChip(
                  Icons.gif_box,
                  'GIF',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectedChip(
    IconData icon,
    String text,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth: 280,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: kBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: kPurple,
            size: 12,
          ),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PHOTO
  // ==========================================================================

  Future<void> _pickPhoto() async {
    try {
      final XFile? file =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _selectedMedia.add(file);
      });

      await _prepareVideoPreview();
    } catch (e) {
      _showError(
        'Could not select photo.',
      );
    }
  }

  // ==========================================================================
  // VIDEO
  // ==========================================================================

  Future<void> _pickVideo() async {
    try {
      final XFile? file =
          await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _selectedMedia.add(file);
      });

      await _prepareVideoPreview();
    } catch (e) {
      _showError(
        'Could not select video.',
      );
    }
  }

  // ==========================================================================
  // CAMERA
  // ==========================================================================

  Future<void> _takePhoto() async {
    try {
      final XFile? file =
          await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _selectedMedia.add(file);
      });

      await _prepareVideoPreview();
    } catch (e) {
      _showError(
        'Could not open camera.',
      );
    }
  }

  // ==========================================================================
  // ADD MORE MEDIA
  // ==========================================================================

  Future<void> _addMoreMedia() async {
    try {
      final List<XFile> files =
          await _picker.pickMultipleMedia();

      if (files.isEmpty) {
        return;
      }

      setState(() {
        _selectedMedia.addAll(files);
      });

      await _prepareVideoPreview();
    } catch (e) {
      _showError(
        'Could not add media.',
      );
    }
  }

  // ==========================================================================
  // VOICE NOTE
  // ==========================================================================

  Future<void> _toggleVoiceNote() async {
    if (_isRecordingVoice) {
      await _stopVoiceNote();
    } else {
      await _startVoiceNote();
    }
  }

  Future<void> _startVoiceNote() async {
    try {
      final bool permission =
          await _audioRecorder.hasPermission();

      if (!permission) {
        _showError(
          'Microphone permission is required.',
        );
        return;
      }

      final Directory directory =
          await getTemporaryDirectory();

      final String path =
          '${directory.path}/chattax_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoice = true;
        _voiceNotePath = null;
      });
    } catch (e) {
      _showError(
        'Could not start Voice Note.',
      );
    }
  }

  Future<void> _stopVoiceNote() async {
    try {
      final String? path =
          await _audioRecorder.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoice = false;
        _voiceNotePath = path;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
        });
      }

      _showError(
        'Could not save Voice Note.',
      );
    }
  }

  void _removeVoiceNote() {
    setState(() {
      _voiceNotePath = null;
    });
  }

  // ==========================================================================
  // VIDEO PREVIEW
  // ==========================================================================

  bool _isVideo(String path) {
    final String lower =
        path.toLowerCase();

    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  Future<void> _prepareVideoPreview() async {
    await _videoController?.dispose();

    _videoController = null;

    if (_selectedMedia.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final XFile media =
        _selectedMedia.last;

    if (!_isVideo(media.path)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final VideoPlayerController controller =
        VideoPlayerController.file(
      File(media.path),
    );

    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
      });
    } catch (e) {
      await controller.dispose();

      debugPrint(
        'ChattªX video preview error: $e',
      );
    }
  }

  void _toggleVideo() {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null) {
      return;
    }

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  Future<void> _removeMedia(
    int index,
  ) async {
    if (index < 0 ||
        index >= _selectedMedia.length) {
      return;
    }

    setState(() {
      _selectedMedia.removeAt(index);
    });

    await _prepareVideoPreview();
  }

  // ==========================================================================
  // MUSIC
  // ==========================================================================

  Future<void> _showMusicPicker() async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final PlatformFile file =
          result.files.first;

      setState(() {
        _selectedMusicPath = file.path;
        _selectedMusicName = file.name;
      });
    } catch (e) {
      _showError(
        'Could not select music.',
      );
    }
  }

  // ==========================================================================
  // FEELING
  // ==========================================================================

  Future<void> _showFeelingPicker() async {
    final String? result =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (
        BuildContext context,
      ) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'How are you feeling?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                GridView.builder(
                  shrinkWrap: true,
                  itemCount:
                      _feelings.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final Map<String, String>
                        feeling =
                        _feelings[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(
                          context,
                          '${feeling['emoji']} ${feeling['name']}',
                        );
                      },
                      child: Container(
                        decoration:
                            BoxDecoration(
                          color: kBg,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          border: Border.all(
                            color: kBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Text(
                              feeling['emoji']!,
                              style:
                                  const TextStyle(
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              feeling['name']!,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
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

    if (result != null) {
      setState(() {
        _selectedFeeling = result;
      });
    }
  }

  // ==========================================================================
  // TAG PEOPLE
  // ==========================================================================

  Future<void> _showTagPeopleDialog() async {
    _tagController.clear();

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return _dialog(
          title: 'Tag people',
          child: TextField(
            controller: _tagController,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                _inputDecoration(
              'Enter a name',
            ),
          ),
          onSave: () {
            final String value =
                _tagController.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(
                context,
                value,
              );
            }
          },
        );
      },
    );

    if (result != null &&
        result.trim().isNotEmpty) {
      setState(() {
        if (!_taggedPeople.contains(
          result.trim(),
        )) {
          _taggedPeople.add(
            result.trim(),
          );
        }
      });
    }
  }

  // ==========================================================================
  // LOCATION
  // ==========================================================================

  Future<void> _showLocationDialog() async {
    _locationController.text =
        _selectedLocation ?? '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return _dialog(
          title: 'Add location',
          child: TextField(
            controller:
                _locationController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                _inputDecoration(
              'e.g. Johannesburg',
            ),
          ),
          onSave: () {
            final String value =
                _locationController
                    .text
                    .trim();

            if (value.isNotEmpty) {
              Navigator.pop(
                context,
                value,
              );
            }
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  // ==========================================================================
  // SCHEDULE
  // ==========================================================================

  Future<void> _showSchedulePicker() async {
    final DateTime now =
        DateTime.now();

    final DateTime? date =
        await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(
        const Duration(days: 365),
      ),
      initialDate:
          _scheduledDateTime ?? now,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.dark(
              primary: kPurple,
              surface: kCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null ||
        !mounted) {
      return;
    }

    final TimeOfDay? time =
        await showTimePicker(
      context: context,
      initialTime:
          _scheduledDateTime != null
              ? TimeOfDay.fromDateTime(
                  _scheduledDateTime!,
                )
              : TimeOfDay.now(),
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.dark(
              primary: kPurple,
              surface: kCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null) {
      return;
    }

    setState(() {
      _scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ==========================================================================
  // POLL
  // ==========================================================================

  Future<void> _showPollDialog() async {
    _pollQuestionController.text =
        _pollQuestion ?? '';

    for (final TextEditingController
        controller
        in _pollOptionControllers) {
      controller.clear();
    }

    if (_pollOptions.isNotEmpty) {
      for (
        int i = 0;
        i < _pollOptions.length &&
            i <
                _pollOptionControllers
                    .length;
        i++
      ) {
        _pollOptionControllers[i].text =
            _pollOptions[i];
      }
    }

    final _PollResult? result =
        await showDialog<_PollResult>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: kCard,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              title: const Text(
                'Create a poll',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          _pollQuestionController,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                      decoration:
                          _inputDecoration(
                        'Poll question',
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...List.generate(
                      _pollOptionControllers
                          .length,
                      (
                        int index,
                      ) {
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 7,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child:
                                    TextField(
                                  controller:
                                      _pollOptionControllers[
                                          index],
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                  ),
                                  decoration:
                                      _inputDecoration(
                                    'Option ${index + 1}',
                                  ),
                                ),
                              ),

                              if (_pollOptionControllers
                                      .length >
                                  2)
                                IconButton(
                                  onPressed: () {
                                    final TextEditingController
                                        controller =
                                        _pollOptionControllers
                                            .removeAt(
                                      index,
                                    );

                                    controller
                                        .dispose();

                                    setDialogState(
                                      () {},
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons.close,
                                    color:
                                        kTextDim,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    if (_pollOptionControllers
                            .length <
                        4)
                      TextButton.icon(
                        onPressed: () {
                          _pollOptionControllers
                              .add(
                            TextEditingController(),
                          );

                          setDialogState(
                            () {},
                          );
                        },
                        icon:
                            const Icon(
                          Icons.add,
                          color: kPurple,
                        ),
                        label:
                            const Text(
                          'Add option',
                          style:
                              TextStyle(
                            color: kPurple,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: kTextDim,
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    final String question =
                        _pollQuestionController
                            .text
                            .trim();

                    final List<String>
                        options =
                        _pollOptionControllers
                            .map(
                              (
                                TextEditingController
                                    controller,
                              ) =>
                                  controller
                                      .text
                                      .trim(),
                            )
                            .where(
                              (
                                String value,
                              ) =>
                                  value
                                      .isNotEmpty,
                            )
                            .toList();

                    if (question.isEmpty ||
                        options.length <
                            2) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a question and at least 2 options.',
                          ),
                        ),
                      );

                      return;
                    }

                    Navigator.pop(
                      context,
                      _PollResult(
                        question: question,
                        options: options,
                      ),
                    );
                  },
                  child: const Text(
                    'Add Poll',
                    style: TextStyle(
                      color: kPurple,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _pollQuestion = result.question;
        _pollOptions = result.options;
      });
    }
  }

  // ==========================================================================
  // EVENT
  // ==========================================================================

  Future<void> _showEventDialog() async {
    _eventTitleController.text =
        _eventTitle ?? '';

    _eventDescriptionController.text =
        _eventDescription ?? '';

    final Map<String, String>? result =
        await showDialog<
            Map<String, String>>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return _dialog(
          title: 'Create event',
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    _eventTitleController,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Event name',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    _eventDescriptionController,
                maxLines: 3,
                style:
                    const TextStyle(
                  color: Colors.white,
                ),
                decoration:
                    _inputDecoration(
                  'Description',
                ),
              ),
            ],
          ),
          onSave: () {
            final String title =
                _eventTitleController
                    .text
                    .trim();

            final String description =
                _eventDescriptionController
                    .text
                    .trim();

            if (title.isNotEmpty) {
              Navigator.pop(
                context,
                <String, String>{
                  'title': title,
                  'description':
                      description,
                },
              );
            }
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _eventTitle = result['title'];
        _eventDescription =
            result['description'];
      });
    }
  }

  // ==========================================================================
  // GIF
  // ==========================================================================

  Future<void> _showGifDialog() async {
    _gifController.text =
        _gifUrl ?? '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext context,
      ) {
        return _dialog(
          title: 'Add GIF',
          child: TextField(
            controller: _gifController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                _inputDecoration(
              'Paste GIF URL',
            ),
          ),
          onSave: () {
            final String value =
                _gifController.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(
                context,
                value,
              );
            }
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _gifUrl = result;
      });
    }
  }

  // ==========================================================================
  // DIALOG
  // ==========================================================================

  AlertDialog _dialog({
    required String title,
    required Widget child,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      backgroundColor: kCard,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      content: child,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: kTextDim,
            ),
          ),
        ),
        TextButton(
          onPressed: onSave,
          child: const Text(
            'Add',
            style: TextStyle(
              color: kPurple,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
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
      hintStyle: const TextStyle(
        color: kTextDim,
        fontSize: 13,
      ),
      filled: true,
      fillColor: kBg,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: kBorder,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: kBorder,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: kPurple,
        ),
      ),
    );
  }

  // ==========================================================================
  // SAVE DRAFT
  // ==========================================================================

  Widget _buildSaveDraftButton() {
    return SizedBox(
      width: double.infinity,
      height: 43,
      child: OutlinedButton.icon(
        onPressed: _savingDraft
            ? null
            : _saveDraft,
        style:
            OutlinedButton.styleFrom(
          side: const BorderSide(
            color: kBorder,
          ),
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        icon: _savingDraft
            ? const SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPurple,
                ),
              )
            : const Icon(
                Icons.description_outlined,
                color: Colors.white70,
                size: 16,
              ),
        label: Text(
          _savingDraft
              ? 'Saving...'
              : 'Save Draft',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight:
                FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_savingDraft) {
      return;
    }

    setState(() {
      _savingDraft = true;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 500,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _savingDraft = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text(
          'Draft saved.',
        ),
      ),
    );
  }

  // ==========================================================================
  // NEXT / POST SUMMARY
  // ==========================================================================

  Future<void> _nextPost() async {
    final bool hasContent =
        _postController.text
                .trim()
                .isNotEmpty ||
            _hasSelectedMedia ||
            _hasAnyEnhancement;

    if (!hasContent) {
      _showError(
        'Add something to your post first.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your post is ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 9),

                _summaryLine(
                  Icons.text_fields,
                  _postController.text
                          .trim()
                          .isEmpty
                      ? 'No caption'
                      : 'Caption added',
                ),

                _summaryLine(
                  Icons.perm_media,
                  _selectedMedia.isNotEmpty
                      ? '${_selectedMedia.length} media item(s)'
                      : 'No media',
                ),

                if (_voiceNotePath != null)
                  _summaryLine(
                    Icons.mic,
                    'Voice note added',
                  ),

                if (_selectedFeeling != null)
                  _summaryLine(
                    Icons.emoji_emotions,
                    _selectedFeeling!,
                  ),

                if (_selectedMusicName != null)
                  _summaryLine(
                    Icons.music_note,
                    _selectedMusicName!,
                  ),

                if (_taggedPeople.isNotEmpty)
                  _summaryLine(
                    Icons.person,
                    '${_taggedPeople.length} tagged',
                  ),

                if (_selectedLocation != null)
                  _summaryLine(
                    Icons.location_on,
                    _selectedLocation!,
                  ),

                if (_pollQuestion != null)
                  _summaryLine(
                    Icons.bar_chart,
                    'Poll added',
                  ),

                if (_eventTitle != null)
                  _summaryLine(
                    Icons.event,
                    _eventTitle!,
                  ),

                if (_gifUrl != null)
                  _summaryLine(
                    Icons.gif_box,
                    'GIF added',
                  ),

                if (_scheduledDateTime != null)
                  _summaryLine(
                    Icons.schedule,
                    'Scheduled for ${_formatDateTime(_scheduledDateTime!)}',
                  ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed:
                      _publishingPost
                          ? null
                          : () async {
                              await _publishPost(
                                sheetContext,
                              );
                            },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        kPurple,
                    disabledBackgroundColor:
                        kPurple.withValues(
                      alpha: .45,
                    ),
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: _publishingPost
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Publishing...',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _scheduledDateTime !=
                                  null
                              ? 'Schedule Post'
                              : 'Publish Post',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w700,
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

  // ==========================================================================
  // PUBLISH POST
  // ==========================================================================

  Future<void> _publishPost(
    BuildContext sheetContext,
  ) async {
    if (_publishingPost) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showError(
        'You must be signed in to publish a post.',
      );
      return;
    }

    final String caption =
        _postController.text.trim();

    final bool hasContent =
        caption.isNotEmpty ||
            _selectedMedia.isNotEmpty ||
            _voiceNotePath != null ||
            _hasAnyEnhancement;

    if (!hasContent) {
      _showError(
        'Add something to your post first.',
      );
      return;
    }

    setState(() {
      _publishingPost = true;
    });

    try {
      // ======================================================================
      // USER PROFILE
      // ======================================================================

      final DocumentSnapshot<
          Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> userData =
          userDoc.data() ??
              <String, dynamic>{};

      String authorName =
          (userData['displayName'] ?? '')
              .toString()
              .trim();

      if (authorName.isEmpty) {
        authorName =
            (userData['name'] ?? '')
                .toString()
                .trim();
      }

      if (authorName.isEmpty) {
        authorName =
            (userData['fullName'] ?? '')
                .toString()
                .trim();
      }

      if (authorName.isEmpty) {
        authorName =
            user.displayName?.trim() ?? '';
      }

      if (authorName.isEmpty) {
        authorName = 'ChattªX User';
      }

      String authorPhoto = '';

      const List<String> photoFields = [
        'photoUrl',
        'profilePhoto',
        'profileImage',
        'profileImageUrl',
        'photoURL',
        'avatarUrl',
        'avatar',
      ];

      for (final String field
          in photoFields) {
        final String? value =
            userData[field]
                ?.toString()
                .trim();

        if (value != null &&
            value.isNotEmpty &&
            value != 'null') {
          authorPhoto = value;
          break;
        }
      }

      if (authorPhoto.isEmpty &&
          user.photoURL != null &&
          user.photoURL!
              .trim()
              .isNotEmpty) {
        authorPhoto =
            user.photoURL!.trim();
      }

      final dynamic verifiedValue =
          userData['verified'] ??
          userData['isVerified'] ??
          userData['verification'] ??
          userData['verifiedUser'];

      final bool verified =
          verifiedValue is bool
              ? verifiedValue
              : verifiedValue
                  .toString()
                  .toLowerCase() ==
                  'true';

      // ======================================================================
      // UPLOAD MEDIA TO CLOUDINARY
      // ======================================================================

      final List<String> imageUrls =
          <String>[];

      final List<String> videoUrls =
          <String>[];

      for (final XFile mediaFile
          in _selectedMedia) {
        final File file =
            File(mediaFile.path);

        if (!await file.exists()) {
          throw Exception(
            'A selected media file could not be found.',
          );
        }

        if (_isVideo(mediaFile.path)) {
          final String? uploadedUrl =
              await CloudinaryService
                  .uploadVideo(
            file,
            folder:
                'chattax_posts/videos',
          );

          if (uploadedUrl == null ||
              uploadedUrl
                  .trim()
                  .isEmpty) {
            throw Exception(
              'The video could not be uploaded to Cloudinary.',
            );
          }

          videoUrls.add(
            uploadedUrl.trim(),
          );
        } else {
          final String? uploadedUrl =
              await CloudinaryService
                  .uploadImage(
            file,
            folder:
                'chattax_posts/images',
          );

          if (uploadedUrl == null ||
              uploadedUrl
                  .trim()
                  .isEmpty) {
            throw Exception(
              'The image could not be uploaded to Cloudinary.',
            );
          }

          imageUrls.add(
            uploadedUrl.trim(),
          );
        }
      }

      // ======================================================================
      // VOICE NOTE
      // ======================================================================

      String? voiceUrl;

      if (_voiceNotePath != null) {
        final File voiceFile =
            File(_voiceNotePath!);

        if (!await voiceFile.exists()) {
          throw Exception(
            'The voice note file could not be found.',
          );
        }

        voiceUrl =
            await CloudinaryService
                .uploadVoice(
          voiceFile,
        );

        if (voiceUrl == null ||
            voiceUrl.trim().isEmpty) {
          throw Exception(
            'Voice note could not be uploaded.',
          );
        }
      }

      // ======================================================================
      // DETERMINE POST TYPE
      // ======================================================================

      String postType = 'text';

      if (imageUrls.isNotEmpty &&
          videoUrls.isEmpty) {
        postType = 'image';
      } else if (videoUrls.isNotEmpty &&
          imageUrls.isEmpty) {
        postType = 'video';
      } else if (imageUrls.isNotEmpty &&
          videoUrls.isNotEmpty) {
        postType = 'mixed';
      } else if (voiceUrl != null) {
        postType = 'voice';
      } else if (_pollQuestion != null) {
        postType = 'poll';
      } else if (_eventTitle != null) {
        postType = 'event';
      } else if (_gifUrl != null) {
        postType = 'gif';
      }

      // ======================================================================
      // POLL DATA
      // ======================================================================

      final List<Map<String, dynamic>>
          pollOptions =
          _pollOptions.map(
        (String option) {
          return <String, dynamic>{
            'text': option,
            'votes': 0,
          };
        },
      ).toList();

      // ======================================================================
      // CREATE POST REFERENCE
      // ======================================================================

      final DocumentReference<
          Map<String, dynamic>> postRef =
          FirebaseFirestore.instance
              .collection('posts')
              .doc();

      // ======================================================================
      // POST DATA
      // ======================================================================

      final bool isScheduled =
          _scheduledDateTime != null;

      final Map<String, dynamic>
          postData =
          <String, dynamic>{
        'postId': postRef.id,

        'authorId': user.uid,
        'userId': user.uid,

        'displayName': authorName,
        'name': authorName,
        'authorName': authorName,

        'photoUrl': authorPhoto,
        'photoURL': authorPhoto,
        'authorPhotoUrl':
            authorPhoto.isEmpty
                ? null
                : authorPhoto,

        'verified': verified,
        'authorVerified': verified,

        'text': caption,
        'caption': caption,

        'type': postType,

        'imageUrls': imageUrls,
        'videoUrls': videoUrls,

        'imageUrl':
            imageUrls.isNotEmpty
                ? imageUrls.first
                : '',

        'videoUrl':
            videoUrls.isNotEmpty
                ? videoUrls.first
                : '',

        'voiceUrl': voiceUrl,

        'mediaCount':
            imageUrls.length +
                videoUrls.length +
                (voiceUrl != null
                    ? 1
                    : 0),

        'feeling': _selectedFeeling,

        'musicName':
            _selectedMusicName,

        'taggedPeople':
            List<String>.from(
          _taggedPeople,
        ),

        'location':
            _selectedLocation,

        'gifUrl': _gifUrl,

        'event': _eventTitle == null
            ? null
            : <String, dynamic>{
                'title': _eventTitle,
                'description':
                    _eventDescription ??
                        '',
              },

        'poll': _pollQuestion == null
            ? null
            : <String, dynamic>{
                'question':
                    _pollQuestion,
                'options':
                    pollOptions,
              },

        'visibility': 'public',

        'status': isScheduled
            ? 'scheduled'
            : 'published',

        'isPublished':
            !isScheduled,

        'scheduledAt':
            _scheduledDateTime == null
                ? null
                : Timestamp.fromDate(
                    _scheduledDateTime!,
                  ),

        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,

        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewsCount': 0,

        'likedBy': <String>[],
        'savedBy': <String>[],
        'resharedBy': <String>[],

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // ======================================================================
      // SAVE POST TO FIRESTORE
      // ======================================================================

      await postRef.set(postData);

      if (!mounted) {
        return;
      }

      setState(() {
        _publishingPost = false;
      });

      if (Navigator.of(sheetContext)
          .canPop()) {
        Navigator.of(sheetContext).pop();
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            isScheduled
                ? 'Post scheduled successfully!'
                : 'Post published successfully!',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(
        const Duration(
          milliseconds: 350,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _publishingPost = false;
      });

      debugPrint(
        'ChattªX publish post error: $e',
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not publish post: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================================
  // SUMMARY LINE
  // ==========================================================================

  Widget _summaryLine(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: kPurple,
            size: 16,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  Widget _buildFooterNote() {
    return const Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline,
          color: kTextDim,
          size: 11,
        ),

        SizedBox(width: 4),

        Flexible(
          child: Text(
            'Your post is protected and private to you until you share.',
            textAlign: TextAlign.center,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: kTextDim,
              fontSize: 9.5,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // FORMAT DATE / TIME
  // ==========================================================================

  String _formatDateTime(
    DateTime date,
  ) {
    final int hour =
        date.hour % 12 == 0
            ? 12
            : date.hour % 12;

    final String minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final String period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// ENHANCE ITEM
// ============================================================================

class _EnhanceItem {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _EnhanceItem(
    this.icon,
    this.color,
    this.label,
    this.onTap,
  );
}

// ============================================================================
// POLL RESULT
// ============================================================================

class _PollResult {
  final String question;
  final List<String> options;

  const _PollResult({
    required this.question,
    required this.options,
  });
}

// ============================================================================
// DOTTED BORDER BOX
// ============================================================================

class DottedBorderBox
    extends StatelessWidget {
  final Widget child;

  const DottedBorderBox({
    super.key,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomPaint(
      painter:
          _DashedBorderPainter(),
      child: Container(
        alignment:
            Alignment.center,
        padding:
            const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}

// ============================================================================
// DASHED BORDER PAINTER
// ============================================================================

class _DashedBorderPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint paint = Paint()
      ..color =
          const Color(0xFF7B2FF7)
      ..strokeWidth = 1.3
      ..style =
          PaintingStyle.stroke;

    final RRect rrect =
        RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
      const Radius.circular(12),
    );

    final Path path =
        Path()..addRRect(rrect);

    const double dashWidth = 6;
    const double dashSpace = 4;

    for (final ui.PathMetric metric
        in path.computeMetrics()) {
      double distance = 0;

      while (distance <
          metric.length) {
        final double end =
            (distance + dashWidth)
                .clamp(
          0.0,
          metric.length,
        );

        canvas.drawPath(
          metric.extractPath(
            distance,
            end,
          ),
          paint,
        );

        distance +=
            dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}