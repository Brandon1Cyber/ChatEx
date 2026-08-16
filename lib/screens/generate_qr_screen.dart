import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GenerateQrScreen extends StatefulWidget {
  const GenerateQrScreen({super.key});

  @override
  State<GenerateQrScreen> createState() => _GenerateQrScreenState();
}

class _GenerateQrScreenState extends State<GenerateQrScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CHATTªX QR TRANSFER
  // ============================================================

  static const String _qrPrefix = 'CHATEX://TRANSFER/';

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  String qrData = '';

  int secondsRemaining = 60;

  Timer? _timer;

  bool waiting = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 6,
      end: 20,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _generateNewQr();
    _startTimer();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  // ============================================================
  // GENERATE QR
  // ============================================================

  void _generateNewQr() {
    final sessionId =
        DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      qrData = '$_qrPrefix$sessionId';
      waiting = true;
    });
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    secondsRemaining = 60;

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (secondsRemaining <= 1) {
          _generateNewQr();

          setState(() {
            secondsRemaining = 60;
            waiting = true;
          });
        } else {
          setState(() {
            secondsRemaining--;
          });
        }
      },
    );
  }

  // ============================================================
  // NEW QR
  // ============================================================

  void _newQr() {
    _generateNewQr();
    _startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: const Row(
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFF00D9FF),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'New ChattªX transfer QR generated.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COPY
  // ============================================================

  Future<void> _copyCode() async {
    if (qrData.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: qrData),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF00D9FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ChattªX transfer code copied.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _button({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF00D9FF),
  }) {
    return Expanded(
      child: SizedBox(
        height: 55,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(title),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFO TILE
  // ============================================================

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF050816),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'Receive Files',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                // ==================================================
                // HEADER ICON
                // ==================================================

                const Icon(
                  Icons.wifi_tethering_rounded,
                  size: 70,
                  color: Color(0xFF00D9FF),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Receive with ChattªX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ask another ChattªX user to scan your secure QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // QR CODE
                // ==================================================

                AnimatedBuilder(
                  animation: _glowAnimation,

                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),

                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x6600D9FF),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: 2,
                          ),
                        ],
                      ),

                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ==================================================
                // BUTTONS
                // ==================================================

                Row(
                  children: [
                    _button(
                      icon: Icons.refresh_rounded,
                      title: 'New QR',
                      onTap: _newQr,
                    ),

                    const SizedBox(width: 12),

                    _button(
                      icon: Icons.copy_rounded,
                      title: 'Copy',
                      onTap: _copyCode,
                      color: const Color(0xFF7B2FF7),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ==================================================
                // WAITING STATUS
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white10,
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,

                        decoration: const BoxDecoration(
                          color: Color(0x2200D9FF),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.sync,
                          color: Color(0xFF00D9FF),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waiting for another ChattªX user...',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'QR refreshes in $secondsRemaining seconds',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // INFORMATION
                // ==================================================

                _infoTile(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF00D9FF),
                  title: 'Secure ChattªX Session',
                  subtitle:
                      'Every QR generated has a unique transfer session.',
                ),

                _infoTile(
                  icon: Icons.flash_on_rounded,
                  iconColor: Colors.orange,
                  title: 'Fast Transfer',
                  subtitle:
                      'Connect instantly with nearby ChattªX devices.',
                ),

                _infoTile(
                  icon: Icons.lock_outline,
                  iconColor: Colors.greenAccent,
                  title: 'Private',
                  subtitle:
                      'Only the person who scans this QR can start the transfer.',
                ),

                const SizedBox(height: 11),

                // ==================================================
                // TRANSFER SESSION CARD
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),

                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6E2CF7),
                        Color(0xFF291A46),
                      ],
                    ),

                    borderRadius: BorderRadius.circular(24),

                    border: Border.all(
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),

                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 42,
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Transfer Session',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      SelectableText(
                        qrData,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius.circular(18),
                        ),

                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: Colors.white,
                              size: 18,
                            ),

                            const SizedBox(width: 8),

                            Text(
                              '$secondsRemaining s remaining',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // BRANDING
                // ==================================================

                const Text(
                  'Powered by',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 6),

                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF00D9FF),
                        Color(0xFF7B2FF7),
                      ],
                    ).createShader(bounds);
                  },

                  child: const Text(
                    'ChattªX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}