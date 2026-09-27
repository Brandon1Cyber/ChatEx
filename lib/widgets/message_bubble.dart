import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatefulWidget {
  // ============================================================
  // MESSAGE
  // ============================================================

  final String type;
final String message;

final String imageUrl;
final String videoUrl;
final String documentUrl;

final String fileName;
final String mimeType;
final int fileSize;

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
// VOICE CALL
// ============================================================

final String callStatus;
final int callDuration;

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
    required this.imageUrl,
required this.videoUrl,
required this.documentUrl,

required this.fileName,
required this.mimeType,
required this.fileSize,
    required this.voiceUrl,
    required this.voiceDuration,
    this.voiceWaveform = const [],
    required this.time,
required this.isMe,
required this.isSeen,
required this.isDelivered,
this.callStatus = '',
this.callDuration = 0,
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

  StreamSubscription<PlayerState>? _playerStateSubscription;
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
)..repeat();

   _playerStateSubscription =
    _audioPlayer.playerStateStream.listen((state) async {
  if (!mounted) return;

  // ------------------------------------------------------------
  // NORMAL PLAY / PAUSE STATE
  // ------------------------------------------------------------

  setState(() {
    _isPlaying = state.playing;
  });

  if (state.playing) {
    _glowController.repeat(reverse: true);
  } else {
    _glowController.stop();
  }

  // ------------------------------------------------------------
  // AUDIO FINISHED
  // ------------------------------------------------------------

  if (state.processingState == ProcessingState.completed) {
    // Make absolutely sure playback has stopped.
    await _audioPlayer.pause();

    // Reset the player to the beginning.
    await _audioPlayer.seek(Duration.zero);

    if (!mounted) return;

    setState(() {
      _isPlaying = false;
      _position = Duration.zero;

      // Keep the speed button available after the user
      // has already played the voice note.
      _hasPlayed = true;
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
  // ============================================================
  // IMAGE
  // ============================================================

  if (widget.type == 'image' ||
      widget.type == 'photo' ||
      widget.type == 'camera' ||
      widget.type == 'gallery') {
    return widget.imageUrl.trim();
  }

  // ============================================================
  // VIDEO
  // ============================================================

  if (widget.type == 'video') {
    return widget.videoUrl.trim();
  }

  // ============================================================
  // DOCUMENT
  // ============================================================

  if (widget.type == 'document' ||
      widget.type == 'file' ||
      widget.type == 'pdf') {
    return widget.documentUrl.trim();
  }

  // ============================================================
  // VOICE
  // ============================================================

  if (widget.voiceUrl.trim().isNotEmpty) {
    return widget.voiceUrl.trim();
  }

  // ============================================================
  // LEGACY ATTACHMENT DATA
  // ============================================================

  final data = _attachmentData();

  final candidates = [
    data['url'],
    data['downloadUrl'],
    data['fileUrl'],
    data['mediaUrl'],
    data['imageUrl'],
    data['videoUrl'],
    data['documentUrl'],
  ];

  for (final candidate in candidates) {
    final value =
        candidate?.toString().trim() ?? '';

    if (value.isEmpty) {
      continue;
    }

    final uri =
        Uri.tryParse(value);

    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return value;
    }
  }

  return '';
}

  String _attachmentName() {
  if (widget.fileName.trim().isNotEmpty) {
    return widget.fileName.trim();
  }

  final data = _attachmentData();

  return data['fileName']
          ?.toString() ??
      data['name']
          ?.toString() ??
      data['title']
          ?.toString() ??
      'Attachment';
}

  String _attachmentMime() {
  if (widget.mimeType.trim().isNotEmpty) {
    return widget.mimeType.trim();
  }

  final data = _attachmentData();

  return data['mimeType']
          ?.toString() ??
      data['mime']
          ?.toString() ??
      '';
}

  // ============================================================
  // REAL VOICE WAVEFORM
  // ============================================================
  //
  // The waveform can arrive in two ways:
  //
  // 1. Directly through widget.voiceWaveform
  //
  // 2. Inside widget.message as JSON:
  //
  // {
  //   "url": "...",
  //   "waveform": [0.12, 0.35, 0.72, ...]
  // }
  //
  // This method safely converts both formats into List<double>.
  // ============================================================

  List<double> _extractWaveform(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    final result = <double>[];

    for (final value in raw) {
      double? parsed;

      if (value is num) {
        parsed = value.toDouble();
      } else if (value is String) {
        parsed = double.tryParse(value);
      }

      if (parsed == null) {
        continue;
      }

      if (parsed.isNaN || parsed.isInfinite) {
        continue;
      }

      result.add(parsed.clamp(0.0, 1.0));
    }

    return result;
  }

  List<double> _effectiveVoiceWaveform() {
    // ----------------------------------------------------------
    // FIRST: use the waveform directly supplied by ChatScreen.
    // ----------------------------------------------------------

    final direct = _extractWaveform(
      widget.voiceWaveform,
    );

    if (direct.isNotEmpty) {
      return direct;
    }

    // ----------------------------------------------------------
    // SECOND: try to recover the waveform from the message JSON.
    // ----------------------------------------------------------

    final data = _attachmentData();

    final rawWaveform =
        data['waveform'] ??
        data['voiceWaveform'] ??
        data['waveformData'] ??
        data['amplitudes'];

    final embedded = _extractWaveform(
      rawWaveform,
    );

    if (embedded.isNotEmpty) {
      return embedded;
    }

    return [];
  }

  // ============================================================
  // SINGLE EMOJI DETECTION
  // ============================================================

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

    if (text.contains(RegExp(r'\s'))) {
      return false;
    }

    final codePoints = text.runes.toList();

    if (codePoints.isEmpty) {
      return false;
    }

    if (_isSingleKeycapEmoji(codePoints)) {
      return true;
    }

    if (codePoints.length == 2 &&
        _isRegionalIndicator(codePoints[0]) &&
        _isRegionalIndicator(codePoints[1])) {
      return true;
    }

    bool foundEmoji = false;

    int i = 0;

    while (i < codePoints.length) {
      final codePoint = codePoints[i];

      if (_isVariationSelector(codePoint)) {
        i++;
        continue;
      }

      if (_isEmojiModifier(codePoint)) {
        if (!foundEmoji) {
          return false;
        }

        i++;
        continue;
      }

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

      if (codePoint == 0x20E3) {
        if (!foundEmoji) {
          return false;
        }

        i++;
        continue;
      }

      if (_isEmojiBase(codePoint)) {
        if (foundEmoji) {
          return false;
        }

        foundEmoji = true;
        i++;
        continue;
      }

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
    if (codePoint >= 0x1F000 &&
        codePoint <= 0x1FAFF) {
      return true;
    }

    if (codePoint >= 0x2600 &&
        codePoint <= 0x26FF) {
      return true;
    }

    if (codePoint >= 0x2700 &&
        codePoint <= 0x27BF) {
      return true;
    }

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

      if (_audioPlayer.processingState ==
          ProcessingState.idle) {
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
    final seconds = duration.inSeconds.clamp(
      0,
      359999,
    );

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
      margin: const EdgeInsets.only(
        bottom: 5,
      ),
      padding: const EdgeInsets.fromLTRB(
        7,
        5,
        7,
        5,
      ),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: .16)
            : const Color(0xff081225)
                .withValues(alpha: .72),
        borderRadius: BorderRadius.circular(7),
        border: Border(
          left: BorderSide(
            color: widget.isMe
                ? const Color(0xffD6B5FF)
                : const Color(0xff00D9FF),
            width: 2.2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tiny reply icon
          Icon(
            Icons.reply_rounded,
            size: 12,
            color: widget.isMe
                ? const Color(0xffE3CFFF)
                : const Color(0xff7DEBFF),
          ),

          const SizedBox(width: 5),

          // Reply content
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isMe ? 'You' : 'Reply',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe
                        ? const Color(0xffE3CFFF)
                        : const Color(0xff7DEBFF),
                    fontSize: 9.5,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  replyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    height: 1.05,
                    fontWeight: FontWeight.w400,
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

  // ============================================================
// CHATTªX MESSAGE COLOR SYSTEM
// ============================================================
//
// IMPORTANT:
// We are NOT adding new colors.
// These only reuse colors that already exist in this file.
//
// MY MESSAGES     -> existing purple system
// OTHER MESSAGES  -> existing blue/cyan system
// ============================================================

Color _messageAccentColor() {
  if (widget.isMe) {
    return const Color(0xffB026FF);
  }

  return const Color(0xff00D9FF);
}

Color _messageSecondaryAccentColor() {
  if (widget.isMe) {
    return const Color(0xffA866FF);
  }

  return const Color(0xff168BFF);
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
  return widget.isMe
      ? const Color(0xffA866FF)
      : const Color(0xff416A9D);
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
      maxWidth: MediaQuery.of(context).size.width * .78,
    ),
    child: IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          10,
          6,
          7,
          4,
        ),
        decoration: BoxDecoration(
          gradient: _messageGradient(),
          borderRadius: _bubbleRadius(),
          border: Border.all(
            color: _messageBorderColor().withValues(
              alpha: widget.isMe ? .78 : .62,
            ),
            width: 1.05,
          ),
          boxShadow: _messageShadows(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReplyPreview(),

            Text(
              widget.message,
              softWrap: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 2),

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
  color: _messageBorderColor()
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

                return SizedBox(
  height: 220,
  child: Center(
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: _messageAccentColor(),
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
    barrierColor: Colors.black.withValues(alpha: .94),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            // ============================================================
            // IMAGE
            // ============================================================

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

            // ============================================================
            // TOP RIGHT BUTTONS
            // ============================================================

            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ------------------------------------------------------
                  // SAVE BUTTON
                  // ------------------------------------------------------

                  GestureDetector(
                    onTap: () async {
                      await _saveDocumentImage(
                        url,
                        dialogContext,
                      );
                    },
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xff111827,
                        ).withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(
                            0xff00D9FF,
                          ).withValues(alpha: .65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xff00D9FF,
                            ).withValues(alpha: .12),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_rounded,
                            color: Color(0xff00D9FF),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ------------------------------------------------------
                  // CLOSE BUTTON
                  // ------------------------------------------------------

                  GestureDetector(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xff111827,
                        ).withValues(alpha: .92),
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
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _saveDocumentImage(
  String url,
  BuildContext dialogContext,
) async {
  try {
    final String cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This image has no download link.'),
          duration: Duration(seconds: 2),
        ),
      );

      return;
    }

    debugPrint('ChattªX SAVE IMAGE: $cleanUrl');

    // ------------------------------------------------------------------------
    // CHECK GALLERY PERMISSION
    // ------------------------------------------------------------------------

    bool hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
    }

    if (!hasAccess) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gallery permission is required to save this image.',
          ),
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving image...'),
        duration: Duration(seconds: 2),
      ),
    );

    // ------------------------------------------------------------------------
    // DOWNLOAD IMAGE
    // ------------------------------------------------------------------------

    final Uri? uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw Exception('Invalid image URL');
    }

    final http.Response response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Image download failed: HTTP ${response.statusCode}',
      );
    }

    final Uint8List imageBytes = response.bodyBytes;

    if (imageBytes.isEmpty) {
      throw Exception('Downloaded image is empty');
    }

    // ------------------------------------------------------------------------
    // SAVE DIRECTLY TO DEVICE GALLERY
    // ------------------------------------------------------------------------

    await Gal.putImageBytes(
      imageBytes,
      album: 'ChattªX',
      name: 'ChattªX_${DateTime.now().millisecondsSinceEpoch}',
    );

    debugPrint('ChattªX IMAGE SAVED SUCCESSFULLY');

    if (!mounted) return;

    // Close the image viewer after successful save.
    if (Navigator.of(dialogContext).canPop()) {
      Navigator.of(dialogContext).pop();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image saved to your gallery ✓'),
        duration: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    debugPrint(
      'ChattªX SAVE IMAGE ERROR: $e',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not save image: $e',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ============================================================================
// DOCUMENT BUBBLE — CHATTªX
// COMPACT + REAL DOCUMENT OPENING
// ============================================================================

Widget _buildDocumentBubble() {
  final String url = widget.documentUrl.trim();

  final String fileName =
    widget.fileName.trim().isNotEmpty
        ? widget.fileName.trim()
        : 'Document';

  // --------------------------------------------------------------------------
  // FILE EXTENSION
  // --------------------------------------------------------------------------

  String extension = '';

  final int dotIndex = fileName.lastIndexOf('.');

  if (dotIndex != -1 && dotIndex < fileName.length - 1) {
    extension = fileName.substring(dotIndex + 1).toUpperCase();
  }

  // --------------------------------------------------------------------------
  // DOCUMENT ICON
  // --------------------------------------------------------------------------

  IconData documentIcon = Icons.insert_drive_file_rounded;

  if (extension == 'PDF') {
    documentIcon = Icons.picture_as_pdf_rounded;
  } else if (['DOC', 'DOCX'].contains(extension)) {
    documentIcon = Icons.description_rounded;
  } else if (['XLS', 'XLSX', 'CSV'].contains(extension)) {
    documentIcon = Icons.table_chart_rounded;
  } else if (['PPT', 'PPTX'].contains(extension)) {
    documentIcon = Icons.slideshow_rounded;
  } else if (['ZIP', 'RAR', '7Z'].contains(extension)) {
    documentIcon = Icons.folder_zip_rounded;
  } else if (extension == 'TXT') {
    documentIcon = Icons.article_rounded;
  }

  // --------------------------------------------------------------------------
  // OPEN DOCUMENT
  // --------------------------------------------------------------------------

  Future<void> openDocument() async {
  final String cleanUrl = url.trim();

  debugPrint('ChattªX DOCUMENT TAP');
  debugPrint('ChattªX DOCUMENT URL: $cleanUrl');

  if (cleanUrl.isEmpty) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This document has no download link.'),
        duration: Duration(seconds: 2),
      ),
    );

    return;
  }

  final Uri? uri = Uri.tryParse(cleanUrl);

  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid document link.'),
        duration: Duration(seconds: 2),
      ),
    );

    return;
  }

  // ============================================================
  // IMAGE SENT AS A DOCUMENT
  // ============================================================

  final String lowerName = fileName.toLowerCase();
  final String lowerMime = _attachmentMime().toLowerCase();

  final bool isImageDocument =
      lowerMime.startsWith('image/') ||
      lowerName.endsWith('.jpg') ||
      lowerName.endsWith('.jpeg') ||
      lowerName.endsWith('.png') ||
      lowerName.endsWith('.webp') ||
      lowerName.endsWith('.gif') ||
      lowerName.endsWith('.bmp') ||
      lowerName.endsWith('.heic') ||
      lowerName.endsWith('.heif');

  if (isImageDocument) {
    _openFullImage(cleanUrl);
    return;
  }

  // ============================================================
  // REAL DOCUMENT
  // ============================================================

  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      debugPrint(
        'ChattªX DOCUMENT ERROR: launchUrl returned false',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this document.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    debugPrint(
      'ChattªX DOCUMENT OPEN ERROR: $e',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open this document.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

  // --------------------------------------------------------------------------
  // COMPACT DOCUMENT BUBBLE
  // --------------------------------------------------------------------------

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: openDocument,
    child: Container(
      width: 250,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xff050816),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
  color: _messageBorderColor()
      .withValues(alpha: 0.65),
  width: 1.1,
),
        boxShadow: [
          BoxShadow(
  color: _messageAccentColor()
      .withValues(alpha: 0.12),
  blurRadius: 10,
  spreadRadius: 1,
),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==================================================================
          // SMALL DOCUMENT ICON
          // ==================================================================

          Container(
            width: 48,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xff10152A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
  color: _messageAccentColor()
      .withValues(alpha: 0.30),
),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(34, 42),
                  painter: _DocumentPaperPainter(),
                ),

                Icon(
  documentIcon,
  color: _messageAccentColor(),
  size: 21,
),

                if (extension.isNotEmpty)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
  color: _messageAccentColor(),
  borderRadius: BorderRadius.circular(3),
),
                      child: Text(
                        extension.length > 5
                            ? extension.substring(0, 5)
                            : extension,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 9),

          // ==================================================================
          // FILE INFORMATION
          // ==================================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    if (extension.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _messageAccentColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          extension,
                          style: const TextStyle(
                            color: Color(0xff00D9FF),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    if (extension.isNotEmpty)
                      const SizedBox(width: 5),

                    const Text(
                      'DOCUMENT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 5),

          // ==================================================================
          // OPEN BUTTON
          // ==================================================================

          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
  color: _messageAccentColor()
      .withValues(alpha: 0.65),
),
            ),
            child: Icon(
  Icons.open_in_new_rounded,
  color: _messageAccentColor(),
  size: 15,
),
          ),
        ],
      ),
    ),
  );
}

  // ============================================================
  // MUSIC
  // ============================================================

  Widget _buildMusicBubble() {
    final String name = _attachmentName();

    final waveform = _effectiveVoiceWaveform();

    return Container(
      constraints:
          const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.all(10),
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
                    gradient: _messageGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: _messageAccentColor().withValues(
  alpha: .20 + glow * .20,
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
                            waveform: waveform,
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
        gradient: _messageGradient(),
        borderRadius: _bubbleRadius(),
        border: Border.all(
  color: _messageBorderColor()
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _messageGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _messageAccentColor().withValues(
  alpha: .30,
),
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
  color: _messageBorderColor()
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
              decoration: BoxDecoration(
  gradient: _messageGradient(),
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

  Widget _buildVideoBubble() {
  final url =
      widget.videoUrl.trim().isNotEmpty
          ? widget.videoUrl.trim()
          : _attachmentUrl();

  if (url.isEmpty) {
    return _buildAttachmentError(
      Icons.videocam_off_rounded,
      'Video unavailable',
    );
  }

  final uri = Uri.tryParse(url);

  if (uri == null ||
      (uri.scheme != 'https' &&
          uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return _buildAttachmentError(
      Icons.videocam_off_rounded,
      'Invalid video URL',
    );
  }

  return _ChattaxVideoBubble(
  url: url,
  time: widget.time,
  isMe: widget.isMe,
);
}
// ============================================================
// VOICE CALL
// ============================================================

Widget _buildVoiceCallBubble() {
  final bool outgoing = widget.isMe;

  final Color accent = _messageAccentColor();

  final Color glow = _messageAccentColor().withValues(
    alpha: outgoing ? .08 : .07,
  );

  final String status = widget.callStatus.toLowerCase();

  final bool unanswered =
      status == 'unanswered' ||
      status == 'missed';

  final String subtitle;

  if (unanswered) {
    subtitle = 'No answer';
  } else if (status == 'ended') {
    final durationText = _formatDuration(
      Duration(
        seconds: widget.callDuration,
      ),
    );

    subtitle = widget.callDuration > 0
        ? 'Call ended · $durationText'
        : 'Call ended';
  } else {
    subtitle = outgoing
        ? 'Outgoing'
        : 'Incoming';
  }

  return Container(
    constraints: const BoxConstraints(
      maxWidth: 175,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 7,
      vertical: 7,
    ),
    decoration: BoxDecoration(
      gradient: _messageGradient(),
      borderRadius: _bubbleRadius(),
      border: Border.all(
        color: accent.withValues(alpha: .48),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: glow,
          blurRadius: 13,
          spreadRadius: 0,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ======================================================
        // CALL ICON
        // ======================================================

        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _messageAccentColor().withValues(
              alpha: .10,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: .32),
              width: 1,
            ),
          ),
          child: Icon(
            unanswered
                ? Icons.phone_missed_rounded
                : Icons.phone_rounded,
            color: accent,
            size: 16,
          ),
        ),

        const SizedBox(width: 7),

        // ======================================================
        // CALL INFORMATION
        // ======================================================

        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice call',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            // ==================================================
            // SUBTITLE + TIME
            // ==================================================

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unanswered
                        ? accent.withValues(alpha: .90)
                        : Colors.white60,
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(width: 6),

                Text(
                  widget.time,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

  // ============================================================
  // VOICE
  // ============================================================

  Widget _buildVoiceBubble() {
  final screenWidth = MediaQuery.sizeOf(context).width;

  // Compact voice-note width.
  // This keeps the bubble comfortably sized without taking up
  // almost the entire screen.
  final double bubbleWidth = screenWidth < 500
      ? (screenWidth * 0.72).clamp(245.0, 340.0).toDouble()
      : (screenWidth * 0.50).clamp(340.0, 700.0).toDouble();

  return Align(
    alignment: widget.isMe
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      width: bubbleWidth,
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff081225),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
  width: 1.15,
  color: _messageAccentColor().withValues(alpha: .92),
),
        boxShadow: [
  BoxShadow(
    color: _messageAccentColor().withValues(alpha: .10),
    blurRadius: 14,
    spreadRadius: 1,
  ),
  BoxShadow(
    color: _messageSecondaryAccentColor().withValues(alpha: .12),
    blurRadius: 22,
    spreadRadius: -2,
  ),
],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ==========================================================
// PLAY BUTTON
// ==========================================================

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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _messageAccentColor().withValues(alpha: .10),
          border: Border.all(
            color: _messageAccentColor().withValues(alpha: .95),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff168CFF).withValues(
                alpha: .12 + glow * .14,
              ),
              blurRadius: 10 + glow * 5,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isPlaying)
              SizedBox(
                width: 43,
                height: 43,
                child: CircularProgressIndicator(
                  value: _progress(),
                  strokeWidth: 1.6,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(
                    Color(0xffB026FF),
                  ),
                ),
              ),

            Icon(
              _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 21,
            ),
          ],
        ),
      );
    },
  ),
),

const SizedBox(width: 3),

// ==========================================================
// REAL VOICE WAVEFORM
// ==========================================================

Expanded(
  child: SizedBox(
    height: 42,
    child: Padding(
      padding: const EdgeInsets.only(
        right: 1,
      ),
      child: CustomPaint(
        painter: _RealWaveformPainter(
          waveform: _effectiveVoiceWaveform(),
          progress: _progress(),
        ),
      ),
    ),
  ),
),

const SizedBox(width: 3),

          // ==========================================================
          // DURATION + MESSAGE TIME
          // ==========================================================

          SizedBox(
            width: 38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _voiceTime(),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  widget.time,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                if (_hasPlayed) ...[
                  const SizedBox(height: 5),

                  GestureDetector(
                    onTap: _changeSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .10),
                        ),
                      ),
                      child: Text(
                        '${_speed.toStringAsFixed(1)}×',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
  color: _messageBorderColor().withValues(alpha: .85),
  width: 1.1,
),
boxShadow: [
  BoxShadow(
    color: _messageAccentColor().withValues(alpha: .22),
    blurRadius: 20,
  ),
  BoxShadow(
    color: _messageSecondaryAccentColor().withValues(alpha: .10),
    blurRadius: 35,
  ),
],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        // ============================================================
        // LOCATION MAP
        // ============================================================

        SizedBox(
          height: 155,
          width: double.infinity,
          child: Container(
            // IMPORTANT:
            // Prevents the white flash while map tiles initialize.
            color: const Color(0xff070B18),

            child: hasLocation
                ? FlutterMap(
                    mapController:
                        _mapController,

                    options: MapOptions(
                      initialCenter:
                          position!,
                      initialZoom: 15.5,

                      interactionOptions:
                          const InteractionOptions(
                        flags:
                            InteractiveFlag.none,
                      ),
                    ),

                    children: [
                      // ==================================================
                      // MAP TILES
                      // ==================================================

                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.chattax.app',

                        // Keeps the map background dark while
                        // individual tiles are loading.
                        tileBuilder:
                            (
                          context,
                          tileWidget,
                          tile,
                        ) {
                          return Container(
                            color:
                                const Color(
                              0xff070B18,
                            ),
                            child:
                                tileWidget,
                          );
                        },
                      ),

                      // ==================================================
                      // LOCATION MARKER
                      // ==================================================

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
                                        blurRadius:
                                            18,
                                        spreadRadius:
                                            3,
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
                      color:
                          Colors.white38,
                      size: 35,
                    ),
                  ),
          ),
        ),

        // ============================================================
        // LOCATION INFORMATION
        // ============================================================

        Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(
    13,
    11,
    10,
    9,
  ),
  decoration: BoxDecoration(
    gradient: _messageGradient(),
    border: Border(
      top: BorderSide(
        color: _messageAccentColor().withValues(alpha: .75),
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
                  color: _messageAccentColor().withValues(alpha: .14),
                ),
                child: Icon(
  Icons.location_on_rounded,
  color: _messageAccentColor(),
  size: 19,
),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
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
                          TextOverflow
                              .ellipsis,
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

  // ==========================================================================
  // DEFROSTED MESSAGE
  // ==========================================================================
  // Keep the REAL message exactly the same size.
  // No "DEFROSTED" label.
  // No extra widget above the bubble.
  //
  // The message simply gets a subtle icy border/glow so it remains visually
  // unique while keeping the exact normal message footprint.
  // ==========================================================================

  if (revealed && !_showFrozenFlame) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9CCFFF)
                .withValues(alpha: .14),
            blurRadius: 12,
            spreadRadius: .5,
          ),
        ],
      ),
      child: _buildTextBubble(),
    );
  }

  // ==========================================================================
  // FROZEN MESSAGE
  // ==========================================================================

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

    onLongPressCancel: _cancelFrozenHold,

    child: Container(
      width: 285,
      constraints: const BoxConstraints(
        minHeight: 78,
        maxHeight: 96,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff30486A),
            Color(0xff17263D),
            Color(0xff0E1B2E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffB9D9FF)
              .withValues(alpha: .82),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffA8D5FF)
                .withValues(alpha: .16),
            blurRadius: 14,
            spreadRadius: .5,
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ------------------------------------------------------------------
          // FROZEN ICON
          // ------------------------------------------------------------------

          Container(
            width: 48,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xff101C30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xffB9D9FF)
                    .withValues(alpha: .35),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.ac_unit_rounded,
                color: Color(0xffD9EAFF),
                size: 27,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ------------------------------------------------------------------
          // FROZEN DETAILS
          // ------------------------------------------------------------------

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                const Text(
                  'FROZEN MESSAGE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xffD9EAFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .25,
                  ),
                ),

                const SizedBox(height: 5),

                if (!_showFrozenFlame)
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: Color(0xffC8E1FF),
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Hold for 3 seconds to reveal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xffC8DFFF),
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                if (_showFrozenFlame)
                  SizedBox(
                    height: 42,
                    child: _buildFrozenFlame(),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 7),

          // ------------------------------------------------------------------
          // TIME
          // ------------------------------------------------------------------

          Align(
            alignment: Alignment.bottomCenter,
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

  // ==========================================================================
  // DEFROSTED VOICE
  // ==========================================================================
  // The REAL voice bubble keeps its exact existing size.
  // There is NO "DEFROSTED" label.
  //
  // Only a very subtle icy glow is added around the existing voice bubble.
  // ==========================================================================

  if (revealed && !_showFrozenFlame) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9CCFFF)
                .withValues(alpha: .14),
            blurRadius: 12,
            spreadRadius: .5,
          ),
        ],
      ),
      child: _buildVoiceBubble(),
    );
  }

  // ==========================================================================
  // FROZEN VOICE
  // ==========================================================================

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

    onLongPressCancel: _cancelFrozenHold,

    child: Container(
      width: 285,
      constraints: const BoxConstraints(
        minHeight: 78,
        maxHeight: 96,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff30486A),
            Color(0xff17263D),
            Color(0xff0E1B2E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffB9D9FF)
              .withValues(alpha: .82),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffA8D5FF)
                .withValues(alpha: .16),
            blurRadius: 14,
            spreadRadius: .5,
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ------------------------------------------------------------------
          // VOICE FROZEN ICON
          // ------------------------------------------------------------------

          Container(
            width: 48,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xff101C30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xffB9D9FF)
                    .withValues(alpha: .35),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.mic_rounded,
                color: Color(0xffD9EAFF),
                size: 25,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ------------------------------------------------------------------
          // FROZEN VOICE DETAILS
          // ------------------------------------------------------------------

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                const Text(
                  'FROZEN VOICE NOTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xffD9EAFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .25,
                  ),
                ),

                const SizedBox(height: 5),

                if (!_showFrozenFlame)
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: Color(0xffC8E1FF),
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Hold for 3 seconds to reveal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xffC8DFFF),
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                if (_showFrozenFlame)
                  SizedBox(
                    height: 42,
                    child: _buildFrozenFlame(),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 7),

          // ------------------------------------------------------------------
          // TIME
          // ------------------------------------------------------------------

          Align(
            alignment: Alignment.bottomCenter,
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
    // ==========================================================

    else if (_isSingleEmojiMessage()) {
      bubble =
          _buildSingleEmojiMessage();
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
    // VIDEO
    // ==========================================================

else if (widget.type == 'video') {
  bubble = _buildVideoBubble();
}

    // ==========================================================
    // DOCUMENT
    // ==========================================================

    else if (widget.type == 'document' ||
        widget.type == 'file' ||
        widget.type == 'pdf') {
      bubble =
          _buildDocumentBubble();
    }

    // ==========================================================
    // MUSIC
    // ==========================================================

    else if (widget.type == 'music' ||
        widget.type == 'audio') {
      bubble =
          _buildMusicBubble();
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
      bubble =
          _buildLocationBubble();
    }

    // ==========================================================
    // VOICE
    // ==========================================================

    else if (widget.type == 'voice_call') {
  bubble = _buildVoiceCallBubble();
}
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
        // ============================================================
        // FROZEN FIRE EFFECT
        // ============================================================

        if (widget.isFrozen && _showFrozenFlame)
          _FrozenFireOverlay(
            animation: _flameController,
            borderRadius: _bubbleRadius(),
            child: bubble,
          )
        else
          bubble,

        _buildReactionPreview(),
      ],
    ),
  ),
);
  }
}

