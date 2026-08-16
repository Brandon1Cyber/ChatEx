import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final String text;

  const TypingIndicator({
    super.key,
    this.text = "Typing...",
  });

  @override
  State<TypingIndicator> createState() =>
      _TypingIndicatorState();
}

class _TypingIndicatorState
    extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value =
            (_controller.value + index * 0.2) % 1.0;

        return Opacity(
          opacity: 0.3 + (value * 0.7),
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0),
          _dot(1),
          _dot(2),

          const SizedBox(width: 10),

          Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}