import 'package:flutter/material.dart';

/// ChattaX — Reels Profile Screen
/// Pixel-styled recreation of the provided design.
/// Fully edge-to-edge (no SafeArea horizontal padding on the outer shell;
/// content areas carry their own internal padding to match the mock).
class ReelsProfileScreen extends StatelessWidget {
  const ReelsProfileScreen({super.key});

  static const Color bgBlack = Color(0xFF060309);
  static const Color neonBlue = Color(0xFF3DE1FF);
  static const Color neonPurple = Color(0xFFA24BFF);
  static const Color neonPink = Color(0xFFE23DFF);
  static const Color cardBorder = Color(0xFF5B2FA8);
  static const Color textGrey = Color(0xFFB6AFC4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // Full-bleed background
          Positioned.fill(
            child: Container(color: bgBlack),
          ),
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _buildBioCard(),
                        const SizedBox(height: 20),
                        _buildHighlightsSection(),
                        const SizedBox(height: 18),
                        _buildTabBar(),
                        const SizedBox(height: 2),
                        _buildReelsGrid(),
                        const SizedBox(height: 90), // leave room for bottom nav
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom nav pinned edge-to-edge
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(context),
          ),
        ],
      ),
    );
  }

  // ---------------- HEADER ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _NeonPlayTriangle(size: 22),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Colors.white, neonBlue],
                      ).createShader(rect),
                      child: const Text(
                        'Reels',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your ChattᵃX Reels',
                  style: TextStyle(
                    color: neonPurple,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _RoundedIconBox(
            icon: Icons.video_collection_outlined,
            withBadge: true,
          ),
          const SizedBox(width: 10),
          _RoundedIconBox(icon: Icons.menu),
        ],
      ),
    );
  }

  // ---------------- PROFILE CARD ----------------
  Widget _buildProfileCard() {
    return _GlowCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 130,
                height: 130,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [neonBlue, neonPurple, neonPink, neonBlue],
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://picsum.photos/seed/brandonhotshot/300/300',
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Chattᵃ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: 'X',
                                  style: TextStyle(
                                    color: neonBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: _EditFab(),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Brandon Hotshot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: neonBlue, size: 18),
                    const Spacer(),
                    Text(
                      'X',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: neonBlue.withValues(alpha: 0.9), blurRadius: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '@djbrandon01',
                  style: TextStyle(color: textGrey, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: neonPurple, width: 1.2),
                    color: neonPurple.withValues(alpha: 0.12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('👑', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 5),
                      Text(
                        'ELITE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    _StatItem(value: '469', label: 'Reels'),
                    SizedBox(width: 22),
                    _StatItem(value: '192', label: 'Following'),
                    SizedBox(width: 22),
                    _StatItem(value: '12.4K', label: 'Followers'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- BIO CARD ----------------
  Widget _buildBioCard() {
    return _GlowCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _BioLine(icon: Icons.people_alt_outlined, text: 'Artist 👑'),
                SizedBox(height: 10),
                _BioLine(icon: Icons.sports_tennis_outlined, text: 'Padel Addict 🎾📍'),
                SizedBox(height: 10),
                _BioLine(icon: Icons.phone_outlined, text: '+27 68 975 4328'),
                SizedBox(height: 10),
                _BioLine(icon: Icons.reply_outlined, text: 'Just curious…'),
                SizedBox(height: 10),
                _BioLine(
                  icon: Icons.link,
                  text: 'clsttckid.com/hyperfollow/djbrandon01/why-qhqghazq4a',
                  isLink: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EditFab(size: 38),
        ],
      ),
    );
  }

  // ---------------- HIGHLIGHTS ----------------
  Widget _buildHighlightsSection() {
    final highlights = [
      _HighlightData('Music', 'https://picsum.photos/seed/musicdeck/200/200', '🎵'),
      _HighlightData('Padel', 'https://picsum.photos/seed/padelcourt/200/200', '🎾'),
      _HighlightData('Lifestyle', 'https://picsum.photos/seed/citylife/200/200', '👑'),
      _HighlightData('Travel', 'https://picsum.photos/seed/planewing/200/200', '✈️'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const _NeonPlayTriangle(size: 16),
              const SizedBox(width: 8),
              const Text(
                'Reels Highlights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: neonPurple.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: neonPurple.withValues(alpha: 0.9), size: 18),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _HighlightBubble.newItem(),
              const SizedBox(width: 16),
              for (int i = 0; i < highlights.length; i++) ...[
                _HighlightBubble(data: highlights[i]),
                if (i != highlights.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- TAB BAR ----------------
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        children: [
          _TabIcon(icon: Icons.grid_view_rounded, active: false),
          _TabIcon(icon: Icons.smart_display_outlined, active: true),
          _TabIcon(icon: Icons.play_circle_outline, active: false),
          _TabIcon(icon: Icons.person_outline, active: false),
        ],
      ),
    );
  }

  // ---------------- REELS GRID ----------------
  Widget _buildReelsGrid() {
    final reels = [
      _ReelData('https://picsum.photos/seed/djnightclub/400/600', '12.6K'),
      _ReelData('https://picsum.photos/seed/padelnight/400/600', '8.4K'),
      _ReelData('https://picsum.photos/seed/citysunset/400/600', '21.3K'),
      _ReelData('https://picsum.photos/seed/carinterior/400/600', ''),
      _ReelData('', '', isText: true),
      _ReelData('https://picsum.photos/seed/nightroad/400/600', ''),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: reels.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (context, index) {
          final reel = reels[index];
          if (reel.isText) {
            return Container(
              color: bgBlack,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [neonPink, neonPurple, neonBlue],
                ).createShader(rect),
                child: const Text(
                  'DREAM\nPLAN\nEXECUTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(reel.imageUrl, fit: BoxFit.cover),
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.movie_creation_outlined, color: Colors.white, size: 16),
              ),
              if (reel.views.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        reel.views,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- BOTTOM NAV ----------------
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: bgBlack,
        border: Border(top: BorderSide(color: cardBorder.withValues(alpha: 0.4), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Icon(Icons.home_outlined, color: textGrey, size: 25),
          const Icon(Icons.public_outlined, color: textGrey, size: 25),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: neonPurple.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: neonPurple, width: 1.4),
            ),
            child: const Text(
              'X',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(Icons.chat_bubble_outline, color: textGrey, size: 24),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.person_outline, color: neonPurple, size: 25),
              SizedBox(height: 3),
              SizedBox(
                width: 22,
                child: Divider(color: neonPurple, thickness: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Reusable pieces
// =========================================================

class _GlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;

  const _GlowCard({
    required this.child,
    required this.margin,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0714),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReelsProfileScreen.cardBorder.withValues(alpha: 0.7), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: ReelsProfileScreen.neonPurple.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundedIconBox extends StatelessWidget {
  final IconData icon;
  final bool withBadge;
  const _RoundedIconBox({required this.icon, this.withBadge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReelsProfileScreen.cardBorder, width: 1.3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (withBadge)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ReelsProfileScreen.neonPurple,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditFab extends StatelessWidget {
  final double size;
  const _EditFab({this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B0714),
        border: Border.all(color: ReelsProfileScreen.neonBlue, width: 1.3),
      ),
      child: Icon(Icons.edit, color: ReelsProfileScreen.neonBlue, size: size * 0.45),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: ReelsProfileScreen.textGrey, fontSize: 12),
        ),
      ],
    );
  }
}

class _BioLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLink;
  const _BioLine({required this.icon, required this.text, this.isLink = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ReelsProfileScreen.neonBlue, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isLink ? ReelsProfileScreen.neonBlue : Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonPlayTriangle extends StatelessWidget {
  final double size;
  const _NeonPlayTriangle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.play_arrow_rounded,
      color: ReelsProfileScreen.neonPurple,
      size: size,
      shadows: [
        Shadow(color: ReelsProfileScreen.neonPurple.withValues(alpha:0.8), blurRadius: 10),
      ],
    );
  }
}

class _HighlightData {
  final String label;
  final String imageUrl;
  final String emoji;
  _HighlightData(this.label, this.imageUrl, this.emoji);
}

class _HighlightBubble extends StatelessWidget {
  final _HighlightData? data;
  final bool isNew;

  const _HighlightBubble({this.data}) : isNew = false;
  const _HighlightBubble.newItem()
      : data = null,
        isNew = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isNew
                ? null
                : const SweepGradient(
                    colors: [
                      ReelsProfileScreen.neonBlue,
                      ReelsProfileScreen.neonPurple,
                      ReelsProfileScreen.neonBlue,
                    ],
                  ),
            border: isNew
                ? Border.all(
                    color: ReelsProfileScreen.neonBlue,
                    width: 1.4,
                    style: BorderStyle.solid,
                  )
                : null,
          ),
          child: ClipOval(
            child: isNew
                ? const ColoredBox(
                    color: Color(0xFF0B0714),
                    child: Icon(Icons.add, color: Colors.white, size: 26),
                  )
                : Image.network(data!.imageUrl, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isNew ? 'New' : data!.label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}

class _TabIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const _TabIcon({required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: active ? ReelsProfileScreen.neonPurple : ReelsProfileScreen.textGrey,
            size: 24,
          ),
          const SizedBox(height: 6),
          if (active)
            Container(
              height: 2.5,
              width: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ReelsProfileScreen.neonBlue, ReelsProfileScreen.neonPurple],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            const SizedBox(height: 2.5),
        ],
      ),
    );
  }
}

class _ReelData {
  final String imageUrl;
  final String views;
  final bool isText;
  _ReelData(this.imageUrl, this.views, {this.isText = false});
}