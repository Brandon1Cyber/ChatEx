import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// ============================================================================
/// CHATTªX — ATTACHMENT SHEET
/// ============================================================================
///
/// Features:
///   • ChattªX Camera
///   • ChattªX Gallery
///   • ChattªX Video
///   • ChattªX Document Picker
///   • ChattªX Music Picker
///   • ChattªX Poll Creator
///   • Location
///   • Contact
///   • ChattªX Pay
///   • Event
///
/// All UI uses ChattªX futuristic styling.
/// Native packages are used only for the underlying device access.
/// ============================================================================

class AttachmentSheet extends StatefulWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onDocument;
  final VoidCallback? onLocation;
  final VoidCallback? onContact;
  final VoidCallback? onAudio;
  final VoidCallback? onPoll;
  final VoidCallback? onPay;
  final VoidCallback? onMusic;
  final VoidCallback? onEvent;

  const AttachmentSheet({
    super.key,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onDocument,
    this.onLocation,
    this.onContact,
    this.onAudio,
    this.onPoll,
    this.onPay,
    this.onMusic,
    this.onEvent,
  });

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet>
    with TickerProviderStateMixin {
  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================

  late final AnimationController _floatController;
  late final AnimationController _appearController;

  // ==========================================================================
  // CHATTªX COLORS
  // ==========================================================================

  static const Color background = Color(0xFF050816);
  static const Color panelBackground = Color(0xFF090D19);

  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFFB026FF);
  static const Color violet = Color(0xFF7B2FF7);

  static const Color white = Colors.white;
  static const Color subText = Color(0xFFB7BED0);

  // ==========================================================================
  // SERVICES
  // ==========================================================================

  final ImagePicker _imagePicker = ImagePicker();

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _appearController.forward();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _appearController,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.10),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _appearController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                20,
              ),
              decoration: BoxDecoration(
                color: panelBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(
                  color: const Color(0xFF273047),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 35,
                    spreadRadius: 2,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDragHandle(),
                  const SizedBox(height: 10),
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildAttachmentGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DRAG HANDLE
  // ==========================================================================

  Widget _buildDragHandle() {
    return Container(
      width: 58,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFF667085),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Attach',
              style: TextStyle(
                color: white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    purple,
                    cyan,
                  ],
                ).createShader(bounds);
              },
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Share something instantly',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // GRID
  // ==========================================================================

  Widget _buildAttachmentGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8;

        final double itemWidth =
            (constraints.maxWidth - (spacing * 4)) / 5;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: 18,
          children: [
            // ------------------------------------------------------------------
            // CAMERA
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.camera_alt_rounded,
              title: 'Camera',
              colors: const [
                Color(0xFFB026FF),
                Color(0xFF7B2FF7),
              ],
              onTap: _openChattaxCamera,
            ),

            // ------------------------------------------------------------------
            // GALLERY
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.photo_library_rounded,
              title: 'Gallery',
              colors: const [
                Color(0xFF5865F2),
                Color(0xFFB026FF),
              ],
              onTap: _openChattaxGallery,
            ),

            // ------------------------------------------------------------------
            // LOCATION
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.location_on_rounded,
              title: 'Location',
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFF18D76B),
              ],
              onTap: () {
                widget.onLocation?.call();
              },
            ),

            // ------------------------------------------------------------------
            // DOCUMENT
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.description_rounded,
              title: 'Document',
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFF7B7CFF),
              ],
              onTap: _openChattaxDocumentPicker,
            ),

            // ------------------------------------------------------------------
            // VIDEO
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.videocam_rounded,
              title: 'Video',
              colors: const [
                Color(0xFFFF4FD8),
                Color(0xFFFFB52E),
              ],
              onTap: _openChattaxVideo,
            ),

            // ------------------------------------------------------------------
            // PAY
            // ------------------------------------------------------------------

            SizedBox(
              width: itemWidth,
              child: _payTile(),
            ),

            // ------------------------------------------------------------------
            // POLL
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.poll_rounded,
              title: 'Poll',
              colors: const [
                Color(0xFFB026FF),
                Color(0xFF6C4CFF),
              ],
              onTap: _openChattaxPoll,
            ),

            // ------------------------------------------------------------------
            // CONTACT
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.person_rounded,
              title: 'Contact',
              colors: const [
                Color(0xFFFFA51F),
                Color(0xFFFFD166),
              ],
              onTap: () {
                widget.onContact?.call();
              },
            ),

            // ------------------------------------------------------------------
            // MUSIC
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.music_note_rounded,
              title: 'Music',
              colors: const [
                Color(0xFFB026FF),
                Color(0xFFFF5BD6),
              ],
              onTap: _openChattaxMusicPicker,
            ),

            // ------------------------------------------------------------------
            // EVENT
            // ------------------------------------------------------------------

            _item(
              width: itemWidth,
              icon: Icons.event_rounded,
              title: 'Event',
              colors: const [
                Color(0xFFFF4FD8),
                Color(0xFFFF8BD8),
              ],
              onTap: () {
                widget.onEvent?.call();
              },
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // GRID ITEM
  // ==========================================================================

  Widget _item({
    required double width,
    required IconData icon,
    required String title,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final double phase =
              _floatController.value * 2 * pi;

          final double offset =
              sin(phase + (title.hashCode % 5)) * 0.55;

          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor:
                colors.first.withValues(alpha: 0.18),
            highlightColor:
                colors.first.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconCircle(
                    icon: icon,
                    colors: colors,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ICON
  // ==========================================================================

  Widget _iconCircle({
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: 0.18),
            colors.last.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          width: 1.2,
          color: colors.first.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: colors.last.withValues(alpha: 0.10),
            blurRadius: 22,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.last.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ).createShader(bounds);
            },
            child: Icon(
              icon,
              color: Colors.white,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CAMERA
  // ==========================================================================

  Future<void> _openChattaxCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChattaxCameraScreen(),
      ),
    );

    widget.onCamera?.call();
  }

  // ==========================================================================
  // GALLERY
  // ==========================================================================

  Future<void> _openChattaxGallery() async {
    try {
      final List<XFile> files =
          await _imagePicker.pickMultiImage(
        imageQuality: 95,
      );

      if (!mounted || files.isEmpty) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChattaxMediaPreviewScreen(
            files: files,
            title: 'ChattªX Gallery',
          ),
        ),
      );

      widget.onGallery?.call();
    } catch (e) {
      _showError('Unable to open Gallery');
    }
  }

  // ==========================================================================
  // VIDEO
  // ==========================================================================

  Future<void> _openChattaxVideo() async {
    try {
      final XFile? file =
          await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (!mounted || file == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChattaxMediaPreviewScreen(
            files: [file],
            title: 'ChattªX Video',
            isVideo: true,
          ),
        ),
      );

      widget.onVideo?.call();
    } catch (e) {
      _showError('Unable to open Video');
    }
  }

  // ==========================================================================
  // DOCUMENT PICKER
  // ==========================================================================

  Future<void> _openChattaxDocumentPicker() async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (!mounted || result == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChattaxDocumentPickerScreen(
            files: result.files,
          ),
        ),
      );

      widget.onDocument?.call();
    } catch (e) {
      _showError('Unable to open Documents');
    }
  }

  // ==========================================================================
  // MUSIC PICKER
  // ==========================================================================

  Future<void> _openChattaxMusicPicker() async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );

      if (!mounted || result == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChattaxMusicPickerScreen(
            files: result.files,
          ),
        ),
      );

      if (widget.onMusic != null) {
        widget.onMusic!.call();
      } else {
        widget.onAudio?.call();
      }
    } catch (e) {
      _showError('Unable to open Music');
    }
  }

  // ==========================================================================
  // POLL
  // ==========================================================================

  Future<void> _openChattaxPoll() async {
    final ChattaxPollData? poll =
        await Navigator.of(context).push<ChattaxPollData>(
      MaterialPageRoute(
        builder: (_) => const ChattaxPollCreatorScreen(),
      ),
    );

    if (!mounted || poll == null) return;

    widget.onPoll?.call();
  }

  // ==========================================================================
  // PAY
  // ==========================================================================

  Widget _payTile() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final double offset =
            sin(
              (_floatController.value * 2 * pi) + 1.5,
            ) *
            0.6;

        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onPay != null) {
              widget.onPay!.call();
              return;
            }

            ScaffoldMessenger.of(context)
                .hideCurrentSnackBar();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '💳 ChattªX Pay is coming soon!',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _iconCircle(
                      icon:
                          Icons.account_balance_wallet_rounded,
                      colors: const [
                        cyan,
                        purple,
                      ],
                    ),
                    Positioned(
                      top: -5,
                      right: -7,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(
                            colors: [
                              purple,
                              violet,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(9),
                          border: Border.all(
                            color: background,
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 6.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'ChattªX Pay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF161D2E),
      ),
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _floatController.dispose();
    _appearController.dispose();
    super.dispose();
  }
}

// ============================================================================
// CHATTªX CAMERA
// ============================================================================

class ChattaxCameraScreen extends StatefulWidget {
  const ChattaxCameraScreen({super.key});

  @override
  State<ChattaxCameraScreen> createState() =>
      _ChattaxCameraScreenState();
}

class _ChattaxCameraScreenState
    extends State<ChattaxCameraScreen> {
  CameraController? _controller;

  List<CameraDescription> _cameras = [];

  bool _loading = true;
  bool _isRecording = false;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      await _createController();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createController() async {
    await _controller?.dispose();

    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D9FF),
              ),
            )
          : _buildCamera(),
    );
  }

  Widget _buildCamera() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera unavailable',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),

        // ChattªX gradient overlay
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),

        // Header
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              _cameraButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Text(
                'ChattªX Camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _cameraButton(
                icon: Icons.cameraswitch_rounded,
                onTap: _switchCamera,
              ),
            ],
          ),
        ),

        // Capture controls
        Positioned(
          bottom: 35,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _capturePhoto,
                onLongPress: _startRecording,
                onLongPressUp: _stopRecording,
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 180),
                  width: _isRecording ? 82 : 74,
                  height: _isRecording ? 82 : 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB026FF),
                        Color(0xFF00D9FF),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6600D9FF),
                        blurRadius: 25,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00D9FF)
                .withValues(alpha: 0.45),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      final XFile photo =
          await controller.takePicture();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChattaxMediaPreviewScreen(
            files: [photo],
            title: 'ChattªX Photo',
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (_controller == null) return;

    try {
      await _controller!.startVideoRecording();

      if (mounted) {
        setState(() => _isRecording = true);
      }
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    if (_controller == null ||
        !_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile video =
          await _controller!.stopVideoRecording();

      if (mounted) {
        setState(() => _isRecording = false);

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChattaxMediaPreviewScreen(
              files: [video],
              title: 'ChattªX Video',
              isVideo: true,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _cameraIndex =
          (_cameraIndex + 1) % _cameras.length;
    });

    try {
      await _createController();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ============================================================================
// MEDIA PREVIEW
// ============================================================================

class ChattaxMediaPreviewScreen extends StatelessWidget {
  final List<XFile> files;
  final String title;
  final bool isVideo;

  const ChattaxMediaPreviewScreen({
    super.key,
    required this.files,
    required this.title,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];

                if (isVideo ||
                    _looksLikeVideo(file.path)) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFB026FF),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Color(0xFF00D9FF),
                          size: 75,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(24),
                    child: Image.file(
                      File(file.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              10,
              18,
              30,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB026FF),
                      Color(0xFF00D9FF),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _looksLikeVideo(String path) {
    final lower = path.toLowerCase();

    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm');
  }
}

// ============================================================================
// DOCUMENT PICKER
// ============================================================================

class ChattaxDocumentPickerScreen extends StatelessWidget {
  final List<PlatformFile> files;

  const ChattaxDocumentPickerScreen({
    super.key,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ChattªX Documents',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: files.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final file = files[index];

          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D9FF)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFF00D9FF),
                        Color(0xFFB026FF),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(file.size),
                        style: const TextStyle(
                          color: Color(0xFF9DA7BB),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ============================================================================
// MUSIC PICKER
// ============================================================================

class ChattaxMusicPickerScreen extends StatelessWidget {
  final List<PlatformFile> files;

  const ChattaxMusicPickerScreen({
    super.key,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ChattªX Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFB026FF)
                    .withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFB026FF),
                        Color(0xFFFF5BD6),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF00D9FF),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// POLL DATA
// ============================================================================

class ChattaxPollData {
  final String question;
  final List<String> options;
  final bool allowMultiple;

  const ChattaxPollData({
    required this.question,
    required this.options,
    required this.allowMultiple,
  });
}

// ============================================================================
// POLL CREATOR
// ============================================================================

class ChattaxPollCreatorScreen extends StatefulWidget {
  const ChattaxPollCreatorScreen({
    super.key,
  });

  @override
  State<ChattaxPollCreatorScreen> createState() =>
      _ChattaxPollCreatorScreenState();
}

class _ChattaxPollCreatorScreenState
    extends State<ChattaxPollCreatorScreen> {
  final TextEditingController _questionController =
      TextEditingController();

  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultiple = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'Create Poll',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            30,
          ),
          children: [
            _sectionTitle('Question'),

            const SizedBox(height: 10),

            _input(
              controller: _questionController,
              hint: 'Ask your question...',
              icon: Icons.help_outline_rounded,
              maxLines: 3,
            ),

            const SizedBox(height: 25),

            _sectionTitle('Options'),

            const SizedBox(height: 10),

            ...List.generate(
              _options.length,
              (index) {
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _input(
                          controller: _options[index],
                          hint: 'Option ${index + 1}',
                          icon:
                              Icons.radio_button_unchecked,
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _options[index].dispose();
                              _options.removeAt(index);
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFFF5B7A),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            TextButton.icon(
              onPressed: () {
                if (_options.length >= 6) return;

                setState(() {
                  _options.add(
                    TextEditingController(),
                  );
                });
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Color(0xFF00D9FF),
              ),
              label: const Text(
                'Add option',
                style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFB026FF)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowMultiple,
                activeThumbColor:
                    const Color(0xFFB026FF),
                activeTrackColor:
                    const Color(0xFFB026FF)
                        .withValues(alpha: 0.30),
                onChanged: (value) {
                  setState(() {
                    _allowMultiple = value;
                  });
                },
                title: const Text(
                  'Allow multiple answers',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'People can select more than one option',
                  style: TextStyle(
                    color: Color(0xFF929DB3),
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB026FF),
                      Color(0xFF00D9FF),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: ElevatedButton.icon(
                  onPressed: _createPoll,
                  icon: const Icon(
                    Icons.poll_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Create ChattªX Poll',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
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

  Widget _sectionTitle(String text) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFB026FF),
            Color(0xFF00D9FF),
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF69758C),
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF00D9FF),
        ),
        filled: true,
        fillColor: const Color(0xFF0B1120),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: const Color(0xFF273047),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: Color(0xFF00D9FF),
            width: 1.3,
          ),
        ),
      ),
    );
  }

  void _createPoll() {
    final question =
        _questionController.text.trim();

    final options = _options
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      _showError('Enter a poll question');
      return;
    }

    if (options.length < 2) {
      _showError('Add at least two options');
      return;
    }

    Navigator.pop(
      context,
      ChattaxPollData(
        question: question,
        options: options,
        allowMultiple: _allowMultiple,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF161D2E),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();

    for (final controller in _options) {
      controller.dispose();
    }

    super.dispose();
  }
}