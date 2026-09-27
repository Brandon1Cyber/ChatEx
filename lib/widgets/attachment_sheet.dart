import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

/// ============================================================================
/// CHATTªX — ATTACHMENT SHEET
/// ============================================================================

class AttachmentSheet extends StatefulWidget {
  final Future<void> Function(XFile file)? onCamera;
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
  late final AnimationController _floatController;
  late final AnimationController _appearController;

  static const Color background = Color(0xFF050816);
  static const Color panelBackground = Color(0xFF090D19);

  static const Color cyan = Color(0xFF00D9FF);
  static const Color purple = Color(0xFFB026FF);
  static const Color violet = Color(0xFF7B2FF7);

  static const Color white = Colors.white;
  static const Color subText = Color(0xFFB7BED0);

  final ImagePicker _imagePicker = ImagePicker();

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
                Icons.attach_file_rounded,
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
            _item(
              width: itemWidth,
              icon: Icons.camera_alt_rounded,
              title: 'Camera',
              colors: const [
                Color(0xFFB026FF),
                Color(0xFF7B2FF7),
              ],
              onTap: () {
  _openChattaxCamera();
},
            ),
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
            SizedBox(
              width: itemWidth,
              child: _payTile(),
            ),
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
              _floatController.value * 2 * math.pi;

          final double offset =
              math.sin(
                    phase + (title.hashCode % 5),
                  ) *
                  0.55;

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

  Future<void> _openChattaxCamera() async {
    final XFile? photo =
        await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        builder: (_) => ChattaxCameraScreen(
  onCamera: widget.onCamera,
),
      ),
    );

    if (!mounted || photo == null) return;

    await widget.onCamera?.call(photo);
  }

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
    } catch (_) {
      _showError('Unable to open Gallery');
    }
  }

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
    } catch (_) {
      _showError('Unable to open Video');
    }
  }

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
    } catch (_) {
      _showError('Unable to open Documents');
    }
  }

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
    } catch (_) {
      _showError('Unable to open Music');
    }
  }

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

  Widget _payTile() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final double offset =
            math.sin(
                  (_floatController.value * 2 * math.pi) +
                      1.5,
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

  @override
  void dispose() {
    _floatController.dispose();
    _appearController.dispose();
    super.dispose();
  }
}

/// ============================================================================
/// CHATTªX CAMERA
/// ============================================================================

class ChattaxCameraScreen extends StatefulWidget {
  final Future<void> Function(XFile file)? onCamera;

  const ChattaxCameraScreen({
    super.key,
    this.onCamera,
  });

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
bool _showEffects = false;
bool _switchingCamera = false;

  FaceDetectorProcessor? _faceDetector;
  FaceMeshProcessor? _faceMesh;

  FaceMeshInferenceStreamProcessor? _streamProcessor;
  StreamController<FaceMeshNv21Image>? _frameController;
  StreamSubscription<FaceMeshInferenceResult>? _inferenceSubscription;

  FaceMeshResult? _faceMeshResult;

  bool _faceTrackingReady = false;
  bool _processingFrame = false;

  int _cameraIndex = 0;
  int _selectedEffect = 0;

