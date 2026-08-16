import 'package:flutter/material.dart';

class MessageMenu extends StatefulWidget {
  final VoidCallback? onReply;

  final VoidCallback? onCopy;
  final VoidCallback? onPin;
  final VoidCallback? onReport;

  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  final VoidCallback? onStar;

  final bool isStarred;

  // ============================================================
  // DELETE FOR EVERYONE PERMISSION
  // ============================================================
  //
  // true  = this is my message, so I can delete it for everyone
  // false = this is someone else's message
  //
  // Delete for me is ALWAYS available.
  //
  final bool canDeleteForEveryone;

  const MessageMenu({
    super.key,

    this.onReply,

    this.onCopy,
    this.onPin,
    this.onReport,

    this.onDeleteForMe,
    this.onDeleteForEveryone,

    this.onStar,

    this.isStarred = false,

    this.canDeleteForEveryone = false,
  });

  @override
  State<MessageMenu> createState() =>
      _MessageMenuState();
}

class _MessageMenuState
    extends State<MessageMenu> {

  String? _submenu;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: AnimatedSize(
        duration: const Duration(
          milliseconds: 180,
        ),

        curve: Curves.easeOut,

        child: AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 160,
          ),

          switchInCurve:
              Curves.easeOut,

          switchOutCurve:
              Curves.easeIn,

          layoutBuilder:
              (
            currentChild,
            previousChildren,
          ) {
            return Stack(
              alignment:
                  Alignment.topCenter,

              children: [
                ...previousChildren,

                if (currentChild != null)
                  currentChild,
              ],
            );
          },

          child:
              _submenu == "more"
                  ? _buildMoreMenu()
                  : _submenu == "delete"
                      ? _buildDeleteMenu()
                      : _buildMainMenu(),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN MENU
  // ============================================================

  Widget _buildMainMenu() {
    return _menuContainer(
      key: const ValueKey(
        "main_menu",
      ),

      children: [

        // ========================================================
        // REPLY
        // ========================================================

        _menuItem(
          icon:
              Icons.reply_rounded,

          title:
              "Reply",

          subtitle:
              "Reply to this message",

          onTap:
              widget.onReply,
        ),

        _divider(),

        // ========================================================
        // MORE
        // ========================================================

        _menuItem(
          icon:
              Icons.more_horiz_rounded,

          title:
              "More",

          subtitle:
              "Copy, pin or report",

          trailing:
              true,

          onTap: () {
            setState(() {
              _submenu =
                  "more";
            });
          },
        ),

        _divider(),

        // ========================================================
        // DELETE
        // ========================================================

        _menuItem(
          icon:
              Icons.delete_outline_rounded,

          title:
              "Delete",

          subtitle:
              "Choose how to delete",

          iconColor:
              Colors.redAccent,

          textColor:
              Colors.redAccent,

          trailing:
              true,

          onTap: () {
            setState(() {
              _submenu =
                  "delete";
            });
          },
        ),

        _divider(),

        // ========================================================
        // STAR
        // ========================================================

        _menuItem(
          icon:
              widget.isStarred
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,

          title:
              widget.isStarred
                  ? "Unstar message"
                  : "Star message",

          subtitle:
              widget.isStarred
                  ? "Remove message from starred"
                  : "Save this message",

          iconColor:
              const Color(
            0xffffc107,
          ),

          onTap:
              widget.onStar,
        ),
      ],
    );
  }

  // ============================================================
  // MORE MENU
  // ============================================================

  Widget _buildMoreMenu() {
    return _menuContainer(
      key: const ValueKey(
        "more_menu",
      ),

      children: [

        // ========================================================
        // BACK
        // ========================================================

        _backItem(
          title:
              "More",

          onTap: () {
            setState(() {
              _submenu =
                  null;
            });
          },
        ),

        _divider(),

        // ========================================================
        // COPY
        // ========================================================

        _menuItem(
          icon:
              Icons.copy_all_rounded,

          title:
              "Copy",

          subtitle:
              "Copy message text",

          onTap:
              widget.onCopy,
        ),

        _divider(),

        // ========================================================
        // PIN
        // ========================================================

        _menuItem(
          icon:
              Icons.push_pin_rounded,

          title:
              "Pin",

          subtitle:
              "Pin this message",

          iconColor:
              const Color(
            0xffB026FF,
          ),

          onTap:
              widget.onPin,
        ),

        _divider(),

        // ========================================================
        // REPORT
        // ========================================================

        _menuItem(
          icon:
              Icons.flag_outlined,

          title:
              "Report",

          subtitle:
              "Report this message",

          iconColor:
              Colors.orangeAccent,

          textColor:
              Colors.orangeAccent,

          onTap:
              widget.onReport,
        ),
      ],
    );
  }

  // ============================================================
  // DELETE MENU
  // ============================================================

  Widget _buildDeleteMenu() {

    final List<Widget> items = [

      // ========================================================
      // BACK
      // ========================================================

      _backItem(
        title:
            "Delete",

        onTap: () {
          setState(() {
            _submenu =
                null;
          });
        },
      ),

      _divider(),

      // ========================================================
      // DELETE FOR ME
      // ========================================================
      //
      // ALWAYS AVAILABLE.
      //
      // This option removes the message from the current user's
      // view only.
      //

      _menuItem(
        icon:
            Icons.delete_outline_rounded,

        title:
            "Delete for me",

        subtitle:
            "Remove it only from your chat",

        iconColor:
            Colors.redAccent,

        onTap:
            widget.onDeleteForMe,
      ),
    ];

    // ============================================================
    // DELETE FOR EVERYONE
    // ============================================================
    //
    // ONLY ADD THIS OPTION WHEN:
    //
    // widget.canDeleteForEveryone == true
    //
    // ChatScreen should pass:
    //
    // canDeleteForEveryone: isMe,
    //
    // Therefore:
    //
    // MY MESSAGE:
    //     Delete for me
    //     Delete for everyone
    //
    // THEIR MESSAGE:
    //     Delete for me
    //
    // ============================================================

    if (widget.canDeleteForEveryone) {

      items.add(
        _divider(),
      );

      items.add(
        _menuItem(
          icon:
              Icons.delete_forever_rounded,

          title:
              "Delete for everyone",

          subtitle:
              "Remove it from the chat",

          iconColor:
              Colors.red,

          textColor:
              Colors.redAccent,

          onTap:
              widget.onDeleteForEveryone,
        ),
      );
    }

    return _menuContainer(
      key: const ValueKey(
        "delete_menu",
      ),

      children:
          items,
    );
  }

  // ============================================================
  // CONTAINER
  // ============================================================

  Widget _menuContainer({
    required Key key,

    required List<Widget> children,
  }) {
    return Container(
      key:
          key,

      width:
          270,

      margin:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),

      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xff0D1528,
        ),

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xff00E5FF,
          ).withValues(
            alpha: .35,
          ),

          width:
              1,
        ),

        boxShadow: [

          // ======================================================
          // BLACK SHADOW
          // ======================================================

          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: .45,
            ),

            blurRadius:
                25,

            spreadRadius:
                1,

            offset:
                const Offset(
              0,
              8,
            ),
          ),

          // ======================================================
          // CYAN GLOW
          // ======================================================

          BoxShadow(
            color:
                const Color(
              0xff00E5FF,
            ).withValues(
              alpha: .08,
            ),

            blurRadius:
                18,

            spreadRadius:
                1,
          ),
        ],
      ),

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children:
            children,
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _backItem({
    required String title,

    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        16,
      ),

      child:
          Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),

        child:
            Row(
          children: [

            // ==================================================
            // BACK ICON
            // ==================================================

            Container(
              width:
                  36,

              height:
                  36,

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xff00E5FF,
                ).withValues(
                  alpha: .10,
                ),

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  const Icon(
                Icons.arrow_back_rounded,

                size:
                    20,

                color:
                    Color(
                  0xff00E5FF,
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            // ==================================================
            // TITLE
            // ==================================================

            Text(
              title,

              style:
                  const TextStyle(
                color:
                    Colors.white,

                fontSize:
                    15,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const Spacer(),

            // ==================================================
            // ARROW
            // ==================================================

            const Icon(
              Icons.keyboard_arrow_up_rounded,

              color:
                  Colors.white30,

              size:
                  20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _divider() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),

      child:
          Divider(
        height:
            1,

        thickness:
            .6,

        color:
            Colors.white.withValues(
          alpha: .07,
        ),
      ),
    );
  }

  // ============================================================
  // MENU ITEM
  // ============================================================

  Widget _menuItem({
    required IconData icon,

    required String title,

    required String subtitle,

    VoidCallback? onTap,

    Color iconColor =
        const Color(
      0xff00E5FF,
    ),

    Color textColor =
        Colors.white,

    bool trailing =
        false,
  }) {
    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),

          child:
              Row(
            children: [

              // ==================================================
              // ICON
              // ==================================================

              Container(
                width:
                    38,

                height:
                    38,

                decoration:
                    BoxDecoration(
                  color:
                      iconColor.withValues(
                    alpha: .10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  size:
                      21,

                  color:
                      iconColor,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              // ==================================================
              // TEXT
              // ==================================================

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      title,

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          TextStyle(
                        color:
                            textColor,

                        fontSize:
                            14.5,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Colors.white38,

                        fontSize:
                            10.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // TRAILING ARROW
              // ==================================================

              if (trailing)
                const Icon(
                  Icons.chevron_right_rounded,

                  color:
                      Colors.white30,

                  size:
                      21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}