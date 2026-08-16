import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';

class MessageBubble extends StatefulWidget {
  // ============================================================
  // MESSAGE
  // ============================================================

  final String type;
  final String message;

  // ============================================================
  // VOICE
  // ============================================================

  final String voiceUrl;
  final int voiceDuration;

  /// Authentic waveform generated from the actual recording.
  final List<double> voiceWaveform;

  // ============================================================
  // MESSAGE META
  // ============================================================

  final String time;

  final bool isMe;
  final bool isSeen;
  final bool isDelivered;

  // ============================================================
  // LOCATION
  // ============================================================

  final double? latitude;
  final double? longitude;

  // ============================================================
  // REPLY
  // ============================================================

  final bool isReply;
  final dynamic replyTo;

  // ============================================================
  // FREEZE
  // ============================================================

  final bool isFrozen;
  final bool isMelted;

  final Future Function()? onMelt;

  // ============================================================
  // REACTIONS
  // ============================================================

  final dynamic reactions;

  final Future<void> Function(String emoji)? onReaction;

  const MessageBubble({
    super.key,
    required this.type,
    required this.message,
    required this.voiceUrl,
    required this.voiceDuration,
    this.voiceWaveform = const [],
    required this.time,
    required this.isMe,
    required this.isSeen,
    required this.isDelivered,
    required this.isReply,
    required this.replyTo,
    required this.isFrozen,
    required this.isMelted,
    required this.reactions,
    this.latitude,
    this.longitude,
    this.onMelt,
    this.onReaction,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  // ============================================================
  // AUDIO
  // ============================================================

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription? _positionSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isPlaying = false;
  bool _hasPlayed = false;

  double _speed = 1.0;

  late final AnimationController _glowController;

  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController = MapController();

  LatLng? _lastMapPosition;

  // ============================================================
  // FROZEN
  // ============================================================

  Timer? _meltTimer;
  Timer? _flameTimer;

  bool _revealedFrozenMessage = false;
  bool _showFrozenFlame = false;

  late final AnimationController _flameController;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _playerStateSubscription =
        _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;
      });

