import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'story_studio_screen.dart';

class FeedCreateStoryScreen extends StatefulWidget {
  const FeedCreateStoryScreen({
    super.key,
    this.onNext,
    this.onText,
    this.onMusic,
    this.onCamera,
    this.onAiVibe,
  });

  final void Function(List<AssetEntity> selectedMedia)? onNext;
  final VoidCallback? onText;
  final VoidCallback? onMusic;
  final VoidCallback? onCamera;
  final VoidCallback? onAiVibe;

  @override
  State<FeedCreateStoryScreen> createState() => _FeedCreateStoryScreenState();
}

class _FeedCreateStoryScreenState extends State<FeedCreateStoryScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // CHATTªX COLOR SYSTEM
  // Cyan = primary accent
  // Purple = secondary accent only
  // ============================================================

  static const Color background = Color(0xFF050816);
  static const Color backgroundDeep = Color(0xFF030309);

  static const Color surface = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF0D1324);
  static const Color surfaceRaised = Color(0xFF10182A);

  static const Color border = Color(0xFF18243A);

  static const Color cyan = Color(0xFF00D9FF);

  // Restrained purple usage.
  static const Color purple = Color(0xFF8B2CF8);
  static const Color neonPurple = Color(0xFFB026FF);

  static const Color primaryText = Color(0xFFF5F7FF);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late final AnimationController _glowController;
  late final AnimationController _selectionController;

  // ============================================================
  // STATE
  // ============================================================

  List<AssetEntity> _assets = <AssetEntity>[];

  final List<AssetEntity> _selectedAssets = <AssetEntity>[];

  int _currentFilter = 0;

  bool _loading = true;
  bool _multipleSelection = false;
  bool _permissionDenied = false;

  final List<String> _filters = <String>[
    'All',
    'Photos',
    'Videos',
    'Live Photos',
  ];

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _loadGallery();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _glowController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  // ============================================================
  // GALLERY / PERMISSIONS
  // ============================================================

  Future<void> _loadGallery() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _permissionDenied = false;
      });
    }

    try {
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      if (!mounted) return;

      // Android can provide limited/selected photo access.
      // hasAccess is the correct check for usable gallery access.
      if (!permission.hasAccess) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }

      final List<AssetPathEntity> albums =
    await PhotoManager.getAssetPathList(
  type: RequestType.common,
  hasAll: true,
  onlyAll: true,
  filterOption: FilterOptionGroup(
    orders: <OrderOption>[
      const OrderOption(
        type: OrderOptionType.createDate,
        asc: false,
      ),
    ],
  ),
);

      if (!mounted) return;

      if (albums.isEmpty) {
        setState(() {
          _assets = <AssetEntity>[];
          _loading = false;
          _permissionDenied = false;
        });
        return;
      }

      final AssetPathEntity allMedia = albums.first;

      final List<AssetEntity> media = await allMedia.getAssetListPaged(
        page: 0,
        size: 300,
      );

      if (!mounted) return;

      setState(() {
        _assets = media;
        _loading = false;
        _permissionDenied = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _permissionDenied = true;
      });

      _showMessage('Could not load your gallery.');
    }
  }

  Future<void> _handlePhotoPermission() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _permissionDenied = false;
        });
      }

      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      if (!mounted) return;

      if (permission.hasAccess) {
        await _loadGallery();
        return;
      }

      setState(() {
        _loading = false;
        _permissionDenied = true;
      });

      await PhotoManager.openSetting();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _permissionDenied = true;
      });

      _showMessage(
        'Please allow ChattªX to access your photos and videos.',
      );
    }
  }

  // ============================================================
  // FILTERED MEDIA
  // ============================================================

  List<AssetEntity> get _filteredAssets {
    switch (_currentFilter) {
      case 1:
        return _assets
            .where(
              (AssetEntity asset) => asset.type == AssetType.image,
            )
            .toList();

      case 2:
        return _assets
            .where(
              (AssetEntity asset) => asset.type == AssetType.video,
            )
            .toList();

      case 3:
        return _assets
            .where(
              (AssetEntity asset) => asset.type == AssetType.other,
            )
            .toList();

      default:
        return _assets;
    }
  }

  // ============================================================
  // SELECTION
  // ============================================================

  bool _isSelected(AssetEntity asset) {
    return _selectedAssets.contains(asset);
  }

  int _selectionNumber(AssetEntity asset) {
    final int index = _selectedAssets.indexOf(asset);

    if (index < 0) {
      return 0;
    }

    return index + 1;
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });

    _selectionController.forward(from: 0);
  }

  void _removeSelection(AssetEntity asset) {
    setState(() {
      _selectedAssets.remove(asset);
    });
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _openCamera() async {
    if (widget.onCamera != null) {
      widget.onCamera!();
      return;
    }

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (file == null || !mounted) {
        return;
      }

      _showMessage(
        'Photo captured. Connect your Story Editor here.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Camera could not be opened.');
    }
  }

  // ============================================================
  // NEXT
  // ============================================================

  // ============================================================
