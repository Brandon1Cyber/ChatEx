import 'package:flutter/material.dart';

class ChatexMapSearchBar extends StatefulWidget {
  final TextEditingController? controller;

  final String hintText;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final VoidCallback? onFilterPressed;

  final VoidCallback? onBackPressed;

  final bool showBackButton;

  const ChatexMapSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search ChattªX Maps',
    this.onChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.onBackPressed,
    this.showBackButton = false,
  });

  @override
  State<ChatexMapSearchBar> createState() =>
      _ChatexMapSearchBarState();
}

class _ChatexMapSearchBarState
    extends State<ChatexMapSearchBar> {
  late final TextEditingController
      _controller;

  bool _usingExternalController = false;

  // ============================================================
  // CHATTªX COLORS
  // ============================================================

  static const Color panel =
      Color(0xff101827);

  static const Color purple =
      Color(0xff8A3DFF);

  static const Color cyan =
      Color(0xff00E5FF);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _controller =
          widget.controller!;
      _usingExternalController = true;
    } else {
      _controller =
          TextEditingController();
    }

    _controller.addListener(
      _onTextChanged,
    );
  }

  // ============================================================
  // TEXT CHANGED
  // ============================================================

  void _onTextChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    if (widget.onChanged != null) {
      widget.onChanged!(
        _controller.text,
      );
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submitSearch() {
    final text =
        _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (widget.onSubmitted != null) {
      widget.onSubmitted!(text);
    }

    FocusScope.of(context).unfocus();
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void _clearSearch() {
    _controller.clear();

    FocusScope.of(context).unfocus();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        // ======================================================
        // BACK BUTTON
        // ======================================================

        if (widget.showBackButton)
          Padding(
            padding:
                const EdgeInsets.only(
              right: 9,
            ),
            child: _buildBackButton(),
          ),

        // ======================================================
        // SEARCH FIELD
        // ======================================================

        Expanded(
          child: Container(
            height: 50,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              color: panel.withValues(
                alpha: .97,
              ),
              borderRadius:
                  BorderRadius.circular(26),
              border: Border.all(
                color: purple.withValues(
                  alpha: .32,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(
                    alpha: .30,
                  ),
                  blurRadius: 16,
                  offset:
                      const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [

                // ==============================================
                // SEARCH ICON
                // ==============================================

                const Icon(
                  Icons.search_rounded,
                  color: cyan,
                  size: 21,
                ),

                const SizedBox(
                  width: 9,
                ),

                // ==============================================
                // TEXT FIELD
                // ==============================================

                Expanded(
                  child: TextField(
                    controller:
                        _controller,
                    textInputAction:
                        TextInputAction.search,
                    keyboardType:
                        TextInputType.text,
                    autocorrect: false,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w500,
                    ),
                    cursorColor: cyan,
                    onSubmitted: (_) {
                      _submitSearch();
                    },
                    decoration:
                        InputDecoration(
                      border:
                          InputBorder.none,
                      enabledBorder:
                          InputBorder.none,
                      focusedBorder:
                          InputBorder.none,
                      isDense: true,
                      hintText:
                          widget.hintText,
                      hintStyle:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // ==============================================
                // CLEAR BUTTON
                // ==============================================

                if (_controller
                    .text
                    .isNotEmpty)
                  GestureDetector(
                    onTap:
                        _clearSearch,
                    child:
                        const Padding(
                      padding:
                          EdgeInsets.all(
                        4,
                      ),
                      child: Icon(
                        Icons
                            .close_rounded,
                        color:
                            Colors.white60,
                        size: 19,
                      ),
                    ),
                  ),

                // ==============================================
                // FILTER BUTTON
                // ==============================================

                if (widget
                        .onFilterPressed !=
                    null)
                  Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      left: 5,
                    ),
                    child:
                        GestureDetector(
                      onTap: widget
                          .onFilterPressed,
                      child:
                          Container(
                        width: 30,
                        height: 30,
                        decoration:
                            BoxDecoration(
                          color: purple
                              .withValues(
                            alpha: .12,
                          ),
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            const Icon(
                          Icons
                              .tune_rounded,
                          color:
                              Colors.white70,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (widget.onBackPressed !=
            null) {
          widget.onBackPressed!();

          return;
        }

        Navigator.of(context).pop();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: panel.withValues(
            alpha: .97,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: purple.withValues(
              alpha: .35,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: .25,
              ),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.removeListener(
      _onTextChanged,
    );

    if (!_usingExternalController) {
      _controller.dispose();
    }

    super.dispose();
  }
}