  final List<_ChattaxCameraEffect> _effects = const [
    _ChattaxCameraEffect(
      name: 'Original',
      icon: Icons.circle_outlined,
      matrix: [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.none,
    ),
    _ChattaxCameraEffect(
      name: 'Vivid',
      icon: Icons.auto_awesome_rounded,
      matrix: [
        1.25, 0, 0, 0, -0.04,
        0, 1.12, 0, 0, -0.02,
        0, 0, 1.25, 0, -0.04,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.sparkles,
    ),
    _ChattaxCameraEffect(
      name: 'Warm',
      icon: Icons.wb_sunny_rounded,
      matrix: [
        1.08, 0, 0, 0, 0.02,
        0, 1.02, 0, 0, 0,
        0, 0, 0.88, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.hearts,
    ),
    _ChattaxCameraEffect(
      name: 'Cool',
      icon: Icons.ac_unit_rounded,
      matrix: [
        0.88, 0, 0, 0, 0,
        0, 0.98, 0, 0, 0,
        0, 0, 1.15, 0, 0.02,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.snow,
    ),
    _ChattaxCameraEffect(
      name: 'Neon',
      icon: Icons.bolt_rounded,
      matrix: [
        1.35, 0, 0, 0, 0,
        0, 0.75, 0, 0, 0,
        0, 0, 1.35, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.neon,
    ),
    _ChattaxCameraEffect(
      name: 'Dream',
      icon: Icons.cloud_rounded,
      matrix: [
        1.08, 0.05, 0, 0, 0.03,
        0.02, 0.98, 0.05, 0, 0.02,
        0, 0.04, 1.08, 0, 0.04,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.dream,
    ),
    _ChattaxCameraEffect(
      name: 'Purple',
      icon: Icons.favorite_rounded,
      matrix: [
        1.05, 0, 0.08, 0, 0,
        0, 0.90, 0.10, 0, 0,
        0.10, 0, 1.25, 0, 0.02,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.hearts,
    ),
    _ChattaxCameraEffect(
      name: 'Sunset',
      icon: Icons.wb_twilight_rounded,
      matrix: [
        1.18, 0.02, 0, 0, 0.01,
        0, 0.92, 0, 0, 0,
        0, 0, 0.82, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.fire,
    ),
    _ChattaxCameraEffect(
      name: 'Noir',
      icon: Icons.contrast_rounded,
      matrix: [
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.none,
    ),
    _ChattaxCameraEffect(
      name: 'Cyber',
      icon: Icons.memory_rounded,
      matrix: [
        1.20, 0, 0.10, 0, 0,
        0, 0.80, 0.12, 0, 0,
        0.08, 0, 1.30, 0, 0,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.cyber,
    ),
    _ChattaxCameraEffect(
      name: 'Crystal',
      icon: Icons.diamond_rounded,
      matrix: [
        1.12, 0.03, 0, 0, 0,
        0.02, 1.08, 0.03, 0, 0,
        0, 0.03, 1.15, 0, 0.02,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.crystal,
    ),
    _ChattaxCameraEffect(
      name: 'Ghost',
      icon: Icons.blur_on_rounded,
      matrix: [
        0.82, 0.08, 0.08, 0, 0.03,
        0.08, 0.82, 0.08, 0, 0.03,
        0.08, 0.08, 0.82, 0, 0.03,
        0, 0, 0, 1, 0,
      ],
      faceStyle: _FaceEffectStyle.ghost,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _initializeFaceTracking();
    _initializeCamera();
  }

  Future<void> _initializeFaceTracking() async {
    try {
      final detector =
          await FaceDetectorProcessor.create(
        model: FaceDetectionModel.shortRange,
        delegate: FaceMeshDelegate.xnnpack,
        maxResults: 1,
      );

      final mesh =
          await FaceMeshProcessor.create(
        model: FaceMeshModel.v2,
        delegate: FaceMeshDelegate.xnnpack,
      );

      if (!mounted) {
        detector.close();
        mesh.close();
        return;
      }

      _faceDetector = detector;
      _faceMesh = mesh;

      _streamProcessor =
          FaceMeshInferenceStreamProcessor(
        FaceMeshInferencePipeline(
          detector: detector,
          mesh: mesh,
          landmarkSmoothing:
              const LandmarkSmoothingOptions(),
        ),
      );

      _faceTrackingReady = true;

      if (mounted) {
        setState(() {});
      }

      _startFaceStreamIfPossible();
    } catch (e) {
      debugPrint(
        'ChattªX face tracking initialization failed: $e',
      );

      if (mounted) {
        setState(() {
          _faceTrackingReady = false;
        });
      }
    }
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

      final frontIndex = _cameras.indexWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.front,
      );

      if (frontIndex >= 0) {
        _cameraIndex = frontIndex;
      }

      await _createController();

      if (mounted) {
        setState(() => _loading = false);
      }

      _startFaceStreamIfPossible();
    } catch (e) {
      debugPrint(
        'ChattªX camera initialization failed: $e',
      );

      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createController() async {
  // Stop face processing first.
  await _stopFaceStream();

  // Remove the old controller from the widget tree BEFORE
  // disposing it. This prevents CameraPreview from trying
  // to build using a disposed controller.
  final oldController = _controller;

  if (mounted) {
    setState(() {
      _controller = null;
      _faceMeshResult = null;
    });
  } else {
    _controller = null;
    _faceMeshResult = null;
  }

  await oldController?.dispose();

  if (!mounted) return;

  // Create the new controller.
  final newController = CameraController(
    _cameras[_cameraIndex],
    ResolutionPreset.high,
    enableAudio: true,
    imageFormatGroup: Platform.isAndroid
        ? ImageFormatGroup.yuv420
        : ImageFormatGroup.bgra8888,
  );

  _controller = newController;

  try {
    await newController.initialize();

    // The screen may have been disposed while initialization
    // was happening.
    if (!mounted) {
      await newController.dispose();
      if (identical(_controller, newController)) {
        _controller = null;
      }
      return;
    }

    // Make sure this is still the active controller.
    if (!identical(_controller, newController)) {
      await newController.dispose();
      return;
    }

    setState(() {});

    await _startFaceStreamIfPossible();
  } catch (e) {
    debugPrint(
      'ChattªX camera controller initialization failed: $e',
    );

    if (identical(_controller, newController)) {
      _controller = null;
    }

    await newController.dispose();

    if (mounted) {
      setState(() {});
    }

    rethrow;
  }
}

  Future<void> _startFaceStreamIfPossible() async {
    if (!_faceTrackingReady ||
        _streamProcessor == null ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _frameController != null) {
      return;
    }

    if (!Platform.isAndroid) {
      return;
    }

    _frameController =
        StreamController<FaceMeshNv21Image>();

    _inferenceSubscription =
        _streamProcessor!
            .processNv21(
      _frameController!.stream,
      runMeshResolver: (_) => true,
      rotationDegrees:
          _cameraRotationDegrees(),
    ).listen(
      (result) {
        _processingFrame = false;

        final mesh = result.meshResult;

        if (!mounted) return;

        if (mesh != null) {
          setState(() {
            _faceMeshResult = mesh;
          });
        } else {
          setState(() {
            _faceMeshResult = null;
          });
        }
      },
      onError: (error) {
        _processingFrame = false;
        debugPrint(
          'ChattªX face stream error: $error',
        );
      },
    );

    try {
      await _controller!.startImageStream(
        _onCameraImage,
      );
    } catch (e) {
      debugPrint(
        'ChattªX image stream failed: $e',
      );
    }
  }

  int _cameraRotationDegrees() {
    if (_controller == null) return 0;

    final sensorOrientation =
        _cameras[_cameraIndex].sensorOrientation;

    if (Platform.isAndroid) {
      if (_cameras[_cameraIndex].lensDirection ==
          CameraLensDirection.front) {
        return (sensorOrientation +
                _deviceOrientationCompensation()) %
            360;
      }

      return (sensorOrientation -
              _deviceOrientationCompensation() +
              360) %
          360;
    }

    return sensorOrientation;
  }

  int _deviceOrientationCompensation() {
    final orientation =
        MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return 90;
    }

    return 0;
  }

  void _onCameraImage(CameraImage image) {
    if (!Platform.isAndroid) return;

    if (_frameController == null ||
        _frameController!.isClosed ||
        _processingFrame ||
        image.planes.length < 3) {
      return;
    }

    _processingFrame = true;

    try {
      final nv21 = _cameraImageToNv21(image);

      _frameController!.add(nv21);
    } catch (e) {
      _processingFrame = false;

      debugPrint(
        'ChattªX camera frame conversion error: $e',
      );
    }
  }

  FaceMeshNv21Image _cameraImageToNv21(
    CameraImage image,
  ) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final int width = image.width;
    final int height = image.height;

    final Uint8List yBytes = _copyPlane(
      yPlane,
      width,
      height,
      isYPlane: true,
    );

    final Uint8List vuBytes = _buildVuPlane(
      image,
      uPlane,
      vPlane,
    );

    return FaceMeshNv21Image(
      yPlane: yBytes,
      vuPlane: vuBytes,
      width: width,
      height: height,
      yBytesPerRow: width,
      vuBytesPerRow: width,
    );
  }

  Uint8List _copyPlane(
    Plane plane,
    int width,
    int height, {
    required bool isYPlane,
  }) {
    final bytes = plane.bytes;

    final int rowStride = plane.bytesPerRow;

    if (rowStride == width) {
      final needed = width * height;

      if (bytes.length >= needed) {
        return Uint8List.fromList(
          bytes.sublist(0, needed),
        );
      }
    }

    final output = Uint8List(width * height);

    int destinationOffset = 0;

    for (int row = 0; row < height; row++) {
      final sourceOffset = row * rowStride;

      if (sourceOffset >= bytes.length) {
        break;
      }

      final available =
          bytes.length - sourceOffset;

      final copyLength =
          math.min(width, available);

      output.setRange(
        destinationOffset,
        destinationOffset + copyLength,
        bytes,
        sourceOffset,
      );

      destinationOffset += width;
    }

    return output;
  }

  Uint8List _buildVuPlane(
    CameraImage image,
    Plane uPlane,
    Plane vPlane,
  ) {
    final int width = image.width;
    final int height = image.height;

    final int chromaWidth = width ~/ 2;
    final int chromaHeight = height ~/ 2;

    final Uint8List output =
        Uint8List(width * height ~/ 2);

    final int uPixelStride =
        uPlane.bytesPerPixel ?? 1;

    final int vPixelStride =
        vPlane.bytesPerPixel ?? 1;

    int destinationOffset = 0;

    for (int row = 0;
        row < chromaHeight;
        row++) {
      final int uRowOffset =
          row * uPlane.bytesPerRow;

      final int vRowOffset =
          row * vPlane.bytesPerRow;

      for (int col = 0;
          col < chromaWidth;
          col++) {
        final int uIndex =
            uRowOffset + col * uPixelStride;

        final int vIndex =
            vRowOffset + col * vPixelStride;

        if (uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length ||
            destinationOffset + 1 >=
                output.length) {
          break;
        }

        // NV21 = V then U.
        output[destinationOffset++] =
            vPlane.bytes[vIndex];

        output[destinationOffset++] =
            uPlane.bytes[uIndex];
      }
    }

    return output;
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

if (_switchingCamera) {
  return const ColoredBox(
    color: Colors.black,
    child: Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF00D9FF),
        ),
      ),
    ),
  );
}

if (controller == null ||
    !controller.value.isInitialized) {
  return const ColoredBox(
    color: Colors.black,
    child: Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF00D9FF),
        ),
      ),
    ),
  );
}

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_switchingCamera)
  const ColoredBox(
    color: Colors.black,
    child: Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF00D9FF),
        ),
      ),
    ),
  )