      if (state.playing) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
      }

      if (state.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);

        if (!mounted) return;

        setState(() {
          _isPlaying = false;
          _hasPlayed = false;
          _speed = 1.0;
          _position = Duration.zero;
        });

        _glowController.stop();
      }
    });

    _durationSubscription =
        _audioPlayer.durationStream.listen((duration) {
      if (!mounted || duration == null) return;

      setState(() {
        _duration = duration;
      });
    });

    _positionSubscription =
        _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;

      setState(() {
        _position = position;
      });
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _meltTimer?.cancel();
    _flameTimer?.cancel();

    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();

    _audioPlayer.dispose();

    _glowController.dispose();
    _flameController.dispose();

    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _attachmentData() {
    if (widget.message.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(widget.message);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return {
      'url': widget.message,
    };
  }

  String _attachmentValue(
    String key, {
    String fallback = '',
  }) {
    final data = _attachmentData();

    final value = data[key];

    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  String _attachmentUrl() {
    final data = _attachmentData();

    return data['url']?.toString() ??
        data['downloadUrl']?.toString() ??
        data['fileUrl']?.toString() ??
        data['mediaUrl']?.toString() ??
        '';
  }

  String _attachmentName() {
    final data = _attachmentData();

    return data['fileName']?.toString() ??
        data['name']?.toString() ??
        data['title']?.toString() ??
        'Attachment';
  }

  String _attachmentMime() {
    final data = _attachmentData();

    return data['mimeType']?.toString() ??
        data['mime']?.toString() ??
        '';
  }

  // ============================================================
  // SINGLE EMOJI DETECTION
  // ============================================================

  /// Returns true only when the entire message is one visible emoji.
  ///
  /// Examples:
  ///
  /// 😀       -> true
  /// ❤️       -> true
  /// 👍🏽     -> true
  /// 👨‍💻     -> true
  /// 1️⃣      -> true
  ///
  /// 😀😀     -> false
  /// Hello 😀 -> false
  /// 😀 hello -> false
  bool _isSingleEmojiMessage() {
    if (widget.type != 'text' &&
        widget.type != 'message' &&
        widget.type != '') {
      return false;
    }

    final text = widget.message.trim();

    if (text.isEmpty) {
      return false;
    }

    // Never allow whitespace inside an emoji-only message.
    if (text.contains(RegExp(r'\s'))) {
      return false;
    }

    final codePoints = text.runes.toList();

    if (codePoints.isEmpty) {
      return false;
    }

    // ----------------------------------------------------------
    // KEYCAP EMOJI
    // Example: 1️⃣, #️⃣, *️⃣
    // ----------------------------------------------------------

    if (_isSingleKeycapEmoji(codePoints)) {
      return true;
    }

    // ----------------------------------------------------------
    // FLAGS
    //
    // Example:
    // 🇿🇦
    // 🇺🇸
    //
    // A flag is represented by two regional indicator
    // characters but visually counts as one emoji.
    // ----------------------------------------------------------

    if (codePoints.length == 2 &&
        _isRegionalIndicator(codePoints[0]) &&
        _isRegionalIndicator(codePoints[1])) {
      return true;
    }

    // ----------------------------------------------------------
    // GENERAL EMOJI SEQUENCE
    //
    // Supports:
    // 😀
    // ❤️
    // 👍🏽
    // 👨‍💻
    // 🏳️‍🌈
    // etc.
    // ----------------------------------------------------------

    bool foundEmoji = false;

    int i = 0;

    while (i < codePoints.length) {
      final codePoint = codePoints[i];

      // Variation selectors are part of the same emoji.
      if (_isVariationSelector(codePoint)) {
        i++;
        continue;
      }

      // Emoji skin tone modifier.
      if (_isEmojiModifier(codePoint)) {
        if (!foundEmoji) {
          return false;
        }

        i++;
        continue;
      }

      // Zero-width joiner connects multiple emoji pieces
      // into one visible emoji.
      if (codePoint == 0x200D) {
        if (!foundEmoji) {
          return false;
        }

        i++;

        if (i >= codePoints.length) {
          return false;
        }

        continue;
      }

      // Combining enclosing keycap.
      if (codePoint == 0x20E3) {
        if (!foundEmoji) {
          return false;
        }

        i++;
        continue;
      }

      if (_isEmojiBase(codePoint)) {
        if (foundEmoji) {
          // A second emoji base means this is something like:
          // 😀😀
          // ❤️🔥
          // 👍😂
          return false;
        }

        foundEmoji = true;
        i++;
        continue;
      }

      // Anything else means it isn't emoji-only.
      return false;
    }

    return foundEmoji;
  }

  bool _isSingleKeycapEmoji(List<int> codePoints) {
    if (codePoints.length < 2 ||
        codePoints.length > 3) {
      return false;
    }

    final first = codePoints.first;

    final bool validBase =
        (first >= 0x30 && first <= 0x39) ||
        first == 0x23 ||
        first == 0x2A;

    if (!validBase) {
      return false;
    }

    if (codePoints.contains(0x20E3)) {
      return true;
    }

    return false;
  }

  bool _isRegionalIndicator(int codePoint) {
    return codePoint >= 0x1F1E6 &&
        codePoint <= 0x1F1FF;
  }

  bool _isVariationSelector(int codePoint) {
    return codePoint == 0xFE0E ||
        codePoint == 0xFE0F ||
        (codePoint >= 0xE0100 &&
            codePoint <= 0xE01EF);
  }

  bool _isEmojiModifier(int codePoint) {
    return codePoint >= 0x1F3FB &&
        codePoint <= 0x1F3FF;
  }

  bool _isEmojiBase(int codePoint) {
    // Main Unicode emoji blocks.
    if (codePoint >= 0x1F000 &&
        codePoint <= 0x1FAFF) {
      return true;
    }

    // Miscellaneous symbols.
    if (codePoint >= 0x2600 &&
        codePoint <= 0x26FF) {
      return true;
    }

    // Dingbats.
    if (codePoint >= 0x2700 &&
        codePoint <= 0x27BF) {
      return true;
    }

    // Miscellaneous Technical.
    if (codePoint >= 0x2300 &&
        codePoint <= 0x23FF) {
      return true;
    }

    return false;
  }

  // ============================================================
  // SINGLE EMOJI MESSAGE
  // ============================================================

  Widget _buildSingleEmojiMessage() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 2,
          right: 2,
          top: 1,
          bottom: 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.message.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42,
                height: 1.0,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 5),

            Padding(
              padding: const EdgeInsets.only(
                bottom: 3,
              ),
              child: _buildTimeRow(
                emojiOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AUDIO PLAYBACK
  // ============================================================

  Future<void> _toggleVoice() async {
    final String url = widget.voiceUrl.isNotEmpty
        ? widget.voiceUrl
        : _attachmentUrl();

    if (url.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      if (_audioPlayer.processingState == ProcessingState.idle) {
        await _audioPlayer.setUrl(url);
      }

      if (_audioPlayer.processingState ==
          ProcessingState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }

      await _audioPlayer.setSpeed(_speed);

      if (mounted) {
        setState(() {
          _hasPlayed = true;
        });
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint(
        'ChattªX audio playback error: $e',
      );
    }
  }

  // ============================================================
  // AUDIO SPEED
  // ============================================================

  Future<void> _changeSpeed() async {
    if (!_hasPlayed) return;

    double nextSpeed;

    if (_speed == 1.0) {
      nextSpeed = 1.5;
    } else if (_speed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    if (!mounted) return;

    setState(() {
      _speed = nextSpeed;
    });

    try {
      await _audioPlayer.setSpeed(nextSpeed);
    } catch (e) {
      debugPrint(
        'ChattªX audio speed error: $e',
      );
    }
  }

  // ============================================================
  // DURATION
  // ============================================================

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 359999);

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _voiceTime() {
    if (_duration > Duration.zero) {
      return _formatDuration(_duration);
    }

    return _formatDuration(
      Duration(
        seconds: widget.voiceDuration,
      ),
    );
  }

  String _musicTime() {
    if (_duration > Duration.zero) {
      return _formatDuration(_duration);
    }

    final durationString = _attachmentValue(
      'duration',
    );

    final seconds =
        int.tryParse(durationString) ?? 0;

    return _formatDuration(
      Duration(seconds: seconds),
    );
  }

  double _progress() {
    if (_duration.inMilliseconds <= 0) {
      return 0;
    }

    return (
      _position.inMilliseconds /
      _duration.inMilliseconds
    ).clamp(0.0, 1.0);
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatus({
    bool emojiOnly = false,
  }) {
    if (!widget.isMe) {
      return const SizedBox.shrink();
    }

    Color statusColor;

    if (widget.isSeen) {
      statusColor = const Color(0xff00E5FF);
    } else if (widget.isDelivered) {
      statusColor = const Color(0xffC98CFF);
    } else {
      statusColor = const Color(0xff777783);
    }

    return Text(
      '∞',
      style: TextStyle(
        color: statusColor,
        fontSize: emojiOnly ? 13 : 17,
        height: .8,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTimeRow({
    bool emojiOnly = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.time,
          style: TextStyle(
            color: emojiOnly
                ? Colors.white60
                : Colors.white54,
            fontSize: emojiOnly ? 9.5 : 10.5,
          ),
        ),
        if (widget.isMe) ...[
          const SizedBox(width: 3),
          _buildStatus(
            emojiOnly: emojiOnly,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // REPLY
  // ============================================================

  Widget _buildReplyPreview() {
    if (!widget.isReply) {
      return const SizedBox.shrink();
    }

    String replyText = '';

    if (widget.replyTo is String) {
      replyText = widget.replyTo.toString();
    } else if (widget.replyTo is Map) {
      final map = Map<String, dynamic>.from(
        widget.replyTo as Map,
      );

      replyText =
          map['message']?.toString() ??
          map['text']?.toString() ??
          '';
    }

    if (replyText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(
        9,
        7,
        9,
        7,
      ),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: .16)
            : const Color(0xff081225)
                .withValues(alpha: .72),
        borderRadius: BorderRadius.circular(9),
        border: Border(
          left: BorderSide(
            color: widget.isMe
                ? const Color(0xffD6B5FF)
                : const Color(0xff00D9FF),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            widget.isMe ? 'You' : 'Reply',
            style: TextStyle(
              color: widget.isMe
                  ? const Color(0xffE3CFFF)
                  : const Color(0xff7DEBFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUBBLE STYLE
  // ============================================================

  BorderRadius _bubbleRadius() {
    if (widget.isMe) {
      return const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(5),
      );
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(5),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(18),
    );
  }

  Gradient _messageGradient() {
    if (widget.isMe) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xff8F20FF),
          Color(0xff7418F5),
          Color(0xff5A20E8),
        ],
      );
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xff172A46),
        Color(0xff101D32),
        Color(0xff0B1427),
      ],
    );
  }

  Color _messageBorderColor() {
    if (widget.isMe) {
      return const Color(0xffA866FF);
    }

    return const Color(0xff416A9D);
  }

  List<BoxShadow> _messageShadows() {
    if (widget.isMe) {
      return [
        BoxShadow(
          color: const Color(0xff7B20FF)
              .withValues(alpha: .30),
          blurRadius: 18,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: const Color(0xff315DFF)
              .withValues(alpha: .14),
          blurRadius: 28,
          spreadRadius: -3,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: .30),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    }

    return [
      BoxShadow(
        color: const Color(0xff168BFF)
            .withValues(alpha: .15),
        blurRadius: 16,
      ),
      BoxShadow(
        color: const Color(0xff7B2FFF)
            .withValues(alpha: .10),
        blurRadius: 24,
        spreadRadius: -3,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .38),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ============================================================
  // TEXT
  // ============================================================

  Widget _buildTextBubble() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * .82,
      ),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            11,
            8,
            8,
            5,
          ),
          decoration: BoxDecoration(
            gradient: _messageGradient(),
            borderRadius: _bubbleRadius(),
            border: Border.all(
              color: _messageBorderColor()
                  .withValues(
                alpha: widget.isMe ? .78 : .62,
              ),
              width: 1.05,
            ),
            boxShadow: _messageShadows(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildReplyPreview(),
              Text(
                widget.message,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: _buildTimeRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE / CAMERA / GALLERY
  // ============================================================

  Widget _buildImageBubble() {
    final String url = _attachmentUrl();

    if (url.isEmpty) {
      return _buildAttachmentError(
        Icons.image_not_supported_rounded,
        'Image unavailable',
      );
    }

    return GestureDetector(
      onTap: () {
        _openFullImage(url);
      },
      child: Container(
        width: 270,
        constraints: const BoxConstraints(
          maxHeight: 360,
        ),
        decoration: BoxDecoration(
          borderRadius: _bubbleRadius(),
          border: Border.all(
            color: const Color(0xffA866FF)
                .withValues(alpha: .65),
          ),
          boxShadow: _messageShadows(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.network(
              url,
              width: 270,
              fit: BoxFit.cover,
              loadingBuilder:
                  (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xffB026FF),
                    ),
                  ),
                );
              },
              errorBuilder:
                  (context, error, stackTrace) {
                return _buildAttachmentError(
                  Icons.broken_image_rounded,
                  'Unable to load image',
                );
              },
            ),
            Positioned(
              right: 8,
              bottom: 7,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withValues(alpha: .62),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: _buildTimeRow(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black
          .withValues(alpha: .94),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xff111827,
                      ).withValues(alpha: .9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(
                          0xffA866FF,
                        ).withValues(alpha: .6),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DOCUMENT
  // ============================================================

  Widget _buildDocumentBubble() {
    final String name = _attachmentName();
    final String mime = _attachmentMime();

    IconData icon = Icons.description_rounded;

    if (mime.contains('pdf') ||
        name.toLowerCase().endsWith('.pdf')) {
      icon = Icons.picture_as_pdf_rounded;
    } else if (name.toLowerCase().endsWith('.doc') ||
        name.toLowerCase().endsWith('.docx')) {
      icon = Icons.article_rounded;
    } else if (name.toLowerCase().endsWith('.xls') ||
        name.toLowerCase().endsWith('.xlsx')) {
      icon = Icons.table_chart_rounded;
    } else if (name.toLowerCase().endsWith('.zip') ||
        name.toLowerCase().endsWith('.rar')) {
      icon = Icons.folder_zip_rounded;
    }

    return Container(
      constraints:
          const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: _messageGradient(),
        borderRadius: _bubbleRadius(),
        border: Border.all(
          color: _messageBorderColor()
              .withValues(alpha: .72),
        ),
        boxShadow: _messageShadows(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xff9B5CFF)
                  .withValues(alpha: .15),
              borderRadius:
                  BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xffB77CFF)
                    .withValues(alpha: .45),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xffD6B5FF),
              size: 25,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mime.isNotEmpty
                      ? mime
                      : 'Document',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.download_rounded,
            color: Color(0xffC98CFF),
            size: 21,
          ),
          const SizedBox(width: 6),
          _buildTimeRow(),
        ],
      ),
    );
  }

  // ============================================================
  // MUSIC
  // ============================================================

  Widget _buildMusicBubble() {
    final String name = _attachmentName();

    return Container(
      constraints:
          const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff27164D),
            Color(0xff111A35),
            Color(0xff0A1328),
          ],
        ),
        borderRadius: _bubbleRadius(),
        border: Border.all(
          color: const Color(0xffA866FF)
              .withValues(alpha: .72),
        ),
        boxShadow: _messageShadows(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleVoice,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glow = _isPlaying
                    ? _glowController.value
                    : 0.0;

                return Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xff9B35FF),
                        Color(0xff5A20E8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xffA020FF,
                        ).withValues(
                          alpha:
                              .20 + glow * .20,
                        ),
                        blurRadius:
                            12 + glow * 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: CustomPaint(
                          painter:
                              _RealWaveformPainter(
                            waveform:
                                widget.voiceWaveform,
                            progress:
                                _progress(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _musicTime(),
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    if (_hasPlayed)
                      GestureDetector(
                        onTap: _changeSpeed,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.white
                                .withValues(
                              alpha: .10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(5),
                          ),
                          child: Text(
                            '${_speed.toStringAsFixed(1)}×',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    _buildTimeRow(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POLL
  // ============================================================

  Widget _buildPollBubble() {
    final data = _attachmentData();

    final String question =
        data['question']?.toString() ??
        'Poll';

    final dynamic rawOptions =
        data['options'];

    final List<String> options = [];

    if (rawOptions is List) {
      for (final option in rawOptions) {
        options.add(option.toString());
      }
    }

    final dynamic rawVotes =
        data['votes'];

    final Map<String, dynamic> votes =
        rawVotes is Map
            ? Map<String, dynamic>.from(
                rawVotes,
              )
            : {};

    int totalVotes = 0;

    for (final value in votes.values) {
      totalVotes +=
          int.tryParse(value.toString()) ?? 0;
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff251346),
            Color(0xff111A35),
            Color(0xff091226),
          ],
        ),
        borderRadius: _bubbleRadius(),
        border: Border.all(
          color: const Color(0xffA866FF)
              .withValues(alpha: .75),
        ),
        boxShadow: _messageShadows(),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xffB026FF),
                      Color(0xff6E20FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xffB026FF,
                      ).withValues(alpha: .30),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.poll_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'POLL',
                  style: TextStyle(
                    color:
                        Color(0xffD8B5FF),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
              _buildTimeRow(),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.25,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (options.isEmpty)
            const Text(
              'No options available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          for (int i = 0;
              i < options.length;
              i++)
            _buildPollOption(
              options[i],
              votes,
              totalVotes,
            ),
          const SizedBox(height: 5),
          Text(
            '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollOption(
    String option,
    Map<String, dynamic> votes,
    int totalVotes,
  ) {
    final int voteCount =
        int.tryParse(
              votes[option]?.toString() ??
                  '0',
            ) ??
            0;

    final double percentage =
        totalVotes > 0
            ? voteCount / totalVotes
            : 0;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 7,
      ),
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xff0A1226),
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xff51618A)
              .withValues(alpha: .48),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor:
                percentage.clamp(0.0, 1.0),
            child: Container(
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    Color(0xff6E20FF),
                    Color(0xffB026FF),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(percentage * 100).round()}%',
                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTACHMENT ERROR
  // ============================================================

  Widget _buildAttachmentError(
    IconData icon,
    String text,
  ) {
    return Container(
      width: 270,
      height: 110,
      decoration: BoxDecoration(
        gradient: _messageGradient(),
        borderRadius: _bubbleRadius(),
        border: Border.all(
          color: _messageBorderColor()
              .withValues(alpha: .65),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white54,
            size: 30,
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VOICE
  // ============================================================

  Widget _buildWaveform() {
    return SizedBox(
      width: 105,
      height: 32,
      child: CustomPaint(
        painter: _RealWaveformPainter(
          waveform: widget.voiceWaveform,
          progress: _progress(),
        ),
      ),
    );
  }

  Widget _buildVoiceBubble() {
    return Container(
      constraints:
          const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.fromLTRB(
        8,
        7,
        8,
        6,
      ),
      decoration: BoxDecoration(
        gradient: _messageGradient(),
        borderRadius: _bubbleRadius(),
        border: Border.all(
          color: _messageBorderColor()
              .withValues(
            alpha: widget.isMe ? .78 : .68,
          ),
          width: 1.05,
        ),
        boxShadow: _messageShadows(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleVoice,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glow = _isPlaying
                    ? _glowController.value
                    : 0.0;

                return Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xff152C50),
                        Color(0xff0A142A),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(
                        0xff4C7CFF,
                      ).withValues(alpha: .58),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xff287DFF,
                        ).withValues(alpha: .13),
                        blurRadius: 10,
                      ),
                      if (_isPlaying)
                        BoxShadow(
                          color: const Color(
                            0xffB026FF,
                          ).withValues(
                            alpha:
                                .15 +
                                glow * .20,
                          ),
                          blurRadius:
                              10 + glow * 8,
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment:
                        Alignment.center,
                    children: [
                      if (_isPlaying)
                        SizedBox(
                          width: 36,
                          height: 36,
                          child:
                              CircularProgressIndicator(
                            value:
                                _progress(),
                            strokeWidth: 1.8,
                            valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(
                              Color(
                                0xffC99BFF,
                              ),
                            ),
                          ),
                        ),
                      Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons
                                .play_arrow_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          _buildWaveform(),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    _voiceTime(),
                    style:
                        const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  if (_hasPlayed) ...[
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: _changeSpeed,
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withValues(
                            alpha: .10,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(5),
                        ),
                        child: Text(
                          '${_speed.toStringAsFixed(1)}×',
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              _buildTimeRow(),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Widget _locationDot() {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xffB98CFF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9B5CFF)
                .withValues(alpha: .75),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  void _updateLiveMapPosition() {
    if (widget.type != 'live_location') {
      return;
    }

    final latitude = widget.latitude;
    final longitude = widget.longitude;

    if (latitude == null || longitude == null) {
      return;
    }

    final newPosition =
        LatLng(latitude, longitude);

    if (_lastMapPosition != null &&
        _lastMapPosition!.latitude ==
            newPosition.latitude &&
        _lastMapPosition!.longitude ==
            newPosition.longitude) {
      return;
    }

    _lastMapPosition = newPosition;

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        _mapController.move(
          newPosition,
          15.5,
        );
      } catch (_) {}
    });
  }

  Widget _buildLocationBubble() {
    final bool isLive =
        widget.type == 'live_location';

    final bool hasLocation =
        widget.latitude != null &&
        widget.longitude != null;

    final LatLng? position = hasLocation
        ? LatLng(
            widget.latitude!,
            widget.longitude!,
          )
        : null;

    if (isLive && position != null) {
      _updateLiveMapPosition();
    }

    return Container(
      constraints:
          const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: const Color(0xff080D1C),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xff7A2CFF)
              .withValues(alpha: .85),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff6E20FF)
                .withValues(alpha: .22),
            blurRadius: 20,
          ),
          BoxShadow(
            color: const Color(0xff8D42FF)
                .withValues(alpha: .10),
            blurRadius: 35,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 155,
            width: double.infinity,
            child: hasLocation
                ? FlutterMap(
                    mapController:
                        _mapController,
                    options: MapOptions(
                      initialCenter: position!,
                      initialZoom: 15.5,
                      interactionOptions:
                          const InteractionOptions(
                        flags:
                            InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.chattax.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: position,
                            width: 70,
                            height: 70,
                            child: Stack(
                              alignment:
                                  Alignment.center,
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape
                                            .circle,
                                    color:
                                        const Color(
                                      0xff8B35FF,
                                    ).withValues(
                                      alpha: .08,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            const Color(
                                          0xff8B35FF,
                                        ).withValues(
                                          alpha: .30,
                                        ),
                                        blurRadius: 18,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons
                                      .location_on_rounded,
                                  color:
                                      Color(
                                    0xff9B35FF,
                                  ),
                                  size: 42,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(
                    child: Icon(
                      Icons
                          .location_off_rounded,
                      color: Colors.white38,
                      size: 35,
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.fromLTRB(
              13,
              11,
              10,
              9,
            ),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff151535),
                  Color(0xff0B1025),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: const Color(
                    0xff8C35FF,
                  ).withValues(alpha: .75),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xff7A2CFF,
                    ).withValues(alpha: .14),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color:
                        Color(0xffD0A0FF),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLocation
                            ? '${widget.latitude!.toStringAsFixed(5)}, '
                              '${widget.longitude!.toStringAsFixed(5)}'
                            : 'Location unavailable',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Color(0xff9293B5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTimeRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FROZEN HOLD
  // ============================================================

  void _startFrozenHold() {
    if (widget.isMe) return;

    if (widget.isMelted ||
        _revealedFrozenMessage) {
      return;
    }

    _meltTimer?.cancel();
    _flameTimer?.cancel();

    _meltTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted) return;

        setState(() {
          _showFrozenFlame = true;
        });

        _flameController
          ..reset()
          ..repeat(reverse: true);

        _flameTimer = Timer(
          const Duration(seconds: 1),
          () async {
            if (!mounted) return;

            _flameController.stop();

            setState(() {
              _showFrozenFlame = false;
              _revealedFrozenMessage = true;
            });

            try {
              await widget.onMelt?.call();
            } catch (e) {
              debugPrint(
                'ChattªX frozen message melt error: $e',
              );
            }
          },
        );
      },
    );
  }

  void _cancelFrozenHold() {
    _meltTimer?.cancel();
    _flameTimer?.cancel();

    _meltTimer = null;
    _flameTimer = null;

    if (_showFrozenFlame && mounted) {
      _flameController.stop();
      _flameController.reset();

      setState(() {
        _showFrozenFlame = false;
      });
    }
  }

  // ============================================================
  // FROZEN FLAME
  // ============================================================

  Widget _buildFrozenFlame() {
    return AnimatedBuilder(
      animation: _flameController,
      builder: (context, child) {
        final value =
            _flameController.value;

        final scale = .90 + value * .16;
        final glow = 10 + value * 12;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xff111827,
                ).withValues(alpha: .88),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(
                    0xffff8A3D,
                  ).withValues(alpha: .70),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xffff5A1F,
                    ).withValues(
                      alpha:
                          .28 + value * .20,
                    ),
                    blurRadius: glow,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'MELTING...',
                    style: TextStyle(
                      color:
                          Color(0xffffC27A),
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FROZEN TEXT
  // ============================================================

  Widget _buildFrozenTextBubble() {
    final revealed =
        widget.isMelted ||
        _revealedFrozenMessage;

    if (revealed && !_showFrozenFlame) {
      return _buildTextBubble();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) {
        if (!widget.isMe) {
          _startFrozenHold();
        }
      },
      onLongPressEnd: (_) {
        _cancelFrozenHold();
      },
      onLongPressCancel:
          _cancelFrozenHold,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 290,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xff30486A),
              Color(0xff17263D),
              Color(0xff0E1B2E),
            ],
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: const Color(
              0xffB9D9FF,
            ).withValues(alpha: .82),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xffA8D5FF,
              ).withValues(alpha: .20),
              blurRadius: 22,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.ac_unit_rounded,
                  color:
                      Color(0xffD9EAFF),
                  size: 32,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'FROZEN MESSAGE',
                        style: TextStyle(
                          color:
                              Color(0xffD9EAFF),
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'This message is frozen',
                        style: TextStyle(
                          color:
                              Color(0xffB9D4F5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_showFrozenFlame)
              const Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color:
                        Color(0xffC8E1FF),
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Hold for 3 seconds to reveal',
                      style: TextStyle(
                        color:
                            Color(0xffC8DFFF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            if (_showFrozenFlame)
              SizedBox(
                width: double.infinity,
                child:
                    _buildFrozenFlame(),
              ),
            const SizedBox(height: 5),
            Align(
              alignment:
                  Alignment.centerRight,
              child: _buildTimeRow(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FROZEN VOICE
  // ============================================================

  Widget _buildFrozenVoiceBubble() {
    final revealed =
        widget.isMelted ||
        _revealedFrozenMessage;

    if (revealed && !_showFrozenFlame) {
      return _buildVoiceBubble();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) {
        if (!widget.isMe) {
          _startFrozenHold();
        }
      },
      onLongPressEnd: (_) {
        _cancelFrozenHold();
      },
      onLongPressCancel:
          _cancelFrozenHold,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 290,
        ),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xff30486A),
              Color(0xff17263D),
              Color(0xff0E1B2E),
            ],
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: const Color(
              0xffB9D9FF,
            ).withValues(alpha: .82),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xffA8D5FF,
              ).withValues(alpha: .20),
              blurRadius: 22,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.ac_unit_rounded,
                  color:
                      Color(0xffD9EAFF),
                  size: 34,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'FROZEN VOICE NOTE',
                        style: TextStyle(
                          color:
                              Color(0xffD9EAFF),
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hold to reveal the voice note',
                        style: TextStyle(
                          color:
                              Color(0xffB9D4F5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_showFrozenFlame)
              const Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color:
                        Color(0xffC8E1FF),
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Hold for 3 seconds to reveal',
                      style: TextStyle(
                        color:
                            Color(0xffC8DFFF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            if (_showFrozenFlame)
              SizedBox(
                width: double.infinity,
                child:
                    _buildFrozenFlame(),
              ),
            const SizedBox(height: 5),
            Align(
              alignment:
                  Alignment.centerRight,
              child: _buildTimeRow(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  List<String> _extractReactionEmojis() {
    if (widget.reactions == null ||
        widget.reactions is! Map) {
      return [];
    }

    final reactions =
        Map<String, dynamic>.from(
      widget.reactions as Map,
    );

    if (reactions.isEmpty) {
      return [];
    }

    final emojis = <String>[];

    for (final entry in reactions.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (_looksLikeEmoji(key)) {
        final count =
            int.tryParse(
                  value.toString(),
                ) ??
                1;

        if (count > 0 &&
            !emojis.contains(key)) {
          emojis.add(key);
        }

        continue;
      }

      final emoji =
          value?.toString() ?? '';

      if (emoji.isNotEmpty &&
          _looksLikeEmoji(emoji) &&
          !emojis.contains(emoji)) {
        emojis.add(emoji);
      }
    }

    return emojis;
  }

  Future<void> _handleReaction(
    String emoji,
  ) async {
    if (emoji.isEmpty) return;

    if (widget.onReaction == null) {
      debugPrint(
        'ChattªX: onReaction callback is not connected.',
      );
      return;
    }

    try {
      await widget.onReaction!(emoji);
    } catch (e) {
      debugPrint(
        'ChattªX reaction error: $e',
      );
    }
  }

  Widget _buildReactionPreview() {
    final emojis =
        _extractReactionEmojis();

    if (emojis.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible =
        emojis.take(3).toList();

    return Align(
      alignment: widget.isMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: GestureDetector(
          behavior:
              HitTestBehavior.opaque,
          onTap: () async {
            if (visible.isNotEmpty) {
              await _handleReaction(
                visible.first,
              );
            }
          },
          child: Container(
            margin:
                const EdgeInsets.symmetric(
              horizontal: 7,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xff161A2B,
              ),
              borderRadius:
                  BorderRadius.circular(13),
              border: Border.all(
                color: const Color(
                  0xff506080,
                ).withValues(alpha: .55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: .38),
                  blurRadius: 7,
                ),
              ],
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                for (final emoji in visible)
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 1,
                    ),
                    child: Text(
                      emoji,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        height: 1,
                      ),
                    ),
                  ),
                if (emojis.length > 3)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      left: 2,
                    ),
                    child: Text(
                      '+',
                      style: TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _looksLikeEmoji(String text) {
    if (text.isEmpty) return false;

    if (text.length > 8) return false;

    final emojiPattern = RegExp(
      r'[\u{1F300}-\u{1FAFF}'
      r'\u{2600}-\u{27BF}'
      r'\u{2300}-\u{23FF}]',
      unicode: true,
    );

    return emojiPattern.hasMatch(text);
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    Widget bubble;

    // ==========================================================
    // FROZEN VOICE
    // ==========================================================

    if (widget.isFrozen &&
        widget.type == 'voice' &&
        (!widget.isMelted ||
            _showFrozenFlame)) {
      bubble =
          _buildFrozenVoiceBubble();
    }

    // ==========================================================
    // FROZEN TEXT
    // ==========================================================

    else if (widget.isFrozen &&
        (!widget.isMelted ||
            _showFrozenFlame)) {
      bubble =
          _buildFrozenTextBubble();
    }

    // ==========================================================
    // SINGLE EMOJI
    //
    // IMPORTANT:
    // This comes BEFORE normal text.
    //
    // One emoji = no background/bubble.
    // ==========================================================

    else if (_isSingleEmojiMessage()) {
      bubble = _buildSingleEmojiMessage();
    }

    // ==========================================================
    // CAMERA / GALLERY IMAGE
    // ==========================================================

    else if (widget.type == 'image' ||
        widget.type == 'photo' ||
        widget.type == 'camera' ||
        widget.type == 'gallery') {
      bubble = _buildImageBubble();
    }

    // ==========================================================
    // DOCUMENT
    // ==========================================================

    else if (widget.type == 'document' ||
        widget.type == 'file' ||
        widget.type == 'pdf') {
      bubble = _buildDocumentBubble();
    }

    // ==========================================================
    // MUSIC
    // ==========================================================

    else if (widget.type == 'music' ||
        widget.type == 'audio') {
      bubble = _buildMusicBubble();
    }

    // ==========================================================
    // POLL
    // ==========================================================

    else if (widget.type == 'poll') {
      bubble = _buildPollBubble();
    }

    // ==========================================================
    // LOCATION
    // ==========================================================

    else if (widget.type == 'location' ||
        widget.type == 'live_location') {
      bubble = _buildLocationBubble();
    }

    // ==========================================================
    // VOICE
    // ==========================================================

    else if (widget.type == 'voice') {
      bubble = _buildVoiceBubble();
    }

    // ==========================================================
    // TEXT
    // ==========================================================

    else {
      bubble = _buildTextBubble();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      child: Align(
        alignment: widget.isMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              widget.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            bubble,
            _buildReactionPreview(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REAL WAVEFORM
// ============================================================================

class _RealWaveformPainter
    extends CustomPainter {
  final List<double> waveform;
  final double progress;

  _RealWaveformPainter({
    required this.waveform,
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (waveform.isEmpty) {
      final paint = Paint()
        ..color = const Color(
          0xffDCE1FF,
        ).withValues(alpha: .30)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;

      final y = size.height / 2;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );

      return;
    }

    final int bars = waveform.length;

    if (bars == 1) {
      _drawBar(
        canvas: canvas,
        size: size,
        value: waveform.first,
        progress: progress,
        paintWidth: 2.5,
      );

      return;
    }

    const double horizontalPadding = 1;

    final double availableWidth =
        size.width -
        horizontalPadding * 2;

    final double spacing =
        availableWidth / (bars - 1);

    for (int i = 0; i < bars; i++) {
      final double value =
          waveform[i].clamp(0.0, 1.0);

      final double x =
          horizontalPadding +
          spacing * i;

      final bool played =
          (i / (bars - 1)) <= progress;

      final double height;

      if (value <= .025) {
        height = 1.4;
      } else if (value <= .05) {
        height = 2.2;
      } else {
        final scaled =
            math.pow(value, .72).toDouble();

        height =
            2.5 + scaled * 25.0;
      }

      final double top =
          (size.height - height) / 2;

      final paint = Paint()
        ..strokeWidth = 2.35
        ..strokeCap = StrokeCap.round;

      paint.color = played
          ? const Color(0xffD59BFF)
          : const Color(0xffE8E8FF)
              .withValues(alpha: .58);

      if (played && value > .08) {
        final glowPaint = Paint()
          ..color = const Color(
            0xffB026FF,
          ).withValues(alpha: .13)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + height),
          glowPaint,
        );
      }

      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        paint,
      );
    }
  }

  void _drawBar({
    required Canvas canvas,
    required Size size,
    required double value,
    required double progress,
    required double paintWidth,
  }) {
    final double height =
        value <= .025
            ? 1.4
            : 2.5 +
                math.pow(
                  value,
                  .72,
                ).toDouble() *
                    25;

    final double x =
        size.width / 2;

    final double top =
        (size.height - height) / 2;

    final paint = Paint()
      ..color = progress >= 1
          ? const Color(0xffD59BFF)
          : const Color(0xffE8E8FF)
              .withValues(alpha: .58)
      ..strokeWidth = paintWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(x, top),
      Offset(x, top + height),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _RealWaveformPainter oldDelegate,
  ) {
    return oldDelegate.waveform !=
            waveform ||
        oldDelegate.progress !=
            progress;
  }
}

// ============================================================================
// FROZEN HEXAGON
// ============================================================================

class _FrozenHexagonClipper
    extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();

    final w = size.width;
    final h = size.height;

    path.moveTo(w * .18, 0);
    path.lineTo(w * .82, 0);
    path.lineTo(w, h * .25);
    path.lineTo(w, h * .75);
    path.lineTo(w * .82, h);
    path.lineTo(w * .18, h);
    path.lineTo(0, h * .75);
    path.lineTo(0, h * .25);
    path.lineTo(w * .18, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant _FrozenHexagonClipper oldClipper,
  ) {
    return false;
  }
}

// ============================================================================
// FROZEN SNOWFLAKE
// ============================================================================

class _FrozenSnowflakePainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color =
          const Color(0xffD8EEFF)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        size.shortestSide * .31;

    for (int i = 0; i < 6; i++) {
      final angle =
          (math.pi / 3) * i;

      final end = Offset(
        center.dx +
            math.cos(angle) * radius,
        center.dy +
            math.sin(angle) * radius,
      );

      canvas.drawLine(
        center,
        end,
        paint,
      );

      final branchLength =
          radius * .42;

      final branchStart =
          radius * .48;

      final branchPoint = Offset(
        center.dx +
            math.cos(angle) *
                branchStart,
        center.dy +
            math.sin(angle) *
                branchStart,
      );

      final sideAngle1 =
          angle + math.pi / 5;

      final sideAngle2 =
          angle - math.pi / 5;

      final branchEnd1 = Offset(
        branchPoint.dx +
            math.cos(sideAngle1) *
                branchLength,
        branchPoint.dy +
            math.sin(sideAngle1) *
                branchLength,
      );

      final branchEnd2 = Offset(
        branchPoint.dx +
            math.cos(sideAngle2) *
                branchLength,
        branchPoint.dy +
            math.sin(sideAngle2) *
                branchLength,
      );

      canvas.drawLine(
        branchPoint,
        branchEnd1,
        paint,
      );

      canvas.drawLine(
        branchPoint,
        branchEnd2,
        paint,
      );
    }

    final centerPaint = Paint()
      ..color =
          const Color(0xffF1FAFF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      3.2,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _FrozenSnowflakePainter
        oldDelegate,
  ) {
    return false;
  }
}