// ============================================================================
// DOCUMENT PAPER — CHATTªX
// ============================================================================

class _DocumentPaperPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0xff050816)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xff00D9FF)
          .withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = ui.Path();

    final double w = size.width;
    final double h = size.height;
    const double fold = 10;

    path.moveTo(4, 2);
    path.lineTo(w - fold - 2, 2);
    path.lineTo(w - 2, fold + 2);
    path.lineTo(w - 2, h - 2);
    path.lineTo(4, h - 2);
    path.close();

    canvas.drawPath(
      path,
      paint,
    );

    canvas.drawPath(
      path,
      borderPaint,
    );

    // Folded corner
    final foldPath = ui.Path();

    foldPath.moveTo(
      w - fold - 2,
      2,
    );

    foldPath.lineTo(
      w - fold - 2,
      fold + 2,
    );

    foldPath.lineTo(
      w - 2,
      fold + 2,
    );

    canvas.drawPath(
      foldPath,
      borderPaint,
    );

    // Document lines
    final linePaint = Paint()
      ..color = const Color(0xff00D9FF)
          .withValues(alpha: 0.22)
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final double y =
          h * 0.55 + (i * 6);

      canvas.drawLine(
        Offset(10, y),
        Offset(w - 10, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _DocumentPaperPainter
        oldDelegate,
  ) {
    return false;
  }
}

