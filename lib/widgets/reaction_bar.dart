import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onAddEmoji;

  const ReactionBar({
    super.key,
    required this.onReactionSelected,
    required this.onAddEmoji,
  });

  static const List<String> reactions = [
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
    '👍',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xff202C33),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: .10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .55),
              blurRadius: 25,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in reactions)
              _ReactionButton(
                emoji: emoji,
                onTap: () {
                  onReactionSelected(emoji);
                },
              ),

            const SizedBox(width: 3),

            _AddReactionButton(
              onTap: onAddEmoji,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// REACTION BUTTON
// ============================================================

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() =>
      _ReactionButtonState();
}

class _ReactionButtonState
    extends State<_ReactionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTapDown: (_) {
        if (!mounted) return;

        setState(() {
          _pressed = true;
        });
      },

      onTapCancel: () {
        if (!mounted) return;

        setState(() {
          _pressed = false;
        });
      },

      onTapUp: (_) {
        if (!mounted) return;

        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedScale(
        scale: _pressed ? 1.28 : 1.0,
        duration: const Duration(
          milliseconds: 100,
        ),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 43,
          height: 43,
          child: Center(
            child: Text(
              widget.emoji,
              style: const TextStyle(
                fontSize: 27,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADD EMOJI
// ============================================================

class _AddReactionButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddReactionButton({
    required this.onTap,
  });

  @override
  State<_AddReactionButton> createState() =>
      _AddReactionButtonState();
}

class _AddReactionButtonState
    extends State<_AddReactionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTapDown: (_) {
        if (!mounted) return;

        setState(() {
          _pressed = true;
        });
      },

      onTapCancel: () {
        if (!mounted) return;

        setState(() {
          _pressed = false;
        });
      },

      onTapUp: (_) {
        if (!mounted) return;

        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedScale(
        scale: _pressed ? .88 : 1.0,
        duration: const Duration(
          milliseconds: 100,
        ),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .08),
            border: Border.all(
              color: Colors.white.withValues(alpha: .10),
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white70,
            size: 23,
          ),
        ),
      ),
    );
  }
}