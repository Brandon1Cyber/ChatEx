import 'dart:async';

import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;

  final VoidCallback onSend;

  final VoidCallback? onFrozenSend;

  final VoidCallback? onAttachment;

  final VoidCallback? onEmoji;

  final VoidCallback? onVoiceStart;

  final ValueChanged<String>? onChanged;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onFrozenSend,
    this.onAttachment,
    this.onEmoji,
    this.onVoiceStart,
    this.onChanged,
  });

  @override
  State<MessageInput> createState() =>
      _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool hasText = false;

  bool _showEmojiPicker = false;

  Timer? _frozenTimer;

  bool _holdingSend = false;

  double _frozenProgress = 0.0;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _onTextChanged,
    );

    hasText =
        widget.controller.text.trim().isNotEmpty;
  }

  void _onTextChanged() {
    if (!mounted) return;

    final value =
        widget.controller.text.trim().isNotEmpty;

    if (value != hasText) {
      setState(() {
        hasText = value;
      });
    }
  }

  // ============================================================
  // EMOJI BUTTON
  // ============================================================

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });

    if (_showEmojiPicker) {
      FocusScope.of(context).unfocus();
    }

    widget.onEmoji?.call();
  }

  // ============================================================
  // EMOJI SELECTED
  // ============================================================

  void _onEmojiSelected(
    Category? category,
    Emoji emoji,
  ) {
    final text = widget.controller.text;

    TextSelection selection =
        widget.controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || start > text.length) {
      start = text.length;
    }

    if (end < 0 || end > text.length) {
      end = start;
    }

    final newText = text.replaceRange(
      start,
      end,
      emoji.emoji,
    );

    final newCursorPosition =
        start + emoji.emoji.length;

    widget.controller.value =
        TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(
        offset: newCursorPosition,
      ),
    );

    _onTextChanged();

    widget.onChanged?.call(
      newText,
    );
  }

  // ============================================================
  // NORMAL SEND
  // ============================================================

  void _normalSend() {
    if (!hasText) return;

    widget.onSend();
  }

  // ============================================================
  // START FROZEN MESSAGE
  // ============================================================

  void _startFrozenSend() {
    if (!hasText) return;

    _frozenTimer?.cancel();

    setState(() {
      _holdingSend = true;
      _frozenProgress = 0.0;
    });

    final startedAt = DateTime.now();

    _frozenTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final elapsed =
            DateTime.now()
                .difference(startedAt)
                .inMilliseconds;

        final progress =
            (elapsed / 3000).clamp(0.0, 1.0);

        setState(() {
          _frozenProgress = progress;
        });

        if (progress >= 1.0) {
          timer.cancel();

          _holdingSend = false;

          setState(() {
            _frozenProgress = 0.0;
          });

          widget.onFrozenSend?.call();
        }
      },
    );
  }

  // ============================================================
  // CANCEL FROZEN MESSAGE
  // ============================================================

  void _cancelFrozenSend() {
    _frozenTimer?.cancel();

    _frozenTimer = null;

    if (!mounted) return;

    setState(() {
      _holdingSend = false;
      _frozenProgress = 0.0;
    });
  }

  // ============================================================
  // SEND BUTTON RELEASE
  // ============================================================

  void _releaseSend() {
    if (!_holdingSend) {
      _frozenTimer?.cancel();
      return;
    }

    _cancelFrozenSend();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ====================================================
          // MESSAGE INPUT
          // ====================================================

          Container(
            margin:
                const EdgeInsets.all(8),

            padding:
                const EdgeInsets.all(1.4),

            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(30),

              gradient:
                  const LinearGradient(
                begin:
                    Alignment.centerLeft,
                end:
                    Alignment.centerRight,
                colors: [
                  Color(0xff00C8FF),
                  Color(0xff5367FF),
                  Color(0xffB026FF),
                  Color(0xff00C8FF),
                ],
              ),

              boxShadow: [
  BoxShadow(
    color: const Color(0xff00C8FF).withValues(
      alpha: 0.10,
    ),
    blurRadius: 6,
    spreadRadius: 0,
  ),
  BoxShadow(
    color: const Color(0xff8A3DFF).withValues(
      alpha: 0.12,
    ),
    blurRadius: 8,
    spreadRadius: 0,
  ),
],
            ),

            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(0xff080D1C)
                        .withValues(
                  alpha: 0.96,
                ),

                borderRadius:
                    BorderRadius.circular(28),

                // Very subtle inner highlight
                border:
                    Border.all(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.025,
                  ),
                  width: 1,
                ),
              ),

              child: Row(
                children: [

                  // =================================================
                  // EMOJI
                  // =================================================

                  _iconButton(
                    _showEmojiPicker
                        ? Icons.keyboard_rounded
                        : Icons
                            .sentiment_satisfied_alt_rounded,
                    _toggleEmojiPicker,
                  ),

                  // =================================================
                  // ATTACHMENT
                  // =================================================

                  _iconButton(
                    Icons.attach_file_rounded,
                    widget.onAttachment,
                  ),

                  // =================================================
                  // MESSAGE TEXT
                  // =================================================

                  Expanded(
                    child: TextField(
                      controller:
                          widget.controller,

                      onChanged:
                          widget.onChanged,

                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() {
                            _showEmojiPicker =
                                false;
                          });
                        }
                      },

                      minLines: 1,

                      maxLines: 5,

                      textAlignVertical:
                          TextAlignVertical.center,

                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w400,
                      ),

                      cursorColor:
                          const Color(
                        0xffB026FF,
                      ),

                      decoration:
                          const InputDecoration(
                        hintText:
                            "Message...",

                        hintStyle:
                            TextStyle(
                          color:
                              Color(0xff766B9E),
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.w500,
                        ),

                        border:
                            InputBorder.none,

                        enabledBorder:
                            InputBorder.none,

                        focusedBorder:
                            InputBorder.none,

                        isDense:
                            true,

                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // SEND / MICROPHONE
                  // =================================================

                  GestureDetector(
                    onTap: hasText
                        ? _normalSend
                        : widget.onVoiceStart,

                    onLongPressStart:
                        hasText
                            ? (_) {
                                _startFrozenSend();
                              }
                            : null,

                    onLongPressEnd:
                        hasText
                            ? (_) {
                                _releaseSend();
                              }
                            : null,

                    onLongPressCancel:
                        hasText
                            ? _cancelFrozenSend
                            : null,

                    child: Stack(
                      alignment:
                          Alignment.center,

                      children: [

                        // =========================================
                        // FROZEN PROGRESS
                        // =========================================

                        SizedBox(
                          width: 48,
                          height: 48,

                          child:
                              _holdingSend
                                  ? CircularProgressIndicator(
                                      value:
                                          _frozenProgress,

                                      strokeWidth:
                                          3,

                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                              Color>(
                                        Color(
                                          0xff00E5FF,
                                        ),
                                      ),

                                      backgroundColor:
                                          Colors.white12,
                                    )
                                  : const SizedBox(),
                        ),

                        // =========================================
                        // MAIN BUTTON
                        // =========================================

                        Container(
                          width: 44,
                          height: 44,

                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,

                            gradient:
                                const LinearGradient(
                              begin:
                                  Alignment.topLeft,
                              end:
                                  Alignment.bottomRight,
                              colors: [
                                Color(
                                  0xffA52CFF,
                                ),
                                Color(
                                  0xff7137FF,
                                ),
                                Color(
                                  0xff00C8FF,
                                ),
                              ],
                            ),

                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(
                                  0xff8A3DFF,
                                ).withValues(
                                  alpha: 0.38,
                                ),
                                blurRadius:
                                    12,
                                spreadRadius:
                                    1,
                              ),
                            ],
                          ),

                          child:
                              Icon(
                            _holdingSend
                                ? Icons
                                    .ac_unit_rounded
                                : hasText
                                    ? Icons
                                        .send_rounded
                                    : Icons
                                        .mic_rounded,

                            color:
                                Colors.white,

                            size:
                                23,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====================================================
          // FROZEN MESSAGE INDICATOR
          // ====================================================

          if (_holdingSend)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 4,
              ),

              child: Text(
                "Keep holding to freeze • "
                "${(3 - (_frozenProgress * 3))
                    .clamp(0.0, 3.0)
                    .toStringAsFixed(1)}s",

                style:
                    const TextStyle(
                  color:
                      Color(0xff66E0FF),
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

          // ====================================================
          // EMOJI PICKER
          // ====================================================

          if (_showEmojiPicker)
            SizedBox(
              height:
                  300,

              child:
                  EmojiPicker(
                onEmojiSelected:
                    _onEmojiSelected,

                config:
                    Config(
                  height:
                      300,

                  checkPlatformCompatibility:
                      true,

                  emojiViewConfig:
                      EmojiViewConfig(
                    backgroundColor:
                        const Color(
                      0xff050816,
                    ),

                    columns:
                        7,

                    emojiSizeMax:
                        28,

                    verticalSpacing:
                        0,

                    horizontalSpacing:
                        0,
                  ),

                  categoryViewConfig:
                      const CategoryViewConfig(
                    backgroundColor:
                        Color(
                      0xff111827,
                    ),

                    indicatorColor:
                        Color(
                      0xffB026FF,
                    ),

                    iconColor:
                        Colors.white54,

                    iconColorSelected:
                        Color(
                      0xffB026FF,
                    ),
                  ),

                  bottomActionBarConfig:
                      const BottomActionBarConfig(
                    backgroundColor:
                        Color(
                      0xff111827,
                    ),

                    buttonColor:
                        Color(
                      0xff1A2235,
                    ),

                    buttonIconColor:
                        Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ICON BUTTON
  // ============================================================

  Widget _iconButton(
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        20,
      ),

      child:
          Padding(
        padding:
            const EdgeInsets.all(
          8,
        ),

        child:
            Icon(
          icon,

          color:
              const Color(
            0xffD7C8FF,
          ),

          size:
              22,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _frozenTimer?.cancel();

    widget.controller.removeListener(
      _onTextChanged,
    );

    super.dispose();
  }
}