// NEXT
// ============================================================

Future<void> _goNext() async {
  if (_selectedAssets.isEmpty) {
    _showMessage(
      'Select at least one photo or video.',
    );
    return;
  }

  final List<AssetEntity> selected =
      List<AssetEntity>.unmodifiable(
    _selectedAssets,
  );

  if (widget.onNext != null) {
    widget.onNext!(selected);
    return;
  }

  final bool? published =
      await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => StoryStudioScreen(
        selectedMedia: selected,
      ),
    ),
  );

  if (!mounted) {
    return;
  }

  if (published == true) {
    Navigator.of(context).pop(true);
  }
}

  // ============================================================
  // ACTIONS
  // ============================================================

  void _openText() {
    if (widget.onText != null) {
      widget.onText!();
      return;
    }

    _showMessage(
      'Open ChattªX Text Story Editor here.',
    );
  }

  void _openMusic() {
    if (widget.onMusic != null) {
      widget.onMusic!();
      return;
    }

    _showMessage(
      'Open ChattªX Music selector here.',
    );
  }

  void _openAiVibe() {
    if (widget.onAiVibe != null) {
      widget.onAiVibe!();
      return;
    }

    _showMessage(
      'Open ChattªX AI Vibe creator here.',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: surface,
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            95,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: border,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDeep,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          _buildBackground(),

          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _buildHeader(),

                Expanded(
                  child: RefreshIndicator(
                    color: cyan,
                    backgroundColor: surface,
                    onRefresh: _loadGallery,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: _buildCreationCards(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildCameraRollHeader(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildFilterBar(),
                        ),

                        _buildGallerySliver(),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 180),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildBottomBar(),
        ],
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _buildBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (
          BuildContext context,
          Widget? child,
        ) {
          final double value = _glowController.value;

          return Stack(
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      background,
                      Color(0xFF040713),
                      backgroundDeep,
                    ],
                  ),
                ),
                child: SizedBox.expand(),
              ),

              // Main ChattªX cyan atmosphere.
              Positioned(
                top: -150 + (value * 18),
                right: -160,
                child: _glowCircle(
                  size: 340,
                  color: cyan,
                  alpha: 0.055,
                ),
              ),

              // Very restrained purple.
              Positioned(
                top: 240,
                left: -195,
                child: _glowCircle(
                  size: 300,
                  color: purple,
                  alpha: 0.022,
                ),
              ),

              // Small cyan lower glow.
              Positioned(
                bottom: 90,
                right: -190,
                child: _glowCircle(
                  size: 310,
                  color: cyan,
                  alpha: 0.025,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glowCircle({
    required double size,
    required Color color,
    required double alpha,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: alpha),
              blurRadius: 120,
              spreadRadius: 30,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        8,
        18,
        4,
      ),
      child: SizedBox(
        height: 78,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: _iconButton(
                icon: Icons.close_rounded,
                size: 28,
                onTap: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Create Story',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: cyan,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      'Share a moment. Inspire Infinity.',
                      style: TextStyle(
                        color: primaryText.withValues(
                          alpha: 0.55,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: purple.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Align(
              alignment: Alignment.centerRight,
              child: _buildMagicHeaderButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: primaryText.withValues(
                alpha: 0.90,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagicHeaderButton() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        final double alpha =
            0.045 + (_glowController.value * 0.035);

        return GestureDetector(
          onTap: _openAiVibe,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: surfaceDark,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: cyan.withValues(alpha: 0.30),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cyan.withValues(
                    alpha: alpha,
                  ),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: cyan,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CREATION CARDS
  // ============================================================

  Widget _buildCreationCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        16,
      ),
      child: SizedBox(
        height: 122,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _creationCard(
                icon: Icons.text_fields_rounded,
                title: 'Text',
                subtitle: 'Express',
                iconColor: cyan,
                onTap: _openText,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _creationCard(
                icon: Icons.music_note_rounded,
                title: 'Music',
                subtitle: 'Add a vibe',
                iconColor: cyan,
                onTap: _openMusic,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _creationCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Capture now',
                iconColor: primaryText,
                onTap: _openCamera,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: border,
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.18,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: iconColor.withValues(
                        alpha: 0.025,
                      ),
                      blurRadius: 45,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor == primaryText
                          ? surfaceRaised
                          : cyan.withValues(
                              alpha: 0.055,
                            ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 23,
                      color: iconColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText.withValues(
                        alpha: 0.48,
                      ),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA ROLL
  // ============================================================

  Widget _buildCameraRollHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        8,
      ),
      child: SizedBox(
        height: 42,
        child: Row(
          children: <Widget>[
            const Text(
              'Camera Roll',
              style: TextStyle(
                color: primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(width: 4),

            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: primaryText.withValues(
                alpha: 0.70,
              ),
              size: 22,
            ),

            const Spacer(),

            GestureDetector(
              onTap: () {
                setState(() {
                  _multipleSelection =
                      !_multipleSelection;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 200,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _multipleSelection
                      ? cyan.withValues(alpha: 0.07)
                      : surfaceDark,
                  borderRadius:
                      BorderRadius.circular(13),
                  border: Border.all(
                    color: _multipleSelection
                        ? cyan.withValues(alpha: 0.45)
                        : border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _multipleSelection
                          ? Icons.check_circle_rounded
                          : Icons
                              .check_circle_outline_rounded,
                      color: cyan,
                      size: 17,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      'Select multiple',
                      style: TextStyle(
                        color: cyan.withValues(
                          alpha: 0.90,
                        ),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        10,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: border,
            width: 0.9,
          ),
        ),
        child: Row(
          children: List<Widget>.generate(
            _filters.length,
            (int index) {
              final bool active =
                  _currentFilter == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentFilter = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? cyan.withValues(
                              alpha: 0.055,
                            )
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(9),
                      border: active
                          ? Border.all(
                              color: cyan.withValues(
                                alpha: 0.28,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _filterIcon(index),
                          size: 15,
                          color: active
                              ? cyan
                              : primaryText.withValues(
                                  alpha: 0.55,
                                ),
                        ),

                        const SizedBox(width: 4),

                        Flexible(
                          child: Text(
                            _filters[index],
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? primaryText
                                  : primaryText
                                      .withValues(
                                      alpha: 0.55,
                                    ),
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _filterIcon(int index) {
    switch (index) {
      case 1:
        return Icons.image_outlined;

      case 2:
        return Icons.play_circle_outline_rounded;

      case 3:
        return Icons.motion_photos_on_rounded;

      default:
        return Icons.grid_view_rounded;
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Widget _buildGallerySliver() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 150,
            ),
            child: SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: cyan,
              ),
            ),
          ),
        ),
      );
    }

    if (_permissionDenied) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildPermissionView(),
      );
    }

    final List<AssetEntity> assets =
        _filteredAssets;

    if (assets.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyGallery(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        0,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (
            BuildContext context,
            int index,
          ) {
            return _buildMediaTile(
              assets[index],
              index,
            );
          },
          childCount: assets.length,
        ),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 7,
          mainAxisSpacing: 7,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }

  Widget _buildMediaTile(
    AssetEntity asset,
    int index,
  ) {
    final bool selected = _isSelected(asset);
    final int number = _selectionNumber(asset);

    return GestureDetector(
      onTap: () {
        _toggleSelection(asset);
      },
      onLongPress: () {
        if (!_multipleSelection) {
          setState(() {
            _multipleSelection = true;
          });
        }

        _toggleSelection(asset);
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? cyan : border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: cyan.withValues(
                      alpha: 0.16,
                    ),
                    blurRadius: 13,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize:
                  ThumbnailSize.square(500),
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return Container(
                  color: surface,
                  child: Icon(
                    Icons
                        .image_not_supported_outlined,
                    color: primaryText.withValues(
                      alpha: 0.20,
                    ),
                  ),
                );
              },
            ),

            if (selected)
              Container(
                color: cyan.withValues(
                  alpha: 0.08,
                ),
              ),

            if (asset.type == AssetType.video)
              Positioned(
                right: 7,
                bottom: 7,
                child: _durationBadge(
                  asset.videoDuration,
                ),
              ),

            Positioned(
              top: 7,
              right: 7,
              child: _selectionCircle(
                selected: selected,
                number: number,
              ),
            ),

            if (selected)
              Positioned(
                left: 7,
                top: 7,
                child: _numberBadge(number),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTION CIRCLE
  // ============================================================

  Widget _selectionCircle({
    required bool selected,
    required int number,
  }) {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 180,
      ),
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? cyan
            : Colors.black.withValues(
                alpha: 0.28,
              ),
        border: Border.all(
          color: selected
              ? cyan
              : Colors.white.withValues(
                  alpha: 0.88,
                ),
          width: selected ? 1.2 : 1.5,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: cyan.withValues(
                    alpha: 0.40,
                  ),
                  blurRadius: 9,
                ),
              ]
            : null,
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              color: backgroundDeep,
              size: 17,
            )
          : null,
    );
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: surface,
        border: Border.all(
          color: cyan.withValues(
            alpha: 0.55,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cyan.withValues(
              alpha: 0.18,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: primaryText,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO DURATION
  // ============================================================

  Widget _durationBadge(Duration duration) {
    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.68,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Text(
        '$minutes:${twoDigits(seconds)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // PERMISSION VIEW
  // ============================================================

  Widget _buildPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyan.withValues(
                  alpha: 0.05,
                ),
                border: Border.all(
                  color: cyan.withValues(
                    alpha: 0.18,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: cyan.withValues(
                      alpha: 0.07,
                    ),
                    blurRadius: 25,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: cyan,
                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Gallery access needed',
              style: TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Allow ChattªX to access your photos '
              'and videos so you can create stories.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryText.withValues(
                  alpha: 0.56,
                ),
                height: 1.4,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: _handlePhotoPermission,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cyan.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: cyan.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyan.withValues(
                        alpha: 0.07,
                      ),
                      blurRadius: 16,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.photo_library_outlined,
                      color: cyan,
                      size: 18,
                    ),

                    SizedBox(width: 8),

                    Text(
                      'Allow Photos',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight:
                            FontWeight.w800,
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

  // ============================================================
  // EMPTY GALLERY
  // ============================================================

  Widget _buildEmptyGallery() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.photo_library_outlined,
            size: 52,
            color: primaryText.withValues(
              alpha: 0.18,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'No media found',
            style: TextStyle(
              color: primaryText.withValues(
                alpha: 0.65,
              ),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Photos and videos will appear here.',
            style: TextStyle(
              color: primaryText.withValues(
                alpha: 0.38,
              ),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 22,
            sigmaY: 22,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              14,
              11,
              14,
              18,
            ),
            decoration: BoxDecoration(
              color: backgroundDeep.withValues(
                alpha: 0.92,
              ),
              border: Border(
                top: BorderSide(
                  color: border.withValues(
                    alpha: 0.90,
                  ),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSelectedMediaRow(),

                const SizedBox(height: 11),

                Row(
                  children: <Widget>[
                    _buildExpiration(),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _buildBottomProgress(),
                    ),

                    const SizedBox(width: 10),

                    _buildNextButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED MEDIA ROW
  // ============================================================

  Widget _buildSelectedMediaRow() {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount:
            _selectedAssets.length + 1,
        separatorBuilder: (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          if (index ==
              _selectedAssets.length) {
            return _buildAddTile();
          }

          return _buildSelectedThumbnail(
            _selectedAssets[index],
            index,
          );
        },
      ),
    );
  }

  // ============================================================
  // SELECTED THUMBNAIL
  // ============================================================

  Widget _buildSelectedThumbnail(
    AssetEntity asset,
    int index,
  ) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child: AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize:
                    ThumbnailSize.square(180),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () {
                _removeSelection(asset);
              },
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface,
                  border: Border.all(
                    color:
                        primaryText.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: primaryText,
                ),
              ),
            ),
          ),

          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cyan,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: cyan.withValues(
                      alpha: 0.22,
                    ),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: backgroundDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD TILE
  // ============================================================

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: () {
        _scrollController.animateTo(
          0,
          duration: const Duration(
            milliseconds: 450,
          ),
          curve: Curves.easeOutCubic,
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(11),
          color: surfaceDark,
          border: Border.all(
            color: border,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 27,
          color: primaryText.withValues(
            alpha: 0.55,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXPIRATION
  // ============================================================

  Widget _buildExpiration() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surfaceDark,
            border: Border.all(
              color: cyan.withValues(
                alpha: 0.35,
              ),
              width: 1.3,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            '24',
            style: TextStyle(
              color: primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(width: 8),

        const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Story expires in',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: 3),

            Text(
              '24 hours',
              style: TextStyle(
                color: primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM PROGRESS
  // ============================================================

  Widget _buildBottomProgress() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        color: surfaceDark,
        border: Border.all(
          color: border,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 86,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      cyan.withValues(
                        alpha: 0.25,
                      ),
                      cyan,
                      cyan.withValues(
                        alpha: 0.25,
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cyan,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyan.withValues(
                        alpha: 0.45,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NEXT BUTTON
  // ============================================================

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _goNext,
      child: Container(
        height: 44,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 17,
        ),
        decoration: BoxDecoration(
          color: cyan,
          borderRadius:
              BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cyan.withValues(
                alpha: 0.18,
              ),
              blurRadius: 14,
              spreadRadius: -3,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Next',
              style: TextStyle(
                color: backgroundDeep,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),

            SizedBox(width: 6),

            Icon(
              Icons.arrow_forward_rounded,
              color: backgroundDeep,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}