else
  ColorFiltered(
    colorFilter: ColorFilter.matrix(
      _effects[_selectedEffect].matrix,
    ),
    child: _buildFullScreenCameraPreview(controller),
  ),

        IgnorePointer(
          child: _buildEffectAtmosphere(),
        ),

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
                  Colors.black.withValues(alpha: 0.80),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top:
              MediaQuery.of(context).padding.top + 10,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              _cameraButton(
                icon: Icons.close_rounded,
                onTap: () =>
                    Navigator.pop(context),
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
                icon:
                    Icons.cameraswitch_rounded,
                onTap: _switchCamera,
              ),
            ],
          ),
        ),

        Positioned(
  right: 18,
  bottom: 39,
  child: _effectsButton(),
),
        if (_showEffects)
          Positioned(
            left: 0,
            right: 0,
            bottom: 105,
            child: _buildEffectsCarousel(),
          ),

        if (_selectedEffect != 0)
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                    70,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey(
                    _selectedEffect,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius:
                        BorderRadius.circular(30),
                    border: Border.all(
                      color:
                          const Color(0xFFB026FF)
                              .withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        _effects[
                                _selectedEffect]
                            .icon,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _effects[
                                _selectedEffect]
                            .name,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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

        Positioned(
          bottom: 28,
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
    duration: const Duration(
      milliseconds: 180,
    ),
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

        if (_isRecording)
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                    72,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.red.withValues(
                    alpha: 0.82,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Colors.white,
                      size: 8,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'RECORDING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 1,
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
  Widget _buildFullScreenCameraPreview(
  CameraController controller,
) {
  final previewSize = controller.value.previewSize;

  if (previewSize == null) {
    return CameraPreview(controller);
  }

  final bool isFrontCamera =
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection ==
          CameraLensDirection.front;

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final screenHeight = constraints.maxHeight;

      final double previewAspectRatio =
          previewSize.width / previewSize.height;

      final double screenAspectRatio =
          screenWidth / screenHeight;

      double scale;

      if (isFrontCamera) {
        // Front camera keeps the current full-screen appearance.
        scale = screenAspectRatio / previewAspectRatio;
      } else {
        // Back camera gets its natural sensor scaling.
        scale = screenAspectRatio / previewAspectRatio;
      }

      if (scale < 1.0) {
        scale = 1.0;
      }

      return ClipRect(
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: AspectRatio(
              aspectRatio: previewAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),

                  if (_faceTrackingReady &&
                      _faceMeshResult != null)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: ChattaxFaceEffectPainter(
                          face: _faceMeshResult!,
                          effectStyle:
                              _effects[_selectedEffect].faceStyle,
                          isFrontCamera:
                              isFrontCamera,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildEffectAtmosphere() {
    switch (_selectedEffect) {
      case 1:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Colors.white.withValues(
                  alpha: 0.04,
                ),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 4:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                const Color(0xFFB026FF)
                    .withValues(alpha: 0.12),
                const Color(0xFF00D9FF)
                    .withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 5:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center:
                  const Alignment(0, -0.25),
              radius: 1.15,
              colors: [
                Colors.white.withValues(
                  alpha: 0.06,
                ),
                const Color(0xFFB026FF)
                    .withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 6:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                const Color(0xFFB026FF)
                    .withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 9:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                const Color(0xFF00D9FF)
                    .withValues(alpha: 0.08),
                const Color(0xFFB026FF)
                    .withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 10:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.white.withValues(
                  alpha: 0.05,
                ),
                const Color(0xFF00D9FF)
                    .withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
        );

      case 11:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.white.withValues(
                  alpha: 0.07,
                ),
                Colors.transparent,
              ],
            ),
          ),
        );

      default:
        return const SizedBox.expand();
    }
  }

  Widget _effectsButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showEffects = !_showEffects;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 220),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(
            alpha: 0.52,
          ),
          border: Border.all(
            color: _showEffects
                ? const Color(0xFFB026FF)
                : Colors.white.withValues(
                    alpha: 0.35,
                  ),
            width: 1.3,
          ),
        ),
        child: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFB026FF),
                Color(0xFF00D9FF),
              ],
            ).createShader(bounds);
          },
          child: const Icon(
            Icons.face_retouching_natural_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ),
    );
  }

  Widget _buildEffectsCarousel() {
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection:
            Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: _effects.length,
        itemBuilder:
            (context, index) {
          final effect =
              _effects[index];

          final selected =
              index == _selectedEffect;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedEffect =
                    index;
              });
            },
            child: Container(
              width: 68,
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 5,
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    width:
                        selected ? 55 : 49,
                    height:
                        selected ? 55 : 49,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      gradient: selected
                          ? const LinearGradient(
                              colors: [
                                Color(
                                  0xFFB026FF,
                                ),
                                Color(
                                  0xFF00D9FF,
                                ),
                              ],
                            )
                          : null,
                      color: selected
                          ? null
                          : Colors.black
                              .withValues(
                              alpha: 0.52,
                            ),
                      border:
                          Border.all(
                        color: selected
                            ? Colors.white
                            : Colors.white
                                .withValues(
                                alpha:
                                    0.25,
                              ),
                        width:
                            selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      effect.icon,
                      color:
                          Colors.white,
                      size:
                          selected ? 25 : 21,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    effect.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white
                              .withValues(
                              alpha:
                                  0.72,
                            ),
                      fontSize: 9.5,
                      fontWeight:
                          selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
          color: Colors.black.withValues(
            alpha: 0.45,
          ),
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
      controller.value.isTakingPicture ||
      _isRecording) {
    return;
  }

  try {
    // ----------------------------------------------------------
    // 1. TAKE ORIGINAL PHOTO
    // ----------------------------------------------------------

    XFile photo = await controller.takePicture();

    // ----------------------------------------------------------
    // 2. READ THE PHOTO
    // ----------------------------------------------------------

    final bytes = await photo.readAsBytes();

    img.Image? decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Unable to decode captured image');
    }

    // ----------------------------------------------------------
    // 3. BAKE CAMERA ORIENTATION INTO THE IMAGE
    // ----------------------------------------------------------

    decoded = img.bakeOrientation(decoded);

    // ----------------------------------------------------------
    // 4. APPLY THE SELECTED CHATTªX COLOR FILTER
    // ----------------------------------------------------------

    if (_selectedEffect != 0) {
      decoded = _applyChattaxColorMatrix(
        decoded,
        _effects[_selectedEffect].matrix,
      );
    }

    // ----------------------------------------------------------
    // 5. SAVE FILTERED PHOTO
    // ----------------------------------------------------------

    final correctedBytes = img.encodeJpg(
      decoded,
      quality: 95,
    );

    final correctedPath =
        '${photo.path}_chattax_filtered.jpg';

    final correctedFile = File(correctedPath);

    await correctedFile.writeAsBytes(
      correctedBytes,
      flush: true,
    );

    photo = XFile(
      correctedFile.path,
    );

    // ----------------------------------------------------------
    // 6. OPEN MEDIA PREVIEW
    // ----------------------------------------------------------

    if (!mounted) return;

    final XFile? confirmedPhoto =
        await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        builder: (_) => ChattaxMediaPreviewScreen(
          files: [photo],
          title: 'ChattªX Camera',
        ),
      ),
    );

    if (!mounted || confirmedPhoto == null) {
      return;
    }

    // ----------------------------------------------------------
    // IMPORTANT:
    // Do NOT use widget.onCamera here.
    //
    // ChattaxCameraScreen returns the photo to AttachmentSheet.
    // AttachmentSheet then calls its own onCamera callback.
    // ----------------------------------------------------------

    Navigator.of(context).pop(
      confirmedPhoto,
    );
  } catch (e) {
    debugPrint(
      'ChattªX photo capture failed: $e',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to capture photo',
        ),
      ),
    );
  }
}

