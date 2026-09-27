import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() =>
      _StoryViewerScreenState();
}

class _StoryViewerScreenState
    extends State<StoryViewerScreen> {
  static const Color _background = Color(0xFF030309);
  static const Color _surface = Color(0xFF111827);
  static const Color _border = Color(0xFF18243A);
  static const Color _cyan = Color(0xFF00D9FF);
  static const Color _purple = Color(0xFF8B2CF8);
  static const Color _brightPurple = Color(0xFFB026FF);
  static const Color _primaryText = Color(0xFFF5F7FF);
  static const Color _secondaryText = Color(0xFFAAB4C6);

  late int _currentIndex;

  Timer? _timer;
  VideoPlayerController? _videoController;

  double _progress = 0.0;

  bool _paused = false;
  bool _loadingVideo = false;

  DateTime? _startedAt;
  Duration _currentDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.stories.isEmpty
          ? 0
          : widget.stories.length - 1,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentStory();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // ==========================================================================
  // STORY LOADING
  // ==========================================================================

  Future<void> _loadCurrentStory() async {
    _timer?.cancel();

    await _videoController?.dispose();
    _videoController = null;

    if (!mounted || widget.stories.isEmpty) {
      return;
    }

    setState(() {
      _progress = 0;
      _paused = false;
      _loadingVideo = false;
      _currentDuration = Duration.zero;
    });

    final story = widget.stories[_currentIndex];

    await _recordView(story);

    if (!mounted) return;

    final String mediaType =
        (story['mediaType'] ?? '').toString().toLowerCase();

    final String mediaUrl =
        (story['mediaUrl'] ?? '').toString();

    if (mediaUrl.isEmpty) {
      _startPhotoTimer();
      return;
    }

    final bool isVideo =
        mediaType == 'video' ||
        mediaType == 'mp4';

    if (isVideo) {
      await _loadVideo(mediaUrl);
    } else {
      _startPhotoTimer();
    }
  }

  // ==========================================================================
  // VIDEO
  // ==========================================================================

  Future<void> _loadVideo(String url) async {
    if (!mounted) return;

    setState(() {
      _loadingVideo = true;
    });

    final controller =
        VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _videoController = controller;

    try {
      await controller.initialize();

      if (!mounted ||
          _videoController != controller) {
        await controller.dispose();
        return;
      }

      _currentDuration =
          controller.value.duration;

      controller.addListener(_videoListener);

      await controller.play();

      setState(() {
        _loadingVideo = false;
      });

      _startedAt = DateTime.now();
    } catch (e) {
      debugPrint(
        'ChattªX story video error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loadingVideo = false;
      });

      _startPhotoTimer();
    }
  }

  void _videoListener() {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized ||
        !mounted) {
      return;
    }

    final Duration position =
        controller.value.position;

    final Duration duration =
        controller.value.duration;

    if (duration.inMilliseconds <= 0) {
      return;
    }

    final double value =
        position.inMilliseconds /
            duration.inMilliseconds;

    setState(() {
      _progress = value.clamp(0.0, 1.0);
    });

    if (position >= duration &&
        !controller.value.isPlaying) {
      _goNext();
    }
  }

  // ==========================================================================
  // PHOTO TIMER
  // ==========================================================================

  void _startPhotoTimer() {
    _timer?.cancel();

    _startedAt = DateTime.now();

    const Duration duration =
        Duration(seconds: 5);

    _timer = Timer.periodic(
      const Duration(milliseconds: 40),
      (timer) {
        if (!mounted || _paused) {
          return;
        }

        final elapsed =
            DateTime.now()
                .difference(_startedAt!);

        final double value =
            elapsed.inMilliseconds /
                duration.inMilliseconds;

        if (value >= 1) {
          timer.cancel();

          setState(() {
            _progress = 1;
          });

          _goNext();
          return;
        }

        setState(() {
          _progress = value;
        });
      },
    );
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  void _goNext() {
    if (!mounted) return;

    if (_currentIndex <
        widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });

      _loadCurrentStory();
      return;
    }

    Navigator.of(context).pop();
  }

  void _goPrevious() {
    if (!mounted) return;

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });

      _loadCurrentStory();
      return;
    }

    Navigator.of(context).pop();
  }

  // ==========================================================================
  // PAUSE / RESUME
  // ==========================================================================

  void _pauseStory() {
    if (_paused) return;

    setState(() {
      _paused = true;
    });

    _videoController?.pause();
  }

  void _resumeStory() {
    if (!_paused) return;

    setState(() {
      _paused = false;
    });

    final controller = _videoController;

    if (controller != null &&
        controller.value.isInitialized) {
      controller.play();
    }
  }

  // ==========================================================================
  // VIEW TRACKING
  // ==========================================================================

  Future<void> _recordView(
    Map<String, dynamic> story,
  ) async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final String storyId =
        (story['id'] ?? '').toString();

    if (storyId.isEmpty) return;

    try {
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;

      final viewerRef = firestore
          .collection('stories')
          .doc(storyId)
          .collection('viewers')
          .doc(user.uid);

      final viewerSnapshot =
          await viewerRef.get();

      if (viewerSnapshot.exists) {
        return;
      }

      await viewerRef.set({
        'userId': user.uid,
        'viewedAt':
            FieldValue.serverTimestamp(),
      });

      await firestore
          .collection('stories')
          .doc(storyId)
          .update({
        'viewCount':
            FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint(
        'ChattªX story view error: $e',
      );
    }
  }

  // ==========================================================================
  // STORY DATA
  // ==========================================================================

  String _storyUrl() {
    if (widget.stories.isEmpty) {
      return '';
    }

    return (widget.stories[_currentIndex]
                ['mediaUrl'] ??
            '')
        .toString();
  }

  String _storyCaption() {
    if (widget.stories.isEmpty) {
      return '';
    }

    return (widget.stories[_currentIndex]
                ['caption'] ??
            '')
        .toString();
  }

  String _storyMediaType() {
    if (widget.stories.isEmpty) {
      return '';
    }

    return (widget.stories[_currentIndex]
                ['mediaType'] ??
            '')
        .toString()
        .toLowerCase();
  }

  String _displayName() {
    if (widget.stories.isEmpty) {
      return 'User';
    }

    return (widget.stories[_currentIndex]
                ['displayName'] ??
            widget.stories[_currentIndex]
                ['name'] ??
            'User')
        .toString();
  }

  String _profilePhoto() {
    if (widget.stories.isEmpty) {
      return '';
    }

    return (widget.stories[_currentIndex]
                ['userPhoto'] ??
            widget.stories[_currentIndex]
                ['photoUrl'] ??
            widget.stories[_currentIndex]
                ['photoURL'] ??
            '')
        .toString();
  }

  bool get _isVideo {
    final type = _storyMediaType();

    return type == 'video' ||
        type == 'mp4';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Text(
            'No story available.',
            style: TextStyle(
              color: _primaryText,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          _pauseStory();
        },
        onLongPressEnd: (_) {
          _resumeStory();
        },
        onHorizontalDragEnd: (details) {
          final velocity =
              details.primaryVelocity ?? 0;

          if (velocity < -300) {
            _goNext();
          } else if (velocity > 300) {
            _goPrevious();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ==========================================================
            // STORY MEDIA
            // ==========================================================

            Center(
              child: _buildStoryMedia(),
            ),

            // ==========================================================
            // TOP DARK GRADIENT
            // ==========================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 190,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: .78,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==========================================================
            // TOP CONTENT
            // ==========================================================

            Positioned(
              top: MediaQuery.of(context)
                      .padding
                      .top +
                  8,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  _buildProgressBars(),
                  const SizedBox(height: 12),
                  _buildHeader(),
                ],
              ),
            ),

            // ==========================================================
            // TAP AREAS
            // ==========================================================

            Positioned(
              left: 0,
              top: 100,
              bottom: 100,
              width:
                  MediaQuery.of(context).size.width *
                      .32,
              child: GestureDetector(
                behavior:
                    HitTestBehavior.translucent,
                onTap: _goPrevious,
              ),
            ),

            Positioned(
              right: 0,
              top: 100,
              bottom: 100,
              width:
                  MediaQuery.of(context).size.width *
                      .32,
              child: GestureDetector(
                behavior:
                    HitTestBehavior.translucent,
                onTap: _goNext,
              ),
            ),

            // ==========================================================
            // CAPTION
            // ==========================================================

            if (_storyCaption().trim().isNotEmpty)
              Positioned(
                left: 18,
                right: 18,
                bottom:
                    MediaQuery.of(context)
                            .padding
                            .bottom +
                        80,
                child: _buildCaption(),
              ),

            // ==========================================================
            // BOTTOM REPLY
            // ==========================================================

            Positioned(
              left: 14,
              right: 14,
              bottom:
                  MediaQuery.of(context)
                          .padding
                          .bottom +
                      15,
              child: _buildBottomBar(),
            ),

            // ==========================================================
            // LOADING
            // ==========================================================

            if (_loadingVideo)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _cyan,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STORY MEDIA
  // ==========================================================================

  Widget _buildStoryMedia() {
    final String url = _storyUrl();

    if (url.isEmpty) {
      return const Icon(
        Icons.image_not_supported_outlined,
        color: _secondaryText,
        size: 45,
      );
    }

    if (_isVideo) {
      final controller = _videoController;

      if (controller == null ||
          !controller.value.isInitialized) {
        return const SizedBox();
      }

      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width:
                controller.value.size.width,
            height:
                controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child: SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _cyan,
              ),
            ),
          );
        },
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: _secondaryText,
              size: 42,
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // PROGRESS
  // ==========================================================================

  Widget _buildProgressBars() {
    return Row(
      children: List.generate(
        widget.stories.length,
        (index) {
          double value;

          if (index < _currentIndex) {
            value = 1;
          } else if (index > _currentIndex) {
            value = 0;
          } else {
            value = _progress;
          }

          return Expanded(
            child: Container(
              height: 2.5,
              margin: EdgeInsets.only(
                right: index ==
                        widget.stories.length - 1
                    ? 0
                    : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: .25,
                ),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        _cyan,
                        _brightPurple,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    final String photo = _profilePhoto();

    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          padding: const EdgeInsets.all(1.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _cyan,
                _brightPurple,
              ],
            ),
          ),
          child: ClipOval(
            child: photo.isNotEmpty
                ? Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _avatarFallback();
                    },
                  )
                : _avatarFallback(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _displayName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: _surface,
      child: const Icon(
        Icons.person_rounded,
        color: _cyan,
        size: 21,
      ),
    );
  }

  // ==========================================================================
  // CAPTION
  // ==========================================================================

  Widget _buildCaption() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: .48,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: .10,
          ),
        ),
      ),
      child: Text(
        _storyCaption(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }

  // ==========================================================================
  // BOTTOM BAR
  // ==========================================================================

  Widget _buildBottomBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: .48,
              ),
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                color: _border,
              ),
            ),
            child: const Center(
              child: Text(
                'Reply to story...',
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _bottomIcon(
          Icons.favorite_border_rounded,
          () {},
        ),
        const SizedBox(width: 5),
        _bottomIcon(
          Icons.send_outlined,
          () {},
        ),
      ],
    );
  }

  Widget _bottomIcon(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: .48,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: _border,
          ),
        ),
        child: Icon(
          icon,
          color: _cyan,
          size: 19,
        ),
      ),
    );
  }
}