// ============================================================================
// REAL VOICE WAVEFORM — CHATTªX
// Uses ONLY the real microphone amplitude samples.
// Quiet sections remain visually quiet.
// ============================================================================

class _RealWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;

  const _RealWaveformPainter({
    required this.waveform,
    required this.progress,
  });

  // --------------------------------------------------------------------------
  // CHATTªX WAVEFORM COLORS
  // --------------------------------------------------------------------------

  static const List<Color> _waveColors = [
    Color(0xff00D9FF),
    Color(0xff08C8FF),
    Color(0xff168CFF),
    Color(0xff4E72FF),
    Color(0xff7B2FF7),
    Color(0xffA02CFF),
    Color(0xffB026FF),
    Color(0xffE42CFF),
  ];

  // --------------------------------------------------------------------------
  // PAINT
  // --------------------------------------------------------------------------

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (waveform.isEmpty) {
      _drawEmptyWaveform(canvas, size);
      return;
    }

    final samples = _prepareSamples();

    if (samples.isEmpty) {
      _drawEmptyWaveform(canvas, size);
      return;
    }

    final int bars = samples.length;

    final double centerY = size.height / 2;

    // Small side padding.
    const double horizontalPadding = 4.0;

    final double usableWidth =
        math.max(
          0,
          size.width - (horizontalPadding * 2),
        );

    // ------------------------------------------------------------------------
    // IMPORTANT:
    //
    // We deliberately leave MORE SPACE between waveform bars.
    //
    // The previous version used too many bars, making the waveform look like
    // one solid block.
    // ------------------------------------------------------------------------

    final double spacing = bars <= 1
        ? 0
        : usableWidth / (bars - 1);

    // ------------------------------------------------------------------------
    // PLAYED GRADIENT
    // ------------------------------------------------------------------------

    final shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: _waveColors,
    ).createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    // ------------------------------------------------------------------------
    // UNPLAYED GRADIENT
    // ------------------------------------------------------------------------

    final unplayedShader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0x6600D9FF),
        Color(0x664E72FF),
        Color(0x667B2FF7),
        Color(0x66B026FF),
        Color(0x66E42CFF),
      ],
    ).createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    // ------------------------------------------------------------------------
    // START DOT
    // ------------------------------------------------------------------------

    final dotPaint = Paint()
      ..color = const Color(0xff76C9FF)
          .withValues(alpha: .95)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        horizontalPadding,
        centerY,
      ),
      2.6,
      dotPaint,
    );

    // ------------------------------------------------------------------------
    // DRAW REAL SAMPLES
    // ------------------------------------------------------------------------

    for (int i = 0; i < bars; i++) {
      final double value = samples[i]
          .clamp(0.0, 1.0)
          .toDouble();

      final double x =
          horizontalPadding + (spacing * i);

      final double normalizedPosition =
          bars <= 1
              ? 0
              : i / (bars - 1);

      final bool played =
          normalizedPosition <= progress;

      // ----------------------------------------------------------------------
      // REAL AMPLITUDE
      // ----------------------------------------------------------------------
      //
      // IMPORTANT:
      //
      // We do NOT give quiet samples a minimum visual height like:
      //
      // 4 + amplitude * 44
      //
      // because that makes silence look like speech.
      //
      // Instead:
      //
      // silence      -> tiny line
      // quiet voice  -> small line
      // normal voice -> medium line
      // loud voice   -> large line
      // ----------------------------------------------------------------------

      double amplitude;

      if (value <= 0.003) {
        amplitude = 0.0;
      } else {
        amplitude = math.pow(
          value,
          0.90,
        ).toDouble();
      }

      // ----------------------------------------------------------------------
      // QUIET / SILENCE
      // ----------------------------------------------------------------------

      double barHeight;

      if (value <= 0.003) {
        // Almost complete silence.
        barHeight = 1.5;
      } else if (value <= 0.012) {
        // Extremely quiet.
        barHeight = 2.2;
      } else if (value <= 0.03) {
        // Very quiet speech / breathing.
        barHeight = 3.5;
      } else {
        // Actual recorded amplitude.
        barHeight =
            3.0 + (amplitude * 39.0);
      }

      barHeight = barHeight.clamp(
        1.5,
        size.height - 5.0,
      );

      final double top =
          centerY - (barHeight / 2);

      final double bottom =
          centerY + (barHeight / 2);

      // ----------------------------------------------------------------------
      // VERY QUIET SAMPLE
      //
      // Do NOT add a large glow here.
      // This keeps silent sections visibly small.
      // ----------------------------------------------------------------------

      if (value > 0.012) {
        final glowPaint = Paint()
          ..shader = played
              ? shader
              : unplayedShader
          ..strokeWidth = value > 0.04
    ? 2.5
    : 1.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x, top),
          Offset(x, bottom),
          glowPaint,
        );
      }

      // ----------------------------------------------------------------------
      // MAIN WAVEFORM BAR
      // ----------------------------------------------------------------------

      final mainPaint = Paint()
        ..shader = played
            ? shader
            : unplayedShader
        ..strokeWidth = 1.35
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        mainPaint,
      );

      // ----------------------------------------------------------------------
      // BRIGHT PLAYED CORE
      // ----------------------------------------------------------------------

      if (played && value > 0.035) {
        final corePaint = Paint()
          ..shader = shader
          ..strokeWidth = 0.65
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x, top),
          Offset(x, bottom),
          corePaint,
        );
      }
    }

    // ------------------------------------------------------------------------
    // END DOT
    // ------------------------------------------------------------------------

    final endDotPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        size.width - horizontalPadding,
        centerY,
      ),
      1.8,
      endDotPaint,
    );
  }

  // ==========================================================================
  // PREPARE REAL SAMPLES
  // ==========================================================================

  List<double> _prepareSamples() {
    if (waveform.isEmpty) {
      return [];
    }

    final cleaned = <double>[];

    for (final raw in waveform) {
      if (raw.isNaN || raw.isInfinite) {
        continue;
      }

      cleaned.add(
        raw.clamp(
          0.0,
          1.0,
        ).toDouble(),
      );
    }

    if (cleaned.isEmpty) {
      return [];
    }

    // ------------------------------------------------------------------------
    // FEWER BARS = MORE SPACE BETWEEN THEM
    // ------------------------------------------------------------------------
    //
    // 80 gives the waveform breathing room.
    // The amplitude itself is still based on the actual recording.
    // ------------------------------------------------------------------------

    const int targetSamples = 48;

    if (cleaned.length <= targetSamples) {
      return cleaned;
    }

    final result = <double>[];

    final double bucketSize =
        cleaned.length / targetSamples;

    for (int i = 0; i < targetSamples; i++) {
      final int start =
          (i * bucketSize).floor();

      final int end =
          ((i + 1) * bucketSize)
              .floor()
              .clamp(
                start + 1,
                cleaned.length,
              );

      // ----------------------------------------------------------------------
      // IMPORTANT:
      //
      // Do NOT use the maximum/peak anymore.
      //
      // The previous code did:
      //
      // if (cleaned[j] > peak) {
      //   peak = cleaned[j];
      // }
      //
      // One loud sample could therefore make an entire section look loud.
      //
      // We now use an RMS-like average of the real samples in the bucket.
      // This preserves quiet sections much better.
      // ----------------------------------------------------------------------

      double sumSquares = 0.0;

      int count = 0;

      for (int j = start; j < end; j++) {
        final double sample =
            cleaned[j].clamp(
          0.0,
          1.0,
        );

        sumSquares +=
            sample * sample;

        count++;
      }

      if (count == 0) {
        result.add(0.0);
        continue;
      }

      final double rms =
          math.sqrt(
            sumSquares / count,
          );

      result.add(
        rms.clamp(
          0.0,
          1.0,
        ),
      );
    }

    return result;
  }

  // ==========================================================================
  // EMPTY WAVEFORM
  // ==========================================================================

  void _drawEmptyWaveform(
    Canvas canvas,
    Size size,
  ) {
    final double centerY =
        size.height / 2;

    final paint = Paint()
      ..color = const Color(0xff00D9FF)
          .withValues(alpha: .25)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(4, centerY),
      Offset(
        size.width - 4,
        centerY,
      ),
      paint,
    );
  }

  // ==========================================================================
  // REPAINT
  // ==========================================================================

  @override
  bool shouldRepaint(
    covariant _RealWaveformPainter oldDelegate,
  ) {
    if (oldDelegate.progress != progress) {
      return true;
    }

    if (oldDelegate.waveform.length !=
        waveform.length) {
      return true;
    }

    for (
      int i = 0;
      i < waveform.length;
      i++
    ) {
      if (oldDelegate.waveform[i] !=
          waveform[i]) {
        return true;
      }
    }

    return false;
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
class _ChattaxVideoBubble
    extends StatefulWidget {
  final String url;
final String time;
final bool isMe;

  const _ChattaxVideoBubble({
  required this.url,
  required this.time,
  required this.isMe,
});

  @override
  State<_ChattaxVideoBubble> createState() =>
      _ChattaxVideoBubbleState();
}

class _ChattaxVideoBubbleState
    extends State<_ChattaxVideoBubble> {
  late final VideoPlayerController
      _controller;

  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;

      setState(() {
        _ready = true;
      });
    }).catchError((error) {
      debugPrint(
        'ChattªX VIDEO LOAD ERROR: $error',
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  final Color borderColor = widget.isMe
      ? const Color(0xffA866FF)
      : const Color(0xff416A9D);

  final Color accentColor = widget.isMe
      ? const Color(0xffB026FF)
      : const Color(0xff00D9FF);

  return GestureDetector(
      onTap: () {
        if (!_ready) return;

        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Container(
        width: 270,
        height: 360,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
  color: borderColor.withValues(alpha: 0.65),
),
        ),
        clipBehavior:
            Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:
                      _controller.value.size.width,
                  height:
                      _controller.value.size.height,
                  child:
                      VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child:
                    CircularProgressIndicator(),
              ),

            if (_ready &&
                !_controller.value.isPlaying)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration:
                      const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Text(
                  widget.time,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),

            if (_ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child:
                    VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding:
                      EdgeInsets.zero,
                  colors: VideoProgressColors(
  playedColor: accentColor,
  bufferedColor: borderColor,
  backgroundColor: Colors.white24,
),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// ============================================================================
// CHATTªX — REAL FROZEN FIRE OVERLAY
// ============================================================================
//
// This is NOT an emoji.
//
// It draws animated flame tongues, glowing fire, embers and heat directly
// over the frozen message bubble.
//
// The effect covers the ENTIRE bubble.
// ============================================================================

class _FrozenFireOverlay extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final BorderRadius borderRadius;

  const _FrozenFireOverlay({
    required this.child,
    required this.animation,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,

          // ---------------------------------------------------------------
          // FIRE OVER THE WHOLE BUBBLE
          // ---------------------------------------------------------------

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FrozenFirePainter(
                  animation: animation,
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------------
          // SUBTLE HOT GLOW
          // ---------------------------------------------------------------

          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final pulse =
                      0.06 +
                      (math.sin(animation.value * math.pi * 2) + 1) *
                          0.025;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffff5a00)
                              .withValues(alpha: pulse),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xffffb300)
                              .withValues(alpha: pulse * .55),
                          blurRadius: 38,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REAL FIRE PAINTER
// ============================================================================

class _FrozenFirePainter extends CustomPainter {
final Animation<double> animation;

_FrozenFirePainter({
required this.animation,
}) : super(repaint: animation);

@override
void paint(
Canvas canvas,
Size size,
) {
if (size.width <= 0 || size.height <= 0) {
return;
}


final double t = animation.value * math.pi * 2;

// ------------------------------------------------------------------------
// WHOLE-BUBBLE FIRE HAZE
// ------------------------------------------------------------------------

final Paint hazePaint = Paint()
  ..shader = ui.Gradient.radial(
    Offset(
      size.width * .5,
      size.height * .55,
    ),
    math.max(
      size.width,
      size.height,
    ) * .72,
    [
      const Color(0xffff4500).withValues(alpha: .045),
      const Color(0xffff8c00).withValues(alpha: .025),
      Colors.transparent,
    ],
    [
      0.0,
      .48,
      1.0,
    ],
  );

canvas.drawRect(
  Offset.zero & size,
  hazePaint,
);

// ------------------------------------------------------------------------
// FLAME HEIGHT
// ------------------------------------------------------------------------

final double baseHeight = math.min(
  42.0,
  math.max(
    24.0,
    size.height * .32,
  ),
);

// ------------------------------------------------------------------------
// TOP FLAMES
// ------------------------------------------------------------------------

for (int i = 0; i < 11; i++) {
  final double x = size.width * (i / 10);

  final double wave =
      math.sin(t * 1.7 + i * 1.43);

  final double wave2 =
      math.sin(t * 2.4 + i * .91);

  final double height =
      baseHeight *
      (.62 + (wave + 1) * .16) *
      (.82 + (wave2 + 1) * .09);

  _drawFlame(
    canvas: canvas,
    base: Offset(x, 2),
    height: height,
    width: 15 + (i % 3) * 4.0,
    direction:
        math.sin(t + i * .8) * 4.0,
    outer: true,
  );
}

// ------------------------------------------------------------------------
// BOTTOM FLAMES
// ------------------------------------------------------------------------

for (int i = 0; i < 9; i++) {
  final double x =
      size.width * (i / 8);

  final double wave =
      math.sin(t * 1.5 + i * 1.21);

  final double height =
      baseHeight *
      (.42 + (wave + 1) * .14);

  _drawFlame(
    canvas: canvas,
    base: Offset(
      x,
      size.height - 2,
    ),
    height: height,
    width: 14 + (i % 2) * 5.0,
    direction:
        math.sin(t * 1.2 + i) * 3.5,
    outer: true,
    upsideDown: true,
  );
}

// ------------------------------------------------------------------------
// LEFT-SIDE FLAMES
// ------------------------------------------------------------------------

for (int i = 0; i < 6; i++) {
  final double y =
      size.height * (i / 5);

  final double wave =
      math.sin(t * 1.9 + i * 1.6);

  _drawSideFlame(
    canvas,
    Offset(2, y),
    18 + (wave + 1) * 6,
    true,
    t + i,
  );
}

// ------------------------------------------------------------------------
// RIGHT-SIDE FLAMES
// ------------------------------------------------------------------------

for (int i = 0; i < 6; i++) {
  final double y =
      size.height * (i / 5);

  final double wave =
      math.sin(t * 1.7 + i * 1.35);

  _drawSideFlame(
    canvas,
    Offset(
      size.width - 2,
      y,
    ),
    18 + (wave + 1) * 6,
    false,
    t + i,
  );
}

// ------------------------------------------------------------------------
// FLOATING EMBERS
// ------------------------------------------------------------------------

final Paint emberPaint = Paint()
  ..style = PaintingStyle.fill;

for (int i = 0; i < 24; i++) {
  final double seed = i * 17.731;

  final double phase =
      (t * (.35 + (i % 5) * .07) + seed) %
          (math.pi * 2);

  final double normalized =
      (math.sin(phase) + 1) / 2;

  final double x =
      (seed * 13.17) % size.width;

  final double y =
      size.height -
      ((seed * 7.31 +
              normalized *
                  size.height *
                  .9) %
          (size.height + 15));

  final double radius =
      0.8 + ((i % 3) * .45);

  if (i.isEven) {
    emberPaint.color =
        const Color(0xffffb300).withValues(
      alpha:
          .55 + normalized * .35,
    );
  } else {
    emberPaint.color =
        const Color(0xffff5722).withValues(
      alpha:
          .45 + normalized * .30,
    );
  }

  canvas.drawCircle(
    Offset(x, y),
    radius,
    emberPaint,
  );
}

// ------------------------------------------------------------------------
// HOT INNER GLOW
// ------------------------------------------------------------------------

final Paint glowPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..color =
      const Color(0xffff8a00).withValues(
    alpha:
        .18 +
        (math.sin(t * 2.0) + 1) * .06,
  );

final RRect glowRect =
    RRect.fromRectAndRadius(
  Rect.fromLTWH(
    1.5,
    1.5,
    math.max(
      0,
      size.width - 3,
    ),
    math.max(
      0,
      size.height - 3,
    ),
  ),
  const Radius.circular(17),
);

canvas.drawRRect(
  glowRect,
  glowPaint,
);

}

// ==========================================================================
// FLAME
// ==========================================================================

void _drawFlame({
required Canvas canvas,
required Offset base,
required double height,
required double width,
required double direction,
required bool outer,
bool upsideDown = false,
}) {
final double sign =
upsideDown ? -1.0 : 1.0;


// IMPORTANT:
// Explicitly use ui.Path so Flutter knows this is dart:ui Path.

final ui.Path outerPath =
    ui.Path();

final Offset p0 = base;

final Offset p1 = Offset(
  base.dx - width * .55,
  base.dy +
      sign * height * .35,
);

final Offset p2 = Offset(
  base.dx - width * .35,
  base.dy +
      sign * height * .72,
);

final Offset tip = Offset(
  base.dx + direction,
  base.dy +
      sign * height,
);

final Offset p3 = Offset(
  base.dx + width * .42,
  base.dy +
      sign * height * .55,
);

final Offset p4 = Offset(
  base.dx + width * .55,
  base.dy +
      sign * height * .22,
);

outerPath.moveTo(
  p0.dx,
  p0.dy,
);

outerPath.cubicTo(
  p1.dx,
  p1.dy,
  p2.dx,
  p2.dy,
  tip.dx,
  tip.dy,
);

outerPath.cubicTo(
  p3.dx,
  p3.dy,
  p4.dx,
  p4.dy,
  p0.dx,
  p0.dy,
);

outerPath.close();

final Paint outerPaint = Paint()
  ..style = PaintingStyle.fill
  ..shader = ui.Gradient.linear(
    Offset(
      base.dx,
      base.dy,
    ),
    Offset(
      tip.dx,
      tip.dy,
    ),
    [
      const Color(0xffff3d00)
          .withValues(alpha: .82),
      const Color(0xffff6d00)
          .withValues(alpha: .70),
      const Color(0xffffc107)
          .withValues(alpha: .48),
    ],
  );

canvas.drawPath(
  outerPath,
  outerPaint,
);

// ------------------------------------------------------------------------
// HOT INNER CORE
// ------------------------------------------------------------------------

final double innerHeight =
    height * .52;

final double innerWidth =
    width * .46;

final ui.Path innerPath =
    ui.Path();

final Offset innerBase =
    Offset(
  base.dx,
  base.dy + sign * 1.0,
);

final Offset innerTip =
    Offset(
  base.dx + direction * .35,
  base.dy +
      sign * innerHeight,
);

innerPath.moveTo(
  innerBase.dx,
  innerBase.dy,
);

innerPath.cubicTo(
  base.dx -
      innerWidth * .55,
  base.dy +
      sign *
          innerHeight *
          .30,
  base.dx -
      innerWidth * .25,
  base.dy +
      sign *
          innerHeight *
          .55,
  innerTip.dx,
  innerTip.dy,
);

innerPath.cubicTo(
  base.dx +
      innerWidth * .30,
  base.dy +
      sign *
          innerHeight *
          .55,
  base.dx +
      innerWidth * .55,
  base.dy +
      sign *
          innerHeight *
          .25,
  innerBase.dx,
  innerBase.dy,
);

innerPath.close();

final Paint innerPaint = Paint()
  ..style = PaintingStyle.fill
  ..color =
      const Color(0xfffff176)
          .withValues(alpha: .72);

canvas.drawPath(
  innerPath,
  innerPaint,
);

}

// ==========================================================================
// SIDE FLAME
// ==========================================================================

void _drawSideFlame(
Canvas canvas,
Offset base,
double height,
bool left,
double phase,
) {
final double direction =
math.sin(phase * 1.7) * 4;

final double sign =
    left ? 1.0 : -1.0;

// IMPORTANT:
// Explicitly use ui.Path.

final ui.Path path =
    ui.Path();

path.moveTo(
  base.dx,
  base.dy,
);

path.cubicTo(
  base.dx + sign * 3,
  base.dy - height * .25,
  base.dx + sign * 9,
  base.dy - height * .50,
  base.dx +
      sign * 4 +
      direction,
  base.dy - height,
);

path.cubicTo(
  base.dx - sign * 5,
  base.dy - height * .58,
  base.dx - sign * 3,
  base.dy - height * .22,
  base.dx,
  base.dy,
);

path.close();

final Paint paint = Paint()
  ..shader = ui.Gradient.linear(
    Offset(
      base.dx,
      base.dy,
    ),
    Offset(
      base.dx + sign * 4,
      base.dy - height,
    ),
    [
      const Color(0xffff3d00)
          .withValues(alpha: .72),
      const Color(0xffffb300)
          .withValues(alpha: .42),
      Colors.transparent,
    ],
  );

canvas.drawPath(
  path,
  paint,
);

}

@override
bool shouldRepaint(
covariant _FrozenFirePainter oldDelegate,
) {
return oldDelegate.animation !=
animation;
}
}