img.Image _applyChattaxColorMatrix(
  img.Image image,
  List<double> matrix,
) {
  final result = img.Image.from(image);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);

      final double r = pixel.r.toDouble();
      final double g = pixel.g.toDouble();
      final double b = pixel.b.toDouble();
      final double a = pixel.a.toDouble();

      // Flutter ColorFilter.matrix uses:
      //
      // R' = m0R + m1G + m2B + m3A + m4
      // G' = m5R + m6G + m7B + m8A + m9
      // B' = m10R + m11G + m12B + m13A + m14
      //
      // Your effect matrices use small normalized offsets,
      // so multiply the offset by 255 when applying it
      // directly to image pixels.

      double newR =
          matrix[0] * r +
          matrix[1] * g +
          matrix[2] * b +
          matrix[3] * a +
          matrix[4] * 255.0;

      double newG =
          matrix[5] * r +
          matrix[6] * g +
          matrix[7] * b +
          matrix[8] * a +
          matrix[9] * 255.0;

      double newB =
          matrix[10] * r +
          matrix[11] * g +
          matrix[12] * b +
          matrix[13] * a +
          matrix[14] * 255.0;

      newR = newR.clamp(0.0, 255.0);
      newG = newG.clamp(0.0, 255.0);
      newB = newB.clamp(0.0, 255.0);

      result.setPixelRgba(
        x,
        y,
        newR.round(),
        newG.round(),
        newB.round(),
        a.round(),
      );
    }
  }

  return result;
}

Future<void> _startRecording() async {
  final controller = _controller;

  if (controller == null ||
      !controller.value.isInitialized ||
      controller.value.isRecordingVideo ||
      _isRecording) {
    return;
  }

  try {
    await controller.startVideoRecording();

    if (!mounted) return;

    setState(() {
      _isRecording = true;
    });
  } catch (e) {
    debugPrint(
      'ChattªX recording start error: $e',
    );

    if (!mounted) return;

    setState(() {
      _isRecording = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to start video recording',
        ),
      ),
    );
  }
}

  Future<void> _stopRecording() async {
    if (_controller == null ||
        !_controller!
            .value
            .isRecordingVideo) {
      return;
    }

    try {
      final XFile video =
          await _controller!
              .stopVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChattaxMediaPreviewScreen(
              files: [video],
              title:
                  'ChattªX Video',
              isVideo: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      debugPrint(
        'ChattªX recording stop error: $e',
      );
    }
  }

  Future<void> _switchCamera() async {
  if (_cameras.length < 2 ||
      _isRecording ||
      _switchingCamera ||
      _loading) {
    return;
  }

  setState(() {
    _switchingCamera = true;
    _faceMeshResult = null;

    _cameraIndex =
        (_cameraIndex + 1) % _cameras.length;
  });

  try {
    await _createController();
  } catch (e) {
    debugPrint(
      'ChattªX camera switch error: $e',
    );
  } finally {
    if (mounted) {
      setState(() {
        _switchingCamera = false;
      });
    }
  }
}

  Future<void> _stopFaceStream() async {
    try {
      if (_controller != null &&
          _controller!.value.isStreamingImages) {
        await _controller!
            .stopImageStream();
      }
    } catch (_) {}

    await _inferenceSubscription?.cancel();
    _inferenceSubscription = null;

    await _frameController?.close();
    _frameController = null;

    _processingFrame = false;
  }

  @override
  void dispose() {
    _stopFaceStream();

    _controller?.dispose();

    _faceDetector?.close();
    _faceMesh?.close();

    super.dispose();
  }
}

/// ============================================================================
/// CAMERA EFFECT MODEL
/// ============================================================================

enum _FaceEffectStyle {
  none,

  // Existing
  sparkles,
  hearts,
  snow,
  neon,
  dream,
  fire,
  cyber,
  crystal,
  ghost,

  // Clown collection
  classicClown,
  circusClown,
  evilClown,
  rainbowClown,
  jokerClown,
  cyberClown,
  glitchClown,
}

class _ChattaxCameraEffect {
  final String name;
  final IconData icon;
  final List<double> matrix;
  final _FaceEffectStyle faceStyle;

  const _ChattaxCameraEffect({
    required this.name,
    required this.icon,
    required this.matrix,
    required this.faceStyle,
  });
}

/// ============================================================================
/// FACE EFFECT PAINTER
/// ============================================================================

