import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../services/story_service.dart';

class StoryStudioScreen extends StatefulWidget {
  const StoryStudioScreen({
    super.key,
    required this.selectedMedia,
  });

  final List<AssetEntity> selectedMedia;

  @override
  State<StoryStudioScreen> createState() =>
      _StoryStudioScreenState();
}

class _StoryStudioScreenState
    extends State<StoryStudioScreen> {
  static const Color _background =
      Color(0xFF050816);

  static const Color _backgroundDeep =
      Color(0xFF030309);

  static const Color _surface =
      Color(0xFF111827);

  static const Color _surfaceDark =
      Color(0xFF0D1324);

  static const Color _surfaceRaised =
      Color(0xFF10182A);

  static const Color _border =
      Color(0xFF18243A);

  static const Color _cyan =
      Color(0xFF00D9FF);

  static const Color _purple =
      Color(0xFF8B2CF8);

  static const Color _brightPurple =
      Color(0xFFB026FF);

  static const Color _text =
      Color(0xFFF5F7FF);

  static const Color _muted =
      Color(0xFFAAB4C6);

  final TextEditingController _captionController =
      TextEditingController();

  final PageController _pageController =
      PageController();

  final List<File?> _files = <File?>[];

  final List<String> _mediaTypes = <String>[];

  int _currentIndex = 0;

  double _scale = 1.0;

  double _rotation = 0;

  String _privacy = 'Everyone';

  bool _loadingFiles = true;

  bool _publishing = false;

  double _publishProgress = 0;

  String _publishStatus = '';

  VideoPlayerController? _videoController;

  int? _videoIndex;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final List<File?> loadedFiles = <File?>[];
    final List<String> types = <String>[];

    for (final AssetEntity asset in widget.selectedMedia) {
      final File? file = await asset.file;

      loadedFiles.add(file);

      if (asset.type == AssetType.video) {
        types.add('video');
      } else {
        types.add('image');
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _files
        ..clear()
        ..addAll(loadedFiles);

      _mediaTypes
        ..clear()
        ..addAll(types);

      _loadingFiles = false;
    });

    await _loadVideoForCurrent();
  }

  Future<void> _loadVideoForCurrent() async {
    await _videoController?.dispose();

    _videoController = null;
    _videoIndex = null;

    if (_currentIndex < 0 ||
        _currentIndex >= _files.length) {
      return;
    }

    if (_mediaTypes[_currentIndex] != 'video') {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final File? file = _files[_currentIndex];

    if (file == null) {
      return;
    }

    final VideoPlayerController controller =
        VideoPlayerController.file(file);

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.setLooping(true);
      await controller.play();

      setState(() {
        _videoController = controller;
        _videoIndex = _currentIndex;
      });
    } catch (e) {
      await controller.dispose();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _scale = 1.0;
      _rotation = 0;
    });

    _loadVideoForCurrent();
  }

  void _rotateLeft() {
    setState(() {
      _rotation -= 90;
    });
  }

  void _rotateRight() {
    setState(() {
      _rotation += 90;
    });
  }

  void _resetTransform() {
    setState(() {
      _scale = 1.0;
      _rotation = 0;
    });
  }

  Future<void> _publish() async {
    if (_publishing) {
      return;
    }

    final List<File> validFiles = <File>[];
    final List<String> validTypes = <String>[];

    for (int i = 0; i < _files.length; i++) {
      final File? file = _files[i];

      if (file == null) {
        continue;
      }

      validFiles.add(file);
      validTypes.add(_mediaTypes[i]);
    }

    if (validFiles.isEmpty) {
      _showMessage('No usable media was found.');
      return;
    }

    setState(() {
      _publishing = true;
      _publishProgress = 0;
      _publishStatus = 'Preparing your story...';
    });

    try {
      final int total = validFiles.length;

      for (int i = 0; i < total; i++) {
        if (!mounted) {
          return;
        }

        setState(() {
          _publishProgress = i / total;
          _publishStatus =
              'Uploading story ${i + 1} of $total...';
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _publishProgress = .8;
        _publishStatus = 'Publishing to ChattªX...';
      });

      final bool success =
          await StoryService.publishStories(
        files: validFiles,
        mediaTypes: validTypes,
        caption: _captionController.text,
        privacy: _privacy,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _publishing = false;
          _publishStatus = '';
        });

        _showMessage(
          'Something went wrong while publishing your story.',
        );

        return;
      }

      setState(() {
        _publishProgress = 1;
        _publishStatus = 'Story published.';
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
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
        _publishing = false;
        _publishStatus = '';
      });

      _showMessage(
        'Could not publish your story.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _openPrivacy() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Story privacy',
                      style: TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose who can see this story.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _privacyOption(
                    title: 'Everyone',
                    subtitle:
                        'Anyone who can view your stories',
                    icon: Icons.public_rounded,
                  ),
                  _privacyOption(
                    title: 'Friends',
                    subtitle:
                        'People connected with you',
                    icon: Icons.people_alt_rounded,
                  ),
                  _privacyOption(
                    title: 'Only me',
                    subtitle:
                        'Visible only to your account',
                    icon: Icons.lock_rounded,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _privacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool selected = _privacy == title;

    return InkWell(
      onTap: () {
        setState(() {
          _privacy = title;
        });

        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _purple.withValues(alpha: .12)
              : _surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? _purple.withValues(alpha: .55)
                : _border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _background,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color:
                    selected ? _cyan : _muted,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: _cyan,
                size: 21,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_files.isEmpty ||
        _currentIndex >= _files.length) {
      return const Center(
        child: Text(
          'No media selected',
          style: TextStyle(color: _muted),
        ),
      );
    }

    final File? file = _files[_currentIndex];

    if (file == null) {
      return const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: _muted,
          size: 42,
        ),
      );
    }

    final bool isVideo =
        _mediaTypes[_currentIndex] == 'video';

    Widget media;

    if (isVideo &&
        _videoController != null &&
        _videoIndex == _currentIndex &&
        _videoController!.value.isInitialized) {
      final VideoPlayerController controller =
          _videoController!;

      final double aspectRatio =
          controller.value.aspectRatio <= 0
              ? 9 / 16
              : controller.value.aspectRatio;

      media = AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(controller),
      );
    } else if (!isVideo) {
      media = Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder:
            (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: _muted,
              size: 42,
            ),
          );
        },
      );
    } else {
      media = const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation<Color>(_cyan),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 3,
      scaleEnabled: true,
      panEnabled: true,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(_rotation * 3.141592653589793 / 180)
          ..scale(_scale),
        child: media,
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          10,
          14,
          8,
        ),
        child: Row(
          children: [
            _iconButton(
              icon: Icons.close_rounded,
              onTap: _publishing
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Story Studio',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Shape your moment',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _iconButton(
              icon: Icons.refresh_rounded,
              onTap: _publishing
                  ? null
                  : _resetTransform,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTools() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _surfaceDark.withValues(alpha: .94),
        border: Border(
          top: BorderSide(
            color: _border.withValues(alpha: .8),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toolButton(
              icon: Icons.rotate_left_rounded,
              label: 'Rotate',
              onTap: _publishing
                  ? null
                  : _rotateLeft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toolButton(
              icon: Icons.rotate_right_rounded,
              label: 'Turn',
              onTap: _publishing
                  ? null
                  : _rotateRight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toolButton(
              icon: Icons.zoom_in_rounded,
              label: 'Zoom',
              onTap: _publishing
                  ? null
                  : () {
                      setState(() {
                        _scale = _scale >= 2.5
                            ? 1
                            : _scale + .25;
                      });
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toolButton(
              icon: Icons.tune_rounded,
              label: 'Privacy',
              onTap: _publishing
                  ? null
                  : _openPrivacy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _surfaceRaised,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? _muted.withValues(alpha: .4)
                    : _cyan,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null
                      ? _muted.withValues(alpha: .4)
                      : _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(
            icon,
            color: onTap == null
                ? _muted.withValues(alpha: .4)
                : _text,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _purple.withValues(alpha: .28),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _captionController,
              enabled: !_publishing,
              maxLines: 2,
              maxLength: 180,
              style: const TextStyle(
                color: _text,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Add a caption...',
                hintStyle: TextStyle(
                  color: _muted.withValues(alpha: .65),
                ),
                filled: true,
                fillColor: _surfaceRaised,
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _border,
                  ),
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _border,
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _cyan,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          4,
          14,
          12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _surfaceRaised,
                  borderRadius:
                      BorderRadius.circular(17),
                  border: Border.all(
                    color: _border,
                  ),
                ),
                child: Center(
                  child: Text(
                    _privacy,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap:
                    _publishing ? null : _publish,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(17),
                    gradient: LinearGradient(
                      colors: [
                        _cyan.withValues(alpha: .9),
                        _purple.withValues(alpha: .95),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            _cyan.withValues(alpha: .10),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _publishing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                _text,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                color: _text,
                                size: 19,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Publish story',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishOverlay() {
    if (!_publishing) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: _backgroundDeep.withValues(alpha: .78),
        child: Center(
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _border,
              ),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: .10),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: _cyan,
                  size: 28,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Publishing',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _publishStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _publishProgress,
                    minHeight: 6,
                    backgroundColor: _border,
                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      _cyan,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${(_publishProgress * 100).round()}%',
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: _loadingFiles
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  _cyan,
                ),
              ),
            )
          : Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildTopBar(),

                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius:
                                BorderRadius.circular(24),
                            border: Border.all(
                              color: _border,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller:
                                    _pageController,
                                itemCount: _files.length,
                                onPageChanged:
                                    _onPageChanged,
                                itemBuilder:
                                    (context, index) {
                                  return _buildMediaPreview();
                                },
                              ),

                              Positioned(
                                top: 12,
                                left: 12,
                                right: 12,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 3,
                                        decoration:
                                            BoxDecoration(
                                          color: _cyan
                                              .withValues(
                                            alpha: .85,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: _backgroundDeep
                                            .withValues(
                                          alpha: .75,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child: Text(
                                        '${_currentIndex + 1}/${_files.length}',
                                        style:
                                            const TextStyle(
                                          color: _text,
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_mediaTypes.isNotEmpty &&
                                  _currentIndex <
                                      _mediaTypes.length &&
                                  _mediaTypes[
                                          _currentIndex] ==
                                      'video')
                                Positioned(
                                  right: 14,
                                  bottom: 14,
                                  child: Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _backgroundDeep
                                              .withValues(
                                        alpha: .72,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons
                                              .play_circle_fill_rounded,
                                          color: _cyan,
                                          size: 15,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'VIDEO',
                                          style:
                                              TextStyle(
                                            color: _text,
                                            fontSize: 9,
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      _buildTools(),
                      _buildCaptionArea(),
                      _buildBottomBar(),
                    ],
                  ),
                ),

                _buildPublishOverlay(),
              ],
            ),
    );
  }
}