class ChattaxFaceEffectPainter
    extends CustomPainter {
  final FaceMeshResult face;
  final _FaceEffectStyle effectStyle;
  final bool isFrontCamera;

  ChattaxFaceEffectPainter({
    required this.face,
    required this.effectStyle,
    required this.isFrontCamera,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final List<Offset> points =
    face.landmarksAsOffsets(
  targetSize: size,
  mirrorHorizontal: false,
);

    if (points.length < 468) {
      return;
    }

    switch (effectStyle) {
      case _FaceEffectStyle.none:
        return;

      case _FaceEffectStyle.sparkles:
        _drawSparkles(canvas, points, size);
        break;

      case _FaceEffectStyle.hearts:
        _drawHearts(canvas, points, size);
        break;

      case _FaceEffectStyle.snow:
        _drawSnow(canvas, points, size);
        break;

      case _FaceEffectStyle.neon:
        _drawNeon(canvas, points, size);
        break;

      case _FaceEffectStyle.dream:
        _drawDream(canvas, points, size);
        break;

      case _FaceEffectStyle.fire:
        _drawFire(canvas, points, size);
        break;

      case _FaceEffectStyle.cyber:
        _drawCyber(canvas, points, size);
        break;

      case _FaceEffectStyle.crystal:
        _drawCrystal(canvas, points, size);
        break;

      case _FaceEffectStyle.ghost:
        _drawGhost(canvas, points, size);
        break;

      // ------------------------------------------------------------
      // NEW CLOWN FILTERS
      // ------------------------------------------------------------

      case _FaceEffectStyle.classicClown:
        _drawClassicClown(canvas, points, size);
        break;

      case _FaceEffectStyle.circusClown:
        _drawCircusClown(canvas, points, size);
        break;

      case _FaceEffectStyle.evilClown:
        _drawEvilClown(canvas, points, size);
        break;

      case _FaceEffectStyle.rainbowClown:
        _drawRainbowClown(canvas, points, size);
        break;

      case _FaceEffectStyle.jokerClown:
        _drawJokerClown(canvas, points, size);
        break;

      case _FaceEffectStyle.cyberClown:
        _drawCyberClown(canvas, points, size);
        break;

      case _FaceEffectStyle.glitchClown:
        _drawGlitchClown(canvas, points, size);
        break;
    }
  }

  // ==========================================================================
  // LANDMARK HELPERS
  // ==========================================================================

  Offset _point(
    List<Offset> points,
    int index,
  ) {
    return points[index];
  }

  double _distance(
    Offset a,
    Offset b,
  ) {
    return (a - b).distance;
  }

  Offset _center(
    Offset a,
    Offset b,
  ) {
    return Offset(
      (a.dx + b.dx) / 2,
      (a.dy + b.dy) / 2,
    );
  }

  double _faceScale(
    List<Offset> points,
  ) {
    return _distance(
      _point(points, 234),
      _point(points, 454),
    );
  }

  // ==========================================================================
  // EXISTING EFFECTS
  // ==========================================================================

  void _drawSparkles(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final forehead = _point(p, 10);
    final scale = _faceScale(p);

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final sparklePositions = [
      Offset(
        forehead.dx - scale * 0.32,
        forehead.dy - scale * 0.08,
      ),
      Offset(
        forehead.dx + scale * 0.32,
        forehead.dy - scale * 0.05,
      ),
      Offset(
        leftEye.dx - scale * 0.12,
        leftEye.dy - scale * 0.18,
      ),
      Offset(
        rightEye.dx + scale * 0.12,
        rightEye.dy - scale * 0.18,
      ),
    ];

    for (int i = 0;
        i < sparklePositions.length;
        i++) {
      paint.color = i.isEven
          ? Colors.white
          : const Color(0xFFB026FF);

      _drawStar(
        canvas,
        sparklePositions[i],
        scale * 0.045,
        paint,
      );
    }
  }

  void _drawHearts(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final scale = _faceScale(p);

    final positions = [
      Offset(
        leftEye.dx,
        leftEye.dy - scale * 0.18,
      ),
      Offset(
        rightEye.dx,
        rightEye.dy - scale * 0.18,
      ),
      Offset(
        (leftEye.dx + rightEye.dx) / 2,
        math.min(
              leftEye.dy,
              rightEye.dy,
            ) -
            scale * 0.40,
      ),
    ];

    for (final position in positions) {
      _drawHeart(
        canvas,
        position,
        scale * 0.055,
      );
    }
  }

  void _drawSnow(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);
    final center = _point(p, 10);

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final angle =
          (math.pi * 2 / 5) * i;

      final point = Offset(
        center.dx +
            math.cos(angle) *
                scale *
                0.48,
        center.dy +
            math.sin(angle) *
                scale *
                0.48,
      );

      _drawSnowflake(
        canvas,
        point,
        scale * 0.035,
        paint,
      );
    }
  }

  void _drawNeon(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final left = _point(p, 234);
    final right = _point(p, 454);
    final top = _point(p, 10);
    final bottom = _point(p, 152);

    final paint = Paint()
      ..color = const Color(0xFF00D9FF)
          .withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rect = Rect.fromLTRB(
      left.dx,
      top.dy,
      right.dx,
      bottom.dy,
    );

    canvas.drawOval(
      rect.inflate(
        _faceScale(p) * 0.08,
      ),
      paint,
    );

    paint.color =
        const Color(0xFFB026FF)
            .withValues(alpha: 0.55);

    canvas.drawLine(
      top,
      bottom,
      paint,
    );
  }

  void _drawDream(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);
    final forehead = _point(p, 10);

    final paint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    _drawCloud(
      canvas,
      Offset(
        forehead.dx,
        forehead.dy - scale * 0.30,
      ),
      scale * 0.14,
      paint,
    );
  }

  void _drawFire(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);
    final top = _point(p, 10);

    final paint = Paint()
      ..color = const Color(0xFFFFB52E)
          .withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(
        top.dx - scale * 0.20,
        top.dy - scale * 0.12,
      ),
      Offset(
        top.dx - scale * 0.08,
        top.dy - scale * 0.38,
      ),
      Offset(
        top.dx,
        top.dy - scale * 0.22,
      ),
      Offset(
        top.dx + scale * 0.08,
        top.dy - scale * 0.42,
      ),
      Offset(
        top.dx + scale * 0.21,
        top.dy - scale * 0.10,
      ),
    ];

    final path = Path()
      ..moveTo(
        points.first.dx,
        points.first.dy,
      );

    for (final point in points.skip(1)) {
      path.lineTo(
        point.dx,
        point.dy,
      );
    }

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawCyber(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final scale = _faceScale(p);

    final paint = Paint()
      ..color = const Color(0xFF00D9FF)
          .withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(
        leftEye.dx - scale * 0.18,
        leftEye.dy,
      ),
      Offset(
        leftEye.dx + scale * 0.08,
        leftEye.dy,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        rightEye.dx - scale * 0.08,
        rightEye.dy,
      ),
      Offset(
        rightEye.dx + scale * 0.18,
        rightEye.dy,
      ),
      paint,
    );

    paint.color =
        const Color(0xFFB026FF)
            .withValues(alpha: 0.75);

    final nose = _point(p, 1);

    canvas.drawCircle(
      nose,
      scale * 0.025,
      paint,
    );
  }

  void _drawCrystal(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);
    final forehead = _point(p, 10);

    final paint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(
        forehead.dx,
        forehead.dy - scale * 0.42,
      )
      ..lineTo(
        forehead.dx + scale * 0.09,
        forehead.dy - scale * 0.22,
      )
      ..lineTo(
        forehead.dx,
        forehead.dy - scale * 0.06,
      )
      ..lineTo(
        forehead.dx - scale * 0.09,
        forehead.dy - scale * 0.22,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawGhost(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final left = _point(p, 234);
    final right = _point(p, 454);
    final top = _point(p, 10);
    final bottom = _point(p, 152);
    final width = _faceScale(p);

    final paint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: _center(top, bottom),
      width: width * 1.15,
      height: _distance(top, bottom) * 1.15,
    );

    canvas.drawOval(
      rect,
      paint,
    );

    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      left,
      width * 0.035,
      eyePaint,
    );

    canvas.drawCircle(
      right,
      width * 0.035,
      eyePaint,
    );
  }

  // ==========================================================================
  // 🤡 CLASSIC CLOWN
  // ==========================================================================

  void _drawClassicClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final nose = _point(p, 1);
    final mouthLeft = _point(p, 61);
    final mouthRight = _point(p, 291);

    // White cheek circles
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        leftEye.dx - scale * 0.10,
        leftEye.dy + scale * 0.12,
      ),
      scale * 0.13,
      whitePaint,
    );

    canvas.drawCircle(
      Offset(
        rightEye.dx + scale * 0.10,
        rightEye.dy + scale * 0.12,
      ),
      scale * 0.13,
      whitePaint,
    );

    // Red clown nose
    final redPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      nose,
      scale * 0.075,
      redPaint,
    );

    // Blue eye circles
    final bluePaint = Paint()
      ..color = const Color(0xFF00D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.035;

    canvas.drawOval(
      Rect.fromCenter(
        center: leftEye,
        width: scale * 0.23,
        height: scale * 0.16,
      ),
      bluePaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: rightEye,
        width: scale * 0.23,
        height: scale * 0.16,
      ),
      bluePaint,
    );

    // Exaggerated smile
    final smilePaint = Paint()
      ..color = const Color(0xFFFF2D75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.025;

    final smile = Path()
      ..moveTo(
        mouthLeft.dx - scale * 0.02,
        mouthLeft.dy,
      )
      ..quadraticBezierTo(
        (mouthLeft.dx + mouthRight.dx) / 2,
        mouthLeft.dy + scale * 0.10,
        mouthRight.dx + scale * 0.02,
        mouthRight.dy,
      );

    canvas.drawPath(
      smile,
      smilePaint,
    );

    // Forehead diamond
    _drawClownDiamond(
      canvas,
      Offset(
        (leftEye.dx + rightEye.dx) / 2,
        math.min(
              leftEye.dy,
              rightEye.dy,
            ) -
            scale * 0.30,
      ),
      scale * 0.065,
      const Color(0xFFFFD740),
    );
  }

  // ==========================================================================
  // 🎪 CIRCUS CLOWN
  // ==========================================================================

  void _drawCircusClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final nose = _point(p, 1);

    // Giant red nose
    final nosePaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      nose,
      scale * 0.095,
      nosePaint,
    );

    // Big colored cheeks
    canvas.drawCircle(
      Offset(
        leftEye.dx - scale * 0.12,
        leftEye.dy + scale * 0.16,
      ),
      scale * 0.09,
      Paint()
        ..color = const Color(0xFFFF4081)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(
        rightEye.dx + scale * 0.12,
        rightEye.dy + scale * 0.16,
      ),
      scale * 0.09,
      Paint()
        ..color = const Color(0xFFFF4081)
        ..style = PaintingStyle.fill,
    );

    // Eyebrow triangles
    _drawTriangle(
      canvas,
      Offset(
        leftEye.dx,
        leftEye.dy - scale * 0.16,
      ),
      scale * 0.07,
      const Color(0xFFB026FF),
    );

    _drawTriangle(
      canvas,
      Offset(
        rightEye.dx,
        rightEye.dy - scale * 0.16,
      ),
      scale * 0.07,
      const Color(0xFF00D9FF),
    );

    // Circus forehead stars
    final starPaint = Paint()
      ..color = const Color(0xFFFFD740)
      ..style = PaintingStyle.fill;

    _drawStar(
      canvas,
      Offset(
        leftEye.dx - scale * 0.20,
        leftEye.dy - scale * 0.32,
      ),
      scale * 0.045,
      starPaint,
    );

    _drawStar(
      canvas,
      Offset(
        rightEye.dx + scale * 0.20,
        rightEye.dy - scale * 0.32,
      ),
      scale * 0.045,
      starPaint,
    );
  }

  // ==========================================================================
  // 😈 EVIL CLOWN
  // ==========================================================================

  void _drawEvilClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final nose = _point(p, 1);

    final darkPaint = Paint()
      ..color = const Color(0xFF26002F)
      ..style = PaintingStyle.fill;

    // Dark eye sockets
    canvas.drawOval(
      Rect.fromCenter(
        center: leftEye,
        width: scale * 0.28,
        height: scale * 0.18,
      ),
      darkPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: rightEye,
        width: scale * 0.28,
        height: scale * 0.18,
      ),
      darkPaint,
    );

    // Red pupils
    final redPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      leftEye,
      scale * 0.035,
      redPaint,
    );

    canvas.drawCircle(
      rightEye,
      scale * 0.035,
      redPaint,
    );

    // Glowing red nose
    canvas.drawCircle(
      nose,
      scale * 0.075,
      Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.fill,
    );

    // Evil smile
    final smilePaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.035;

    final smile = Path()
      ..moveTo(
        _point(p, 61).dx,
        _point(p, 61).dy,
      )
      ..quadraticBezierTo(
        (leftEye.dx + rightEye.dx) / 2,
        _point(p, 17).dy + scale * 0.14,
        _point(p, 291).dx,
        _point(p, 291).dy,
      );

    canvas.drawPath(
      smile,
      smilePaint,
    );

    // Sharp forehead mark
    _drawTriangle(
      canvas,
      Offset(
        (leftEye.dx + rightEye.dx) / 2,
        _point(p, 10).dy - scale * 0.30,
      ),
      scale * 0.10,
      const Color(0xFFFF1744),
    );
  }

  // ==========================================================================
  // 🌈 RAINBOW CLOWN
  // ==========================================================================

  void _drawRainbowClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final center = Offset(
      (_point(p, 33).dx +
              _point(p, 263).dx) /
          2,
      _point(p, 10).dy - scale * 0.12,
    );

    final colors = [
      const Color(0xFFFF1744),
      const Color(0xFFFF9800),
      const Color(0xFFFFEB3B),
      const Color(0xFF00E676),
      const Color(0xFF00D9FF),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF2D75),
    ];

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.025;

      final rect = Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy + scale * 0.04,
        ),
        width: scale * (0.18 + i * 0.055),
        height: scale * (0.10 + i * 0.035),
      );

      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        paint,
      );
    }

    // Rainbow cheeks
    final cheekLeft = Offset(
      _point(p, 33).dx - scale * 0.15,
      _point(p, 33).dy + scale * 0.15,
    );

    final cheekRight = Offset(
      _point(p, 263).dx + scale * 0.15,
      _point(p, 263).dy + scale * 0.15,
    );

    for (int i = 0; i < colors.length; i++) {
      canvas.drawCircle(
        cheekLeft,
        scale * (0.025 + i * 0.012),
        Paint()
          ..color = colors[i].withValues(alpha: 0.30),
      );

      canvas.drawCircle(
        cheekRight,
        scale * (0.025 + i * 0.012),
        Paint()
          ..color = colors[i].withValues(alpha: 0.30),
      );
    }

    // Rainbow nose
    canvas.drawCircle(
      _point(p, 1),
      scale * 0.075,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF1744),
            Color(0xFFFFEB3B),
            Color(0xFF00D9FF),
            Color(0xFFB026FF),
          ],
        ).createShader(
          Rect.fromCircle(
            center: _point(p, 1),
            radius: scale * 0.075,
          ),
        ),
    );
  }

  // ==========================================================================
  // 🃏 JOKER CLOWN
  // ==========================================================================

  void _drawJokerClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);

    final purple = Paint()
      ..color = const Color(0xFFB026FF)
      ..style = PaintingStyle.fill;

    final green = Paint()
      ..color = const Color(0xFF39FF14)
      ..style = PaintingStyle.fill;

    // Purple left eye
    final leftPath = Path()
      ..moveTo(
        leftEye.dx - scale * 0.15,
        leftEye.dy - scale * 0.05,
      )
      ..lineTo(
        leftEye.dx,
        leftEye.dy - scale * 0.20,
      )
      ..lineTo(
        leftEye.dx + scale * 0.12,
        leftEye.dy,
      )
      ..lineTo(
        leftEye.dx,
        leftEye.dy + scale * 0.13,
      )
      ..close();

    canvas.drawPath(
      leftPath,
      purple,
    );

    // Green right eye
    final rightPath = Path()
      ..moveTo(
        rightEye.dx - scale * 0.12,
        rightEye.dy,
      )
      ..lineTo(
        rightEye.dx,
        rightEye.dy - scale * 0.20,
      )
      ..lineTo(
        rightEye.dx + scale * 0.15,
        rightEye.dy - scale * 0.05,
      )
      ..lineTo(
        rightEye.dx,
        rightEye.dy + scale * 0.13,
      )
      ..close();

    canvas.drawPath(
      rightPath,
      green,
    );

    // Purple nose
    canvas.drawCircle(
      _point(p, 1),
      scale * 0.07,
      purple,
    );

    // Joker smile
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.035;

    final smile = Path()
      ..moveTo(
        _point(p, 61).dx,
        _point(p, 61).dy,
      )
      ..quadraticBezierTo(
        (_point(p, 61).dx +
                _point(p, 291).dx) /
            2,
        _point(p, 17).dy + scale * 0.12,
        _point(p, 291).dx,
        _point(p, 291).dy,
      );

    canvas.drawPath(
      smile,
      smilePaint,
    );

    // Smile teeth
    for (int i = 0; i < 7; i++) {
      final x =
          _point(p, 61).dx +
              ((_point(p, 291).dx -
                      _point(p, 61).dx) /
                  6) *
              i;

      canvas.drawLine(
        Offset(
          x,
          _point(p, 17).dy +
              scale * 0.04,
        ),
        Offset(
          x,
          _point(p, 17).dy +
              scale * 0.10,
        ),
        smilePaint,
      );
    }
  }

  // ==========================================================================
  // 🤖 CYBER CLOWN
  // ==========================================================================

  void _drawCyberClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final nose = _point(p, 1);

    final cyan = Paint()
      ..color = const Color(0xFF00D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.025;

    final purple = Paint()
      ..color = const Color(0xFFB026FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.025;

    // Cyber eye frames
    canvas.drawRect(
      Rect.fromCenter(
        center: leftEye,
        width: scale * 0.28,
        height: scale * 0.14,
      ),
      cyan,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: rightEye,
        width: scale * 0.28,
        height: scale * 0.14,
      ),
      purple,
    );

    // Digital cheek lines
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(
          leftEye.dx - scale * 0.20,
          leftEye.dy +
              scale * (0.15 + i * 0.055),
        ),
        Offset(
          leftEye.dx - scale * 0.05,
          leftEye.dy +
              scale * (0.15 + i * 0.055),
        ),
        cyan,
      );

      canvas.drawLine(
        Offset(
          rightEye.dx + scale * 0.05,
          rightEye.dy +
              scale * (0.15 + i * 0.055),
        ),
        Offset(
          rightEye.dx + scale * 0.20,
          rightEye.dy +
              scale * (0.15 + i * 0.055),
        ),
        purple,
      );
    }

    // Neon clown nose
    canvas.drawCircle(
      nose,
      scale * 0.065,
      Paint()
        ..color = const Color(0xFFFF2D75)
        ..style = PaintingStyle.fill,
    );

    // Cyber forehead symbol
    _drawCyberDiamond(
      canvas,
      Offset(
        (leftEye.dx + rightEye.dx) / 2,
        _point(p, 10).dy - scale * 0.27,
      ),
      scale * 0.09,
      cyan,
    );
  }

  // ==========================================================================
  // 🧬 GLITCH CLOWN
  // ==========================================================================

  void _drawGlitchClown(
    Canvas canvas,
    List<Offset> p,
    Size size,
  ) {
    final scale = _faceScale(p);

    final leftEye = _point(p, 33);
    final rightEye = _point(p, 263);
    final nose = _point(p, 1);

    final cyan = Paint()
      ..color = const Color(0xFF00D9FF)
      ..style = PaintingStyle.fill;

    final pink = Paint()
      ..color = const Color(0xFFFF2D75)
      ..style = PaintingStyle.fill;

    // Offset glitch blocks around left eye
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          leftEye.dx - scale * 0.09,
          leftEye.dy - scale * 0.03,
        ),
        width: scale * 0.12,
        height: scale * 0.045,
      ),
      cyan,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          leftEye.dx + scale * 0.08,
          leftEye.dy + scale * 0.08,
        ),
        width: scale * 0.10,
        height: scale * 0.035,
      ),
      pink,
    );

    // Offset glitch blocks around right eye
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          rightEye.dx + scale * 0.09,
          rightEye.dy - scale * 0.03,
        ),
        width: scale * 0.12,
        height: scale * 0.045,
      ),
      pink,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          rightEye.dx - scale * 0.08,
          rightEye.dy + scale * 0.08,
        ),
        width: scale * 0.10,
        height: scale * 0.035,
      ),
      cyan,
    );

    // Glitched nose
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          nose.dx - scale * 0.025,
          nose.dy,
        ),
        width: scale * 0.09,
        height: scale * 0.07,
      ),
      pink,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          nose.dx + scale * 0.035,
          nose.dy - scale * 0.02,
        ),
        width: scale * 0.055,
        height: scale * 0.045,
      ),
      cyan,
    );

    // Glitch forehead bars
    final forehead = _point(p, 10);

    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(
            forehead.dx +
                math.sin(i * 2.0) *
                    scale *
                    0.18,
            forehead.dy -
                scale *
                    (0.22 + i * 0.055),
          ),
          width: scale *
              (0.12 + (i % 2) * 0.08),
          height: scale * 0.025,
        ),
        i.isEven ? cyan : pink,
      );
    }
  }

  // ==========================================================================
  // CLOWN SHAPE HELPERS
  // ==========================================================================

  void _drawClownDiamond(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(
        center.dx,
        center.dy - radius,
      )
      ..lineTo(
        center.dx + radius * 0.65,
        center.dy,
      )
      ..lineTo(
        center.dx,
        center.dy + radius,
      )
      ..lineTo(
        center.dx - radius * 0.65,
        center.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawTriangle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(
        center.dx,
        center.dy - radius,
      )
      ..lineTo(
        center.dx + radius,
        center.dy + radius,
      )
      ..lineTo(
        center.dx - radius,
        center.dy + radius,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawCyberDiamond(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(
        center.dx,
        center.dy - radius,
      )
      ..lineTo(
        center.dx + radius,
        center.dy,
      )
      ..lineTo(
        center.dx,
        center.dy + radius,
      )
      ..lineTo(
        center.dx - radius,
        center.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  // ==========================================================================
  // EXISTING SHAPE HELPERS
  // ==========================================================================

  void _drawHeart(
    Canvas canvas,
    Offset center,
    double size,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFF4FD8)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(
      center.dx,
      center.dy + size,
    );

    path.cubicTo(
      center.dx - size * 1.5,
      center.dy - size * 0.1,
      center.dx - size * 0.8,
      center.dy - size * 1.25,
      center.dx,
      center.dy - size * 0.55,
    );

    path.cubicTo(
      center.dx + size * 0.8,
      center.dy - size * 1.25,
      center.dx + size * 1.5,
      center.dy - size * 0.1,
      center.dx,
      center.dy + size,
    );

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();

    for (int i = 0; i < 8; i++) {
      final angle =
          -math.pi / 2 +
              (math.pi / 4) * i;

      final r =
          i.isEven
              ? radius
              : radius * 0.22;

      final point = Offset(
        center.dx +
            math.cos(angle) * r,
        center.dy +
            math.sin(angle) * r,
      );

      if (i == 0) {
        path.moveTo(
          point.dx,
          point.dy,
        );
      } else {
        path.lineTo(
          point.dx,
          point.dy,
        );
      }
    }

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  void _drawSnowflake(
    Canvas canvas,
    Offset center,
    double size,
    Paint paint,
  ) {
    for (int i = 0; i < 3; i++) {
      final angle =
          i * math.pi / 3;

      final dx =
          math.cos(angle) * size;

      final dy =
          math.sin(angle) * size;

      canvas.drawLine(
        Offset(
          center.dx - dx,
          center.dy - dy,
        ),
        Offset(
          center.dx + dx,
          center.dy + dy,
        ),
        paint,
      );
    }
  }

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double size,
    Paint paint,
  ) {
    canvas.drawCircle(
      Offset(
        center.dx - size * 0.35,
        center.dy,
      ),
      size * 0.45,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx,
        center.dy - size * 0.15,
      ),
      size * 0.60,
      paint,
    );

    canvas.drawCircle(
      Offset(
        center.dx + size * 0.35,
        center.dy,
      ),
      size * 0.45,
      paint,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy + size * 0.20,
        ),
        width: size * 1.25,
        height: size * 0.50,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant ChattaxFaceEffectPainter oldDelegate,
  ) {
    return oldDelegate.face != face ||
        oldDelegate.effectStyle != effectStyle ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}

/// ============================================================================
/// MEDIA PREVIEW
/// ============================================================================

class ChattaxMediaPreviewScreen
    extends StatelessWidget {
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
      backgroundColor:
          const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                PageView.builder(
              itemCount:
                  files.length,
              itemBuilder:
                  (context, index) {
                final file =
                    files[index];

                if (isVideo ||
                    _looksLikeVideo(
                      file.path,
                    )) {
                  return Center(
                    child:
                        Container(
                      margin:
                          const EdgeInsets
                              .all(18),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          24,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFB026FF,
                          ),
                        ),
                      ),
                      child:
                          const Center(
                        child:
                            Icon(
                          Icons
                              .play_circle_fill_rounded,
                          color:
                              Color(
                            0xFF00D9FF,
                          ),
                          size: 75,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding:
                      const EdgeInsets
                          .all(12),
                  child:
                      ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      24,
                    ),
                    child:
                        Image.file(
                      File(
                        file.path,
                      ),
                      fit: BoxFit
                          .contain,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              10,
              18,
              30,
            ),
            child:
                SizedBox(
              width:
                  double.infinity,
              height: 55,
              child:
                  DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(
                        0xFFB026FF,
                      ),
                      Color(
                        0xFF00D9FF,
                      ),
                    ],
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                ),
                child:
                    ElevatedButton
                        .icon(
                  onPressed: () {
                    if (files
                        .isEmpty) {
                      return;
                    }

                    Navigator.pop<
                        XFile>(
                      context,
                      files.first,
                    );
                  },
                  icon:
                      const Icon(
                    Icons
                        .send_rounded,
                    color:
                        Colors.white,
                  ),
                  label:
                      const Text(
                    'Send',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors
                            .transparent,
                    shadowColor:
                        Colors
                            .transparent,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
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

  bool _looksLikeVideo(
    String path,
  ) {
    final lower =
        path.toLowerCase();

    return lower.endsWith(
          '.mp4',
        ) ||
        lower.endsWith(
          '.mov',
        ) ||
        lower.endsWith(
          '.mkv',
        ) ||
        lower.endsWith(
          '.avi',
        ) ||
        lower.endsWith(
          '.webm',
        );
  }
}

/// ============================================================================
/// DOCUMENT PICKER
/// ============================================================================

class ChattaxDocumentPickerScreen
    extends StatelessWidget {
  final List<PlatformFile> files;

  const ChattaxDocumentPickerScreen({
    super.key,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        title:
            const Text(
          'ChattªX Documents',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
      ),
      body:
          ListView.separated(
        padding:
            const EdgeInsets
                .all(18),
        itemCount:
            files.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(
          height: 10,
        ),
        itemBuilder:
            (context, index) {
          final file =
              files[index];

          return Container(
            padding:
                const EdgeInsets
                    .all(15),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF0B1120,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                20,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFF00D9FF,
                ).withValues(
                  alpha: 0.25,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        LinearGradient(
                      colors: [
                        Color(
                          0xFF00D9FF,
                        ),
                        Color(
                          0xFFB026FF,
                        ),
                      ],
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .insert_drive_file_rounded,
                    color:
                        Colors.white,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _formatBytes(
                          file.size,
                        ),
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF9DA7BB,
                          ),
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

  String _formatBytes(
    int bytes,
  ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes <
        1024 *
            1024 *
            1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// ============================================================================
/// MUSIC PICKER
/// ============================================================================

class ChattaxMusicPickerScreen
    extends StatelessWidget {
  final List<PlatformFile> files;

  const ChattaxMusicPickerScreen({
    super.key,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        title:
            const Text(
          'ChattªX Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
      ),
      body:
          ListView.builder(
        padding:
            const EdgeInsets
                .all(18),
        itemCount:
            files.length,
        itemBuilder:
            (context, index) {
          final file =
              files[index];

          return Container(
            margin:
                const EdgeInsets
                    .only(
              bottom: 12,
            ),
            padding:
                const EdgeInsets
                    .all(14),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF0B1120,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                22,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFB026FF,
                ).withValues(
                  alpha: 0.30,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        LinearGradient(
                      colors: [
                        Color(
                          0xFFB026FF,
                        ),
                        Color(
                          0xFFFF5BD6,
                        ),
                      ],
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .music_note_rounded,
                    color:
                        Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Color(
                    0xFF00D9FF,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// POLL DATA
/// ============================================================================

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

/// ============================================================================
/// POLL CREATOR
/// ============================================================================

class ChattaxPollCreatorScreen
    extends StatefulWidget {
  const ChattaxPollCreatorScreen({
    super.key,
  });

  @override
  State<ChattaxPollCreatorScreen>
      createState() =>
          _ChattaxPollCreatorScreenState();
}

class _ChattaxPollCreatorScreenState
    extends State<
        ChattaxPollCreatorScreen> {
  final TextEditingController
      _questionController =
      TextEditingController();

  final List<
          TextEditingController>
      _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultiple = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
        title:
            const Text(
          'Create Poll',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child:
            ListView(
          padding:
              const EdgeInsets
                  .fromLTRB(
            18,
            10,
            18,
            30,
          ),
          children: [
            _sectionTitle(
              'Question',
            ),
            const SizedBox(
              height: 10,
            ),
            _input(
              controller:
                  _questionController,
              hint:
                  'Ask your question...',
              icon:
                  Icons.help_outline_rounded,
              maxLines: 3,
            ),
            const SizedBox(
              height: 25,
            ),
            _sectionTitle(
              'Options',
            ),
            const SizedBox(
              height: 10,
            ),
            ...List.generate(
              _options.length,
              (index) {
                return Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            _input(
                          controller:
                              _options[
                                  index],
                          hint:
                              'Option ${index + 1}',
                          icon:
                              Icons.radio_button_unchecked,
                        ),
                      ),
                      if (_options
                              .length >
                          2)
                        IconButton(
                          onPressed:
                              () {
                            setState(
                              () {
                                _options[
                                        index]
                                    .dispose();

                                _options
                                    .removeAt(
                                  index,
                                );
                              },
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                            color:
                                Color(
                              0xFFFF5B7A,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: () {
                if (_options
                        .length >=
                    6) {
                  return;
                }

                setState(() {
                  _options.add(
                    TextEditingController(),
                  );
                });
              },
              icon:
                  const Icon(
                Icons.add_rounded,
                color:
                    Color(
                  0xFF00D9FF,
                ),
              ),
              label:
                  const Text(
                'Add option',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF00D9FF,
                  ),
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF0B1120,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFB026FF,
                  ).withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child:
                  SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                value:
                    _allowMultiple,
                activeThumbColor:
                    const Color(
                  0xFFB026FF,
                ),
                activeTrackColor:
                    const Color(
                  0xFFB026FF,
                ).withValues(
                  alpha: 0.30,
                ),
                onChanged:
                    (value) {
                  setState(() {
                    _allowMultiple =
                        value;
                  });
                },
                title:
                    const Text(
                  'Allow multiple answers',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                subtitle:
                    const Text(
                  'People can select more than one option',
                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF929DB3,
                    ),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            SizedBox(
              height: 56,
              child:
                  DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(
                        0xFFB026FF,
                      ),
                      Color(
                        0xFF00D9FF,
                      ),
                    ],
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                ),
                child:
                    ElevatedButton
                        .icon(
                  onPressed:
                      _createPoll,
                  icon:
                      const Icon(
                    Icons
                        .poll_rounded,
                    color:
                        Colors.white,
                  ),
                  label:
                      const Text(
                    'Create ChattªX Poll',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors
                            .transparent,
                    shadowColor:
                        Colors
                            .transparent,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
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

  Widget _sectionTitle(
    String text,
  ) {
    return ShaderMask(
      shaderCallback:
          (bounds) {
        return const LinearGradient(
          colors: [
            Color(
              0xFFB026FF,
            ),
            Color(
              0xFF00D9FF,
            ),
          ],
        ).createShader(
          bounds,
        );
      },
      child:
          Text(
        text,
        style:
            const TextStyle(
          color:
              Colors.white,
          fontSize: 16,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController
        controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller:
          controller,
      maxLines:
          maxLines,
      style:
          const TextStyle(
        color:
            Colors.white,
      ),
      decoration:
          InputDecoration(
        hintText:
            hint,
        hintStyle:
            const TextStyle(
          color:
              Color(
            0xFF69758C,
          ),
        ),
        prefixIcon:
            Icon(
          icon,
          color:
              const Color(
            0xFF00D9FF,
          ),
        ),
        filled:
            true,
        fillColor:
            const Color(
          0xFF0B1120,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius
                  .circular(
            17,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFF273047,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius
                  .circular(
            17,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFF00D9FF,
            ),
            width:
                1.3,
          ),
        ),
      ),
    );
  }

  void _createPoll() {
    final question =
        _questionController
            .text
            .trim();

    final options =
        _options
            .map(
              (controller) =>
                  controller.text
                      .trim(),
            )
            .where(
              (text) =>
                  text.isNotEmpty,
            )
            .toList();

    if (question.isEmpty) {
      _showError(
        'Enter a poll question',
      );
      return;
    }

    if (options.length < 2) {
      _showError(
        'Add at least two options',
      );
      return;
    }

    Navigator.pop(
      context,
      ChattaxPollData(
        question:
            question,
        options:
            options,
        allowMultiple:
            _allowMultiple,
      ),
    );
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            const Color(
          0xFF161D2E,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController
        .dispose();

    for (final controller
        in _options) {
      controller.dispose();
    }

    super.dispose();
  }
}